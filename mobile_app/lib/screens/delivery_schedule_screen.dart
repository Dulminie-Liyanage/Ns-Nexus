import 'package:flutter/material.dart';
import '../services/order_service.dart';
import '../services/driver_service.dart';
import 'delivery_confirmation_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class DeliveryScheduleScreen extends StatefulWidget {
  const DeliveryScheduleScreen({super.key});

  @override
  State<DeliveryScheduleScreen> createState() => _DeliveryScheduleScreenState();
}

class _DeliveryScheduleScreenState extends State<DeliveryScheduleScreen> {
  final _svc = OrderService();
  final _driverSvc = DriverService();
  List<DeliveryStop> _stops = [];
  bool _loading = true;
  // Track which orders are "in transit" (started but not ended)
  final Set<String> _inTransit = {};
  String? _updatingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final stops = await _svc.getTodayStops();
      stops.sort((a, b) => a.stopNumber.compareTo(b.stopNumber));
      setState(() {
        _stops = stops;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  // US-13: Step 1 — startDelivery() → status = "in_transit"
  // US-16: Auto-sets driver status to BUSY
  Future<void> _startDelivery(DeliveryStop stop) async {
    setState(() => _updatingId = stop.orderId);
    try {
      await _svc.advanceStage(stop.orderId);
      // US-16: Explicitly set BUSY immediately — real-time, no refresh needed
      await _driverSvc.updateStatus('BUSY');
      setState(() {
        _inTransit.add(stop.orderId);
        _updatingId = null;
      });
      _snack('Delivery started — status set to Busy.');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
      setState(() => _updatingId = null);
    }
  }

    // US-13 + US-17: Step 2 — Opens digital confirmation screen
  // Driver captures signature + photo + GPS before delivery is marked complete
  Future<void> _endDelivery(DeliveryStop stop) async {
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryConfirmationScreen(stop: stop),
      ),
    );
    if (confirmed == true) {
      _load(); // Reload schedule — confirmation screen already saved everything
    }
  }

  void _showStopDetail(DeliveryStop stop) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Stop #${stop.stopNumber}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              _statusBadge(stop.status),
            ]),
            const SizedBox(height: 20),
            // Order ID first — unique identifier for tracking
            _detailRow(Icons.tag, 'Order ID', 'Order #${stop.orderId}'),
            const SizedBox(height: 14),
            _detailRow(Icons.store_outlined, 'Store', stop.retailerName),
            const SizedBox(height: 14),
            _detailRow(
                Icons.location_on_outlined, 'Address', stop.address),
            const SizedBox(height: 14),
            _detailRow(Icons.phone_outlined, 'Phone', stop.phone),
            const SizedBox(height: 24),
            // Show appropriate button based on delivery state
            if (stop.status != 'delivered') ...[
              if (_inTransit.contains(stop.orderId))
                // Step 2: End Delivery
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _endDelivery(stop);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('End Delivery',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                )
              else
                // Step 1: Start Delivery
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _startDelivery(stop);
                    },
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Start Delivery',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0056B3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'delivered':
        color = Colors.green;
        label = 'Delivered';
        break;
      case 'in_transit':
      case 'out_for_delivery':
        color = Colors.blue;
        label = 'In Transit';
        break;
      default:
        color = Colors.orange;
        label = 'Assigned';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: const Color(0xFF0056B3)),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500)),
      ]),
    ]);
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pending = _stops.where((s) => s.status != 'delivered').toList();
    final done = _stops.where((s) => s.status == 'delivered').toList();
    final allDone = _stops.isNotEmpty && pending.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        title: Image.asset('assets/images/nestle_logo.png',
            height: 50, fit: BoxFit.contain),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black54),
              onPressed: _load),
          const CircleAvatar(
              backgroundColor: Color(0xFFE2E8F0),
              radius: 18,
              child: Icon(Icons.person, color: Colors.black54, size: 20)),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            onPressed: () async {
              await AuthService().logout();
              if (!mounted) return;
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stops.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.route_outlined,
                      size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No deliveries assigned for today',
                      style: TextStyle(
                          fontSize: 15, color: Colors.grey.shade400)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text("Today's Schedule",
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B))),
                      const SizedBox(height: 12),
                      // Progress banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: allDone
                              ? Colors.green.shade50
                              : const Color(0xFFE6EFFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: allDone
                                ? Colors.green.shade200
                                : const Color(0xFF0056B3).withOpacity(0.2),
                          ),
                        ),
                        child: Row(children: [
                          Icon(
                            allDone
                                ? Icons.check_circle
                                : Icons.local_shipping_outlined,
                            color: allDone
                                ? Colors.green.shade700
                                : const Color(0xFF0056B3),
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                allDone
                                    ? 'All deliveries completed!'
                                    : 'Route in progress',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: allDone
                                        ? Colors.green.shade800
                                        : const Color(0xFF1E293B)),
                              ),
                              Text(
                                  '${done.length} of ${_stops.length} stops completed',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B))),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),

                      // Pending stops
                      if (pending.isNotEmpty) ...[
                        const Text('Pending stops',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF1E293B))),
                        const SizedBox(height: 8),
                        ...pending.map((stop) => _StopCard(
                              stop: stop,
                              isInTransit: _inTransit.contains(stop.orderId),
                              isUpdating: _updatingId == stop.orderId,
                              onTap: () => _showStopDetail(stop),
                              onStart: () => _startDelivery(stop),
                              onEnd: () => _endDelivery(stop),
                            )),
                      ],

                      // Completed stops
                      if (done.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Completed',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF1E293B))),
                        const SizedBox(height: 8),
                        ...done.map((stop) => _StopCard(
                              stop: stop,
                              isInTransit: false,
                              isUpdating: false,
                              onTap: () => _showStopDetail(stop),
                              onStart: () {},
                              onEnd: () {},
                            )),
                      ],
                    ],
                  ),
                ),
    );
  }
}

// ── Stop card with Order ID, two-step delivery buttons ────────────────────────
class _StopCard extends StatelessWidget {
  final DeliveryStop stop;
  final bool isInTransit;
  final bool isUpdating;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  const _StopCard({
    required this.stop,
    required this.isInTransit,
    required this.isUpdating,
    required this.onTap,
    required this.onStart,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = stop.status == 'delivered';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? Colors.green.shade200
              : isInTransit
                  ? const Color(0xFF0056B3).withOpacity(0.3)
                  : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Stop number / state indicator circle
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? Colors.green.shade100
                  : isInTransit
                      ? const Color(0xFFE6EFFF)
                      : Colors.grey.shade100,
            ),
            child: Center(
              child: isDone
                  ? Icon(Icons.check, size: 18, color: Colors.green.shade700)
                  : isInTransit
                      ? const Icon(Icons.local_shipping_outlined,
                          size: 18, color: Color(0xFF0056B3))
                      : Text('${stop.stopNumber}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0056B3))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Store name
              Text(stop.retailerName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 2),
              // Order ID — shown prominently so driver can track the order
              Text('Order #${stop.orderId}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0056B3))),
              // Delivery address
              Text(stop.address,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (isDone)
            Icon(Icons.check_circle, color: Colors.green.shade600)
          else
            IconButton(
              icon: const Icon(Icons.info_outline,
                  size: 20, color: Color(0xFF64748B)),
              onPressed: onTap,
            ),
        ]),

        // Two-step action buttons for pending stops
        if (!isDone) ...[
          const SizedBox(height: 10),
          isUpdating
              ? const Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : isInTransit
                  // Step 2: End Delivery button
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onEnd,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('End Delivery',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ))
                  // Step 1: Start Delivery button
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onStart,
                        icon: const Icon(Icons.local_shipping_outlined,
                            size: 18),
                        label: const Text('Start Delivery',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0056B3),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      )),
        ],
      ]),
    );
  }
}