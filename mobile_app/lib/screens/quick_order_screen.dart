import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';

class QuickOrderScreen extends StatefulWidget {
  const QuickOrderScreen({super.key});

  @override
  State<QuickOrderScreen> createState() => _QuickOrderScreenState();
}

class _QuickOrderScreenState extends State<QuickOrderScreen> {
  final _orderSvc = OrderService();
  final _productSvc = ProductService();

  bool _loadingOrders = true;
  bool _loadingProducts = false;
  bool _submitting = false;
  String? _error;
  String? _validationError;

  List<dynamic> _pastOrders = [];
  dynamic _selectedOrder;
  List<dynamic> _products = [];
  final Map<String, int> _cart = {};
  final Map<String, int> _originalQty = {}; // qty from the selected order
  DateTime? _selectedDate;
  bool _isUrgent = false;
  bool? _isPriority; // null = not loaded yet
  double _totalWeight = 0;
  double _totalPrice = 0;

  @override
  void initState() {
    super.initState();
    // addPostFrameCallback — runs AFTER first frame is painted, never blocks UI
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Priority from local prefs — fast
      try {
        final prefs = await SharedPreferences.getInstance();
        final strVal = prefs.getString('priorityStatus') ?? '';
        final intVal = prefs.getInt('priorityStatus') ?? 0;
        if (mounted) {
          setState(
            () =>
                _isPriority = strVal == '1' || strVal == 'true' || intVal == 1,
          );
        }
      } catch (_) {
        if (mounted) setState(() => _isPriority = false);
      }
      // Then load orders from network
      _loadPastOrders();
    });
  }

  Future<void> _loadPastOrders() async {
    if (mounted)
      setState(() {
        _loadingOrders = true;
        _error = null;
      });
    try {
      final history = await _orderSvc.fetchOrderHistory();
      // Show ALL orders — retailer picks any past order to reuse its items
      history.sort((a, b) {
        final aId = int.tryParse((a['OrderID'] ?? 0).toString()) ?? 0;
        final bId = int.tryParse((b['OrderID'] ?? 0).toString()) ?? 0;
        return bId.compareTo(aId);
      });
      setState(() {
        _pastOrders = history;
        _loadingOrders = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loadingOrders = false;
      });
    }
  }

  Future<void> _selectOrder(dynamic order) async {
    setState(() {
      _loadingProducts = true;
      _error = null;
      _cart.clear();
    });
    try {
      final orderId = order['OrderID'];
      final results = await Future.wait([
        _productSvc.fetchAvailableProducts(),
        _orderSvc.fetchOrderItems(orderId),
      ]);
      final products = results[0] as List<dynamic>;
      final items = results[1] as List<dynamic>;
      final availableIds = products
          .map((p) => (p['ProductID'] ?? p['id'] ?? '').toString())
          .toSet();
      _originalQty.clear();
      for (final item in items) {
        final pid = (item['ProductID'] ?? item['productId'] ?? '').toString();
        final qty = int.tryParse((item['QtyRequested'] ?? 0).toString()) ?? 0;
        if (pid.isNotEmpty && qty > 0) {
          _originalQty[pid] = qty;
          if (availableIds.contains(pid)) _cart[pid] = qty;
        }
      }
      setState(() {
        _selectedOrder = order;
        _products = products;
        _loadingProducts = false;
      });
      _calculateTotals();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loadingProducts = false;
      });
    }
  }

  void _goBack() => setState(() {
    _selectedOrder = null;
    _products.clear();
    _cart.clear();
    _originalQty.clear();
    _selectedDate = null;
    _validationError = null;
    _isUrgent = false;
  });

  String _pid(dynamic p) => (p['ProductID'] ?? p['id'] ?? '').toString();
  int _stock(dynamic p) =>
      int.tryParse(p['StockLevel']?.toString() ?? '999') ?? 999;

  void _calculateTotals() {
    double w = 0, p = 0;
    for (final product in _products) {
      final qty = _cart[_pid(product)] ?? 0;
      if (qty <= 0) continue;
      p += (double.tryParse((product['Price'] ?? 0).toString()) ?? 0) * qty;
      w += (double.tryParse((product['Weight'] ?? 0).toString()) ?? 0) * qty;
    }
    setState(() {
      _totalWeight = w;
      _totalPrice = p;
    });
  }

  void _updateQty(String id, int delta) {
    setState(() {
      int next = (_cart[id] ?? 0) + delta;
      if (delta > 0) {
        final product = _products.firstWhere(
          (p) => _pid(p) == id,
          orElse: () => null,
        );
        if (product != null) {
          final stock = _stock(product);
          if (next > stock) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Only $stock units available'),
                backgroundColor: Colors.orange.shade700,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
            next = stock;
          }
        }
      }
      if (next <= 0)
        _cart.remove(id);
      else
        _cart[id] = next;
    });
    _calculateTotals();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 2)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null)
      setState(() {
        _selectedDate = picked;
        _validationError = null;
      });
  }

  Future<void> _submit() async {
    if (_cart.isEmpty) {
      setState(() => _validationError = 'Please add at least one item.');
      return;
    }
    if (!_isUrgent && _selectedDate == null) {
      setState(() => _validationError = 'Please select a delivery date.');
      return;
    }
    if (!_isUrgent && _selectedDate!.difference(DateTime.now()).inHours < 48) {
      setState(
        () =>
            _validationError = 'Standard orders need at least 48 hours notice.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _validationError = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final retailerId = int.tryParse(prefs.getString('userId') ?? '0') ?? 0;
      final date = _isUrgent ? DateTime.now() : _selectedDate!;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final items = _cart.entries
          .map(
            (e) => {
              'product_id': int.tryParse(e.key) ?? e.key,
              'qty_requested': e.value,
            },
          )
          .toList();
      await _orderSvc.placeOrder(retailerId, items, dateStr, _isUrgent ? 1 : 0);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order placed successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(
        () => _validationError = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF1E293B),
            size: 20,
          ),
          onPressed: _selectedOrder != null
              ? _goBack
              : () => Navigator.pop(context),
        ),
        title: Text(
          _selectedOrder != null
              ? 'Order #${_selectedOrder['OrderID']} — Adjust & Confirm'
              : 'Quick Order',
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadingOrders || _loadingProducts) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF0056B3)),
            const SizedBox(height: 16),
            Text(
              _loadingOrders
                  ? 'Loading your past orders...'
                  : 'Loading products...',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
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
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _selectedOrder != null ? _goBack : _loadPastOrders,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return _selectedOrder == null ? _buildOrderList() : _buildProductAdjust();
  }

  Widget _buildOrderList() {
    if (_pastOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'No orders found',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your past orders will appear here',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0056B3).withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF0056B3).withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: 16,
                color: Color(0xFF0056B3),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Select a past order to pre-fill your cart. Adjust quantities then confirm.',
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
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            itemCount: _pastOrders.length,
            itemBuilder: (ctx, i) => _buildPastOrderCard(_pastOrders[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildPastOrderCard(dynamic order) {
    final orderId = order['OrderID'];
    final status = (order['Status'] ?? '').toString();
    final date = (order['CreatedAt'] ?? '').toString().split('T')[0];
    final total = order['TotalPrice']?.toString() ?? '0.00';
    final isUrgent = order['IsUrgent'] == 1;
    final statusColor = _statusColor(status);

    return InkWell(
      onTap: () => _selectOrder(order),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF0056B3).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_outlined,
                color: Color(0xFF0056B3),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Order #$orderId',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (isUrgent) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.bolt_rounded,
                          size: 14,
                          color: Colors.red.shade600,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Placed: $date',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  Text(
                    'LKR $total',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0056B3),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
      case 'partially_approved':
        return Colors.green;
      case 'delivered':
        return Colors.green.shade700;
      case 'packing':
        return Colors.blue;
      case 'in_3pl_transit':
      case 'ready_to_ship':
        return Colors.indigo;
      case 'out_for_delivery':
        return Colors.teal;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildProductAdjust() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Items pre-filled with current prices. Adjust quantities as needed then confirm.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            itemCount: _products.length,
            itemBuilder: (ctx, i) => _buildProductCard(_products[i]),
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildProductCard(dynamic product) {
    final id = _pid(product);
    final qty = _cart[id] ?? 0;
    final origQty = _originalQty[id] ?? 0;
    final isFromOrder = origQty > 0;
    final qtyChanged = isFromOrder && qty != origQty;
    final name = product['ProductName'] ?? 'Product';
    final price = double.tryParse((product['Price'] ?? 0).toString()) ?? 0.0;
    final stock = _stock(product);
    final isAvailable = product['IsAvailable'] != 0 && stock > 0;

    return Opacity(
      opacity: isAvailable ? 1.0 : 0.45,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isFromOrder
              ? Border.all(
                  color: const Color(0xFF0056B3).withOpacity(0.35),
                  width: 1.5,
                )
              : Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + name + prev qty badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isFromOrder
                        ? const Color(0xFF0056B3).withOpacity(0.08)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: isFromOrder
                        ? const Color(0xFF0056B3)
                        : Colors.grey.shade400,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            'LKR ${price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF0056B3),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isAvailable
                                ? (stock <= 10
                                      ? 'Only $stock left'
                                      : '$stock in stock')
                                : 'Out of stock',
                            style: TextStyle(
                              fontSize: 11,
                              color: isAvailable
                                  ? (stock <= 10
                                        ? Colors.orange.shade600
                                        : Colors.green.shade600)
                                  : Colors.red.shade400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Qty row — prev ordered (reference) + new qty (adjustable)
            if (isAvailable) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Previously ordered qty — read-only reference
                  if (isFromOrder) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Previously ordered',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$origQty units',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      width: 1,
                      height: 32,
                      color: Colors.grey.shade200,
                    ),
                  ],
                  // New qty — adjustable
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New quantity',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _qtyBtn(
                            Icons.remove_rounded,
                            qty > 0 ? () => _updateQty(id, -1) : null,
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 48,
                            height: 34,
                            decoration: BoxDecoration(
                              color: qty > 0
                                  ? const Color(0xFF0056B3).withOpacity(0.07)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: qty > 0
                                    ? const Color(0xFF0056B3).withOpacity(0.3)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$qty',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: qty > 0
                                      ? const Color(0xFF0056B3)
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _qtyBtn(
                            Icons.add_rounded,
                            qty < stock ? () => _updateQty(id, 1) : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Line total
                  if (qty > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        Text(
                          'LKR ${(price * qty).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Unavailable',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: onTap == null
              ? const Color(0xFFF1F5F9)
              : const Color(0xFF0056B3).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? Colors.grey.shade400 : const Color(0xFF0056B3),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Weight',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  Text(
                    '${_totalWeight.toStringAsFixed(2)} kg',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total Amount',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  Text(
                    'LKR ${_totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Color(0xFF0056B3),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Date + Urgent row
          Row(
            children: [
              // Date picker — hidden for urgent priority orders
              if (!_isUrgent)
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 13,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFF1F5F9),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _selectedDate == null
                                ? 'Select Delivery Date'
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
                        ],
                      ),
                    ),
                  ),
                ),
              // Urgent toggle — ONLY for priority retailers (hidden until loaded)
              if (_isPriority == true) ...[
                if (!_isUrgent) const SizedBox(width: 10),
                InkWell(
                  onTap: () => setState(() {
                    _isUrgent = !_isUrgent;
                    if (_isUrgent) {
                      _selectedDate = null;
                      _validationError = null;
                    }
                  }),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isUrgent
                            ? Colors.red.shade400
                            : Colors.amber.shade300,
                        width: _isUrgent ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: _isUrgent
                          ? Colors.red.shade50
                          : Colors.amber.shade50,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 18,
                          color: _isUrgent
                              ? Colors.red.shade700
                              : Colors.amber.shade800,
                        ),
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
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          // Urgent banner
          if (_isUrgent) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 14,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Urgent order — 48-hour rule bypassed',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_validationError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _validationError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _submitting
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0056B3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Confirm Order',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
