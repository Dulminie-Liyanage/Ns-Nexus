import 'package:flutter/material.dart';
import 'disruption_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/product_service.dart';
import '../services/order_service.dart';

class OrderScreen extends StatefulWidget {
  final bool isUrgent;
  final Map<String, int>? preFilledCart;
  final bool isReorder;
  /// US-26: Preloaded items from smart template
  final List<Map<String, dynamic>>? preloadedItems;
  final String? templateName;
  /// US-27: Offer discount percentage
  final double offerDiscount;
  /// US-27: Minimum order value to qualify for discount
  final double offerMinValue;
  /// US-27: Offer title shown to retailer
  final String? offerTitle;
  /// US-27: Suggested products from combo
  final List<dynamic>? suggestedProducts;

  const OrderScreen({
    super.key,
    this.isUrgent = false,
    this.preFilledCart,
    this.isReorder = false,
    this.preloadedItems,
    this.templateName,
    this.offerDiscount = 0.0,
    this.offerMinValue = 0.0,
    this.offerTitle,
    this.suggestedProducts,
  });

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final ProductService _productService = ProductService();
  final OrderService _orderService = OrderService();

  List<dynamic> _products = [];
  final Map<String, int> _cart = {};
  bool _isLoading = true;
  String? _errorMessage;

  DateTime? _selectedDate;
  bool _isUrgent = false;
  bool _isSubmitting = false;
  String? _validationError;

  double _currentTotalWeight = 0.0;
  double _currentTotalPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _isUrgent = false; // always start false, check priority before enabling
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProducts());
    // If opened from "Create Urgent Order" card, verify priority first
    if (widget.isUrgent) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryEnableUrgent());
    }
  }

  // Check priority status before enabling urgent mode
  // Urgent toggle is visible to ALL retailers — non-priority see an info dialog
  Future<void> _tryEnableUrgent() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    final isPriority = await _orderService.checkPriorityStatus(userId);
    if (!mounted) return;
    if (isPriority) {
      setState(() => _isUrgent = true);
    } else {
      // Show info dialog explaining how to get priority status
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.bolt_rounded, color: Colors.amber.shade700, size: 22),
            const SizedBox(width: 8),
            const Text('Priority Required', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          content: const Text(
            'Urgent orders are only available to Priority retailers.'
            'Priority status allows you to bypass the 48-hour notice rule for urgent restocking needs.'
            'Contact your Nestlé representative to request priority status for your account.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _productService.fetchAvailableProducts();
      if (!mounted) return;
      // Sort: available + in-stock first, out of stock at bottom
      final sorted = [...products];
      sorted.sort((a, b) {
        final aAvail = (a['IsAvailable'] == 1 || a['IsAvailable'] == true) ? 1 : 0;
        final bAvail = (b['IsAvailable'] == 1 || b['IsAvailable'] == true) ? 1 : 0;
        final aStock = int.tryParse(a['StockLevel']?.toString() ?? '0') ?? 0;
        final bStock = int.tryParse(b['StockLevel']?.toString() ?? '0') ?? 0;
        if (aAvail != bAvail) return bAvail - aAvail;
        if ((aStock > 0) != (bStock > 0)) return bStock > 0 ? 1 : -1;
        return 0;
      });

      setState(() {
        _products = sorted;
        _isLoading = false;
        // US-19: Pre-fill from quick reorder
        if (widget.preFilledCart != null) {
          final availableIds = products.map((p) =>
            (p['ProductID'] ?? p['id'] ?? '').toString()).toSet();
          for (final entry in widget.preFilledCart!.entries) {
            if (availableIds.contains(entry.key) && entry.value > 0) {
              _cart[entry.key] = entry.value;
            }
          }
        }
        // US-26: Pre-fill from smart template
        if (widget.preloadedItems != null && widget.preloadedItems!.isNotEmpty) {
          for (final item in widget.preloadedItems!) {
            final pid = item['productId']?.toString() ?? '';
            final qty = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;
            if (pid.isNotEmpty && qty > 0) {
              _cart[pid] = qty;
            }
          }
        }
        // US-27: Pre-fill from combo suggestions
        if (widget.suggestedProducts != null && widget.suggestedProducts!.isNotEmpty) {
          for (final p in widget.suggestedProducts!) {
            final pid = (p['ProductID'] ?? p['productId'] ?? '').toString();
            if (pid.isNotEmpty) {
              _cart[pid] = 1;
            }
          }
        }
      });
      _calculateTotals();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Returns stock level for a product ────────────────────────────────────────
  int _getStockLevel(dynamic product) {
    return int.tryParse(product['StockLevel']?.toString() ?? '999') ?? 999;
  }

  // ── Update quantity with stock cap ────────────────────────────────────────────
  void _updateQuantity(String id, int delta) {
    setState(() {
      final current = _cart[id] ?? 0;
      int next = current + delta;

      if (delta > 0) {
        final product = _products.firstWhere(
          (p) => _getProductId(p) == id,
          orElse: () => null,
        );
        if (product != null) {
          final stockLevel = _getStockLevel(product);
          if (next > stockLevel) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Only $stockLevel units available for ${product['ProductName']}'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ));
            next = stockLevel;
          }
        }
      }

      if (next <= 0) {
        _cart.remove(id);
      } else {
        _cart[id] = next;
      }
      if (_validationError != null && _validationError!.contains('empty')) {
        _validationError = null;
      }
    });
    _calculateTotals();
  }

  void _calculateTotals() {
    double tempWeight = 0.0;
    double tempPrice = 0.0;

    for (var p in _products) {
      final id = _getProductId(p);
      if (_cart.containsKey(id) && _cart[id]! > 0) {
        final price =
            double.tryParse((p['Price'] ?? p['price'])?.toString() ?? '0') ??
                0.0;
        final weightRaw = p['Weight'] ??
            p['weight'] ??
            p['ItemWeight'] ??
            p['item_weight'] ??
            p['TotalWeight'];

        double weight = 0.0;
        if (weightRaw != null) {
          weight = double.tryParse(weightRaw.toString()) ?? 0.0;
        } else {
          weight = _extractWeightFromName(
              p['ProductName'] ?? p['productName'] ?? '');
        }

        tempWeight += (weight * _cart[id]!);
        tempPrice += (price * _cart[id]!);
      }
    }

    // US-27: Apply offer discount ONLY if minimum order value is met
    final subtotal = tempPrice;
    if (widget.offerDiscount > 0) {
      if (widget.offerMinValue <= 0 || subtotal >= widget.offerMinValue) {
        tempPrice = subtotal * (1 - widget.offerDiscount / 100);
      }
      // else: discount NOT applied — minimum not met
    }

    setState(() {
      _currentTotalWeight = tempWeight;
      _currentTotalPrice = tempPrice;
    });
  }

  double _extractWeightFromName(String name) {
    name = name.toLowerCase();
    final kgMatch = RegExp(r'(\d+(?:\.\d+)?)\s*kg').firstMatch(name);
    if (kgMatch != null) return double.tryParse(kgMatch.group(1)!) ?? 0.0;
    final gMatch = RegExp(r'(\d+(?:\.\d+)?)\s*g').firstMatch(name);
    if (gMatch != null)
      return (double.tryParse(gMatch.group(1)!) ?? 0.0) / 1000.0;
    return 0.0;
  }

  String _getProductId(dynamic product) {
    return (product['ProductID'] ??
            product['productId'] ??
            product['id'] ??
            product['Id'] ??
            product['_id'])
        .toString();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _validationError = null;
      });
    }
  }

  // ── Submit with full stock validation ─────────────────────────────────────────
  Future<void> _submitOrder() async {
    if (_cart.isEmpty) {
      setState(() => _validationError = 'Cart is empty. Please add items.');
      return;
    }
    if (_selectedDate == null) {
      setState(() => _validationError = 'Please select a delivery date.');
      return;
    }

    // 48-hour check — skipped for urgent (priority already verified when toggle was enabled)
    if (!_isUrgent) {
      final diff = _selectedDate!.difference(DateTime.now());
      if (diff.inHours < 48) {
        setState(() => _validationError =
            'Standard orders require a 48-hour notice. Please select a later date or mark as Urgent.');
        return;
      }
    }

    // Stock validation — prevent ordering more than available
    for (final entry in _cart.entries) {
      final matches = _products.where((p) => _getProductId(p) == entry.key);
      final product = matches.isNotEmpty ? matches.first : null;
      if (product != null) {
        // Check if product is available
        if (product['IsAvailable'] == 0) {
          setState(() => _validationError =
              '"${product['ProductName']}" is currently unavailable.');
          return;
        }
        // Check stock level
        final stockLevel = _getStockLevel(product);
        if (entry.value > stockLevel) {
          setState(() => _validationError =
              '"${product['ProductName']}": only $stockLevel units in stock. Please reduce quantity.');
          return;
        }
      }
    }

    setState(() {
      _isSubmitting = true;
      _validationError = null;
    });

    try {
      final itemsList = _cart.entries
          .map((e) => {
                'product_id': int.tryParse(e.key) ?? e.key,
                'qty_requested': e.value,
              })
          .toList();

      final dateStr =
          "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";

      final prefs = await SharedPreferences.getInstance();
      final retailerId =
          int.tryParse(prefs.getString('userId') ?? '0') ?? 0;

      await _orderService.placeOrder(
          retailerId, itemsList, dateStr, _isUrgent ? 1 : 0);

      if (!mounted) return;

      // Show success snackbar then navigate back to retailer home
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isUrgent
            ? 'Urgent order placed successfully!'
            : 'Order placed successfully!'),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));

      // Navigate back to previous screen (RetailerScreen)
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _validationError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isReorder ? 'Quick Reorder' : (_isUrgent ? 'Urgent Order' : 'New Order'),
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        // Show urgent banner in app bar if urgent (not shown in reorder mode)
        bottom: !widget.isReorder && _isUrgent
            ? PreferredSize(
                preferredSize: const Size.fromHeight(32),
                child: Container(
                  width: double.infinity,
                  color: Colors.red.shade50,
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  child: Row(children: [
                    Icon(Icons.bolt_rounded,
                        size: 14, color: Colors.red.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'Urgent order — 48-hour rule bypassed',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
    }
    if (_errorMessage != null) {
      return Center(
          child:
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)));
    }

    // PO-02: Wrap body with disruption banner at top
    return Column(children: [
      const DisruptionBanner(),
      Expanded(child: _buildProductList()),
    ]);
  }

  Widget _buildProductList() {
    if (_products.isEmpty) {
      return const Center(
          child: Text('No products available',
              style: TextStyle(color: Colors.grey, fontSize: 18)));
    }

    return Column(
      children: [
        // US-19: Reorder info banner — informs retailer prices are auto-updated
        if (widget.isReorder)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0056B3).withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0056B3).withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.replay_outlined, size: 16, color: Color(0xFF0056B3)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Items loaded from your previous order. Prices have been updated to current rates. Adjust quantities as needed.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF0056B3), fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              final id = _getProductId(product);
              final qty = _cart[id] ?? 0;
              final stockLevel = _getStockLevel(product);
              final isAvailable = product['IsAvailable'] != 0;

              final weightRaw = product['Weight'] ??
                  product['weight'] ??
                  product['ItemWeight'] ??
                  product['item_weight'];
              double weight = 0.0;
              if (weightRaw != null) {
                weight = double.tryParse(weightRaw.toString()) ?? 0.0;
              } else {
                weight = _extractWeightFromName(
                    product['ProductName'] ?? product['productName'] ?? '');
              }

              // Determine stock status color
              Color stockColor;
              String stockLabel;
              if (!isAvailable || stockLevel == 0) {
                stockColor = Colors.red.shade400;
                stockLabel = 'Out of stock';
              } else if (stockLevel <= 10) {
                stockColor = Colors.orange.shade600;
                stockLabel = 'Only $stockLevel left';
              } else {
                stockColor = Colors.green.shade600;
                stockLabel = '$stockLevel in stock';
              }

              return Opacity(
                opacity: isAvailable ? 1.0 : 0.5,
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: qty > 0
                        ? Border.all(
                            color: const Color(0xFF3B82F6).withOpacity(0.4),
                            width: 1.5)
                        : null,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Product icon
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF3B82F6).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.inventory_2_outlined,
                            color: Color(0xFF3B82F6), size: 26),
                      ),
                      const SizedBox(width: 14),
                      // Product info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['ProductName'] ??
                                  product['productName'] ??
                                  'Unknown',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'LKR ${product['Price']?.toString() ?? '0'} · ${weight}kg',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            // Stock indicator
                            Row(children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: stockColor,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 4),
                              Text(stockLabel,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: stockColor,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ],
                        ),
                      ),
                      // Qty controls
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        _buildQtyBtn(Icons.remove,
                            qty > 0 ? () => _updateQuantity(id, -1) : null),
                        SizedBox(
                          width: 32,
                          child: Text('$qty',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B))),
                        ),
                        _buildQtyBtn(
                          Icons.add,
                          // Disable + if out of stock or at max
                          (!isAvailable || qty >= stockLevel)
                              ? null
                              : () => _updateQuantity(id, 1),
                        ),
                      ]),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // ── Bottom panel ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, -5)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Totals
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Estimated Weight',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${_currentTotalWeight.toStringAsFixed(2)} kg',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: Color(0xFF1E293B))),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                    Text('Total Amount',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    if (widget.offerDiscount > 0)
                      Builder(builder: (ctx) {
                        // Calculate subtotal WITHOUT discount to check condition
                        double sub = 0;
                        for (var p in _products) {
                          final id = _getProductId(p);
                          if (_cart.containsKey(id) && _cart[id]! > 0) {
                            final price = double.tryParse(
                                (p['Price'] ?? p['price'])?.toString() ?? '0') ?? 0;
                            sub += price * _cart[id]!;
                          }
                        }
                        final qualifies = widget.offerMinValue <= 0 || sub >= widget.offerMinValue;
                        return Container(
                          margin: const EdgeInsets.only(top: 2, bottom: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: qualifies ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: qualifies ? Colors.green.shade200 : Colors.orange.shade200)),
                          child: Text(
                            qualifies
                              ? '${widget.offerDiscount.toInt()}% offer applied ✓'
                              : 'Add LKR ${(widget.offerMinValue - sub).toStringAsFixed(0)} more for ${widget.offerDiscount.toInt()}% off',
                            style: TextStyle(
                              fontSize: 10,
                              color: qualifies ? Colors.green.shade700 : Colors.orange.shade800,
                              fontWeight: FontWeight.w700)),
                        );
                      }),
                    const SizedBox(height: 2),
                    Text(
                        'LKR ${_currentTotalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Color(0xFF3B82F6))),
                  ]),
                ],
              ),
              const SizedBox(height: 16),
              // Date + Urgent row
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFFF1F5F9),
                      ),
                      child: Row(children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 10),
                        Text(
                          _selectedDate == null
                              ? 'Schedule Date'
                              : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 13,
                            color: _selectedDate == null
                                ? Colors.grey.shade600
                                : const Color(0xFF1E293B),
                            fontWeight: _selectedDate == null
                                ? FontWeight.w500
                                : FontWeight.bold,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Hide urgent in reorder mode — reorder uses original order intent
                if (!widget.isReorder) _buildUrgentBtn(),
              ]),
              // Validation error
              if (_validationError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_validationError!,
                            style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w600))),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              // Confirm button
              _isSubmitting
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF3B82F6)))
                  : ElevatedButton(
                      onPressed: _submitOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isUrgent
                            ? Colors.red.shade600
                            : const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _isUrgent
                            ? 'Confirm Urgent Order'
                            : 'Confirm Order',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUrgentBtn() {
    return InkWell(
      onTap: () async {
        if (_isUrgent) {
          // Turning OFF is always allowed
          setState(() => _isUrgent = false);
          return;
        }
        // Turning ON — check priority first
        await _tryEnableUrgent();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: _isUrgent
                ? Colors.red.shade400
                : Colors.amber.shade300,
            width: _isUrgent ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
          color: _isUrgent ? Colors.red.shade50 : Colors.amber.shade50,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bolt_rounded,
              size: 18,
              color: _isUrgent
                  ? Colors.red.shade700
                  : Colors.amber.shade800),
          const SizedBox(width: 6),
          Text(
            _isUrgent ? 'Urgent ON' : 'Urgent',
            style: TextStyle(
              color: _isUrgent
                  ? Colors.red.shade700
                  : Colors.amber.shade900,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: onTap == null
              ? const Color(0xFFF1F5F9)
              : const Color(0xFF3B82F6).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: onTap == null
                ? Colors.grey.shade300
                : const Color(0xFF3B82F6)),
      ),
    );
  }
}