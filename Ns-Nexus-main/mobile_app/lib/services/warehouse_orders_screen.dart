import 'package:flutter/material.dart';
import '../services/order_service.dart';

class WarehouseOrdersScreen extends StatefulWidget {
  /// Pass 'urgent' to open directly on the urgent tab
  final String? initialFilter;

  const WarehouseOrdersScreen({super.key, this.initialFilter});

  @override
  State<WarehouseOrdersScreen> createState() => _WarehouseOrdersScreenState();
}

class _WarehouseOrdersScreenState extends State<WarehouseOrdersScreen>
    with SingleTickerProviderStateMixin {
  final _svc = OrderService();
  List<OrderModel> _orders = [];
  bool _loading = true;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    final startTab = widget.initialFilter == 'urgent' ? 1 : 0;
    _tabs = TabController(length: 2, vsync: this, initialIndex: startTab);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final orders = await _svc.getPendingOrders();
      const rankOrder = {'Gold': 0, 'Silver': 1, 'Bronze': 2};
      orders.sort(
        (a, b) => (rankOrder[a.loyaltyRank] ?? 9).compareTo(
          rankOrder[b.loyaltyRank] ?? 9,
        ),
      );
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  List<OrderModel> get _pending =>
      _orders.where((o) => o.status == 'pending').toList();
  List<OrderModel> get _urgent => _orders.where((o) => o.isUrgent).toList();

  Future<void> _openReview(OrderModel order) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _OrderReviewSheet(order: order, svc: _svc),
    );
    if (result == true) _load();
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Approvals'),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'All pending (${_pending.length})'),
            Tab(text: 'Urgent (${_urgent.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _OrderList(orders: _pending, onTap: _openReview),
                _OrderList(orders: _urgent, onTap: _openReview),
              ],
            ),
    );
  }
}

// ── Order list ────────────────────────────────────────────────────────────────
class _OrderList extends StatelessWidget {
  final List<OrderModel> orders;
  final void Function(OrderModel) onTap;

  const _OrderList({required this.orders, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No orders',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _OrderCard(order: orders[i], onTap: onTap),
      ),
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final void Function(OrderModel) onTap;

  const _OrderCard({required this.order, required this.onTap});

  static const _loyaltyColors = {
    'Gold': Color(0xFFBA7517),
    'Silver': Color(0xFF5F5E5A),
    'Bronze': Color(0xFF993C1D),
  };
  static const _loyaltyBg = {
    'Gold': Color(0xFFFAEEDA),
    'Silver': Color(0xFFF1EFE8),
    'Bronze': Color(0xFFFAECE7),
  };

  @override
  Widget build(BuildContext context) {
    final loyaltyColor = _loyaltyColors[order.loyaltyRank] ?? Colors.grey;
    final loyaltyBg = _loyaltyBg[order.loyaltyRank] ?? Colors.grey.shade100;

    return GestureDetector(
      onTap: () => onTap(order),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: order.isUrgent
                ? Colors.red.shade300
                : Theme.of(context).colorScheme.outline.withOpacity(0.15),
            width: order.isUrgent ? 1.5 : 0.5,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Order #${order.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: loyaltyBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 12, color: loyaltyColor),
                      const SizedBox(width: 4),
                      Text(
                        order.loyaltyRank,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: loyaltyColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (order.isUrgent) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'URGENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              order.retailerName,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            ...order.items
                .take(2)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${item['name']} × ${item['quantity']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            if (order.items.length > 2)
              Text(
                '+${order.items.length - 2} more items',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: order.stockSufficient
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        order.stockSufficient
                            ? Icons.check_circle
                            : Icons.warning_amber,
                        size: 12,
                        color: order.stockSufficient
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.stockSufficient ? 'Stock OK' : 'Low stock',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: order.stockSufficient
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Tap to review',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Review bottom sheet ───────────────────────────────────────────────────────
class _OrderReviewSheet extends StatefulWidget {
  final OrderModel order;
  final OrderService svc;

  const _OrderReviewSheet({required this.order, required this.svc});

  @override
  State<_OrderReviewSheet> createState() => _OrderReviewSheetState();
}

class _OrderReviewSheetState extends State<_OrderReviewSheet> {
  final _reasonCtrl = TextEditingController();
  bool _loading = false;
  String? _action;

  Future<void> _submit(String action) async {
    if ((action == 'partial' || action == 'reject') &&
        _reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _loading = true;
      _action = action;
    });
    try {
      await widget.svc.reviewOrder(
        orderId: widget.order.id,
        action: action,
        reason: _reasonCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _loading = false;
          _action = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Order #${o.id}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              o.retailerName,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Items', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...o.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['name'] ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '×${item['quantity']}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: o.stockSufficient
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    o.stockSufficient
                        ? Icons.check_circle
                        : Icons.warning_amber,
                    color: o.stockSufficient
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      o.stockSufficient
                          ? 'Sufficient stock available'
                          : 'Insufficient stock — partial or reject recommended',
                      style: TextStyle(
                        fontSize: 13,
                        color: o.stockSufficient
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Reason (required for partial/reject)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => _submit('reject'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade400),
                      foregroundColor: Colors.red.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _loading && _action == 'reject'
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => _submit('partial'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.orange.shade400),
                      foregroundColor: Colors.orange.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _loading && _action == 'partial'
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Partial'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : () => _submit('approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _loading && _action == 'approve'
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
