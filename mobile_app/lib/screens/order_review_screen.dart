import 'package:flutter/material.dart';
import '../services/order_service.dart';      // Added '../' to go out of screens folder
import '../services/inventory_service.dart';  // Added '../' to go out of screens folder

class OrderReviewScreen extends StatefulWidget {
  final dynamic order;
  const OrderReviewScreen({super.key, required this.order});

  @override
  State<OrderReviewScreen> createState() => _OrderReviewScreenState();
}

class _OrderReviewScreenState extends State<OrderReviewScreen> {
  final OrderService _orderService = OrderService();
  List<dynamic> _items = [];
  bool _isLoading = true;
  String? _error;
  final Map<String, int> _approvedQty = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  String _getItemId(dynamic item, int index) {
    return (item['resolved_product_id'] ?? item['ProductID'] ?? item['product_id'] ?? index).toString();
  }

  Future<void> _loadItems() async {
    try {
      final orderId = widget.order['OrderID'] ?? widget.order['id'] ?? widget.order['_id'];
      final items = await _orderService.fetchOrderItems(orderId);
      final productsList = await InventoryService().fetchProducts();
      
      if (!mounted) return;
      
      final Map<String, int> initialQty = {};
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        
        final name = (item['ProductName'] ?? item['productName'] ?? '').toString().toLowerCase();
        final matchedProduct = productsList.firstWhere(
           (p) => (p['ProductName'] ?? '').toString().toLowerCase() == name, 
           orElse: () => null
        );
        
        item['resolved_product_id'] = matchedProduct != null 
            ? (matchedProduct['ProductID'] ?? matchedProduct['product_id'] ?? matchedProduct['id']) 
            : null;

        final id = _getItemId(item, i);
        final qtyRaw = item['QtyRequested'] ?? item['qty_requested'] ?? item['Quantity'] ?? item['quantity'] ?? 0;
        initialQty[id] = int.tryParse(qtyRaw.toString()) ?? 0;
      }
      
      setState(() {
        _items = items;
        _approvedQty.addAll(initialQty);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  double _extractWeightFromName(String name) {
    name = name.toLowerCase();
    final kgMatch = RegExp(r'(\d+(?:\.\d+)?)\s*kg').firstMatch(name);
    if (kgMatch != null) return double.tryParse(kgMatch.group(1)!) ?? 0.0;
    final gMatch = RegExp(r'(\d+(?:\.\d+)?)\s*g').firstMatch(name);
    if (gMatch != null) return (double.tryParse(gMatch.group(1)!) ?? 0.0) / 1000.0;
    return 0.0;
  }

  double get _currentTotalPrice {
    double total = 0.0;
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final id = _getItemId(item, i);
      final price = double.tryParse((item['UnitPrice'] ?? item['unit_price'] ?? item['Price'] ?? item['price'])?.toString() ?? '0') ?? 0.0;
      final qty = _approvedQty[id] ?? 0;
      total += (price * qty);
    }
    return total;
  }

  double get _currentTotalWeight {
    double total = 0.0;
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final id = _getItemId(item, i);
      final weightRaw = item['Weight'] ?? item['weight'] ?? item['ItemWeight'] ?? item['item_weight'];
      double w = 0.0;
      if (weightRaw != null) {
        w = double.tryParse(weightRaw.toString()) ?? 0.0;
      } else {
        w = _extractWeightFromName(item['ProductName'] ?? item['productName'] ?? '');
      }
      final qty = _approvedQty[id] ?? 0;
      total += (w * qty);
    }
    return total;
  }

  int get _totalRequestedQty {
    int total = 0;
    for (var item in _items) {
      total += int.tryParse((item['QtyRequested'] ?? item['qty_requested'] ?? item['Quantity'] ?? item['quantity'])?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  int get _totalApprovedQty {
    int total = 0;
    for (int i = 0; i < _items.length; i++) {
      total += (_approvedQty[_getItemId(_items[i], i)] ?? 0);
    }
    return total;
  }

  bool get _isFullyApproved => _totalApprovedQty == _totalRequestedQty;
  bool get _isPartiallyApproved => _totalApprovedQty > 0 && _totalApprovedQty < _totalRequestedQty;
  bool get _isFullyRejected => _totalApprovedQty == 0;

  Future<void> _handleApproveAction() async {
    try {
      final orderId = widget.order['OrderID'] ?? widget.order['id'] ?? widget.order['_id'];
      final isPartial = _isPartiallyApproved;
      
      List<Map<String, dynamic>> itemsList = [];
      if (isPartial) {
        for (int i = 0; i < _items.length; i++) {
          final item = _items[i];
          final idStr = _getItemId(item, i);
          
          itemsList.add({
            'product_id': int.tryParse(idStr) ?? int.parse((item['ProductID'] ?? 0).toString()),
            'qty_approved': (_approvedQty[idStr] ?? 0).toInt(),
          });
        }
      }
      
      final status = isPartial ? 'partially_approved' : 'approved';
      await _orderService.updateOrderStatus(orderId, status, items: isPartial ? itemsList : null);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order $status successfully!'.toUpperCase())));
      Navigator.pop(context); // return to orders list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleReject() async {
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Reject Order'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please provide a reason for rejecting this order:'),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Rejection reason...',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final reason = reasonController.text.trim();
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reason is required')));
                          return;
                        }
                        
                        setDialogState(() => isSubmitting = true);
                        try {
                          final orderId = widget.order['OrderID'] ?? widget.order['id'] ?? widget.order['_id'];
                          await _orderService.updateOrderStatus(orderId, 'rejected', rejectionReason: reason);
                          if (!context.mounted) return;
                          
                          Navigator.pop(context); // pop dialog
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Rejected')));
                          Navigator.pop(this.context); // pop review screen
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Reject', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderId = widget.order['OrderID'] ?? widget.order['id'] ?? widget.order['_id'];
    final shopName = widget.order['ShopName'] ?? 'Unknown Shop';
    final retailerName = widget.order['RetailerName'] ?? 'Unknown Retailer';

    return Scaffold(
      appBar: AppBar(title: Text('Review Order #$orderId')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Retailer: $retailerName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Shop: $shopName', style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Total Weight: ${_currentTotalWeight.toStringAsFixed(2)}kg', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Total Price: LKR ${_currentTotalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Delivery Date: ${widget.order['DeliveryDate']?.toString().split('T')[0] ?? 'N/A'}'),
                if (widget.order['IsUrgent'] == 1 || widget.order['is_urgent'] == 1)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('URGENT ORDER', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final id = _getItemId(item, index);
                          final name = item['ProductName'] ?? item['productName'] ?? 'Product $id';
                          final requestedQty = int.tryParse((item['QtyRequested'] ?? item['qty_requested'] ?? item['Quantity'] ?? item['quantity'])?.toString() ?? '0') ?? 0;
                          final priceRaw = item['UnitPrice'] ?? item['unit_price'] ?? item['Price'] ?? item['price'] ?? 0.0;
                          
                          final approvedQty = _approvedQty[id] ?? requestedQty;
                          final p = double.tryParse(priceRaw.toString()) ?? 0.0;
                          final lineTotal = p * approvedQty; // Total reflects approved line volume.

                          return ListTile(
                            title: Text('$name (Req: $requestedQty)'),
                            subtitle: Text('Unit Price: LKR ${p.toStringAsFixed(2)}\nLine Total: LKR ${lineTotal.toStringAsFixed(2)}'),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: approvedQty > 0 ? () {
                                    setState(() => _approvedQty[id] = approvedQty - 1);
                                  } : null,
                                ),
                                Text('$approvedQty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                  onPressed: approvedQty < requestedQty ? () {
                                    setState(() => _approvedQty[id] = approvedQty + 1);
                                  } : null,
                                ),
                              ],
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
              children: [
                if (!_isFullyRejected)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleApproveAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPartiallyApproved ? Colors.orange : Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(_isPartiallyApproved ? 'Partially Approve' : 'Approve Order', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                if (!_isFullyRejected) const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _handleReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Reject Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
