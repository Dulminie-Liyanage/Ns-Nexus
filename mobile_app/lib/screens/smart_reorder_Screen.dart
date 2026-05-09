import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'order_screen.dart';

class SmartReorderScreen extends StatefulWidget {
  const SmartReorderScreen({super.key});
  @override
  State<SmartReorderScreen> createState() => _SmartReorderScreenState();
}

class _SmartReorderScreenState extends State<SmartReorderScreen> {
  static const String _base = 'http://15.235.160.20:25568';

  List<dynamic> _templates = [];
  bool _loading = true;
  bool _isHeavy = false;
  String? _error;
  String _userId = '';

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId') ?? '';
      if (_userId.isEmpty) throw Exception('Session error');

      final token = await _token();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Check if heavy retailer
      final heavyRes = await http
          .get(
            Uri.parse('$_base/orders/retailer/$_userId/heavy-check'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      final heavyData = jsonDecode(heavyRes.body);
      final isHeavy = heavyData['isHeavy'] == true;

      if (!isHeavy) {
        setState(() {
          _isHeavy = false;
          _loading = false;
        });
        return;
      }

      // Get templates
      final templatesRes = await http
          .get(
            Uri.parse('$_base/orders/retailer/$_userId/templates'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      final templatesData = jsonDecode(templatesRes.body);
      setState(() {
        _isHeavy = true;
        _templates = templatesData['templates'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  IconData _templateIcon(String icon) {
    switch (icon) {
      case 'inventory_2':
        return Icons.inventory_2_outlined;
      case 'calendar_today':
        return Icons.calendar_today_outlined;
      case 'bolt':
        return Icons.bolt_rounded;
      default:
        return Icons.shopping_cart_outlined;
    }
  }

  Color _templateColor(String id) {
    switch (id) {
      case 'large_bulk':
        return const Color(0xFF0056B3);
      case 'medium_weekly':
        return const Color(0xFF16A34A);
      case 'emergency_restock':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF7C3AED);
    }
  }

  void _useTemplate(dynamic template) {
    final items =
        (template['items'] as List?)
            ?.map(
              (i) => {
                'productId': i['productId']?.toString() ?? '',
                'productName': i['productName'] ?? '',
                'sku': i['sku'] ?? '',
                'unit': i['unit'] ?? '',
                'qty': i['qty'] ?? 1,
                'price': i['currentPrice'] ?? 0.0,
              },
            )
            .toList() ??
        [];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OrderScreen(preloadedItems: items, templateName: template['name']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Smart Quick Order',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errView()
          : !_isHeavy
          ? _notHeavyView()
          : _templates.isEmpty
          ? _insufficientHistoryView()
          : _buildTemplates(),
    );
  }

  Widget _buildTemplates() {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0056B3), Color(0xFF1E88E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(50),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart Templates',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Generated from your purchase history',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Choose a Template',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to pre-fill your order — you can modify before placing',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),

            ..._templates.map((t) => _templateCard(t)),
          ],
        ),
      ),
    );
  }

  Widget _templateCard(dynamic t) {
    final color = _templateColor(t['id'] ?? '');
    final items = (t['items'] as List?) ?? [];
    final total =
        double.tryParse(t['estimatedTotal']?.toString() ?? '0') ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withAlpha(15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              border: Border(bottom: BorderSide(color: color.withAlpha(30))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _templateIcon(t['icon'] ?? ''),
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['name'] ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      Text(
                        t['description'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'LKR ${_fmt(total)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      '${items.length} items',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Items preview
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                ...items
                    .take(3)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FA),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.inventory_outlined,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item['productName'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'x${item['qty']}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'LKR ${_fmt(((item['currentPrice'] as num?) ?? 0).toDouble() * ((item['qty'] as num?) ?? 1).toDouble())}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0056B3),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (items.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${items.length - 3} more items',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _useTemplate(t),
                    icon: const Icon(Icons.shopping_cart_checkout, size: 18),
                    label: const Text(
                      'Use This Template',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
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

  Widget _notHeavyView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Smart Templates Not Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Smart order templates are available for heavy bulk retailers.\n\nPlace more orders to unlock this feature.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE6EFFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              children: [
                Text(
                  'Requirements to unlock:',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF0056B3),
                  ),
                ),
                SizedBox(height: 8),
                _Req('At least 5 completed orders'),
                _Req('At least 1 bulk order (LKR 10,000+ or 50kg+)'),
                _Req('Orders with 3+ different products'),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _insufficientHistoryView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Building Your Templates',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Place a few more orders and we\'ll generate personalized templates for you.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    ),
  );

  Widget _errView() => Center(
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
  );

  String _fmt(num val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toStringAsFixed(0);
  }
}

class _Req extends StatelessWidget {
  final String text;
  const _Req(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 14,
          color: Color(0xFF0056B3),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
          ),
        ),
      ],
    ),
  );
}
