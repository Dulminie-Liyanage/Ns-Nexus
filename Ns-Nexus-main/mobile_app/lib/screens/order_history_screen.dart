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

  // 🚨 FIXED: Now accepts status and reason directly from the card
  Future<void> _showItemsDialog(
    dynamic orderId,
    String status,
    String reason,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final items = await _orderService.fetchOrderItems(orderId);
      if (!mounted) return;
      Navigator.pop(context); // close loader

      showDialog(
        context: context,
        builder: (ctx) {
          // Clean up the status and reason to ensure safe rendering
          final String safeStatus = status.toLowerCase();
          final String safeReason = (reason.isNotEmpty && reason != 'null')
              ? reason
              : 'No reason provided';

          return AlertDialog(
            title: const Text('Order Items'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize:
                    MainAxisSize.min, // Important to prevent empty space
                children: [
                  // 1. SCROLLABLE LIST OF ITEMS
                  Flexible(
                    child: items.isEmpty
                        ? const Text('No items inside this order.')
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final item = items[i];
                              final name =
                                  item['ProductName'] ??
                                  item['productName'] ??
                                  'Product';
                              final qtyRaw =
                                  item['QtyRequested'] ?? item['Quantity'] ?? 0;
                              final approvedRaw = item['QtyApproved'] ?? qtyRaw;
                              final priceRaw =
                                  item['UnitPrice'] ?? item['Price'] ?? 0.0;

                              final qReq = int.tryParse(qtyRaw.toString()) ?? 0;
                              final qApprv =
                                  int.tryParse(approvedRaw.toString()) ?? qReq;
                              final p =
                                  double.tryParse(priceRaw.toString()) ?? 0.0;
                              final lineTotal = p * qApprv;
                              final isModified =
                                  qApprv < qReq && safeStatus != 'rejected';

                              return Container(
                                color: isModified
                                    ? Colors.orange.withOpacity(0.2)
                                    : null,
                                child: ListTile(
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      color: isModified
                                          ? Colors.deepOrange
                                          : Colors.black,
                                      fontWeight: isModified
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Requested: $qReq   |   Approved: $qApprv\nUnit Price: LKR ${p.toStringAsFixed(2)}  —  Line Total: LKR ${lineTotal.toStringAsFixed(2)}',
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                          ),
                  ),

                  // 2. THE RED BOX AT THE BOTTOM (ONLY IF REJECTED)
                  if (safeStatus == 'rejected') ...[
                    const Divider(height: 30, thickness: 1),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "REJECTION REASON",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            safeReason, // Displaying the passed reason here
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
      Navigator.pop(context);
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
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_orders.isEmpty) {
      return const Center(
        child: Text(
          'No order history found',
          style: TextStyle(color: Colors.grey, fontSize: 18),
        ),
      );
    }

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
                      onPressed: () {
                        // 🚨 FIXED: Extracting data from the order card to pass to dialog
                        final String status = order['Status']?.toString() ?? '';
                        final String reason =
                            order['RejectionReason']?.toString() ?? '';
                        _showItemsDialog(orderId, status, reason);
                      },
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
