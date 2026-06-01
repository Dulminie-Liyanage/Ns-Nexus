import 'package:flutter/material.dart';
import '../services/order_service.dart';
import '../services/shipment_service.dart';
import '../services/driver_service.dart';

class ShipmentManagementScreen extends StatefulWidget {
  /// [initialTab]: 0 = Create Shipment, 1 = Shipment Status
  final int initialTab;
  const ShipmentManagementScreen({super.key, this.initialTab = 1});
  @override
  State<ShipmentManagementScreen> createState() =>
      _ShipmentManagementScreenState();
}

class _ShipmentManagementScreenState extends State<ShipmentManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF0056B3),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0056B3),
          tabs: const [
            Tab(text: 'Create Shipment'),
            Tab(text: 'Shipment Status'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_CreateShipmentTab(), _ShipmentStatusTab()],
      ),
    );
  }
}

// ── Tab 1: Create Shipment ────────────────────────────────────────────────────
class _CreateShipmentTab extends StatefulWidget {
  const _CreateShipmentTab();
  @override
  State<_CreateShipmentTab> createState() => _CreateShipmentTabState();
}

class _CreateShipmentTabState extends State<_CreateShipmentTab> {
  final _orderSvc = OrderService();
  final _shipSvc = ShipmentService();
  final _driverSvc = DriverService();

  List<OrderModel> _orders = [];
  List<DriverModel> _drivers = [];
  final Set<String> _selected = {};
  CapacityResult? _capacity;
  DateTime? _departure;
  DriverModel? _selectedDriver;
  bool _loading = true;
  bool _checkingCapacity = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _orderSvc
            .getApprovedOrders(), // Approved orders ready to be grouped into a shipment
        _driverSvc.getAllDrivers(),
      ]);
      setState(() {
        // Shipment groups approved orders — one driver handles all selected orders
        _orders = results[0] as List<OrderModel>;
        // Show all drivers with current status — 3PL picks one for the whole shipment
        _drivers = results[1] as List<DriverModel>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _checkCapacity() async {
    if (_selected.isEmpty) return;
    // Filter out any empty or invalid IDs before sending
    final validIds = _selected.where((id) => id.isNotEmpty).toList();
    if (validIds.isEmpty) {
      _snack('Selected orders have invalid IDs.', isError: true);
      return;
    }
    setState(() {
      _checkingCapacity = true;
      _capacity = null;
    });
    try {
      final result = await _shipSvc.checkCapacity(validIds);
      setState(() {
        _capacity = result;
        _checkingCapacity = false;
      });
    } catch (e) {
      setState(() => _checkingCapacity = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _pickDeparture() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(
      () => _departure = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _createShipment() async {
    if (_selected.isEmpty) {
      _snack('Select at least one order.', isError: true);
      return;
    }
    if (_capacity == null) {
      _snack('Check capacity first.', isError: true);
      return;
    }
    if (!_capacity!.sufficient) {
      _snack('Capacity exceeded.', isError: true);
      return;
    }
    if (_departure == null) {
      _snack('Set a departure time.', isError: true);
      return;
    }
    if (_selectedDriver == null) {
      _snack('Please assign a driver.', isError: true);
      return;
    }

    final confirm = await _showManifest();
    if (confirm != true) return;

    setState(() => _creating = true);
    try {
      await _shipSvc.createShipment(
        orderIds: _selected.toList(),
        departureTime: _departure!,
        driverId: _selectedDriver!.id,
        vehicleType: _selectedDriver!.vehicleType,
      );
      if (mounted) {
        _snack('Shipment created and driver assigned!');
        setState(() {
          _selected.clear();
          _capacity = null;
          _departure = null;
          _selectedDriver = null;
        });
        _load();
      }
    } catch (e) {
      if (mounted) {
        _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
        setState(() => _creating = false);
      }
    }
  }

  Future<bool?> _showManifest() {
    final sel = _orders.where((o) => _selected.contains(o.id)).toList();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Confirm Shipment',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shipment summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${sel.length} order(s)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Weight: ${_capacity?.totalWeight.toStringAsFixed(2)} kg',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Departure: ${_departure?.day}/${_departure?.month}/${_departure?.year} '
                    '${_departure?.hour.toString().padLeft(2, '0')}:${_departure?.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (_selectedDriver != null)
                    Text(
                      'Driver: ${_selectedDriver!.fullName}',
                      style: const TextStyle(fontSize: 13),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Orders:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            ...sel.map(
              (o) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: Color(0xFF0056B3)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Order #${o.id} — ${o.retailerName}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0056B3),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
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
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section: Select Orders
                      Row(
                        children: [
                          const Text(
                            'Select Orders',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            onPressed: _load,
                          ),
                        ],
                      ),
                      Text(
                        _selected.isEmpty
                            ? '${_orders.length} orders ready'
                            : '${_selected.length} selected',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _orders.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: const Center(
                                child: Text(
                                  'No orders ready for shipment',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                              ),
                            )
                          : Column(
                              children: _orders.map((o) {
                                final sel = _selected.contains(o.id);
                                return GestureDetector(
                                  onTap: () => setState(() {
                                    sel
                                        ? _selected.remove(o.id)
                                        : _selected.add(o.id);
                                    _capacity = null;
                                  }),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? const Color(0xFFE6EFFF)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: sel
                                            ? const Color(0xFF0056B3)
                                            : Colors.grey.shade200,
                                        width: sel ? 1.5 : 0.5,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: sel,
                                          activeColor: const Color(0xFF0056B3),
                                          onChanged: (_) => setState(() {
                                            sel
                                                ? _selected.remove(o.id)
                                                : _selected.add(o.id);
                                            _capacity = null;
                                          }),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Order #${o.id}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                o.retailerName,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _statusChip(o.status),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                      const SizedBox(height: 20),

                      // Section: Assign Driver — one driver handles ALL selected orders
                      const Text(
                        'Assign Driver to Shipment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Selected driver will handle all orders in this shipment',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _drivers.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('No available drivers'),
                                ],
                              ),
                            )
                          : ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: _drivers.map((d) {
                                    final sel = _selectedDriver?.id == d.id;
                                    final isAvail = d.status == 'AVAILABLE';
                                    return GestureDetector(
                                      onTap: isAvail
                                          ? () => setState(
                                              () => _selectedDriver = d,
                                            )
                                          : null,
                                      child: Opacity(
                                        opacity: isAvail ? 1.0 : 0.5,
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: sel
                                                ? const Color(0xFFE6EFFF)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: sel
                                                  ? const Color(0xFF0056B3)
                                                  : Colors.grey.shade200,
                                              width: sel ? 1.5 : 0.5,
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor: const Color(
                                                  0xFFE6EFFF,
                                                ),
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
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      d.fullName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    Text(
                                                      d.vehicleType,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Color(
                                                          0xFF64748B,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              _driverStatusChip(d.status),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                      const SizedBox(height: 20),

                      // Section: Departure Time
                      const Text(
                        'Departure Time',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickDeparture,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule,
                                color: Color(0xFF0056B3),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _departure == null
                                    ? 'Tap to set departure date & time'
                                    : '${_departure!.day}/${_departure!.month}/${_departure!.year}  '
                                          '${_departure!.hour.toString().padLeft(2, '0')}:${_departure!.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _departure == null
                                      ? Colors.grey.shade500
                                      : const Color(0xFF1E293B),
                                  fontWeight: _departure == null
                                      ? FontWeight.w400
                                      : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 150), // space for bottom panel
                    ],
                  ),
                ),
              ),

              // Bottom panel: capacity check + create
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (_checkingCapacity)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: LinearProgressIndicator(),
                      ),
                    if (_capacity != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _capacity!.sufficient
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _capacity!.sufficient
                                ? Colors.green.shade200
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _capacity!.sufficient
                                  ? Icons.check_circle
                                  : Icons.warning_amber,
                              color: _capacity!.sufficient
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _capacity!.sufficient
                                    ? 'Capacity OK — ${_capacity!.totalWeight.toStringAsFixed(1)} kg'
                                    : 'Capacity exceeded — remove some orders',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _capacity!.sufficient
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _selected.isEmpty || _checkingCapacity
                                ? null
                                : _checkCapacity,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text('Check capacity'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _creating ? null : _createShipment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0056B3),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: _creating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Create Shipment',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
  }

  Widget _statusChip(String status) {
    Color bg, fg;
    switch (status.toLowerCase()) {
      case 'assigned':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        break;
      case 'approved':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _driverStatusChip(String status) {
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
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ── Tab 2: Shipment Status ────────────────────────────────────────────────────
class _ShipmentStatusTab extends StatefulWidget {
  const _ShipmentStatusTab();
  @override
  State<_ShipmentStatusTab> createState() => _ShipmentStatusTabState();
}

class _ShipmentStatusTabState extends State<_ShipmentStatusTab> {
  final _shipSvc = ShipmentService();
  List<ShipmentModel> _shipments = [];
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
      final shipments = await _shipSvc.getShipments();
      setState(() {
        _shipments = shipments;
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
      case 'in_transit':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_shipments.isEmpty) {
      return Center(
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
              'No shipments yet',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _shipments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final s = _shipments[i];
          final statusColor = _statusColor(s.status);
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Row(
                children: [
                  Text(
                    'Shipment #${s.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.driverName != null)
                      Text(
                        'Driver: ${s.driverName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    Text(
                      '${s.orderCount} order(s)  •  ${s.totalWeight.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (s.departureTime.isNotEmpty)
                      Text(
                        'Departure: ${s.departureTime.split('T')[0]}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              children: [
                // Expanded: show order details for this shipment
                _ShipmentOrderList(shipmentId: s.id, shipSvc: _shipSvc),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Expandable order list inside each shipment card ───────────────────────────
class _ShipmentOrderList extends StatefulWidget {
  final String shipmentId;
  final ShipmentService shipSvc;
  const _ShipmentOrderList({required this.shipmentId, required this.shipSvc});
  @override
  State<_ShipmentOrderList> createState() => _ShipmentOrderListState();
}

class _ShipmentOrderListState extends State<_ShipmentOrderList> {
  List<dynamic> _orders = [];
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
      final orders = await widget.shipSvc.getShipmentOrders(widget.shipmentId);
      if (mounted)
        setState(() {
          _orders = orders;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Failed: \$_error',
              style: TextStyle(color: Colors.red.shade600, fontSize: 12),
            ),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No orders in this shipment',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }
    return Column(
      children: _orders.map((o) {
        final orderId = o['OrderID']?.toString() ?? '';
        final retailer = o['RetailerName'] ?? o['ShopName'] ?? '';
        final address = o['Address'] ?? '';
        final phone = o['Phone'] ?? '';
        final status = o['Status'] ?? '';
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6EFFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '#$orderId',
                    style: const TextStyle(
                      fontSize: 10,
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
                      retailer,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (address.isNotEmpty)
                      Text(
                        address,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
