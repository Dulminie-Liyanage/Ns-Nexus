import 'package:flutter/material.dart';
import 'services/order_service.dart';

class OrderScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const OrderScreen({super.key, required this.product});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final OrderService _orderService = OrderService();
  
  DateTime? _selectedDate;
  bool _isUrgent = false;
  bool _isLoading = false;
  String? _errorMessage;

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
        _errorMessage = null; // Clear error on new date
      });
    }
  }

  Future<void> _placeOrder() async {
    if (_selectedDate == null) {
      setState(() {
        _errorMessage = 'Please select a delivery date.';
      });
      return;
    }

    // Checking if date is strictly less than 48 hours away
    final diff = _selectedDate!.difference(DateTime.now());
    if (diff.inHours < 48 && !_isUrgent) {
      setState(() {
        _errorMessage = 'Standard orders require a 48-hour notice. Please select a later date or mark as Urgent.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final productId = widget.product['ProductID'] ?? widget.product['productId'] ?? widget.product['id'] ?? widget.product['Id'] ?? widget.product['_id'];
      
      final dateString = "${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";

      await _orderService.placeOrder(productId, dateString, _isUrgent ? 1 : 0);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.product['ProductName']?.toString() ?? 'Product';
    final price = widget.product['Price']?.toString() ?? '0.00';

    return Scaffold(
      appBar: AppBar(title: const Text('Place Order')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ordering: $productName',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Price: \$$price',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            ListTile(
              title: Text(_selectedDate == null 
                  ? 'Select Delivery Date' 
                  : 'Delivery Date: ${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.calendar_today),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            
            CheckboxListTile(
              title: const Text('Mark as Urgent'),
              value: _isUrgent,
              onChanged: (val) {
                setState(() {
                  _isUrgent = val ?? false;
                  // Clear error if user turns on Urgent and it was previously blocked
                  if (_isUrgent && _errorMessage != null && _errorMessage!.contains('48-hour')) {
                    _errorMessage = null;
                  }
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            
            const Spacer(),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _placeOrder,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Place Order', style: TextStyle(fontSize: 16)),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
