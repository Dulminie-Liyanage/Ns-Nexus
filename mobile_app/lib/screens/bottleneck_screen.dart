import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:web/web.dart' as web;
import '../services/analiytics_service.dart';

double _n(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;
int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

class BottleneckScreen extends StatefulWidget {
  const BottleneckScreen({super.key});
  @override
  State<BottleneckScreen> createState() => _BottleneckScreenState();
}

class _BottleneckScreenState extends State<BottleneckScreen> {
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
      final data = await _svc.getBottleneck(
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
    final stages = (_data!['stages'] as List?) ?? [];
    final rows = [
      ['Stage', 'Label', 'Count', 'Drop-off %', 'Avg Hours'],
      ...stages.map(
        (s) => [
          s['stage']?.toString() ?? '',
          s['label'] ?? '',
          s['count']?.toString() ?? '0',
          '${s['dropOffPct'] ?? 0}%',
          '${s['avgHours'] ?? 0}h',
        ],
      ),
    ];
    try {
      final csvString = Csv().encode(rows);
      final fname = 'bottleneck_${DateTime.now().millisecondsSinceEpoch}.csv';
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
          'Order Bottleneck Analysis',
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errView()
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
                    _kpiRow(),
                    const SizedBox(height: 16),
                    _bottleneckAlert(),
                    const SizedBox(height: 16),
                    _funnelChart(),
                    const SizedBox(height: 16),
                    _avgTimeChart(),
                    const SizedBox(height: 16),
                    _stageTable(),
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
      ('monthly', 'Month'),
      ('weekly', 'Week'),
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
                fontSize: 12,
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

  Widget _kpiRow() {
    final k = _data!['kpis'] ?? {};
    return Row(
      children: [
        _kpi(
          'Total Orders',
          k['totalOrders']?.toString() ?? '0',
          const Color(0xFF0056B3),
        ),
        const SizedBox(width: 10),
        _kpi('Delivered', k['delivered']?.toString() ?? '0', Colors.green),
        const SizedBox(width: 10),
        _kpi('Drop-off', '${k['dropOffRate'] ?? 0}%', Colors.red),
      ],
    );
  }

  Widget _kpi(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bottleneckAlert() {
    final k = _data!['kpis'] ?? {};
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bottleneck: ${k['bottleneckStage'] ?? 'N/A'}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.red.shade800,
                  ),
                ),
                Text(
                  'Avg time: ${k['bottleneckAvgHours'] ?? 0}h — highest in pipeline',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _funnelChart() {
    final stages = (_data!['stages'] as List?) ?? [];
    if (stages.isEmpty) return const SizedBox.shrink();
    final maxCount = stages
        .map((s) => _n(s['count']))
        .reduce((a, b) => a > b ? a : b);
    final stageColors = [
      Colors.grey.shade400,
      Colors.blue.shade300,
      Colors.indigo.shade400,
      Colors.purple.shade400,
      Colors.teal.shade500,
      Colors.orange.shade500,
      Colors.green.shade600,
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pipeline Funnel',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          ...stages.asMap().entries.map((e) {
            final s = e.value;
            final count = _n(s['count']);
            final pct = maxCount > 0 ? count / maxCount : 0.0;
            final dropOff = _i(s['dropOffPct']);
            final ci = e.key.clamp(0, stageColors.length - 1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      s['label'] ?? '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: pct.clamp(0.02, 1.0),
                          child: Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: stageColors[ci],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              '${count.toInt()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (dropOff > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '-$dropOff%',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _avgTimeChart() {
    final stages = (_data!['stages'] as List?) ?? [];
    if (stages.isEmpty) return const SizedBox.shrink();
    final bottleneckStage = _data!['bottleneck']?['stage'];
    final maxAvg = stages
        .map((s) => _n(s['avgHours']))
        .reduce((a, b) => a > b ? a : b);
    if (maxAvg == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Average Time per Stage (Hours)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxAvg + 5,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      '${rod.toY.toInt()}h',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
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
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}h',
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
                        if (idx < 0 || idx >= stages.length)
                          return const SizedBox.shrink();
                        return Text(
                          'S${stages[idx]['stage']}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                barGroups: stages.asMap().entries.map((e) {
                  final s = e.value;
                  final avg = _n(s['avgHours']);
                  final isBottle = _i(s['stage']) == _i(bottleneckStage);
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: avg,
                        color: isBottle
                            ? Colors.red.shade400
                            : const Color(0xFF60A5FA),
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
          const SizedBox(height: 8),
          Row(
            children: [
              _legend(Colors.red.shade400, 'Bottleneck'),
              const SizedBox(width: 16),
              _legend(const Color(0xFF60A5FA), 'Other stages'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stageTable() {
    final stages = (_data!['stages'] as List?) ?? [];
    if (stages.isEmpty) return const SizedBox.shrink();
    final bottleneckStage = _data!['bottleneck']?['stage'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stage Summary',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1.2),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                children: ['Stage', 'Orders', 'Drop-off', 'Avg Time']
                    .map(
                      (h) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          h,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              ...stages.map((s) {
                final dropOff = _i(s['dropOffPct']);
                final isBottle = _i(s['stage']) == _i(bottleneckStage);
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        s['label'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isBottle
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isBottle
                              ? Colors.red.shade700
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        s['count']?.toString() ?? '0',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        dropOff > 0 ? '-$dropOff%' : '—',
                        style: TextStyle(
                          fontSize: 12,
                          color: dropOff > 30
                              ? Colors.red.shade500
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '${s['avgHours'] ?? 0}h',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isBottle
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isBottle
                              ? Colors.red.shade700
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      ),
    ],
  );

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
