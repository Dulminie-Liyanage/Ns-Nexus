import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/product_service.dart';
import '../services/order_service.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

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
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _productService.fetchAvailableProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
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

  void _updateQuantity(String id, int delta) {
    setState(() {
      final current = _cart[id] ?? 0;
      final next = current + delta;
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
        final price = double.tryParse((p['Price'] ?? p['price'])?.toString() ?? '0') ?? 0.0;
        final weightRaw = p['Weight'] ?? p['weight'] ?? p['ItemWeight'] ?? p['item_weight'] ?? p['TotalWeight'];
        
        double weight = 0.0;
        if (weightRaw != null) {
          weight = double.tryParse(weightRaw.toString()) ?? 0.0;
        } else {
          weight = _extractWeightFromName(p['ProductName'] ?? p['productName'] ?? '');
        }

        tempWeight += (weight * _cart[id]!);
        tempPrice += (price * _cart[id]!);
      }
    }

    setState(() {
      _currentTotalWeight = tempWeight;
      _currentTotalPrice = tempPrice;
    });
  }

  double _extractWeightFromName(String name) {
    name = name.toLowerCase();
    final kgMatch = RegExp(r'(\d+(?:\.\d+)?)\s*kg').firstMatch(name);
    if (kgMatch != null) {
      return double.tryParse(kgMatch.group(1)!) ?? 0.0;
    }
    final gMatch = RegExp(r'(\d+(?:\.\d+)?)\s*g').firstMatch(name);
    if (gMatch != null) {
      return (double.tryParse(gMatch.group(1)!) ?? 0.0) / 1000.0;
    }
    return 0.0;
  }

  String _getProductId(dynamic product) {
    return (product['ProductID'] ?? product['productId'] ?? product['id'] ?? product['Id'] ?? product['_id']).toString();
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

  Future<void> _submitOrder() async {
    if (_cart.isEmpty) {
      setState(() => _validationError = 'Cart is empty. Please add items.');
      return;
    }
    if (_selectedDate == null) {
      setState(() => _validationError = 'Please select a delivery date.');
      return;
    }

    final diff = _selectedDate!.difference(DateTime.now());
    if (diff.inHours < 48 && !_isUrgent) {
      setState(() => _validationError = 'Standard orders require a 48-hour notice. Please select a later date or mark as Urgent.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _validationError = null;
    });

    try {
      final itemsList = _cart.entries.map((e) => {
        'product_id': int.tryParse(e.key) ?? e.key,
        'qty_requested': e.value,
      }).toList();

      final dateStr = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";

      final prefs = await SharedPreferences.getInstance();
      final retailerId = int.tryParse(prefs.getString('userId') ?? '0') ?? 0;

      await _orderService.placeOrder(retailerId, itemsList, dateStr, _isUrgent ? 1 : 0);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully!')),
      );

      setState(() {
        _cart.clear();
        _selectedDate = null;
        _isUrgent = false;
      });
      _calculateTotals();
    } catch (e) {
      if (!mounted) return;
      setState(() => _validationError = e.toString().replaceFirst('Exception: ', ''));
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
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Complete Your Order',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
    if (_errorMessage != null) return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)));
    if (_products.isEmpty) return const Center(child: Text('No products available', style: TextStyle(color: Colors.grey, fontSize: 18)));

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              final id = _getProductId(product);
              final qty = _cart[id] ?? 0;
              final weightRaw = product['Weight'] ?? product['weight'] ?? product['ItemWeight'] ?? product['item_weight'];
              
              double weight = 0.0;
              if (weightRaw != null) {
                weight = double.tryParse(weightRaw.toString()) ?? 0.0;
              } else {
                weight = _extractWeightFromName(product['ProductName'] ?? product['productName'] ?? '');
              }
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF3B82F6), size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['ProductName'] ?? product['productName'] ?? 'Unknown Product',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'LKR ${product['Price']?.toString() ?? '0.00'} • ${weight}kg',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildQtyBtn(Icons.remove, qty > 0 ? () => _updateQuantity(id, -1) : null),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '$qty', 
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                        ),
                        _buildQtyBtn(Icons.add, () => _updateQuantity(id, 1)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 25,
                offset: const Offset(0, -5),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estimated Weight', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('${_currentTotalWeight.toStringAsFixed(2)} kg', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B))),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Total Amount', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('LKR ${_currentTotalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF3B82F6))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(16),
                          color: const Color(0xFFF1F5F9),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 18, color: Colors.grey.shade700),
                            const SizedBox(width: 12),
                            Text(
                              _selectedDate == null 
                                  ? 'Schedule Date' 
                                  : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2,'0')}-${_selectedDate!.day.toString().padLeft(2,'0')}',
                              style: TextStyle(
                                fontSize: 14,
                                color: _selectedDate == null ? Colors.grey.shade700 : const Color(0xFF1E293B),
                                fontWeight: _selectedDate == null ? FontWeight.w500 : FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildSprint2UrgentBtn(),
                ],
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_validationError!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _isSubmitting
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.25),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _submitOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Confirm Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSprint2UrgentBtn() {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Urgent orders will be enabled in Sprint 2'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.amber.shade300),
          borderRadius: BorderRadius.circular(16),
          color: Colors.amber.shade50,
        ),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, size: 20, color: Colors.amber.shade800),
            const SizedBox(width: 8),
            Text(
              'Urgent',
              style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFFF1F5F9) : const Color(0xFF3B82F6).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon, 
          size: 20, 
          color: onTap == null ? Colors.grey.shade400 : const Color(0xFF3B82F6),
        ),
      ),
    );
  }
}
