import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'offers_screen.dart';
import 'analiytics_dashboard_screen.dart';
import 'demand_analiysis_screen.dart';
import 'bottleneck_screen.dart';
import 'daily_report_list_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sales Manager Home Screen
// PO-04: Owns offer management
// PO-05: Reviews flagged anomaly orders
// Analytics: Demand trend access
// ─────────────────────────────────────────────────────────────────────────────
class SalesManagerScreen extends StatefulWidget {
  const SalesManagerScreen({super.key});
  @override
  State<SalesManagerScreen> createState() => _SalesManagerScreenState();
}

class _SalesManagerScreenState extends State<SalesManagerScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const _FlaggedOrdersTab(),
      const ManageOffersScreen(),
      const AnalyticsDashboardScreen(role: 'sales_manager'),
      const DemandAnalysisScreen(),
      const BottleneckScreen(),
      const DailyReportListScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withAlpha(20),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.business_center_outlined,
                color: Color(0xFF7C3AED), size: 20)),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sales Manager',
                style: TextStyle(color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w700, fontSize: 16)),
            Text('Commercial & Approvals',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          ]),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Color(0xFF64748B)),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) { if (i >= 0 && i < 6) setState(() => _tab = i); },
        selectedItemColor: const Color(0xFF7C3AED),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.flag_outlined), label: 'Flagged'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_offer_outlined), label: 'Offers'),
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.trending_up_outlined), label: 'Demand'),
          BottomNavigationBarItem(
              icon: Icon(Icons.speed_outlined), label: 'Bottleneck'),
          BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined), label: 'Report'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PO-05: Flagged Orders Tab — anomaly review queue
// ─────────────────────────────────────────────────────────────────────────────
class _FlaggedOrdersTab extends StatefulWidget {
  const _FlaggedOrdersTab();
  @override
  State<_FlaggedOrdersTab> createState() => _FlaggedOrdersTabState();
}

class _FlaggedOrdersTabState extends State<_FlaggedOrdersTab> {
  static const _base = 'http://15.235.160.20:25568';
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sessionToken') ?? prefs.getString('token') ?? '';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId') ?? '';
      final token = await _token();
      final res = await http.get(
        Uri.parse('$_base/orders/flagged'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      setState(() {
        _orders = data['orders'] ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() { _orders = []; _loading = false; });
    }
  }

  Future<void> _release(dynamic order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Release Order',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Release Order #${order['OrderID']}?\n\nThis will auto-approve it and notify the retailer.',
            style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
            child: const Text('Release'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final token = await _token();
      await http.put(
        Uri.parse('$_base/orders/${order['OrderID']}/release'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'releasedBy': _userId}),
      ).timeout(const Duration(seconds: 10));
      _snack('✓ Order #${order['OrderID']} released and approved');
      _load();
    } catch (e) {
      _snack('Failed: $e', isError: true);
    }
  }

  Future<void> _hold(dynamic order) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Hold Order',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Hold Order #${order['OrderID']}?',
              style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            decoration: InputDecoration(
              labelText: 'Reason (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            child: const Text('Hold'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final token = await _token();
      await http.put(
        Uri.parse('$_base/orders/${order['OrderID']}/hold'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'reason': reasonCtrl.text.trim()}),
      ).timeout(const Duration(seconds: 10));
      _snack('Order #${order['OrderID']} held');
      _load();
    } catch (e) {
      _snack('Failed: $e', isError: true);
    }
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
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_orders.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
        const SizedBox(height: 16),
        const Text('No Flagged Orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        Text('All orders are within normal range',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white),
        ),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(children: [
        // Header banner
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200)),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(
              '${_orders.length} order${_orders.length != 1 ? 's' : ''} flagged for review — unusual order quantities detected',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800,
                  fontWeight: FontWeight.w600))),
          ]),
        ),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _flaggedCard(_orders[i]),
          ),
        ),
      ]),
    );
  }

  Widget _flaggedCard(dynamic order) {
    final retailer = order['RetailerName'] ?? order['ShopName'] ?? 'Retailer';
    final orderId = order['OrderID']?.toString() ?? '';
    final flagReason = order['FlagReason']?.toString() ?? 'Unusual order quantity';
    final totalPrice = double.tryParse(order['TotalPrice']?.toString() ?? '0') ?? 0;
    final createdAt = order['CreatedAt']?.toString().split('T').first ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8)],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14), topRight: Radius.circular(14))),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.flag_rounded, color: Colors.orange.shade700, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Order #$orderId',
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 14, color: Color(0xFF1E293B))),
              Text(retailer,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('LKR ${totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 14, color: Color(0xFF7C3AED))),
              Text(createdAt,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ]),
          ]),
        ),

        // Flag reason
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade100)),
              child: Row(children: [
                Icon(Icons.info_outline, size: 14, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Expanded(child: Text(flagReason,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700))),
              ]),
            ),
            const SizedBox(height: 12),

            // Action buttons
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _hold(order),
                  icon: Icon(Icons.pause_circle_outlined,
                      size: 16, color: Colors.red.shade600),
                  label: Text('Hold',
                      style: TextStyle(color: Colors.red.shade600,
                          fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _release(order),
                  icon: const Icon(Icons.check_circle_outlined, size: 16),
                  label: const Text('Release',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}