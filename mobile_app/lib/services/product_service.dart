import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductService {
  static const String _baseUrl = 'http://15.235.160.20:25568/products';

  Future<List<dynamic>> fetchAvailableProducts() async {
    final response = await http.get(Uri.parse(_baseUrl));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return List<dynamic>.from(decoded['products'] ?? []);
    } else {
      throw Exception('Failed to load available products. Status: ${response.statusCode}');
    }
  }
}
