import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/product_service.dart';
import '../services/order_service.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
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
      appBar: AppBar(title: const Text('New Order')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)));
    if (_products.isEmpty) return const Center(child: Text('No products available', style: TextStyle(color: Colors.grey, fontSize: 18)));

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
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
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(product['ProductName'] ?? product['productName'] ?? 'Unknown Product'),
                  subtitle: Text('SKU: ${product['SKU'] ?? 'N/A'} - Price: \$${product['Price']?.toString() ?? '0.00'} (${weight}kg)'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: qty > 0 ? () => _updateQuantity(id, -1) : null,
                      ),
                      Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _updateQuantity(id, 1),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text('Total Weight: ${_currentTotalWeight.toStringAsFixed(2)} kg', style: const TextStyle(fontWeight: FontWeight.bold)),
                   Text('Total Price: \$${_currentTotalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_selectedDate == null 
                          ? 'Select Date' 
                          : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2,'0')}-${_selectedDate!.day.toString().padLeft(2,'0')}'),
                      onPressed: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: _isUrgent,
                        onChanged: (val) {
                          setState(() {
                            _isUrgent = val ?? false;
                            if (_isUrgent && _validationError != null && _validationError!.contains('48-hour')) {
                              _validationError = null;
                            }
                          });
                        },
                      ),
                      const Text('Urgent'),
                    ],
                  )
                ],
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 8),
                Text(_validationError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 12),
              _isSubmitting
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitOrder,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Place Order', style: TextStyle(fontSize: 16)),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
