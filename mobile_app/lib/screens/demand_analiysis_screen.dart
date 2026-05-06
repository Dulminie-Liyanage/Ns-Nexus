import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:web/web.dart' as web;
import '../services/analiytics_service.dart';

double _n(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;
int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

class DemandAnalysisScreen extends StatefulWidget {
  const DemandAnalysisScreen({super.key});
  @override
  State<DemandAnalysisScreen> createState() => _DemandAnalysisScreenState();
}

class _DemandAnalysisScreenState extends State<DemandAnalysisScreen>
    with SingleTickerProviderStateMixin {
  final _svc = AnalyticsService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String _range = 'all';
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
      final data = await _svc.getDemand(range: _range == 'all' ? null : _range);
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
    final top10 = (_data!['top10'] as List?) ?? [];
    final rows = [
      ['Rank', 'Product', 'SKU', 'Total Qty', 'Order Count', 'Total Value LKR'],
      ...top10.asMap().entries.map(
        (e) => [
          (e.key + 1).toString(),
          e.value['ProductName'] ?? '',
          e.value['SKU'] ?? '',
          e.value['totalQty']?.toString() ?? '0',
          e.value['orderCount']?.toString() ?? '0',
          e.value['totalValue']?.toString() ?? '0',
        ],
      ),
    ];
    try {
      final csvString = Csv().encode(rows);
      final fname = 'demand_${DateTime.now().millisecondsSinceEpoch}.csv';
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
          'Product Demand Analysis',
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
            Tab(text: 'Top 10'),
            Tab(text: 'Trends'),
            Tab(text: 'Growth'),
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
                    children: [_buildTop10(), _buildTrends(), _buildGrowth()],
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
                side: BorderSide(
                  color: isActive
                      ? const Color(0xFF0056B3)
                      : Colors.grey.shade300,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTop10() {
    final top10 = (_data!['top10'] as List?) ?? [];
    final kpis = _data!['kpis'] ?? {};
    if (top10.isEmpty) return _emptyView('No demand data for this period');
    final maxQty = top10
        .map((p) => _n(p['totalQty']))
        .reduce((a, b) => a > b ? a : b);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _miniKpi(
                'Top Product',
                kpis['topProduct'] ?? 'N/A',
                Colors.purple.shade400,
              ),
              const SizedBox(width: 10),
              _miniKpi(
                'High Demand',
                '${kpis['highDemandCount'] ?? 0} products',
                Colors.orange.shade500,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top 10 Products by Volume',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxQty + 5,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                            '${rod.toY.toInt()} units',
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
                              '${v.toInt()}',
                              style: const TextStyle(
                                fontSize: 10,
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
                              if (idx >= top10.length)
                                return const SizedBox.shrink();
                              final name = (top10[idx]['ProductName'] ?? '')
                                  .toString();
                              return Text(
                                name.length > 6 ? name.substring(0, 6) : name,
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
                      gridData: FlGridData(
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                      ),
                      barGroups: top10.asMap().entries.map((e) {
                        final qty = _n(e.value['totalQty']);
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: qty,
                              color: e.key == 0
                                  ? const Color(0xFF0056B3)
                                  : const Color(0xFF60A5FA),
                              width: 20,
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...top10.asMap().entries.map((e) {
            final p = e.value;
            final qty = _n(p['totalQty']);
            final pct = maxQty > 0 ? qty / maxQty : 0.0;
            final isHigh = pct >= 0.5;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: _cardDeco(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: e.key < 3
                              ? const Color(0xFF0056B3)
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${e.key + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: e.key < 3
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p['ProductName'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (isHigh)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            '🔥 High',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade100,
                      color: isHigh
                          ? Colors.orange.shade400
                          : const Color(0xFF0056B3),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${p['totalQty']} units • ${p['orderCount']} orders',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'LKR ${_fmt(p['totalValue'])}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0056B3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTrends() {
    final trend = (_data!['trend'] as List?) ?? [];
    if (trend.isEmpty) return _emptyView('No trend data available');
    final Map<String, List<FlSpot>> productData = {};
    final weekSet = <String>{};
    for (final t in trend) {
      weekSet.add(t['week'] ?? '');
      productData.putIfAbsent(t['ProductName'] ?? '', () => []);
    }
    final weeks = weekSet.toList()..sort();
    for (final t in trend) {
      final name = t['ProductName'] ?? '';
      final weekIdx = weeks.indexOf(t['week'] ?? '').toDouble();
      productData[name]?.add(FlSpot(weekIdx, _n(t['qty'])));
    }
    final colors = [
      const Color(0xFF0056B3),
      Colors.green.shade500,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.teal.shade400,
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
                  'Demand Trend — Top Products (Weekly)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
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
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
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
                      lineBarsData: productData.entries
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
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
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
                  children: productData.keys
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
                                fontSize: 10,
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

  Widget _buildGrowth() {
    final growth = (_data!['growth'] as List?) ?? [];
    growth.sort((a, b) => _i(b['growthPct']).compareTo(_i(a['growthPct'])));
    if (growth.isEmpty) return _emptyView('No growth data available');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardDeco(),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demand Growth (Last 30 days vs Prior 30 days)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Positive % = growing demand',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...growth.map((g) {
            final pct = _i(g['growthPct']);
            final isPos = pct >= 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: _cardDeco(),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g['ProductName'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Recent: ${g['recent']} | Prior: ${g['prior']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isPos ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isPos
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Text(
                      '${isPos ? '+' : ''}$pct%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isPos
                            ? Colors.green.shade700
                            : Colors.red.shade700,
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

  Widget _miniKpi(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _emptyView(String msg) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.bar_chart_outlined, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(msg, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
      ],
    ),
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

  String _fmt(dynamic val) {
    final d = _n(val);
    if (d >= 1000000) return '${(d / 1000000).toStringAsFixed(1)}M';
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)}K';
    return d.toStringAsFixed(0);
  }
}
