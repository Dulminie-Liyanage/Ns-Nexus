import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/inventory_service.dart';
import 'login_screen.dart';
import 'warehouse_orders_screen.dart';
import 'product_form_screen.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final InventoryService _inventoryService = InventoryService();
  List<dynamic> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _inventoryService.fetchProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleStatus(int index, bool newValue) async {
    final product = _products[index];
    final productId = product['ProductID'] ?? product['productId'] ?? product['id'] ?? product['Id'] ?? product['ProductId'] ?? product['_id'];
    
    if (productId == null || productId.toString().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update failed: Invalid Product ID')),
      );
      return;
    }

    final newStatusInt = newValue ? 1 : 0;
    
    setState(() {
      _products[index]['IsAvailable'] = newStatusInt;
    });

    try {
      await _inventoryService.toggleProductStatus(productId, newStatusInt);
      if (!mounted) return;
      await _loadProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status Updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _products[index]['IsAvailable'] = newValue ? 0 : 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  Future<void> _openProductForm([Map<String, dynamic>? product]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
    if (result == true) {
      _loadProducts(); // Refresh list after add/edit
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Product Management' : 'Order Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().logout();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _currentIndex == 0 ? _buildInventoryTab() : const WarehouseOrdersScreen(),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => _openProductForm(),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Products'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Orders'),
        ],
      ),
    );
  }

  Widget _buildInventoryTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadProducts,
                child: ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    final isAvailable = product['IsAvailable'] == 1 || product['IsAvailable'] == '1';
                    final stockLevel = product['StockLevel'] ?? product['stockLevel'] ?? product['stock_level'];
                    final stockInt = int.tryParse(stockLevel?.toString() ?? '') ?? -1;
                    final backendLowStock = product['isLowStock'] == true || product['isLowStock'] == 1 || product['IsLowStock'] == true || product['IsLowStock'] == 1;
                    final isLowStock = backendLowStock || (stockInt >= 0 && stockInt <= 10);
                    final price = product['Price']?.toString() ?? '0.00';
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(product['ProductName']?.toString() ?? 'Unknown Product', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SKU: ${product['SKU'] ?? 'N/A'} - Price: \$${price}'),
                            if (stockLevel != null)
                              Text(
                                'Stock: $stockLevel',
                                style: TextStyle(
                                  fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                                  color: isLowStock ? Colors.red : Colors.black87,
                                ),
                              ),
                          ],
                        ),
                        trailing: Switch(
                          value: isAvailable,
                          onChanged: (value) => _toggleStatus(index, value),
                        ),
                        onTap: () => _openProductForm(Map<String, dynamic>.from(product)),
                      ),
                    );
                  },
                ),
              );
  }
}
