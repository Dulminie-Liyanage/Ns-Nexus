import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String _loginUrl = 'http://15.235.160.20:25568/auth/login';

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      // Handle network or other errors here if needed
    }
    return null;
  }
}
