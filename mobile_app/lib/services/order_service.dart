import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OrderService {
  static const String _baseUrl = 'http://15.235.160.20:25568/orders';

  Future<void> placeOrder(int retailerId, List<Map<String, dynamic>> items, String deliveryDate, int isUrgent) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'retailer_id': retailerId,
        'delivery_date': deliveryDate,
        'is_urgent': isUrgent,
        'items': items,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to place order. Status: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> fetchOrderHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final retailerId = prefs.getString('userId') ?? '0';
    
    final response = await http.get(Uri.parse('$_baseUrl/retailer/$retailerId'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded.containsKey('orders')) {
        return List<dynamic>.from(decoded['orders']);
      } else if (decoded is List) {
        return List<dynamic>.from(decoded);
      }
      return [];
    } else {
      throw Exception('Failed to load order history. Status: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> fetchOrderItems(dynamic orderId) async {
    if (orderId == null || orderId.toString().trim().isEmpty) {
      throw Exception('Invalid Order ID');
    }
    final response = await http.get(Uri.parse('$_baseUrl/$orderId/items'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> itemList = decoded['items'] ?? [];
      return itemList;
    } else {
      throw Exception('Failed to fetch items for order $orderId. Status: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> fetchAllOrders() async {
    final response = await http.get(Uri.parse(_baseUrl));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded.containsKey('orders')) {
        return List<dynamic>.from(decoded['orders']);
      } else if (decoded is List) {
        return List<dynamic>.from(decoded);
      }
      return [];
    } else {
      throw Exception('Failed to load global orders. Status: ${response.statusCode}');
    }
  }

  Future<void> updateOrderStatus(dynamic orderId, String status, {String? rejectionReason, List<Map<String, dynamic>>? items}) async {
    final body = <String, dynamic>{'status': status};
    if (rejectionReason != null && rejectionReason.trim().isNotEmpty) {
      body['rejection_reason'] = rejectionReason.trim();
    }
    if (items != null && items.isNotEmpty) {
      body['items'] = items;
    }
    
    print('--- Payload Log ---');
    print(jsonEncode(body));
    print('-------------------');
    
    final response = await http.put(
      Uri.parse('$_baseUrl/$orderId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update order status');
    }
  }

  Future<void> advanceNextStage(dynamic orderId) async {
    if (orderId == null || orderId.toString().trim().isEmpty) {
      throw Exception('Invalid Order ID');
    }
    final response = await http.post(
      Uri.parse('$_baseUrl/$orderId/next-stage'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      String msg = 'Status ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        msg = decoded['message'] ?? decoded['error'] ?? response.body;
      } catch (_) {
        msg = response.body.isNotEmpty ? response.body : msg;
      }
      throw Exception(msg);
    }
  }
}
