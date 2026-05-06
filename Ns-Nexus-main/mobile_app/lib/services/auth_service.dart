import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthException implements Exception {
  final String message;
  final int statusCode;

  AuthException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class AuthService {
  static const String _loginUrl = 'http://15.235.160.20:25568/auth/login';

  Future<Map<String, dynamic>> login(String email, String password) async {
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
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sessionToken', data['sessionToken']?.toString() ?? '');
        final user = data['user'] ?? {};
        await prefs.setString('role', user['role']?.toString() ?? '');
        await prefs.setString('userId', user['id']?.toString() ?? '');
        return data;
      } else {
        // Try parsing error message from response, else fallback to generic error.
        try {
            final errorData = jsonDecode(response.body);
            final message = errorData['message'] ?? 'Login failed. Status code: ${response.statusCode}';
            throw AuthException(message, response.statusCode);
        } catch(e) {
            if (e is AuthException) rethrow;
            throw AuthException('Login failed. Status code: ${response.statusCode}', response.statusCode);
        }
      }
    } catch (e) {
      if (e is AuthException) {
        rethrow;
      }
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessionToken');
    await prefs.remove('role');
    await prefs.remove('userId');
  }
}
