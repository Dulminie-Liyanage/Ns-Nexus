import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:web/web.dart' as web;
import '../services/analiytics_service.dart';

double _n(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;
int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

class DriverPerformanceScreen extends StatefulWidget {
  const DriverPerformanceScreen({super.key});
  @override
  State<DriverPerformanceScreen> createState() =>
      _DriverPerformanceScreenState();
}

class _DriverPerformanceScreenState extends State<DriverPerformanceScreen>
    with SingleTickerProviderStateMixin {
  final _svc = AnalyticsService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String _range = 'all';
  late TabController _tabs;
  bool _showFlaggedOnly = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.getDriverPerformance(
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
    final drivers = (_data!['drivers'] as List?) ?? [];
    final rows = [
      [
        'Rank',
        'Driver',
        'Total',
        'Completed',
        'On-Time',
        'Rate %',
        'Score',
        'Flagged',
      ],
      ...drivers.map(
        (d) => [
          d['rank']?.toString() ?? '',
          d['Name'] ?? '',
          d['totalDeliveries']?.toString() ?? '0',
          d['completed']?.toString() ?? '0',
          d['onTime']?.toString() ?? '0',
          '${d['onTimeRate'] ?? 0}%',
          d['performanceScore']?.toString() ?? '0',
          (d['isFlagged'] == true) ? 'YES' : 'No',
        ],
      ),
    ];
    try {
      final csvString = Csv().encode(rows);
      final fname = 'driver_perf_${DateTime.now().millisecondsSinceEpoch}.csv';
      final bytes = utf8.encode(csvString);
      final blob = web.Blob(
        [bytes.buffer.toJS].toJS,
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
          'Driver Performance',
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
              onPressed: _exportCsv,
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF0056B3),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0056B3),
          tabs: const [
            Tab(text: 'Rankings'),
            Tab(text: 'Trend'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errView()
          : Column(
              children: [
                _filterRow(),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [_buildRankings(), _buildTrend()],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _filterRow() {
    final filters = [
      ('all', 'All Time'),
      ('monthly', 'Month'),
      ('weekly', 'Week'),
      ('daily', 'Today'),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...filters.map((f) {
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
                    fontSize: 12,
                  ),
                  showCheckmark: false,
                  side: BorderSide(
                    color: isActive
                        ? const Color(0xFF0056B3)
                        : Colors.grey.shade300,
                  ),
                ),
              );
            }),
            FilterChip(
              label: const Text('⚠️ Flagged Only'),
              selected: _showFlaggedOnly,
              onSelected: (v) => setState(() => _showFlaggedOnly = v),
              selectedColor: Colors.red.shade100,
              labelStyle: TextStyle(
                color: _showFlaggedOnly
                    ? Colors.red.shade700
                    : const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: _showFlaggedOnly
                    ? FontWeight.w700
                    : FontWeight.normal,
              ),
              showCheckmark: false,
              side: BorderSide(
                color: _showFlaggedOnly
                    ? Colors.red.shade300
                    : Colors.grey.shade300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankings() {
    final k = _data!['kpis'] ?? {};
    List<dynamic> drivers = (_data!['drivers'] as List?) ?? [];
    if (_showFlaggedOnly) {
      drivers = drivers.where((d) => d['isFlagged'] == true).toList();
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _kpi(
                'Avg On-Time',
                '${k['avgOnTimeRate'] ?? 0}%',
                const Color(0xFF0056B3),
              ),
              const SizedBox(width: 10),
              _kpi('Top Driver', k['topDriver'] ?? 'N/A', Colors.green),
              const SizedBox(width: 10),
              _kpi('Flagged', '${k['flaggedDrivers'] ?? 0}', Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          if ((k['flaggedDrivers'] ?? 0) > 0 && !_showFlaggedOnly)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${k['flaggedDrivers']} driver(s) below 60% on-time rate.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (drivers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No driver data for this period',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...drivers.map((d) => _driverCard(d)),
        ],
      ),
    );
  }

  Widget _driverCard(Map<String, dynamic> d) {
    final rank = _i(d['rank']);
    final onTimeRate = _i(d['onTimeRate']);
    final score = _i(d['performanceScore']);
    final isFlagged = d['isFlagged'] == true;
    final completed = _i(d['completed']);
    final onTime = _i(d['onTime']);

    Color rankColor;
    if (rank == 1)
      rankColor = const Color(0xFFFFD700);
    else if (rank == 2)
      rankColor = const Color(0xFFC0C0C0);
    else if (rank == 3)
      rankColor = const Color(0xFFCD7F32);
    else
      rankColor = Colors.grey.shade300;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFlagged ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFlagged ? Colors.red.shade200 : Colors.grey.shade200,
          width: isFlagged ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: rankColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          d['Name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (isFlagged) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '⚠️ Low',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _statusLabel(d['CurrentStatus'] ?? ''),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: score >= 70
                          ? Colors.green
                          : score >= 50
                          ? Colors.orange
                          : Colors.red,
                    ),
                  ),
                  const Text(
                    'score',
                    style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'On-time rate',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              Text(
                '$onTime / $completed deliveries',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 8),
              Text(
                '$onTimeRate%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: onTimeRate >= 80
                      ? Colors.green
                      : onTimeRate >= 60
                      ? Colors.orange
                      : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (onTimeRate / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade100,
              color: onTimeRate >= 80
                  ? Colors.green
                  : onTimeRate >= 60
                  ? Colors.orange
                  : Colors.red,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statChip(
                Icons.local_shipping_outlined,
                '${d['totalDeliveries']} assigned',
              ),
              const SizedBox(width: 8),
              _statChip(Icons.check_circle_outline, '$completed completed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrend() {
    final trend = (_data!['trend'] as List?) ?? [];
    if (trend.isEmpty)
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.show_chart_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'No trend data for this period',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      );

    final Map<String, List<FlSpot>> driverData = {};
    final weekSet = <String>{};
    for (final t in trend) {
      weekSet.add(t['week'] ?? '');
      driverData.putIfAbsent(t['driver'] ?? '', () => []);
    }
    final weeks = weekSet.toList()..sort();
    for (final t in trend) {
      final name = t['driver'] ?? '';
      final weekIdx = weeks.indexOf(t['week'] ?? '').toDouble();
      driverData[name]?.add(FlSpot(weekIdx, _n(t['deliveries'])));
    }
    final colors = [
      const Color(0xFF0056B3),
      Colors.green.shade500,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.teal.shade400,
      Colors.red.shade400,
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deliveries per Driver — Weekly Trend',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                        drawVerticalLine: false,
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
                            getTitlesWidget: (v, _) => Text(
                              '${v.toInt()}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx < 0 || idx >= weeks.length)
                                return const SizedBox.shrink();
                              final w = weeks[idx].length > 5
                                  ? weeks[idx].substring(5)
                                  : weeks[idx];
                              return Text(
                                'W$w',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF94A3B8),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: driverData.entries
                          .toList()
                          .asMap()
                          .entries
                          .map((e) {
                            final ci = e.key % colors.length;
                            return LineChartBarData(
                              spots: e.value.value
                                ..sort((a, b) => a.x.compareTo(b.x)),
                              isCurved: true,
                              color: colors[ci],
                              barWidth: 2.5,
                              dotData: const FlDotData(show: true),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: driverData.keys
                      .toList()
                      .asMap()
                      .entries
                      .map(
                        (e) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: colors[e.key % colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              e.value,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );

  Widget _statChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F7FA),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    ),
  );

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'AVAILABLE':
        return '🟢 Available';
      case 'BUSY':
        return '🔴 Busy';
      case 'ON_BREAK':
        return '🟡 On Break';
      default:
        return '⚫ Offline';
    }
  }

  Widget _errView() => Center(
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

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.grey.shade200),
    boxShadow: [
      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6),
    ],
  );
}
