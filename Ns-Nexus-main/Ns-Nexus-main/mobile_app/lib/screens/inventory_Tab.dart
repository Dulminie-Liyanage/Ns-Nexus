import 'package:flutter/material.dart';
import '../services/inventory_service.dart';
import 'product_form_screen.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final InventoryService _service = InventoryService();
  List<dynamic> _products = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _filter = 'All'; // All, In Stock, Out of Stock, Low Stock

  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textLight = Color(0xFF6B7280);
  static const Color borderLight = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final products = await _service.fetchProducts();
      setState(() {
        _products = products;
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack('Failed to load products: $e', isError: true);
    }
  }

  void _applyFilters() {
    setState(() {
      _filtered = _products.where((p) {
        final name = (p['ProductName'] ?? '').toString().toLowerCase();
        final sku = (p['SKU'] ?? '').toString().toLowerCase();
        final matchSearch =
            _search.isEmpty ||
            name.contains(_search.toLowerCase()) ||
            sku.contains(_search.toLowerCase());

        final stock = int.tryParse(p['StockLevel']?.toString() ?? '0') ?? 0;
        final isAvailable = p['IsAvailable'] == 1;
        final matchFilter =
            _filter == 'All' ||
            (_filter == 'In Stock' && isAvailable && stock > 10) ||
            (_filter == 'Low Stock' && stock > 0 && stock <= 10) ||
            (_filter == 'Out of Stock' && (!isAvailable || stock == 0));

        return matchSearch && matchFilter;
      }).toList();
    });
  }

  Future<void> _toggleStatus(dynamic productId, int current) async {
    try {
      await _service.toggleProductStatus(productId, current == 1 ? 0 : 1);
      _load();
      _snack('Product status updated.');
    } catch (e) {
      _snack('Failed: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _openForm({dynamic product}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
    if (result == true) _load();
  }

  // ── Stock badge ──────────────────────────────────────────────────────────────
  Widget _stockBadge(int stock, bool isAvailable) {
    Color bg, fg;
    String label;
    IconData icon;

    if (!isAvailable || stock == 0) {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
      label = 'Out of Stock';
      icon = Icons.remove_circle_outline;
    } else if (stock <= 10) {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFD97706);
      label = 'Low Stock';
      icon = Icons.warning_amber_rounded;
    } else {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF059669);
      label = 'In Stock';
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  // ── Stock level bar ──────────────────────────────────────────────────────────
  Widget _stockBar(int stock) {
    final maxStock = 100;
    final pct = (stock / maxStock).clamp(0.0, 1.0);
    Color barColor;
    if (stock == 0) {
      barColor = const Color(0xFFDC2626);
    } else if (stock <= 10) {
      barColor = const Color(0xFFD97706);
    } else {
      barColor = const Color(0xFF059669);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Stock: ', style: TextStyle(fontSize: 11, color: textLight)),
            Text(
              '$stock units',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: stock <= 10 ? barColor : textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: borderLight,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Summary counts
    final totalProducts = _products.length;
    final inStock = _products
        .where(
          (p) =>
              p['IsAvailable'] == 1 &&
              (int.tryParse(p['StockLevel']?.toString() ?? '0') ?? 0) > 10,
        )
        .length;
    final lowStock = _products.where((p) {
      final s = int.tryParse(p['StockLevel']?.toString() ?? '0') ?? 0;
      return s > 0 && s <= 10;
    }).length;
    final outOfStock = _products
        .where(
          (p) =>
              p['IsAvailable'] != 1 ||
              (int.tryParse(p['StockLevel']?.toString() ?? '0') ?? 0) == 0,
        )
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Header ──────────────────────────────────────
                          Row(
                            children: [
                              const Text(
                                'Inventory',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: () => _openForm(),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Product'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Summary cards ────────────────────────────────
                          Row(
                            children: [
                              _summaryCard(
                                'Total',
                                '$totalProducts',
                                Icons.inventory_2_outlined,
                                const Color(0xFF3B82F6),
                                const Color(0xFFEFF6FF),
                              ),
                              const SizedBox(width: 8),
                              _summaryCard(
                                'In Stock',
                                '$inStock',
                                Icons.check_circle_outline,
                                const Color(0xFF059669),
                                const Color(0xFFECFDF5),
                              ),
                              const SizedBox(width: 8),
                              _summaryCard(
                                'Low',
                                '$lowStock',
                                Icons.warning_amber_rounded,
                                const Color(0xFFD97706),
                                const Color(0xFFFFFBEB),
                              ),
                              const SizedBox(width: 8),
                              _summaryCard(
                                'Out',
                                '$outOfStock',
                                Icons.remove_circle_outline,
                                const Color(0xFFDC2626),
                                const Color(0xFFFEF2F2),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Search ───────────────────────────────────────
                          TextField(
                            onChanged: (v) {
                              _search = v;
                              _applyFilters();
                            },
                            decoration: InputDecoration(
                              hintText: 'Search by name or SKU...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: borderLight),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: borderLight),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Filter chips ─────────────────────────────────
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children:
                                  [
                                    'All',
                                    'In Stock',
                                    'Low Stock',
                                    'Out of Stock',
                                  ].map((f) {
                                    final active = _filter == f;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        label: Text(f),
                                        selected: active,
                                        onSelected: (_) {
                                          setState(() => _filter = f);
                                          _applyFilters();
                                        },
                                        selectedColor: primaryBlue,
                                        labelStyle: TextStyle(
                                          fontSize: 12,
                                          color: active
                                              ? Colors.white
                                              : textDark,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
                          const SizedBox(height: 8),

                          Text(
                            '${_filtered.length} product${_filtered.length == 1 ? '' : 's'}',
                            style: TextStyle(fontSize: 12, color: textLight),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // ── Product list ──────────────────────────────────────────
                  _filtered.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 48,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No products found',
                                  style: TextStyle(color: Colors.grey.shade400),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ProductCard(
                                  product: _filtered[i],
                                  onEdit: () =>
                                      _openForm(product: _filtered[i]),
                                  onToggle: () => _toggleStatus(
                                    _filtered[i]['ProductID'],
                                    _filtered[i]['IsAvailable'] ?? 0,
                                  ),
                                  stockBadge: _stockBadge(
                                    int.tryParse(
                                          _filtered[i]['StockLevel']
                                                  ?.toString() ??
                                              '0',
                                        ) ??
                                        0,
                                    _filtered[i]['IsAvailable'] == 1,
                                  ),
                                  stockBar: _stockBar(
                                    int.tryParse(
                                          _filtered[i]['StockLevel']
                                                  ?.toString() ??
                                              '0',
                                        ) ??
                                        0,
                                  ),
                                ),
                              ),
                              childCount: _filtered.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color bg,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Product card widget ────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final dynamic product;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final Widget stockBadge;
  final Widget stockBar;

  static const Color textDark = Color(0xFF1F2937);
  static const Color textLight = Color(0xFF6B7280);
  static const Color borderLight = Color(0xFFE5E7EB);

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onToggle,
    required this.stockBadge,
    required this.stockBar,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    final price = double.tryParse(p['Price']?.toString() ?? '0') ?? 0.0;
    final weight = double.tryParse(p['Weight']?.toString() ?? '0') ?? 0.0;
    final isAvailable = p['IsAvailable'] == 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row ──────────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Name + SKU
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['ProductName']?.toString() ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${p['SKU']?.toString() ?? 'N/A'}',
                      style: const TextStyle(fontSize: 12, color: textLight),
                    ),
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: textLight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'toggle') onToggle();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          isAvailable
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAvailable ? 'Mark unavailable' : 'Mark available',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Stats row ─────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statItem('Price', 'LKR ${price.toStringAsFixed(0)}'),
                _divider(),
                _statItem('Weight', '${weight}kg'),
                _divider(),
                _statItem('Unit', p['Unit']?.toString() ?? 'N/A'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Stock bar ─────────────────────────────────────────────────────────
          stockBar,
          const SizedBox(height: 10),

          // ── Bottom row: badge + toggle ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              stockBadge,
              Row(
                children: [
                  Text(
                    isAvailable ? 'Available' : 'Unavailable',
                    style: TextStyle(
                      fontSize: 12,
                      color: isAvailable
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isAvailable,
                      activeColor: const Color(0xFF059669),
                      onChanged: (_) => onToggle(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: textLight)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 28, color: const Color(0xFFE5E7EB));
  }
}
