import 'package:flutter/material.dart';
import '../services/order_service.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final OrderService _orderService = OrderService();
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await _orderService.fetchOrderHistory();
      if (!mounted) return;
      setState(() {
        _orders = data;
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

  Future<void> _showItemsDialog(dynamic orderId) async {
    // 1. Show Loading Indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final items = await _orderService.fetchOrderItems(orderId);
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      showDialog(
        context: context,
        builder: (ctx) {
          // --- DATA MAPPING ---
          // We look at the first item to get the overall Order status and reason
          final firstItem = items.isNotEmpty ? items[0] : {};

          // CRITICAL: We use EXACT Case to match your Backend SQL results
          final String status = (firstItem['Status'] ?? '')
              .toString()
              .toLowerCase();
          final String reason =
              (firstItem['RejectionReason'] ?? 'No reason provided').toString();

          return AlertDialog(
            title: const Text('Order Details'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: items.isEmpty
                        ? const Text('No items found.')
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final item = items[i];

                              // Mapping backend fields
                              final name = item['ProductName'] ?? 'Product';
                              final qtyReq = item['QtyRequested'] ?? 0;
                              final qtyApprv = item['QtyApproved'] ?? qtyReq;
                              final price =
                                  double.tryParse(
                                    item['Price']?.toString() ?? '0',
                                  ) ??
                                  0.0;

                              // 1. RE-ADDING THE ORANGE LOGIC:
                              // Only highlight if items were reduced AND it's not a full rejection
                              final bool isModified =
                                  (qtyApprv < qtyReq) && (status != 'rejected');

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                decoration: BoxDecoration(
                                  color: isModified
                                      ? Colors.orange.withOpacity(0.15)
                                      : null,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: ListTile(
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: isModified
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isModified
                                          ? Colors.orange.shade900
                                          : Colors.black,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Requested: $qtyReq | Approved: $qtyApprv',
                                  ),
                                  trailing: Text(
                                    'LKR ${(price * qtyApprv).toStringAsFixed(2)}',
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // 2. THE REJECTION UI:
                  // This shows the red box only if the order status is 'rejected'
                  if (status == 'rejected') ...[
                    const Divider(height: 30),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "REJECTION REASON",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reason,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _getStageName(int stage) {
    switch (stage) {
      case 1:
        return 'Pending';
      case 2:
        return 'Approved';
      case 3:
        return 'Packing';
      case 4:
        return 'Shipped';
      case 5:
        return 'At Hub';
      case 6:
        return 'Out for Delivery';
      case 7:
        return 'Delivered';
      default:
        return 'Pending';
    }
  }

  Widget _buildProgressBar(int currentStage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(7, (index) {
            final stage = index + 1;
            final isActive = stage <= currentStage;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: stage < 7 ? 4 : 0),
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Stage $currentStage of 7: ${_getStageName(currentStage)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order History')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    if (_orders.isEmpty)
      return const Center(
        child: Text(
          'No order history found',
          style: TextStyle(color: Colors.grey, fontSize: 18),
        ),
      );

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          final orderId = order['OrderID'] ?? order['id'] ?? order['_id'];

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order ID: #$orderId',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Status: ${order['Status'] ?? 'Pending'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'LKR ${order['TotalPrice']?.toString() ?? '0.00'}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Order Date: ${(order['CreatedAt'] ?? order['OrderDate'] ?? order['orderDate'] ?? 'N/A').toString().split('T')[0]}',
                  ),
                  Text(
                    'Delivery Date: ${(order['DeliveryDate'] ?? order['deliveryDate'] ?? 'N/A').toString().split('T')[0]}',
                  ),
                  Text(
                    'Total Weight: ${order['TotalWeight']?.toString() ?? '0.00'} kg',
                  ),
                  const SizedBox(height: 16),
                  _buildProgressBar(
                    int.tryParse(order['CurrentStage']?.toString() ?? '1') ?? 1,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _showItemsDialog(orderId),
                      child: const Text('View Items'),
                    ),
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
