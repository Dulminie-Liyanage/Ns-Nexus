import 'package:flutter/material.dart';
import '../services/order_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE 7-STAGE AUDIT TRAIL WIDGET
// Builds timeline from CurrentStage integer — no separate audit table needed
// ─────────────────────────────────────────────────────────────────────────────
class AuditTrailWidget extends StatelessWidget {
  final int currentStage;
  final String status;
  final String? rejectionReason;

  const AuditTrailWidget({
    super.key,
    required this.currentStage,
    required this.status,
    this.rejectionReason,
  });

  static const _stages = [
    // New flow: Retailer → 3PL → Warehouse → 3PL → Retailer
    _StageInfo(
      'Order Placed',
      'Retailer submitted order — auto approved',
      Icons.shopping_cart_outlined,
      'Retailer',
    ),
    _StageInfo(
      'Received by 3PL',
      '3PL distributor received the order',
      Icons.handshake_outlined,
      '3PL Distributor',
    ),
    _StageInfo(
      'At Warehouse',
      'Order arrived at Nestlé warehouse',
      Icons.warehouse_outlined,
      'Warehouse Manager',
    ),
    _StageInfo(
      'Packing',
      'Order being packed at warehouse',
      Icons.inventory_2_outlined,
      'Warehouse Manager',
    ),
    _StageInfo(
      'Dispatched to 3PL',
      'Packed order handed back to 3PL',
      Icons.local_shipping_outlined,
      '3PL Distributor',
    ),
    _StageInfo(
      'Out for Delivery',
      'Driver en route to retailer',
      Icons.directions_bike_outlined,
      'Delivery Driver',
    ),
    _StageInfo(
      'Delivered',
      'Order delivered to retailer successfully',
      Icons.check_circle_outline,
      'Delivery Driver',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isRejected = status.toLowerCase() == 'rejected';

    return Column(
      children: List.generate(_stages.length, (i) {
        final stage = i + 1;
        final info = _stages[i];
        final isDone = stage <= currentStage;
        final isCurrent = stage == currentStage;
        final isRejectedStage =
            false; // PO-03: No rejection — orders auto-approved
        final isLast = i == _stages.length - 1;

        Color stageColor;
        IconData stageIcon;
        if (isRejectedStage) {
          stageColor = Colors.red;
          stageIcon = Icons.cancel_outlined;
        } else if (isDone) {
          stageColor = const Color(0xFF0056B3);
          stageIcon = info.icon;
        } else {
          stageColor = Colors.grey.shade300;
          stageIcon = info.icon;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line + circle
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone || isRejectedStage
                          ? stageColor.withOpacity(0.12)
                          : Colors.grey.shade100,
                      border: Border.all(
                        color: stageColor,
                        width: isCurrent ? 2.5 : 1.5,
                      ),
                    ),
                    child: Icon(
                      isDone && !isRejectedStage ? Icons.check : stageIcon,
                      size: 16,
                      color: stageColor,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 48,
                      color: stage < currentStage
                          ? const Color(0xFF0056B3).withOpacity(0.3)
                          : Colors.grey.shade200,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Stage content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Stage $stage — ${isRejectedStage ? "Order Rejected" : info.label}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isCurrent || isRejectedStage
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isDone || isRejectedStage
                                ? const Color(0xFF1E293B)
                                : Colors.grey.shade400,
                          ),
                        ),
                        if (isCurrent && !isRejected) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0056B3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Current',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRejectedStage && rejectionReason != null
                          ? 'Rejected: $rejectionReason'
                          : isDone
                          ? '${info.description} · By: ${info.actor}'
                          : 'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        color: isRejectedStage
                            ? Colors.red.shade600
                            : isDone
                            ? const Color(0xFF64748B)
                            : Colors.grey.shade300,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _StageInfo {
  final String label;
  final String description;
  final IconData icon;
  final String actor;
  const _StageInfo(this.label, this.description, this.icon, this.actor);
}

// ─────────────────────────────────────────────────────────────────────────────
// AUDIT TRAIL SCREEN — WM selects an order and sees the 7-stage timeline
// ─────────────────────────────────────────────────────────────────────────────
class AuditTrailScreen extends StatefulWidget {
  /// If true, only shows orders from stage 4 onwards (3PL view).
  /// 3PL only sees orders they are responsible for: In 3PL Transit → Delivered.
  final bool onlyShipped;
  const AuditTrailScreen({super.key, this.onlyShipped = false});

  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  final _svc = OrderService();
  List<dynamic> _orders = [];
  dynamic _selected;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final allOrders = await _svc.fetchAllOrders();
      // 3PL view: only show orders from stage 4+ (after shipment is created)
      // Stages: 4=In 3PL Transit, 5=Ready to Ship, 6=Out for Delivery, 7=Delivered
      final orders = widget.onlyShipped
          ? allOrders.where((o) {
              final stage =
                  int.tryParse(o['CurrentStage']?.toString() ?? '0') ?? 0;
              return stage >= 4;
            }).toList()
          : allOrders;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Color _statusColor(String status) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : _selected == null
          ? _buildOrderList()
          : _buildAuditDetail(),
    );
  }

  Widget _buildOrderList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              const Text(
                'Audit Trail',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Select an order to view its 7-stage timeline',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _orders.isEmpty
              ? Center(
                  child: Text(
                    'No orders found',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final o = _orders[i];
                    final orderId = o['OrderID']?.toString() ?? '';
                    final status = o['Status']?.toString() ?? 'pending';
                    final retailer = o['RetailerName'] ?? o['ShopName'] ?? '';
                    final stage =
                        int.tryParse(o['CurrentStage']?.toString() ?? '1') ?? 1;
                    final statusColor = _statusColor(status);

                    return GestureDetector(
                      onTap: () => setState(() => _selected = o),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6EFFF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '$stage/7',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0056B3),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #$orderId',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    retailer,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status.replaceAll('_', ' '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: statusColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF64748B),
                                  size: 18,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAuditDetail() {
    final o = _selected;
    final orderId = o['OrderID']?.toString() ?? '';
    final status = o['Status']?.toString() ?? 'pending';
    final retailer = o['RetailerName'] ?? o['ShopName'] ?? '';
    final stage = int.tryParse(o['CurrentStage']?.toString() ?? '1') ?? 1;
    final rejectionReason = o['RejectionReason']?.toString();
    final statusColor = _statusColor(status);

    return Column(
      children: [
        // Back header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => setState(() => _selected = null),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #$orderId',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      retailer,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
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
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Timeline
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order info card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _infoItem('Stage', '$stage of 7')),
                      Expanded(
                        child: _infoItem(
                          'Total',
                          'LKR ${o['TotalPrice']?.toString() ?? '0'}',
                        ),
                      ),
                      Expanded(
                        child: _infoItem(
                          'Weight',
                          '${o['TotalWeight']?.toString() ?? '0'} kg',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Order Timeline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),
                // The 7-stage widget
                AuditTrailWidget(
                  currentStage: stage,
                  status: status,
                  rejectionReason: rejectionReason,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
