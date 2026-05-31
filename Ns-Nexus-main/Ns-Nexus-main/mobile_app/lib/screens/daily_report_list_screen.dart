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

  // Flow states: idle → fetching → generating → done (or error)
  String _flowState = 'idle'; // idle | fetching | generating | done | error
  String? _error;

  // Step 1: User clicks "View Report" — starts the flow
  Future<void> _viewReport() async {
    // Step 2: Fetch order & delivery data
    setState(() {
      _flowState = 'fetching';
      _error = null;
    });
    await Future.delayed(const Duration(milliseconds: 600)); // visual feedback

    try {
      // Step 3: Generate summary (backend calls generateSummary())
      setState(() => _flowState = 'generating');
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // visual feedback

      final report = await _svc.getDailyReport();

      // Step 4: Display report
      setState(() {
        _report = report;
        _flowState = 'done';
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _flowState = 'error';
      });
    }
  }

  void _reset() => setState(() {
    _flowState = 'idle';
    _report = null;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _buildCurrentState(),
    );
  }

  Widget _buildCurrentState() {
    switch (_flowState) {
      case 'idle':
        return _buildLanding();
      case 'fetching':
        return _buildProgress('Fetching order & delivery data...', 0.33);
      case 'generating':
        return _buildProgress('Generating summary report...', 0.66);
      case 'done':
        return _buildReport();
      case 'error':
        return _buildError();
      default:
        return _buildLanding();
    }
  }

  // ── Landing page ─────────────────────────────────────────────────────────────
  Widget _buildLanding() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reports',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Generate and view daily order summaries',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 32),

          // Report card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6EFFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bar_chart_outlined,
                        color: Color(0xFF0056B3),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Order Report',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            "Today's orders, deliveries & stock summary",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // What the report includes
                _includeItem(
                  Icons.receipt_long_outlined,
                  'Total orders placed today',
                ),
                _includeItem(
                  Icons.check_circle_outline,
                  'Orders by status breakdown',
                ),
                _includeItem(
                  Icons.people_outline,
                  'Orders grouped by retailer',
                ),
                _includeItem(
                  Icons.warning_amber_outlined,
                  'Low stock inventory alerts',
                ),
                _includeItem(Icons.attach_money, 'Total order value'),
                const SizedBox(height: 24),

                // 6PM auto-trigger note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6EFFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 15,
                        color: Color(0xFF0056B3),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Report auto-generates daily at 6:00 PM',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0056B3),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // View Report button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _viewReport,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'View Report',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0056B3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _includeItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  // ── Progress screen ───────────────────────────────────────────────────────────
  Widget _buildProgress(String message, double progress) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE6EFFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.bar_chart_outlined,
                color: Color(0xFF0056B3),
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF0056B3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${(progress * 100).toInt()}% complete',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error screen ──────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text(
              'Failed to generate report',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(onPressed: _reset, child: const Text('Back')),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _viewReport,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0056B3),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Report display ────────────────────────────────────────────────────────────
  Widget _buildReport() {
    final r = _report!;
    return RefreshIndicator(
      onRefresh: _viewReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Row(
              children: [
                const Text(
                  'Daily Report',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _viewReport,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _reset,
                  tooltip: 'Back',
                ),
              ],
            ),

            // Generated at banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE6EFFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF0056B3).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 15,
                    color: Color(0xFF0056B3),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Report generated  •  ${r.generatedAt}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0056B3),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Summary stats grid
            const Text(
              'Summary',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
              children: [
                _StatCard(
                  'Total orders',
                  '${r.totalOrders}',
                  Icons.receipt_long_outlined,
                  const Color(0xFF0056B3),
                ),
                _StatCard(
                  'Approved',
                  '${r.approvedOrders}',
                  Icons.check_circle_outline,
                  Colors.green.shade600,
                ),
                _StatCard(
                  'Rejected',
                  '${r.rejectedOrders}',
                  Icons.cancel_outlined,
                  Colors.red.shade500,
                ),
                _StatCard(
                  'Pending',
                  '${r.pendingOrders}',
                  Icons.hourglass_empty,
                  Colors.orange.shade600,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Total value
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6EFFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.attach_money,
                      color: Color(0xFF0056B3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total order value',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        'LKR ${r.totalValue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Orders by retailer
            if (r.ordersByRetailer.isNotEmpty) ...[
              const Text(
                'Orders by Retailer',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: r.ordersByRetailer.asMap().entries.map((e) {
                    final isLast = e.key == r.ordersByRetailer.length - 1;
                    final retailer = e.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: !isLast
                            ? Border(
                                bottom: BorderSide(color: Colors.grey.shade100),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFE6EFFF),
                            child: Text(
                              (retailer['retailerName'] as String? ?? '?')[0]
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0056B3),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              retailer['retailerName'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6EFFF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${retailer['orderCount']} orders',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0056B3),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Low stock items
            if (r.lowStockItems.isNotEmpty) ...[
              Row(
                children: [
                  const Text(
                    'Low Stock Items',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${r.lowStockItems.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Column(
                  children: r.lowStockItems.asMap().entries.map((e) {
                    final isLast = e.key == r.lowStockItems.length - 1;
                    final item = e.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: !isLast
                            ? Border(
                                bottom: BorderSide(color: Colors.red.shade100),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            size: 18,
                            color: Colors.red.shade500,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item['name'] ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${item['remaining']} left',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
