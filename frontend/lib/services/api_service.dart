import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://15.235.160.20:25568';

  static Future<Map<String, dynamic>> login(
    String phone,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'password': password}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  static Future<Map<String, dynamic>> getProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products'));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'products': data['products']};
      } else {
        return {'success': false, 'products': []};
      }
    } catch (e) {
      return {'success': false, 'products': []};
    }
  }

  static Future<Map<String, dynamic>> placeOrder({
    required int retailerId,
    required String deliveryDate,
    required bool isUrgent,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'retailer_id': retailerId,
          'delivery_date': deliveryDate,
          'is_urgent': isUrgent,
          'items': items,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  static Future<Map<String, dynamic>> getMyOrders(int retailerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/retailer/$retailerId'),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'orders': data['orders']};
      } else {
        return {'success': false, 'orders': []};
      }
    } catch (e) {
      return {'success': false, 'orders': []};
    }
  }

  static Future<Map<String, dynamic>> getOrderItems(int orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/$orderId/items'),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'items': data['items']};
      } else {
        return {'success': false, 'items': []};
      }
    } catch (e) {
      return {'success': false, 'items': []};
    }
  }
}
