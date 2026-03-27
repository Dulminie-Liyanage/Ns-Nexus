import 'package:flutter/material.dart';
import 'services/order_service.dart';
import 'order_review_screen.dart';

class WarehouseOrdersScreen extends StatefulWidget {
  const WarehouseOrdersScreen({super.key});

  @override
  State<WarehouseOrdersScreen> createState() => _WarehouseOrdersScreenState();
}

class _WarehouseOrdersScreenState extends State<WarehouseOrdersScreen> with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  List<dynamic> _allOrders = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;
  String? _advancingOrderId; // tracks which order is currently advancing (spinner guard)

  static const _stageNames = {
    1: 'Pending',
    2: 'Approved',
    3: 'Packing',
    4: 'Shipped',
    5: 'At Hub',
    6: 'Out for Delivery',
    7: 'Delivered',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    try {
      final allOrders = await _orderService.fetchAllOrders();
      if (!mounted) return;
      setState(() {
        _allOrders = allOrders;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _pendingOrders =>
      _allOrders.where((o) {
        final s = o['Status'] ?? '';
        return s == 'pending' || s == 'under_review';
      }).toList();

  List<dynamic> get _processingOrders =>
      _allOrders.where((o) {
        final s = o['Status'] ?? '';
        return s == 'approved' || s == 'partially_approved' || s == 'processing' || s == 'packing' || s == 'shipped' || s == 'at_hub' || s == 'out_for_delivery';
      }).toList();

  List<dynamic> get _deliveredOrders =>
      _allOrders.where((o) => (o['Status'] ?? '') == 'delivered').toList();

  List<dynamic> get _rejectedOrders =>
      _allOrders.where((o) => (o['Status'] ?? '') == 'rejected').toList();

  Future<void> _advanceNextStage(dynamic order) async {
    // Extract OrderID and force it to a clean integer string
    final rawId = order['OrderID'] ?? order['id'] ?? order['_id'];
    final orderId = int.tryParse(rawId.toString());
    
    if (orderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid OrderID: $rawId (type: ${rawId.runtimeType})')),
      );
      return;
    }

    // Prevent double-clicks
    setState(() => _advancingOrderId = orderId.toString());

    try {
      print('--- Next Stage ---');
      print('POST /orders/$orderId/next-stage');
      print('------------------');
      
      await _orderService.advanceNextStage(orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order advanced to next stage!')));
      await _loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 5)));
    } finally {
      if (mounted) setState(() => _advancingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'Pending (${_pendingOrders.length})'),
            Tab(text: 'Processing (${_processingOrders.length})'),
            Tab(text: 'History (${_deliveredOrders.length + _rejectedOrders.length})'),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPendingTab(),
                        _buildProcessingTab(),
                        _HistoryTabView(
                          deliveredOrders: _deliveredOrders,
                          rejectedOrders: _rejectedOrders,
                          onRefresh: _loadOrders,
                        ),
                      ],
                    ),
        ),
      ],
    );
  }

  // ────── TAB 1: PENDING ──────
  Widget _buildPendingTab() {
    if (_pendingOrders.isEmpty) return const Center(child: Text('No pending orders', style: TextStyle(fontSize: 18, color: Colors.grey)));

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        itemCount: _pendingOrders.length,
        itemBuilder: (context, index) {
          final order = _pendingOrders[index];
          return InkWell(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderReviewScreen(order: order)));
              _loadOrders();
            },
            child: _buildOrderCard(order, actionButton: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderReviewScreen(order: order)));
                  _loadOrders();
                },
                icon: const Icon(Icons.rate_review),
                label: const Text('Review Order'),
              ),
            )),
          );
        },
      ),
    );
  }

  // ────── TAB 2: PROCESSING ──────
  Widget _buildProcessingTab() {
    if (_processingOrders.isEmpty) return const Center(child: Text('No orders in processing', style: TextStyle(fontSize: 18, color: Colors.grey)));

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        itemCount: _processingOrders.length,
        itemBuilder: (context, index) {
          final order = _processingOrders[index];
          final status = order['Status'] ?? '';
          final currentStage = int.tryParse(order['CurrentStage']?.toString() ?? '2') ?? 2;
          final nextStage = (currentStage + 1).clamp(1, 7);
          final nextStageName = _stageNames[nextStage] ?? 'Next';
          final rawId = (order['OrderID'] ?? order['id'] ?? '').toString();
          final isAdvancing = _advancingOrderId == rawId;

          String buttonLabel;
          IconData buttonIcon;
          Color buttonColor;

          if (status == 'approved' || status == 'partially_approved') {
            buttonLabel = 'Start Packing';
            buttonIcon = Icons.inventory_2;
            buttonColor = Colors.orange;
          } else if (currentStage >= 7) {
            buttonLabel = 'Delivered ✓';
            buttonIcon = Icons.check_circle;
            buttonColor = Colors.green;
          } else {
            buttonLabel = 'Next Step → $nextStageName';
            buttonIcon = Icons.arrow_forward;
            buttonColor = Colors.blue;
          }

          return _buildOrderCard(order, actionButton: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (currentStage >= 7 || isAdvancing) ? null : () => _advanceNextStage(order),
              icon: isAdvancing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(buttonIcon),
              label: Text(isAdvancing ? 'Advancing...' : buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: isAdvancing ? buttonColor.withOpacity(0.7) : Colors.green.shade200,
              ),
            ),
          ));
        },
      ),
    );
  }

  Widget _buildOrderCard(dynamic order, {Widget? actionButton}) {
    final isUrgent = (order['IsUrgent'] == 1 || order['is_urgent'] == 1);
    final deliveryDate = order['DeliveryDate']?.toString().split('T')[0] ?? 'N/A';
    final shopName = order['ShopName'] ?? 'Unknown Shop';
    final retailerName = order['RetailerName'] ?? 'Unknown Retailer';
    final status = order['Status'] ?? 'unknown';
    final currentStage = int.tryParse(order['CurrentStage']?.toString() ?? '1') ?? 1;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('$shopName ($retailerName)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                if (isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                    child: const Text('URGENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Delivery: $deliveryDate', style: const TextStyle(color: Colors.grey)),
            Row(
              children: [
                Text('Status: $status', style: TextStyle(color: status == 'rejected' ? Colors.red : Colors.blueGrey, fontWeight: FontWeight.w500)),
                if (status != 'pending' && status != 'rejected' && status != 'delivered') ...[
                  const Text(' · ', style: TextStyle(color: Colors.grey)),
                  Text('Stage $currentStage/7: ${_stageNames[currentStage] ?? 'Unknown'}', style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                ],
              ],
            ),
            if (actionButton != null) ...[
              const SizedBox(height: 8),
              actionButton,
            ],
          ],
        ),
      ),
    );
  }
}

// ────── TAB 3: HISTORY (Segmented Control) ──────
class _HistoryTabView extends StatefulWidget {
  final List<dynamic> deliveredOrders;
  final List<dynamic> rejectedOrders;
  final Future<void> Function() onRefresh;

  const _HistoryTabView({required this.deliveredOrders, required this.rejectedOrders, required this.onRefresh});

  @override
  State<_HistoryTabView> createState() => _HistoryTabViewState();
}

class _HistoryTabViewState extends State<_HistoryTabView> {
  int _selectedSegment = 0; // 0 = Delivered, 1 = Rejected

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSegment = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedSegment == 0 ? Colors.green : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '✅ Delivered (${widget.deliveredOrders.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _selectedSegment == 0 ? Colors.white : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSegment = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedSegment == 1 ? Colors.red : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '❌ Rejected (${widget.rejectedOrders.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _selectedSegment == 1 ? Colors.white : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _selectedSegment == 0 ? _buildDeliveredList() : _buildRejectedList(),
        ),
      ],
    );
  }

  Widget _buildDeliveredList() {
    if (widget.deliveredOrders.isEmpty) return const Center(child: Text('No delivered orders yet', style: TextStyle(fontSize: 16, color: Colors.grey)));

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        itemCount: widget.deliveredOrders.length,
        itemBuilder: (context, index) {
          final order = widget.deliveredOrders[index];
          final shopName = order['ShopName'] ?? 'Unknown Shop';
          final retailerName = order['RetailerName'] ?? 'Unknown';
          final deliveryDate = order['DeliveryDate']?.toString().split('T')[0] ?? 'N/A';
          final orderDate = (order['CreatedAt'] ?? order['OrderDate'] ?? 'N/A').toString().split('T')[0];
          final totalPrice = order['TotalPrice']?.toString() ?? '0.00';
          final totalWeight = order['TotalWeight']?.toString() ?? '0.00';

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 28),
                      const SizedBox(width: 10),
                      Expanded(child: Text(retailerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Shop: $shopName', style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order Date: $orderDate'),
                      Text('Delivery: $deliveryDate'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Weight: ${totalWeight}kg', style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('Total: \$$totalPrice', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRejectedList() {
    if (widget.rejectedOrders.isEmpty) return const Center(child: Text('No rejected orders', style: TextStyle(fontSize: 16, color: Colors.grey)));

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        itemCount: widget.rejectedOrders.length,
        itemBuilder: (context, index) {
          final order = widget.rejectedOrders[index];
          final shopName = order['ShopName'] ?? 'Unknown Shop';
          final retailerName = order['RetailerName'] ?? 'Unknown';
          final deliveryDate = order['DeliveryDate']?.toString().split('T')[0] ?? 'N/A';
          final orderDate = (order['CreatedAt'] ?? order['OrderDate'] ?? 'N/A').toString().split('T')[0];
          final totalPrice = order['TotalPrice']?.toString() ?? '0.00';
          final reason = order['RejectionReason']?.toString() ?? 'No reason provided';

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cancel, color: Colors.red, size: 28),
                      const SizedBox(width: 10),
                      Expanded(child: Text(retailerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Shop: $shopName', style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order Date: $orderDate'),
                      Text('Delivery: $deliveryDate'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Total: \$$totalPrice', style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reason for Rejection:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(reason, style: TextStyle(color: Colors.red.shade700, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
