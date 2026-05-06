import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/order_service.dart';
import 'order_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final OrderService _orderService = OrderService();
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _error;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Step 1 — get userId from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('userId') ?? '';

      // Step 2 — guard: if no userId something went wrong at login
      if (_currentUserId.isEmpty || _currentUserId == '0') {
        setState(() {
          _error = 'Session error — please log out and log in again.';
          _isLoading = false;
        });
        return;
      }

      // Step 3 — fetch from /orders/retailer/:userId
      final data = await _orderService.fetchOrderHistory();
      if (!mounted) return;

      // Step 4 — client-side safety filter
      // The backend already filters by RetailerID, but we double-check here
      // in case the session somehow has the wrong userId stored
      final filtered = data.where((order) {
        final orderRetailerId =
            (order['RetailerID'] ?? order['retailer_id'] ?? order['retailerId'])
                ?.toString() ??
            '';

        // If backend returns RetailerID, strictly match it
        // If not returned (older backend), trust the backend filter
        if (orderRetailerId.isEmpty) return true;
        return orderRetailerId == _currentUserId;
      }).toList();

      setState(() {
        _orders = filtered;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _showItemsDialog(
    dynamic orderId,
    String status,
    String reason,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final items = await _orderService.fetchOrderItems(orderId);
      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (ctx) {
          final String safeStatus = status.toLowerCase();
          final String safeReason = (reason.isNotEmpty && reason != 'null')
              ? reason
              : 'No reason provided';

          return AlertDialog(
            title: Text(
              'Order #$orderId Items',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: items.isEmpty
                        ? const Text('No items found for this order.')
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final item = items[i];
                              final name =
                                  item['ProductName'] ??
                                  item['productName'] ??
                                  'Product';
                              final qtyRaw =
                                  item['QtyRequested'] ?? item['Quantity'] ?? 0;
                              final approvedRaw = item['QtyApproved'] ?? qtyRaw;
                              final priceRaw =
                                  item['UnitPrice'] ?? item['Price'] ?? 0.0;
                              final qReq = int.tryParse(qtyRaw.toString()) ?? 0;
                              final qApprv =
                                  int.tryParse(approvedRaw.toString()) ?? qReq;
                              final p =
                                  double.tryParse(priceRaw.toString()) ?? 0.0;
                              final lineTotal = p * qApprv;
                              final isModified =
                                  qApprv < qReq && safeStatus != 'rejected';

                              return Container(
                                color: isModified
                                    ? Colors.orange.withOpacity(0.1)
                                    : null,
                                child: ListTile(
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      color: isModified
                                          ? Colors.deepOrange
                                          : Colors.black87,
                                      fontWeight: isModified
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Requested: $qReq  |  Approved: $qApprv\n'
                                    'Unit: LKR ${p.toStringAsFixed(2)}  —  Total: LKR ${lineTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                          ),
                  ),
                  if (safeStatus == 'rejected') ...[
                    const Divider(height: 24),
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
                          const Text(
                            'REJECTION REASON',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            safeReason,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ── US-19: Quick Reorder ────────────────────────────────────────────────────
  // Fetches the previous order's items, maps them to productId→qty,
  // then opens OrderScreen pre-filled with those quantities.
  // Prices are auto-updated because OrderScreen loads current product prices.
  Future<void> _reorder(dynamic orderId) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading your previous order...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final cart = await _orderService.fetchReorderCart(orderId);
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      if (cart.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No items found in this order to reorder.'),
          ),
        );
        return;
      }

      // Push OrderScreen with pre-filled cart — prices auto-update from products
      Navigator.push(
        context,
        MaterialPageRoute(
          // isReorder: true hides urgent toggle and shows "Quick Reorder" title
          builder: (_) => OrderScreen(preFilledCart: cart, isReorder: true),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load order: ${e.toString().replaceFirst("Exception: ", "")}',
          ),
        ),
      );
    }
  }

  String _getStageName(int stage) {
    const stages = {
      1: 'Pending',
      2: 'Approved / Rejected',
      3: 'Packing',
      4: 'In 3PL Transit',
      5: 'Ready to Ship',
      6: 'Out for Delivery',
      7: 'Delivered',
    };
    return stages[stage] ?? 'Pending';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'partially_approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'shipped':
      case 'processing':
        return Colors.blue;
      case 'delivered':
        return Colors.green.shade700;
      default:
        return Colors.grey;
    }
  }

  Widget _buildProgressBar(int currentStage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(7, (index) {
            final stage = index + 1;
            final isActive = stage <= currentStage;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: stage < 7 ? 4 : 0),
                height: 7,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF0056B3)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          'Stage $currentStage / 7 — ${_getStageName(currentStage)}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF0056B3),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Order History',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadHistory,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'No orders yet',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your order history will appear here',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          final orderId = order['OrderID'] ?? order['id'] ?? order['_id'];
          final status = order['Status']?.toString() ?? 'pending';
          final statusColor = _getStatusColor(status);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #$orderId',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date: ${(order['CreatedAt'] ?? 'N/A').toString().split('T')[0]}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            'Delivery: ${(order['DeliveryDate'] ?? 'N/A').toString().split('T')[0]}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            'Weight: ${order['TotalWeight']?.toString() ?? '0'} kg',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'LKR ${order['TotalPrice']?.toString() ?? '0.00'}',
                        style: const TextStyle(
                          color: Color(0xFF0056B3),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),

                  // Urgent badge
                  if (order['IsUrgent'] == 1) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 12,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Urgent Order',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Progress bar
                  _buildProgressBar(
                    int.tryParse(order['CurrentStage']?.toString() ?? '1') ?? 1,
                  ),
                  const SizedBox(height: 14),

                  // Action buttons row — View Items + optional Reorder
                  Row(
                    children: [
                      // View Items
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showItemsDialog(
                            orderId,
                            order['Status']?.toString() ?? '',
                            order['RejectionReason']?.toString() ?? '',
                          ),
                          icon: const Icon(Icons.list_alt_outlined, size: 15),
                          label: const Text('View Items'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0056B3),
                            side: const BorderSide(color: Color(0xFF0056B3)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // US-19: One-tap Reorder — only for approved/delivered orders
                      // Rejected/pending orders should not be reordered as-is
                      if ([
                        'approved',
                        'partially_approved',
                        'delivered',
                        'packing',
                        'in_3pl_transit',
                        'ready_to_ship',
                        'out_for_delivery',
                      ].contains(status.toLowerCase()))
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _reorder(orderId),
                            icon: const Icon(Icons.replay_outlined, size: 15),
                            label: const Text('Reorder'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0056B3),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
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
}
