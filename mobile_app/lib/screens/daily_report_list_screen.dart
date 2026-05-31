import 'package:flutter/material.dart';
import '../services/order_service.dart';

class DailyReportListScreen extends StatefulWidget {
  const DailyReportListScreen({super.key});

  @override
  State<DailyReportListScreen> createState() => _DailyReportListScreenState();
}

class _DailyReportListScreenState extends State<DailyReportListScreen> {
  final _svc = OrderService();
  DailyReport? _report;
  String _flowState = 'idle';
  String? _error;

  Future<void> _viewReport() async {
    setState(() { _flowState = 'fetching'; _error = null; });
    await Future.delayed(const Duration(milliseconds: 600));
    try {
      setState(() => _flowState = 'generating');
      await Future.delayed(const Duration(milliseconds: 500));
      final report = await _svc.getDailyReport();
      setState(() { _report = report; _flowState = 'done'; });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _flowState = 'error';
      });
    }
  }

  void _reset() => setState(() { _flowState = 'idle'; _report = null; _error = null; });

  @override
  Widget build(BuildContext context) {
    // Wrap in LayoutBuilder to provide constraints when used inside IndexedStack
    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
        width: constraints.maxWidth == double.infinity
            ? MediaQuery.of(context).size.width
            : constraints.maxWidth,
        height: constraints.maxHeight == double.infinity
            ? MediaQuery.of(context).size.height
            : constraints.maxHeight,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          body: _buildCurrentState(),
        ),
      );
    });
  }

  Widget _buildCurrentState() {
    switch (_flowState) {
      case 'fetching':   return _buildProgress('Fetching order & delivery data...', 0.33);
      case 'generating': return _buildProgress('Generating summary report...', 0.66);
      case 'done':       return _buildReport();
      case 'error':      return _buildError();
      default:           return _buildLanding();
    }
  }

  // ── Landing ───────────────────────────────────────────────────────────────
  Widget _buildLanding() {
    final now = DateTime.now();
    final dateStr = '${now.day} ${_month(now.month)} ${now.year}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Reports',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        const SizedBox(height: 4),
        Text('Daily warehouse & order summary', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        const SizedBox(height: 24),

        // Main report card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
            // Blue header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0056B3), Color(0xFF1E88E5)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.bar_chart_outlined, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Daily Order Report',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                ])),
              ]),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _includeItem(Icons.receipt_long_outlined, 'Total orders placed today'),
                _includeItem(Icons.check_circle_outline, 'Orders by status breakdown'),
                _includeItem(Icons.people_outline, 'Orders grouped by retailer'),
                _includeItem(Icons.warning_amber_outlined, 'Low stock inventory alerts'),
                _includeItem(Icons.attach_money, 'Total order value (LKR)'),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6EFFF),
                    borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.schedule, size: 15, color: Color(0xFF0056B3)),
                    SizedBox(width: 8),
                    Expanded(child: Text('Report auto-generates daily at 6:00 PM',
                        style: TextStyle(fontSize: 12, color: Color(0xFF0056B3), fontWeight: FontWeight.w500))),
                  ]),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _viewReport,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Generate Report',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0056B3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _includeItem(IconData icon, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFE6EFFF), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: const Color(0xFF0056B3)),
      ),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
    ]),
  );

  // ── Progress ──────────────────────────────────────────────────────────────
  Widget _buildProgress(String message, double progress) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: const Color(0xFFE6EFFF), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.bar_chart_outlined, color: Color(0xFF0056B3), size: 36),
          ),
          const SizedBox(height: 24),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress, minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0056B3)),
            ),
          ),
          const SizedBox(height: 12),
          Text('${(progress * 100).toInt()}% complete',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text('Failed to generate report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          Text(_error ?? 'Unknown error', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          Row(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton(onPressed: _reset, child: const Text('Back')),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _viewReport,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0056B3), foregroundColor: Colors.white),
            ),
          ]),
        ]),
      ),
    );
  }

  // ── Report ────────────────────────────────────────────────────────────────
  Widget _buildReport() {
    final r = _report!;
    final now = DateTime.now();
    final dateStr = '${now.day} ${_month(now.month)} ${now.year}';
    final fulfillmentRate = r.totalOrders > 0
        ? ((r.approvedOrders / r.totalOrders) * 100).toStringAsFixed(1)
        : '0.0';

    return RefreshIndicator(
      onRefresh: _viewReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Report Title Card ───────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0056B3), Color(0xFF1E88E5)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.description_outlined, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                const Text('NESTLÉ SRI LANKA',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20)),
                  child: const Text('DAILY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 10),
              const Text('Supply Chain Report',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(dateStr, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.access_time, color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text('Generated at ${r.generatedAt}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Fulfillment Rate Banner ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Today\'s Fulfillment Rate',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Text('$fulfillmentRate%',
                    style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w900,
                      color: double.parse(fulfillmentRate) >= 80
                          ? Colors.green.shade600
                          : double.parse(fulfillmentRate) >= 60
                              ? Colors.orange.shade600
                              : Colors.red.shade600)),
                Text(
                  double.parse(fulfillmentRate) >= 80 ? '🎯 Excellent performance'
                      : double.parse(fulfillmentRate) >= 60 ? '📈 Room to improve'
                      : '⚠️ Below target',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ])),
              SizedBox(
                width: 80, height: 80,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: (double.tryParse(fulfillmentRate) ?? 0) / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      double.parse(fulfillmentRate) >= 80 ? Colors.green.shade500 : Colors.orange.shade500),
                  ),
                  Text('${double.parse(fulfillmentRate).toInt()}%',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Summary Stats ───────────────────────────────────────────────
          _sectionTitle('Order Summary'),
          const SizedBox(height: 10),
          // Use Row/Column instead of GridView to avoid size constraints issue
          Column(children: [
            Row(children: [
              Expanded(child: _statCard('Total Orders', '${r.totalOrders}', Icons.receipt_long_outlined, const Color(0xFF0056B3))),
              const SizedBox(width: 10),
              Expanded(child: _statCard('Approved', '${r.approvedOrders}', Icons.check_circle_outline, Colors.green.shade600)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _statCard('Pending', '${r.pendingOrders}', Icons.hourglass_empty, Colors.orange.shade600)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('Rejected', '${r.rejectedOrders}', Icons.cancel_outlined, Colors.red.shade500)),
            ]),
          ]),
          const SizedBox(height: 10),

          // Delivered stat + Total Value
          Row(children: [
            Expanded(child: _statCard('Delivered', '${r.deliveredOrders}',
                Icons.local_shipping_outlined, Colors.teal.shade600)),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.attach_money, size: 18, color: Colors.purple.shade400),
                    const SizedBox(width: 6),
                    const Text('Revenue', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ]),
                  const Spacer(),
                  Text(_fmtLkr(r.totalValue),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.purple.shade600)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // ── By Retailer ─────────────────────────────────────────────────
          if (r.ordersByRetailer.isNotEmpty) ...[
            _sectionTitle('Orders by Retailer'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200)),
              child: Column(children: r.ordersByRetailer.asMap().entries.map((e) {
                final isLast = e.key == r.ordersByRetailer.length - 1;
                final retailer = e.value;
                final name = retailer['retailerName'] as String? ?? '?';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: !isLast ? Border(bottom: BorderSide(color: Colors.grey.shade100)) : null),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFE6EFFF),
                      child: Text(name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0056B3)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6EFFF), borderRadius: BorderRadius.circular(20)),
                      child: Text('${retailer['orderCount']} orders',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0056B3), fontWeight: FontWeight.w600)),
                    ),
                  ]),
                );
              }).toList()),
            ),
            const SizedBox(height: 24),
          ],

          // ── Low Stock ───────────────────────────────────────────────────
          if (r.lowStockItems.isNotEmpty) ...[
            Row(children: [
              _sectionTitle('⚠️ Low Stock Alerts'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
                child: Text('${r.lowStockItems.length}',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.red.shade50, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100)),
              child: Column(children: r.lowStockItems.asMap().entries.map((e) {
                final isLast = e.key == r.lowStockItems.length - 1;
                final item = e.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: !isLast ? Border(bottom: BorderSide(color: Colors.red.shade100)) : null),
                  child: Row(children: [
                    Icon(Icons.warning_amber, size: 18, color: Colors.red.shade500),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item['name'] ?? '',
                        style: TextStyle(fontSize: 13, color: Colors.red.shade800, fontWeight: FontWeight.w500))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100, borderRadius: BorderRadius.circular(20)),
                      child: Text('${item['remaining']} left',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                );
              }).toList()),
            ),
            const SizedBox(height: 24),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade100)),
              child: Row(children: [
                Icon(Icons.check_circle_outline, color: Colors.green.shade600),
                const SizedBox(width: 10),
                const Text('All products are well stocked',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.green)),
              ]),
            ),
            const SizedBox(height: 24),
          ],

          // ── Footer ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200)),
            child: Row(children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'This report covers orders placed on ${dateStr}. Generated by NS Nexus Supply Chain System.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400))),
            ]),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _viewReport,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0056B3), foregroundColor: Colors.white),
              ),
            ),
          ]),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)));

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis)),
        ]),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }

  String _fmtLkr(double val) {
    if (val >= 1000000) return 'LKR ${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return 'LKR ${(val / 1000).toStringAsFixed(1)}K';
    return 'LKR ${val.toStringAsFixed(0)}';
  }

  String _month(int m) => ['Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}