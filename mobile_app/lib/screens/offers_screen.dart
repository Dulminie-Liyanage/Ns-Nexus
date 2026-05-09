import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'order_screen.dart';

double _d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;
int _ii(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

// Sanitize API response — convert string numbers to actual nums
dynamic _sanitize(dynamic obj) {
  if (obj is Map) {
    return Map<String, dynamic>.fromEntries(
      obj.entries.map((e) => MapEntry(e.key.toString(), _sanitize(e.value))),
    );
  } else if (obj is List) {
    return obj.map(_sanitize).toList();
  } else if (obj is String) {
    final i = int.tryParse(obj);
    if (i != null) return i;
    final d = double.tryParse(obj);
    if (d != null) return d;
  }
  return obj;
}

// ─────────────────────────────────────────────────────────────────────────────
// RETAILER VIEW — Personalized offers
// ─────────────────────────────────────────────────────────────────────────────
class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});
  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  static const String _base = 'http://15.235.160.20:25568';
  List<dynamic> _offers = [];
  List<dynamic> _combos = [];
  bool _loading = true;
  String? _error;

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
      final userId = prefs.getString('userId') ?? '';
      if (userId.isEmpty) throw Exception('Session error');
      final token = await _token();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final res = await http
          .get(Uri.parse('$_base/offers/retailer/$userId'), headers: headers)
          .timeout(const Duration(seconds: 10));

      final data = _sanitize(jsonDecode(res.body)) as Map<String, dynamic>;
      setState(() {
        _offers = (data['offers'] ?? []) as List;
        _combos = (data['comboSuggestions'] ?? []) as List;
        _loading = false;
      });
    } catch (e) {
      // If offers endpoint not available yet, just show empty screen
      setState(() {
        _offers = [];
        _combos = [];
        _loading = false;
      });
    }
  }

  Color _offerColor(String type) {
    switch (type) {
      case 'bulk_discount':
        return const Color(0xFF0056B3);
      case 'combo':
        return const Color(0xFF16A34A);
      case 'flash_sale':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF7C3AED);
    }
  }

  String _offerTypeLabel(String type) {
    switch (type) {
      case 'bulk_discount':
        return '💰 Bulk Discount';
      case 'combo':
        return '🎁 Combo Deal';
      case 'flash_sale':
        return '⚡ Flash Sale';
      default:
        return '🏷️ Special Offer';
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
          'Special Offers',
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
          : RefreshIndicator(
              onRefresh: _load,
              child: _offers.isEmpty && _combos.isEmpty
                  ? _emptyView()
                  : _buildContent(),
            ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF0056B3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🎉', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 8),
                    Text(
                      'Personalized for You',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_offers.length} exclusive offers based on your order history',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Active offers
          if (_offers.isNotEmpty) ...[
            const Text(
              'Active Offers',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            ..._offers.map((offer) => _offerCard(offer)),
            const SizedBox(height: 20),
          ],

          // Combo suggestions
          if (_combos.isNotEmpty) ...[
            const Text(
              'Frequently Ordered Together',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Products you typically order — add them quickly',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            _comboSection(),
          ],
        ],
      ),
    );
  }

  Widget _offerCard(dynamic offer) {
    final color = _offerColor(offer['OfferType'] ?? '');
    final discount = _d(offer['DiscountPercent']);
    final minOrder = _d(offer['MinOrderValue']);
    final expiry = offer['ExpiresAt']?.toString();
    final expiryStr = expiry != null ? expiry.split('T').first : 'No expiry';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // Top banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withAlpha(15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              border: Border(bottom: BorderSide(color: color.withAlpha(25))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _offerTypeLabel(offer['OfferType'] ?? ''),
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (discount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${discount.toInt()}% OFF',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer['Title'] ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if ((offer['Description'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    offer['Description'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (minOrder > 0) ...[
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Min order: LKR ${minOrder.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(
                      Icons.schedule_outlined,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Expires: $expiryStr',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OrderScreen(offerDiscount: _d(discount)),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Place Order with Offer',
                      style: TextStyle(fontWeight: FontWeight.w700),
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

  Widget _comboSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ..._combos.asMap().entries.map((e) {
            final isLast = e.key == _combos.length - 1;
            final p = e.value;
            final price = _d(p['Price']);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: !isLast
                    ? Border(bottom: BorderSide(color: Colors.grey.shade100))
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6EFFF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF0056B3),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['ProductName'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Ordered ${_ii(p['orderCount'])} times',
                          style: const TextStyle(
                            fontSize: 11,
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
                        'LKR ${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0056B3),
                        ),
                      ),
                      Text(
                        p['Unit'] ?? '',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderScreen(suggestedProducts: _combos),
                  ),
                ),
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
                label: const Text(
                  'Order These Products',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0056B3),
                  side: const BorderSide(color: Color(0xFF0056B3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_offer_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text(
          'No offers available right now',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Check back soon for personalized deals',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      ],
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
}

// ─────────────────────────────────────────────────────────────────────────────
// WM VIEW — Manage offers
// ─────────────────────────────────────────────────────────────────────────────
class ManageOffersScreen extends StatefulWidget {
  const ManageOffersScreen({super.key});
  @override
  State<ManageOffersScreen> createState() => _ManageOffersScreenState();
}

class _ManageOffersScreenState extends State<ManageOffersScreen> {
  static const String _base = 'http://15.235.160.20:25568';
  List<dynamic> _offers = [];
  bool _loading = true;

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
      final token = await _token();
      final res = await http
          .get(
            Uri.parse('$_base/offers/all'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      final data = _sanitize(jsonDecode(res.body)) as Map<String, dynamic>;
      setState(() {
        _offers = (data['offers'] ?? []) as List;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _offers = [];
        _loading = false;
      });
    }
  }

  Future<void> _deleteOffer(int id) async {
    try {
      final token = await _token();
      await http
          .delete(
            Uri.parse('$_base/offers/$id'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer deactivated'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (_) {}
  }

  void _showCreateDialog({dynamic existing}) {
    final titleCtrl = TextEditingController(text: existing?['Title'] ?? '');
    final descCtrl = TextEditingController(
      text: existing?['Description'] ?? '',
    );
    final discountCtrl = TextEditingController(
      text: existing?['DiscountPercent']?.toString() ?? '',
    );
    final minCtrl = TextEditingController(
      text: existing?['MinOrderValue']?.toString() ?? '',
    );
    String type = existing?['OfferType'] ?? 'bulk_discount';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null ? 'Create New Offer' : 'Edit Offer',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: _field('Offer Title *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: _field('Description'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: _field('Offer Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'bulk_discount',
                      child: Text('💰 Bulk Discount'),
                    ),
                    DropdownMenuItem(
                      value: 'combo',
                      child: Text('🎁 Combo Deal'),
                    ),
                    DropdownMenuItem(
                      value: 'flash_sale',
                      child: Text('⚡ Flash Sale'),
                    ),
                  ],
                  onChanged: (v) => setS(() => type = v!),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: discountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _field('Discount %'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: minCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _field('Min Order (LKR)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.isEmpty) return;
                      final token = await _token();
                      final body = jsonEncode({
                        'title': titleCtrl.text,
                        'description': descCtrl.text,
                        'offerType': type,
                        'discountPercent':
                            double.tryParse(discountCtrl.text) ?? 0,
                        'minOrderValue': double.tryParse(minCtrl.text) ?? 0,
                        'productIds': [],
                      });
                      if (existing == null) {
                        await http.post(
                          Uri.parse('$_base/offers'),
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer $token',
                          },
                          body: body,
                        );
                      } else {
                        await http.put(
                          Uri.parse('$_base/offers/${existing['OfferID']}'),
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer $token',
                          },
                          body: body,
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0056B3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      existing == null ? 'Create Offer' : 'Save Changes',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _field(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Manage Offers',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF0056B3)),
            onPressed: () => _showCreateDialog(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(),
        backgroundColor: const Color(0xFF0056B3),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Offer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _offers.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    size: 56,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No offers yet',
                    style: TextStyle(fontSize: 16, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap + to create your first offer',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _offers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final o = _offers[i];
                final isActive = _ii(o['IsActive']) == 1;
                final discount = _d(o['DiscountPercent']);
                return Container(
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? Colors.grey.shade200
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFE6EFFF)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.local_offer_outlined,
                        color: isActive ? const Color(0xFF0056B3) : Colors.grey,
                      ),
                    ),
                    title: Text(
                      o['Title'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isActive ? const Color(0xFF1E293B) : Colors.grey,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o['OfferType']?.toString().replaceAll('_', ' ') ?? '',
                          style: const TextStyle(fontSize: 11),
                        ),
                        if (discount > 0)
                          Text(
                            '${discount.toInt()}% discount',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF0056B3),
                            ),
                          ),
                        Text(
                          isActive ? '✅ Active' : '❌ Inactive',
                          style: TextStyle(
                            fontSize: 11,
                            color: isActive ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _showCreateDialog(existing: o),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red.shade400,
                          ),
                          onPressed: () => _deleteOffer(o['OfferID']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
