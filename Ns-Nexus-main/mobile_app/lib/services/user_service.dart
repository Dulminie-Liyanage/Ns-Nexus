import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;
  final bool isActive;
  final bool priorityStatus; // US-09/10: priority retailer flag

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    this.priorityStatus = false,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      firstName: json['firstName'] ?? json['first_name'] ?? '',
      lastName: json['lastName'] ?? json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      isActive: json['isActive'] ?? json['is_active'] ?? true,
      priorityStatus:
          json['priorityStatus'] ?? json['priority_status'] ?? false,
    );
  }
}

class UserService {
  static const String _base = 'http://15.235.160.20:25568';

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sessionToken') ?? '';
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<List<UserModel>> getAllUsers() async {
    final token = await _token();
    final res = await http.get(
      Uri.parse('$_base/users'),
      headers: _headers(token),
    );
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((e) => UserModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load users: ${res.statusCode}');
  }

  Future<UserModel> createUser({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String role,
    bool priorityStatus = false,
  }) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse('$_base/users'),
      headers: _headers(token),
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'role': role,
        'priorityStatus': priorityStatus,
      }),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return UserModel.fromJson(jsonDecode(res.body));
    }
    if (res.statusCode == 409)
      throw Exception('A user with this email already exists.');
    throw Exception('Failed to create user: ${res.statusCode}');
  }

  Future<UserModel> updateUser({
    required String userId,
    required String firstName,
    required String lastName,
    required String phone,
    required String role,
    bool priorityStatus = false,
  }) async {
    final token = await _token();
    final res = await http.put(
      Uri.parse('$_base/users/$userId'),
      headers: _headers(token),
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'role': role,
        'priorityStatus': priorityStatus,
      }),
    );
    if (res.statusCode == 200) return UserModel.fromJson(jsonDecode(res.body));
    throw Exception('Failed to update user: ${res.statusCode}');
  }

  Future<void> toggleUserStatus(String userId, bool isActive) async {
    final token = await _token();
    final res = await http.patch(
      Uri.parse('$_base/users/$userId/status'),
      headers: _headers(token),
      body: jsonEncode({'isActive': isActive}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update status: ${res.statusCode}');
    }
  }
}
