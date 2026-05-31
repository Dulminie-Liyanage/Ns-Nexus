import 'package:flutter/material.dart';
import '../services/order_service.dart';
import '../services/driver_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class DriverAssignmentScreen extends StatefulWidget {
  const DriverAssignmentScreen({super.key});
  @override
  State<DriverAssignmentScreen> createState() => _DriverAssignmentScreenState();
}

class _DriverAssignmentScreenState extends State<DriverAssignmentScreen> {
  final _orderSvc = OrderService();
  final _driverSvc = DriverService();
  List<OrderModel> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final orders = await _orderSvc.getApprovedOrders();
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
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

  Future<void> _openAssign(OrderModel order) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AssignSheet(
        order: order,
        driverSvc: _driverSvc,
        orderSvc: _orderSvc,
      ),
    );
    if (result == true) {
      _load();
      _snack('Driver assigned successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        title: Image.asset(
          'assets/images/nestle_logo.png',
          height: 50,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: _load,
          ),
          const CircleAvatar(
            backgroundColor: Color(0xFFE2E8F0),
            radius: 18,
            child: Icon(Icons.person, color: Colors.black54, size: 20),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            onPressed: () async {
              await AuthService().logout();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assign Deliveries',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '${_orders.length} approved order${_orders.length == 1 ? '' : 's'} waiting',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _orders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_shipping_outlined,
                                size: 56,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No approved orders waiting',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _orders.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final o = _orders[i];
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6EFFF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long_outlined,
                                        color: Color(0xFF0056B3),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Order #${o.id}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          Text(
                                            o.retailerName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                          Text(
                                            '${o.items.length} item(s)',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => _openAssign(o),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0056B3,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: const Text(
                                        'Assign',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

// ── Colored status badge (top-level so both classes can use it) ───────────────
Widget _buildStatusBadge(String status) {
  Color bg, fg;
  switch (status.toUpperCase()) {
    case 'AVAILABLE':
      bg = Colors.green.shade50;
      fg = Colors.green.shade700;
      break;
    case 'BUSY':
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
      break;
    case 'ON_BREAK':
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade700;
      break;
    default:
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade500;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
    ),
  );
}

// ── Assign bottom sheet ───────────────────────────────────────────────────────
class _AssignSheet extends StatefulWidget {
  final OrderModel order;
  final DriverService driverSvc;
  final OrderService orderSvc;
  const _AssignSheet({
    required this.order,
    required this.driverSvc,
    required this.orderSvc,
  });
  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  List<DriverModel> _drivers = [];
  DriverModel? _selected;
  String _vehicle = 'Van';
  bool _loadingDrivers = true;
  bool _submitting = false;
  static const _vehicles = ['Van', 'Truck', 'Motorcycle', 'Car'];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _loadingDrivers = true);
    try {
      final drivers = await widget.driverSvc.getAllDrivers();
      setState(() {
        _drivers = drivers;
        _loadingDrivers = false;
      });
    } catch (e) {
      setState(() => _loadingDrivers = false);
    }
  }

  Future<void> _confirm() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an available driver.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.orderSvc.assignDriver(
        orderId: widget.order.id,
        driverId: _selected!.id,
        vehicleType: _vehicle,
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
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
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

          // Title row
          Row(
            children: [
              Expanded(
                child: Text(
                  'Assign driver — Order #${widget.order.id}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Header + refresh
          Row(
            children: [
              const Text(
                'Select driver',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadDrivers,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Refresh',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Only AVAILABLE drivers can be selected',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 10),

          // Driver list
          _loadingDrivers
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _drivers.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      const Text('No drivers found.'),
                    ],
                  ),
                )
              : SizedBox(
                  height: 200,
                  child: ListView.separated(
                    itemCount: _drivers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final d = _drivers[i];
                      final sel = _selected?.id == d.id;
                      final isAvailable = d.status == 'AVAILABLE';

                      return GestureDetector(
                        onTap: isAvailable
                            ? () => setState(() => _selected = d)
                            : null,
                        child: Opacity(
                          opacity: isAvailable ? 1.0 : 0.6,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: sel
                                  ? const Color(0xFFE6EFFF)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: sel
                                    ? const Color(0xFF0056B3)
                                    : Colors.grey.shade200,
                                width: sel ? 1.5 : 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFFE6EFFF),
                                  child: Text(
                                    d.firstName.isNotEmpty
                                        ? d.firstName[0]
                                        : 'D',
                                    style: const TextStyle(
                                      color: Color(0xFF0056B3),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Name & vehicle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      Text(
                                        '${d.vehicleType} · ${d.currentOrders} active',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Live status badge
                                _buildStatusBadge(d.status),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          const SizedBox(height: 16),

          // Vehicle type
          const Text(
            'Vehicle type',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _vehicles.map((v) {
              final sel = _vehicle == v;
              return GestureDetector(
                onTap: () => setState(() => _vehicle = v),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF0056B3) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sel
                          ? const Color(0xFF0056B3)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    v,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: sel ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting || _selected == null ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0056B3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Confirm assignment',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
