import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:web/web.dart' as web;
import '../services/analiytics_service.dart';
import 'demand_analiysis_screen.dart';
import 'bottleneck_screen.dart';
import 'driver_performance_screen.dart';

double _n(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;
int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

class AnalyticsDashboardScreen extends StatefulWidget {
  final String role;
  const AnalyticsDashboardScreen({super.key, required this.role});
  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final _svc = AnalyticsService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String _range = 'all';

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
      final data = await _svc.getDashboard(
        range: _range == 'all' ? null : _range,
      );
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _exportCsv() async {
    if (_data == null) return;
    final summary = _data!['summary'] ?? {};
    final stages = _data!['stageDistribution'] as List? ?? [];
    final rows = [
      ['Metric', 'Value'],
      ['Total Orders', summary['totalOrders'] ?? 0],
      ['Delivered', summary['delivered'] ?? 0],
      ['Pending', summary['pending'] ?? 0],
      ['Urgent', summary['urgent'] ?? 0],
      ['Revenue LKR', summary['totalRevenue'] ?? 0],
      ['Fulfillment %', summary['fulfillmentRate'] ?? 0],
      ['', ''],
      ['Stage', 'Count'],
      ...stages.map((s) => [s['stage'].toString(), s['count'].toString()]),
    ];
    try {
      final csvString = Csv().encode(rows);
      final fname = 'dashboard_${DateTime.now().millisecondsSinceEpoch}.csv';
      final bytes = utf8.encode(csvString);
      final content = bytes.buffer.toJS;
      final blob = web.Blob(
        [content].toJS,
        web.BlobPropertyBag(type: 'text/csv'),
      );
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;
      anchor.download = fname;
      web.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      web.URL.revokeObjectURL(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Downloading: $fname'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Analytics Dashboard',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          if (_data != null)
            IconButton(
              icon: const Icon(
                Icons.download_outlined,
                color: Color(0xFF0056B3),
              ),
              tooltip: 'Export CSV',
              onPressed: _exportCsv,
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorView()
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _filterRow(),
                    const SizedBox(height: 16),
                    _kpiGrid(),
                    const SizedBox(height: 20),
                    _fulfillmentCard(),
                    const SizedBox(height: 20),
                    _trendCard(),
                    const SizedBox(height: 20),
                    _stageCard(),
                    const SizedBox(height: 20),
                    _subAnalyticsSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _filterRow() {
    final filters = [
      ('all', 'All Time'),
      ('monthly', 'This Month'),
      ('weekly', 'This Week'),
      ('daily', 'Today'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isActive = _range == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.$2),
              selected: isActive,
              onSelected: (_) {
                setState(() => _range = f.$1);
                _load();
              },
              selectedColor: const Color(0xFF0056B3),
              labelStyle: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF64748B),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              showCheckmark: false,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isActive
                    ? const Color(0xFF0056B3)
                    : Colors.grey.shade300,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _kpiGrid() {
    final s = _data!['summary'] ?? {};
    final items = [
      _KpiItem(
        'Total Orders',
        s['totalOrders']?.toString() ?? '0',
        Icons.receipt_long_outlined,
        const Color(0xFF0056B3),
      ),
      _KpiItem(
        'Delivered',
        s['delivered']?.toString() ?? '0',
        Icons.check_circle_outline,
        Colors.green,
      ),
      _KpiItem(
        'Pending',
        s['pending']?.toString() ?? '0',
        Icons.pending_outlined,
        Colors.orange,
      ),
      _KpiItem(
        'Urgent',
        s['urgent']?.toString() ?? '0',
        Icons.bolt_rounded,
        Colors.red,
      ),
      _KpiItem(
        'Revenue LKR',
        _fmt(s['totalRevenue']),
        Icons.attach_money,
        const Color(0xFF7C3AED),
      ),
      _KpiItem(
        'Weight kg',
        _fmt(s['totalWeight']),
        Icons.scale_outlined,
        Colors.teal,
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: items
          .map(
            (e) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(e.icon, size: 18, color: e.color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          e.label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: e.color,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _fulfillmentCard() {
    final pct = _n(_data!['summary']?['fulfillmentRate']).clamp(0.0, 100.0);
    final color = pct >= 80
        ? Colors.green
        : pct >= 60
        ? Colors.orange
        : Colors.red;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fulfillment Rate',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        sectionsSpace: 0,
                        centerSpaceRadius: 32,
                        sections: [
                          PieChartSectionData(
                            value: pct,
                            color: color,
                            radius: 18,
                            title: '',
                          ),
                          PieChartSectionData(
                            value: 100 - pct,
                            color: Colors.grey.shade100,
                            radius: 18,
                            title: '',
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${pct.toInt()}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pct >= 80
                          ? '🎯 Excellent!'
                          : pct >= 60
                          ? '📈 Room to improve'
                          : '⚠️ Below target',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Target: 80%+\nCurrent: ${pct.toInt()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trendCard() {
    final trend = (_data!['weeklyTrend'] as List?) ?? [];
    if (trend.isEmpty) return const SizedBox.shrink();

    final spots = trend
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), _n(e.value['count'])))
        .toList();

    final counts = spots.map((s) => s.y).toList();
    final maxY = counts.reduce((a, b) => a > b ? a : b);
    final effectiveMaxY = maxY <= 0 ? 5.0 : maxY + (maxY * 0.25).clamp(1, 20);
    final total = counts.fold(0.0, (a, b) => a + b).toInt();

    // Build day labels — handle both "2025-05-03" and "2025-05-03T00:00:00.000Z"
    final dayLabels = trend.map((t) {
      final raw = t['day']?.toString() ?? '';
      // Extract just the date part before any T
      final datePart = raw.split('T').first;
      // Show as "May 3" format
      try {
        final d = DateTime.parse(datePart);
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return '${months[d.month - 1]} ${d.day}';
      } catch (_) {
        return datePart.length >= 10 ? datePart.substring(5) : datePart;
      }
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Order Volume — Last 7 Days',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Text(
                'Total: $total orders',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: maxY == 0
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.show_chart,
                          size: 36,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No orders in the last 7 days',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: effectiveMaxY,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                      ),
                      // ALL axis titles disabled — we draw labels manually below
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (v, _) {
                              if (v == 0 || v == effectiveMaxY) {
                                return Text(
                                  '${v.toInt()}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF94A3B8),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: const Color(0xFF0056B3),
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, _, __, ___) =>
                                FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.white,
                                  strokeWidth: 2,
                                  strokeColor: const Color(0xFF0056B3),
                                ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF0056B3).withValues(alpha: 0.15),
                                const Color(0xFF0056B3).withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          // Manual day labels row — perfectly spaced, never overlaps
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(
              left: 24,
            ), // align with chart left axis
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: dayLabels
                  .map(
                    (d) => Text(
                      d,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageCard() {
    // Try multiple possible key names from backend
    final raw =
        (_data!['stageDistribution'] as List?) ??
        (_data!['stages'] as List?) ??
        [];
    // Always show the card — even with empty data show all 7 stages as 0

    // Build a full 7-stage list — fill missing stages with 0
    const stageLabels = {
      1: 'Pending',
      2: 'Approved',
      3: 'Packing',
      4: '3PL',
      5: 'Ship',
      6: 'Delivery',
      7: 'Done',
    };
    final colors = [
      Colors.grey.shade400,
      Colors.green.shade400,
      Colors.blue.shade300,
      Colors.purple.shade300,
      Colors.teal.shade400,
      Colors.orange.shade400,
      Colors.green.shade600,
    ];

    // Map stage number → count from API response
    final stageMap = <int, double>{};
    for (final s in raw) {
      // Backend may return 'stage' or 'CurrentStage' as key
      final stageKey = s['stage'] ?? s['CurrentStage'] ?? 0;
      stageMap[_i(stageKey)] = _n(s['count']);
    }

    // Build all 7 bars even if some stages have 0 orders
    final allStages = List.generate(7, (i) => i + 1);
    final maxVal = stageMap.values.isEmpty
        ? 1.0
        : stageMap.values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Orders by Pipeline Stage',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal + (maxVal * 0.2).clamp(1, 10),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, __) {
                      final stage = group.x + 1;
                      return BarTooltipItem(
                        '${stageLabels[stage]}${rod.toY.toInt()} orders',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) => v % 1 == 0
                          ? Text(
                              '${v.toInt()}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF94A3B8),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) {
                        final stage = v.toInt() + 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            stageLabels[stage] ?? '',
                            style: const TextStyle(
                              fontSize: 8,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                barGroups: allStages.map((stage) {
                  final count = stageMap[stage] ?? 0.0;
                  final ci = (stage - 1).clamp(0, colors.length - 1);
                  return BarChartGroupData(
                    x: stage - 1,
                    barRods: [
                      BarChartRodData(
                        toY: count,
                        color: count > 0 ? colors[ci] : Colors.grey.shade200,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend row
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: allStages.map((stage) {
              final ci = (stage - 1).clamp(0, colors.length - 1);
              final count = stageMap[stage] ?? 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors[ci],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${stageLabels[stage]}: ${count.toInt()}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _subAnalyticsSection() {
    final showDemand = ['admin', 'warehouse_manager'].contains(widget.role);
    final showBottleneck = ['admin', 'warehouse_manager'].contains(widget.role);
    final showDrivers = ['admin', '3pl_manager'].contains(widget.role);
    final items = [
      if (showDemand)
        _NavItem(
          '📊 Product Demand Analysis',
          'Top products, trends & growth',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DemandAnalysisScreen()),
          ),
        ),
      if (showBottleneck)
        _NavItem(
          '🔍 Order Bottleneck Analysis',
          'Pipeline stages, drop-off & delays',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BottleneckScreen()),
          ),
        ),
      if (showDrivers)
        _NavItem(
          '🚚 Driver Performance',
          'Rankings, on-time rates & flags',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DriverPerformanceScreen()),
          ),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detailed Analytics',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListTile(
              onTap: item.onTap,
              title: Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              subtitle: Text(
                item.subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(0xFF0056B3),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorView() => Center(
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
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    ),
  );

  String _fmt(dynamic val) {
    final d = _n(val);
    if (d >= 1000000) return '${(d / 1000000).toStringAsFixed(1)}M';
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)}K';
    return d.toStringAsFixed(0);
  }
}

class _KpiItem {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiItem(this.label, this.value, this.icon, this.color);
}

class _NavItem {
  final String title, subtitle;
  final VoidCallback onTap;
  const _NavItem(this.title, this.subtitle, this.onTap);
}
