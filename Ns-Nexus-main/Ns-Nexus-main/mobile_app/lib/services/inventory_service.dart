import 'dart:convert';
import 'package:http/http.dart' as http;

class InventoryService {
  static const String _baseUrl = 'http://15.235.160.20:25568/products';

  Future<List<dynamic>> fetchProducts() async {
    final response = await http.get(Uri.parse('$_baseUrl/all'));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return List<dynamic>.from(decoded['products']);
    } else {
      throw Exception('Failed to load products');
    }
  }

  Future<void> toggleProductStatus(dynamic productId, int isAvailable) async {
    if (productId == null || productId.toString().trim().isEmpty) {
      throw Exception('Product ID is missing or null');
    }

    final response = await http.patch(
      Uri.parse('$_baseUrl/$productId/toggle'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'isAvailable': isAvailable}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update product status');
    }
  }

  Future<void> createProduct(Map<String, dynamic> productData) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(productData),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      String msg = 'Status ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded['message'] != null && decoded['error'] != null) {
          msg = "${decoded['message']}: ${decoded['error']}";
        } else {
          msg = decoded['message'] ?? decoded['error'] ?? response.body;
        }
      } catch (_) {
        msg = response.body.isNotEmpty ? response.body : msg;
      }
      throw Exception('Failed to create product: $msg');
    }
  }

  Future<void> updateProduct(
    dynamic productId,
    Map<String, dynamic> productData,
  ) async {
    if (productId == null || productId.toString().trim().isEmpty) {
      throw Exception('Product ID is missing or null');
    }
    final response = await http.put(
      Uri.parse('$_baseUrl/$productId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(productData),
    );
    if (response.statusCode != 200) {
      String msg = 'Status ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        msg = decoded['message'] ?? decoded['error'] ?? response.body;
      } catch (_) {
        msg = response.body.isNotEmpty ? response.body : msg;
      }
      throw Exception('Failed to update product: $msg');
    }
  }
}
