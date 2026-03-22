import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PlaceOrderScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const PlaceOrderScreen({super.key, required this.user});

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  List<dynamic> _products = [];
  List<Map<String, dynamic>> _cartItems = [];
  DateTime? _deliveryDate;
  bool _isUrgent = false;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final result = await ApiService.getProducts();
    setState(() {
      _products = result['products'] ?? [];
      _isLoading = false;
    });
  }

  void _increaseQty(dynamic product) {
    setState(() {
      final existing = _cartItems.indexWhere(
        (item) => item['product_id'] == product['ProductID'],
      );
      if (existing >= 0) {
        _cartItems[existing]['qty_requested']++;
      } else {
        _cartItems.add({
          'product_id': product['ProductID'],
          'name': product['ProductName'],
          'unit': product['Unit'],
          'price': product['Price'],
          'qty_requested': 1,
        });
      }
    });
  }

  void _decreaseQty(dynamic product) {
    setState(() {
      final existing = _cartItems.indexWhere(
        (item) => item['product_id'] == product['ProductID'],
      );
      if (existing >= 0) {
        if (_cartItems[existing]['qty_requested'] > 1) {
          _cartItems[existing]['qty_requested']--;
        } else {
          _cartItems.removeAt(existing);
        }
      }
    });
  }

  int _getQty(int productId) {
    final existing = _cartItems.indexWhere(
      (item) => item['product_id'] == productId,
    );
    if (existing >= 0) return _cartItems[existing]['qty_requested'];
    return 0;
  }

  Future<void> _selectDeliveryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() {
        _deliveryDate = picked;
      });
    }
  }

  Future<void> _submitOrder() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product')),
      );
      return;
    }
    if (_deliveryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery date')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await ApiService.placeOrder(
      retailerId: widget.user['id'],
      deliveryDate: _deliveryDate!.toIso8601String().split('T')[0],
      isUrgent: _isUrgent,
      items: _cartItems
          .map(
            (item) => {
              'product_id': item['product_id'],
              'qty_requested': item['qty_requested'],
            },
          )
          .toList(),
    );

    setState(() => _isSubmitting = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order placed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to place order'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Place Order'),
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Available Products',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._products.map((product) {
                        final qty = _getQty(product['ProductID']);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: qty > 0
                                  ? const Color(0xFF1A73E8)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product['ProductName'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${product['Unit']} — Rs. ${product['Price']}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _decreaseQty(product),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: qty > 0
                                            ? Colors.red.shade50
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.remove,
                                        size: 18,
                                        color: qty > 0
                                            ? Colors.red
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 36,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$qty',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _increaseQty(product),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        size: 18,
                                        color: Color(0xFF1A73E8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      const Text(
                        'Order Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _selectDeliveryDate,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: Color(0xFF1A73E8),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _deliveryDate == null
                                    ? 'Select Delivery Date'
                                    : 'Delivery: ${_deliveryDate!.day}/${_deliveryDate!.month}/${_deliveryDate!.year}',
                                style: TextStyle(
                                  color: _deliveryDate == null
                                      ? Colors.grey
                                      : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Mark as Urgent Order'),
                            Switch(
                              value: _isUrgent,
                              onChanged: (val) =>
                                  setState(() => _isUrgent = val),
                              activeColor: const Color(0xFF1A73E8),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_cartItems.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      children: [
                        Text(
                          '${_cartItems.length} product(s) — ${_cartItems.fold(0, (sum, item) => sum + (item['qty_requested'] as int))} total units',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A73E8),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _isSubmitting
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'Submit Order',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
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
}
