import 'package:flutter/material.dart';
import 'package:ns_nexus_mobile_app/services/analiytics_service.dart';
import '../services/order_service.dart';

class WarehouseOrdersScreen extends StatefulWidget {
  final String? initialFilter;
  const WarehouseOrdersScreen({super.key, this.initialFilter});

  @override
  State<WarehouseOrdersScreen> createState() => _WarehouseOrdersScreenState();
}

class _WarehouseOrdersScreenState extends State<WarehouseOrdersScreen>
    with SingleTickerProviderStateMixin {
  final _svc = OrderService();
  final _analyticsSvc = AnalyticsService();
  List<dynamic> _allOrders = [];
  bool _loading = true;
  late TabController _tabs;
  String _search = '';

  // US-18: Stage override & batch update
  final Set<String> _selectedOrderIds = {};
  bool _batchMode = false;
  int? _batchTargetStage;

  @override
  void initState() {
    super.initState();
    final startTab = widget.initialFilter == 'urgent'
        ? 1
        : widget.initialFilter == 'all'
        ? 2
        : 0;
    _tabs = TabController(length: 2, vsync: this, initialIndex: 0);
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
      final orders = await _svc.fetchAllOrders();
      setState(() {
        _allOrders = orders;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  List<dynamic> get _pending => _allOrders
      .where((o) => (o['Status'] ?? '').toString().toLowerCase() == 'pending')
      .toList();

  List<dynamic> get _urgent => _allOrders
      .where(
        (o) =>
            o['IsUrgent'] == 1 ||
            (o['Status'] ?? '').toString().toLowerCase() ==
                'flagged_for_review',
      )
      .toList();

  List<dynamic> get _filtered => _search.isEmpty
      ? _allOrders
      : _allOrders.where((o) {
          final name = (o['RetailerName'] ?? o['ShopName'] ?? '')
              .toString()
              .toLowerCase();
          final id = (o['OrderID'] ?? '').toString();
          return name.contains(_search.toLowerCase()) || id.contains(_search);
        }).toList();

  // US-18: Single stage override
  Future<void> _showStageOverride(dynamic order) async {
    final orderId = (order['OrderID'] ?? order['id'] ?? '').toString();
    final currentStage =
        int.tryParse(order['CurrentStage']?.toString() ?? '1') ?? 1;
    final status = (order['Status'] ?? '').toString().toLowerCase();
    final stageLabels = {
      1: 'Pending',
      2: 'Approved',
      3: 'Packing',
      4: 'In 3PL Transit',
      5: 'Ready to Ship',
      6: 'Out for Delivery',
      7: 'Delivered',
    };

    // Block rejected orders — cannot override
    if (status == 'rejected') {
      _snack('Rejected orders cannot be overridden', isError: true);
      return;
    }

    // Block delivered orders — already complete
    if (status == 'delivered' || currentStage == 7) {
      _snack('Order is already delivered', isError: true);
      return;
    }

    // Only allow moving FORWARD from current stage
    // WM should not send an order backwards in the pipeline
    final allowedStages = stageLabels.keys
        .where((s) => s > currentStage && s <= 7)
        .toList();

    if (allowedStages.isEmpty) {
      _snack('No further stages available for this order', isError: true);
      return;
    }

    int? selected = allowedStages.first;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Override Stage — Order #$orderId',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Currently: ${stageLabels[currentStage] ?? 'Unknown'}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (ctx, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: allowedStages.map((stage) {
              return RadioListTile<int>(
                value: stage,
                groupValue: selected,
                onChanged: (v) => setS(() => selected = v),
                title: Text(
                  stageLabels[stage]!,
                  style: TextStyle(
                    fontWeight: stage == selected
                        ? FontWeight.w700
                        : FontWeight.normal,
                    color: stage == selected
                        ? const Color(0xFF0056B3)
                        : Colors.black87,
                  ),
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF0056B3),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, selected),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0056B3),
              foregroundColor: Colors.white,
            ),
            child: const Text('Move Forward'),
          ),
        ],
      ),
    ).then((newStage) async {
      if (newStage == null || newStage == currentStage) return;
      try {
        await _analyticsSvc.overrideStage(orderId, newStage);
        _load();
        _snack('✓ Order #$orderId → ${stageLabels[newStage]}');
      } catch (e) {
        _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    });
  }

  // US-18: Batch update all selected orders
  Future<void> _applyBatchOverride() async {
    if (_selectedOrderIds.isEmpty || _batchTargetStage == null) return;
    final stageLabels = <int, String>{
      1: 'Pending',
      2: 'Approved',
      3: 'Packing',
      4: 'In 3PL Transit',
      5: 'Ready to Ship',
      6: 'Out for Delivery',
      7: 'Delivered',
    };
    // Capture values BEFORE clearing state
    final count = _selectedOrderIds.length;
    final stage = _batchTargetStage!;
    final ids = _selectedOrderIds.toList();
    try {
      await _analyticsSvc.batchOverride(ids, stage);
    } catch (e) {
      if (mounted)
        _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
      return;
    }
    // Clear batch state first
    if (mounted) {
      setState(() {
        _selectedOrderIds.clear();
        _batchMode = false;
        _batchTargetStage = null;
      });
    }
    // Reload in background — don't await so UI isn't blocked
    _load();
    if (mounted) {
      _snack(
        '✓ $count orders moved to ${stageLabels[stage] ?? 'Stage $stage'}',
      );
    }
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

  Future<void> _openOrder(dynamic order) async {
    // PO-03: No approve/reject — orders auto-approved, just show details
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _OrderDetailSheet(order: order, svc: _svc, onUpdated: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Orders',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const Spacer(),
                          // US-18: Batch mode toggle
                          IconButton(
                            icon: Icon(
                              _batchMode
                                  ? Icons.close
                                  : Icons.checklist_outlined,
                            ),
                            tooltip: _batchMode
                                ? 'Exit Batch'
                                : 'Batch Override',
                            onPressed: () => setState(() {
                              _batchMode = !_batchMode;
                              _selectedOrderIds.clear();
                              _batchTargetStage = null;
                            }),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _load,
                          ),
                        ],
                      ),
                      // US-18: Batch action bar
                      if (_batchMode) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6EFFF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF0056B3).withAlpha(51),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${_selectedOrderIds.length} selected',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0056B3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _batchTargetStage,
                                    hint: const Text(
                                      'Move to stage...',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    isDense: true,
                                    items:
                                        {
                                              1: 'Pending',
                                              2: 'Approved',
                                              3: 'Packing',
                                              4: 'In 3PL Transit',
                                              5: 'Ready',
                                              6: 'Out for Delivery',
                                              7: 'Delivered',
                                            }.entries
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e.key,
                                                child: Text(
                                                  e.value,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (v) =>
                                        setState(() => _batchTargetStage = v),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed:
                                    _selectedOrderIds.isNotEmpty &&
                                        _batchTargetStage != null
                                    ? _applyBatchOverride
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0056B3),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  minimumSize: Size.zero,
                                ),
                                child: const Text(
                                  'Apply',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: InputDecoration(
                          hintText: 'Search retailer or order ID...',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TabBar(
                        controller: _tabs,
                        labelColor: const Color(0xFF0056B3),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFF0056B3),
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: [
                          Tab(text: 'Urgent (${_urgent.length})'),
                          Tab(text: 'All (${_filtered.length})'),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _OrderList(
                        orders: _urgent,
                        onTap: _openOrder,
                        onOverride: _showStageOverride,
                        batchMode: _batchMode,
                        selectedIds: _selectedOrderIds,
                        onSelect: (id, v) => setState(
                          () => v
                              ? _selectedOrderIds.add(id)
                              : _selectedOrderIds.remove(id),
                        ),
                      ),
                      _OrderList(
                        orders: _filtered,
                        onTap: _openOrder,
                        onOverride: _showStageOverride,
                        batchMode: _batchMode,
                        selectedIds: _selectedOrderIds,
                        onSelect: (id, v) => setState(
                          () => v
                              ? _selectedOrderIds.add(id)
                              : _selectedOrderIds.remove(id),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Order list widget ─────────────────────────────────────────────────────────
class _OrderList extends StatelessWidget {
  final List<dynamic> orders;
  final void Function(dynamic) onTap;
  final void Function(dynamic)? onOverride;
  final bool batchMode;
  final Set<String> selectedIds;
  final void Function(String, bool)? onSelect;

  const _OrderList({
    required this.orders,
    required this.onTap,
    this.onOverride,
    this.batchMode = false,
    this.selectedIds = const {},
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No orders',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final order = orders[i];
        final id = (order['OrderID'] ?? order['id'] ?? '').toString();
        return _OrderCard(
          order: order,
          onTap: onTap,
          onOverride: onOverride,
          batchMode: batchMode,
          isSelected: selectedIds.contains(id),
          onSelect: onSelect,
        );
      },
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final dynamic order;
  final void Function(dynamic) onTap;
  final void Function(dynamic)? onOverride;
  final bool batchMode;
  final bool isSelected;
  final void Function(String, bool)? onSelect;

  const _OrderCard({
    required this.order,
    required this.onTap,
    this.onOverride,
    this.batchMode = false,
    this.isSelected = false,
    this.onSelect,
  });

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
        return const Color(0xFF16A34A);
      case 'rejected':
        return const Color(0xFFDC2626);
      case 'pending':
        return const Color(0xFFEA580C);
      case 'packing':
        return const Color(0xFF2563EB);
      case 'assigned':
      case 'processing':
        return const Color(0xFF2563EB);
      case 'in_3pl_transit':
      case 'ready_to_ship':
      case 'out_for_delivery':
        return const Color(0xFF7C3AED);
      case 'delivered':
        return const Color(0xFF15803D);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = order['OrderID']?.toString() ?? '';
    final orderId = order['OrderID'] ?? id;
    final retailer = order['RetailerName'] ?? order['ShopName'] ?? '';
    final status = (order['Status'] ?? 'pending').toString();
    final isUrgent = order['IsUrgent'] == 1;
    final stage = int.tryParse(order['CurrentStage']?.toString() ?? '1') ?? 1;
    final statusColor = _statusColor(status);

    return GestureDetector(
      onTap: () {
        if (batchMode) {
          onSelect?.call(id, !isSelected);
        } else {
          onTap(order);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE6EFFF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0056B3)
                : isUrgent
                ? Colors.red.shade300
                : Colors.grey.shade200,
            width: isSelected
                ? 1.5
                : isUrgent
                ? 1.5
                : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // US-18: Batch mode checkbox
                if (batchMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (v) => onSelect?.call(id, v ?? false),
                    activeColor: const Color(0xFF0056B3),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                Text(
                  'Order #$id',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                if (isUrgent)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
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
                        const SizedBox(width: 3),
                        Text(
                          'URGENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                // US-18: Stage override button — hide for rejected/delivered
                if (!batchMode &&
                    onOverride != null &&
                    status.toLowerCase() != 'rejected' &&
                    status.toLowerCase() != 'delivered')
                  GestureDetector(
                    onTap: () => onOverride!(order),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6EFFF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF0056B3).withAlpha(51),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.edit_outlined,
                            size: 12,
                            color: Color(0xFF0056B3),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'Override',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF0056B3),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              retailer,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            // Progress bar
            Row(
              children: List.generate(7, (i) {
                final s = i + 1;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: s < 7 ? 3 : 0),
                    height: 5,
                    decoration: BoxDecoration(
                      color: s <= stage
                          ? const Color(0xFF0056B3)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Stage $stage/7',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                const Spacer(),
                Text(
                  'Tap for details →',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF0056B3),
                    fontWeight: FontWeight.w500,
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

// ── Detail sheet — shows 7-stage timeline, WM can only close at stage 7 ───────
class _OrderDetailSheet extends StatefulWidget {
  final dynamic order;
  final OrderService svc;
  final VoidCallback onUpdated;
  const _OrderDetailSheet({
    required this.order,
    required this.svc,
    required this.onUpdated,
  });

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  bool _advancing = false;

  static const _stageLabels = [
    'Pending',
    'Approved / Rejected',
    'Packing',
    'In 3PL Transit',
    'Ready to Ship',
    'Out for Delivery',
    'Delivered',
  ];

  static const _stageActors = [
    'Retailer',
    'Warehouse Manager',
    '3PL Manager',
    '3PL Manager',
    '3PL Manager',
    'Delivery Driver',
    'Delivery Driver',
  ];

  // WM can only close the order (advance from stage 6 → 7)
  bool get _canClose {
    final stage =
        int.tryParse(widget.order['CurrentStage']?.toString() ?? '1') ?? 1;
    final status = (widget.order['Status'] ?? '').toString().toLowerCase();
    return stage == 7 && status == 'delivered';
  }

  Future<void> _closeOrder() async {
    setState(() => _advancing = true);
    try {
      final orderId = widget.order['OrderID']?.toString() ?? '';
      await widget.svc.advanceStage(orderId);
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order closed successfully.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _advancing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final orderId = o['OrderID']?.toString() ?? '';
    final status = (o['Status'] ?? 'pending').toString();
    final stage = int.tryParse(o['CurrentStage']?.toString() ?? '1') ?? 1;
    final retailer = o['RetailerName'] ?? o['ShopName'] ?? '';
    final isRejected = status.toLowerCase() == 'rejected';

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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #$orderId',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        retailer,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(child: _info('Stage', '$stage / 7')),
                  Expanded(child: _info('Status', status.replaceAll('_', ' '))),
                  Expanded(
                    child: _info(
                      'Total',
                      'LKR ${o['TotalPrice']?.toString() ?? '0'}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Order Timeline',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            // 7-stage timeline
            ...List.generate(_stageLabels.length, (i) {
              final s = i + 1;
              final isDone = s <= stage;
              final isCurrent = s == stage;
              final isRejectedStage = isRejected && s == 2;
              final isLast = i == _stageLabels.length - 1;
              final color = isRejectedStage
                  ? const Color(0xFFDC2626)
                  : isDone
                  ? const Color(0xFF0056B3)
                  : const Color(0xFFD1D5DB);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withAlpha(30),
                            border: Border.all(
                              color: color,
                              width: isCurrent ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            isRejectedStage
                                ? Icons.close
                                : isDone
                                ? Icons.check
                                : Icons.circle,
                            size: 12,
                            color: color,
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 30,
                            color: s < stage
                                ? const Color(0xFF0056B3).withAlpha(63)
                                : Colors.grey.shade200,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 6, top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isRejectedStage
                                      ? 'Order Rejected'
                                      : _stageLabels[i],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isCurrent || isRejectedStage
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isDone || isRejectedStage
                                        ? const Color(0xFF1E293B)
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              if (isCurrent && !isRejected)
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
                          ),
                          if (isDone || isRejectedStage)
                            Text(
                              'By: ${_stageActors[i]}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          if (isRejectedStage &&
                              (o['RejectionReason'] ?? o['rejection_reason']) !=
                                  null &&
                              (o['RejectionReason'] ?? o['rejection_reason'])
                                  .toString()
                                  .isNotEmpty)
                            Text(
                              'Reason: ${o['RejectionReason'] ?? o['rejection_reason']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.shade400,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 20),

            // WM can only close order (stage 6 → 7)
            if (_canClose)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _advancing ? null : _closeOrder,
                  icon: _advancing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text(
                    'Close Order',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056B3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              )
            else if (!isRejected && stage < 7)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stage <= 2
                            ? 'Waiting for warehouse manager approval'
                            : stage == 3
                            ? 'Approved — waiting for 3PL to assign driver'
                            : stage == 4
                            ? 'Driver assigned — waiting for shipment execution'
                            : stage == 5
                            ? 'Shipped — waiting for driver to complete delivery'
                            : 'Delivered — ready to close',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      ),
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
