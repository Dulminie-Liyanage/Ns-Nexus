import 'package:flutter/material.dart';
import '../services/order_service.dart';
import 'order_review_screen.dart';

class WarehouseOrdersScreen extends StatefulWidget {
  final String? initialFilter; // Catches dashboard clicks

  const WarehouseOrdersScreen({super.key, this.initialFilter});

  @override
  State<WarehouseOrdersScreen> createState() => _WarehouseOrdersScreenState();
}

class _WarehouseOrdersScreenState extends State<WarehouseOrdersScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  List<dynamic> _allOrders = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;
  String? _advancingOrderId;

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

    // Switch tab if filter is passed from dashboard
    if (widget.initialFilter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.initialFilter == 'pending' ||
            widget.initialFilter == 'urgent') {
          _tabController.animateTo(0);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant WarehouseOrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != oldWidget.initialFilter &&
        widget.initialFilter == 'pending') {
      _tabController.animateTo(0);
    }
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

  // Filter Logic
  List<dynamic> get _pendingOrders => _allOrders
      .where(
        (o) =>
            o['Status'].toString().toLowerCase() == 'pending' ||
            o['Status'].toString().toLowerCase() == 'under_review',
      )
      .toList();

  List<dynamic> get _processingOrders => _allOrders.where((o) {
    final s = o['Status']?.toString().toLowerCase() ?? '';
    return [
      'approved',
      'partially_approved',
      'processing',
      'packing',
      'shipped',
      'at_hub',
      'out_for_delivery',
    ].contains(s);
  }).toList();

  List<dynamic> get _historyOrders => _allOrders.where((o) {
    final s = o['Status']?.toString().toLowerCase() ?? '';
    return s == 'delivered' || s == 'rejected';
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color.fromARGB(255, 65, 65, 65),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color.fromARGB(255, 91, 91, 91),
            tabs: [
              Tab(text: 'Pending (${_pendingOrders.length})'),
              Tab(text: 'Processing (${_processingOrders.length})'),
              Tab(text: 'History (${_historyOrders.length})'),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOrderList(_pendingOrders, isPending: true),
                    _buildOrderList(_processingOrders),
                    _buildHistoryTab(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildOrderList(List<dynamic> orders, {bool isPending = false}) {
    if (orders.isEmpty) return const Center(child: Text('No orders found'));
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderCard(order, isPending: isPending);
        },
      ),
    );
  }

  Widget _buildOrderCard(dynamic order, {bool isPending = false}) {
    final isUrgent = (order['IsUrgent'] == 1 || order['is_urgent'] == 1);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order['OrderID']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'URGENT',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Shop: ${order['ShopName'] ?? 'Nestle Partner'}'),
            Text(
              'Status: ${order['Status']}',
              style: TextStyle(
                color: isPending
                    ? const Color.fromARGB(255, 132, 79, 0)
                    : const Color.fromARGB(255, 0, 55, 100),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderReviewScreen(order: order),
                  ),
                ).then((_) => _loadOrders()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPending
                      ? const Color.fromARGB(255, 22, 32, 48)
                      : const Color.fromARGB(255, 173, 122, 33),
                ),
                child: Text(
                  isPending ? 'Review Order' : 'Update Status',
                  style: const TextStyle(
                    color: Colors.white, // 🚨 Changes the text to white
                    fontWeight: FontWeight
                        .bold, // Makes it look professional like the image
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final delivered = _allOrders
        .where((o) => o['Status'].toString().toLowerCase() == 'delivered')
        .toList();
    final rejected = _allOrders
        .where((o) => o['Status'].toString().toLowerCase() == 'rejected')
        .toList();
    return ListView(
      children: [
        if (delivered.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Delivered",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ...delivered.map((o) => _buildOrderCard(o)),
        ],
        if (rejected.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Rejected",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ),
          ...rejected.map((o) => _buildOrderCard(o)),
        ],
      ],
    );
  }
}
