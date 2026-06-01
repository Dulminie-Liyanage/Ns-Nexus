import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class InventoryService {
  static const String _base = 'http://15.235.160.20:25568';

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sessionToken') ?? prefs.getString('token') ?? '';
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  // GET /products — all products for WM inventory view
  Future<List<dynamic>> fetchProducts() async {
    final token = await _token();
    final res = await http
        .get(Uri.parse('$_base/products'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      // Handle both {products: [...]} and [...] response formats
      if (data is Map && data['products'] != null) {
        return data['products'] as List<dynamic>;
      } else if (data is List) {
        return data;
      }
      return [];
    }
    throw Exception('Failed to load products: ${res.statusCode} — ${res.body}');
  }

  // PATCH /products/:id/availability — toggle stock availability
  Future<void> toggleProductStatus(dynamic productId, int isAvailable) async {
    final token = await _token();
    final res = await http
        .patch(
          Uri.parse('$_base/products/$productId/availability'),
          headers: _headers(token),
          body: jsonEncode({'isAvailable': isAvailable}),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Failed to update availability: ${res.statusCode}');
    }
  }

  // PUT /products/:id — update product details
  Future<void> updateProduct({
    required dynamic productId,
    required String productName,
    required String sku,
    required String unit,
    required double price,
    required double weight,
    required int stockLevel,
    required int isAvailable,
  }) async {
    final token = await _token();
    final res = await http
        .put(
          Uri.parse('$_base/products/$productId'),
          headers: _headers(token),
          body: jsonEncode({
            'productName': productName,
            'sku': sku,
            'unit': unit,
            'price': price,
            'weight': weight,
            'stockLevel': stockLevel,
            'isAvailable': isAvailable,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Failed to update product: ${res.statusCode}');
    }
  }

  // POST /products — create new product
  Future<void> createProduct({
    required String productName,
    required String sku,
    required String unit,
    required double price,
    required double weight,
    required int stockLevel,
  }) async {
    final token = await _token();
    final res = await http
        .post(
          Uri.parse('$_base/products'),
          headers: _headers(token),
          body: jsonEncode({
            'productName': productName,
            'sku': sku,
            'unit': unit,
            'price': price,
            'weight': weight,
            'stockLevel': stockLevel,
            'isAvailable': 1,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 201) {
      throw Exception('Failed to create product: ${res.statusCode}');
    }
  }
}
