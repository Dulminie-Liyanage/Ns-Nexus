import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DriverModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String status; // AVAILABLE, BUSY, OFFLINE, ON_BREAK
  final String vehicleType;
  final int currentOrders;

  DriverModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.status,
    required this.vehicleType,
    required this.currentOrders,
  });

  String get fullName => '$firstName $lastName';

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id']?.toString() ?? '',
      firstName: json['firstName'] ?? json['first_name'] ?? '',
      lastName: json['lastName'] ?? json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      status: json['status'] ?? 'OFFLINE',
      vehicleType: json['vehicleType'] ?? json['vehicle_type'] ?? '',
      currentOrders: json['currentOrders'] ?? json['current_orders'] ?? 0,
    );
  }
}

class DriverStatusStats {
  final int activeMinutes;
  final int deliveryMinutes;
  final int breakMinutes;
  final int offlineMinutes;

  DriverStatusStats({
    required this.activeMinutes,
    required this.deliveryMinutes,
    required this.breakMinutes,
    required this.offlineMinutes,
  });

  factory DriverStatusStats.fromJson(Map<String, dynamic> json) {
    return DriverStatusStats(
      activeMinutes: json['activeMinutes'] ?? 0,
      deliveryMinutes: json['deliveryMinutes'] ?? 0,
      breakMinutes: json['breakMinutes'] ?? 0,
      offlineMinutes: json['offlineMinutes'] ?? 0,
    );
  }

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  String get activeFormatted => _fmt(activeMinutes);
  String get deliveryFormatted => _fmt(deliveryMinutes);
  String get breakFormatted => _fmt(breakMinutes);
  String get offlineFormatted => _fmt(offlineMinutes);
}

class DriverService {
  static const String _base = 'http://15.235.160.20:25568';

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sessionToken') ?? '';
  }

  Future<String> _driverId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId') ?? '';
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<DriverModel>> getAvailableDrivers() async {
    final token = await _token();
    final res = await http.get(
      Uri.parse('$_base/drivers?status=AVAILABLE'),
      headers: _headers(token),
    );
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((e) => DriverModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load drivers: ${res.statusCode}');
  }

  Future<List<DriverModel>> getAllDrivers() async {
    final token = await _token();
    final res = await http.get(
      Uri.parse('$_base/drivers'),
      headers: _headers(token),
    );
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((e) => DriverModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load drivers: ${res.statusCode}');
  }

  Future<String> getCurrentStatus() async {
    final token = await _token();
    final id = await _driverId();
    final res = await http.get(
      Uri.parse('$_base/drivers/$id/status'),
      headers: _headers(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['status'] ?? 'OFFLINE';
    }
    throw Exception('Failed to get status: ${res.statusCode}');
  }

  Future<DriverStatusStats> getStatusStats() async {
    final token = await _token();
    final id = await _driverId();
    final res = await http.get(
      Uri.parse('$_base/drivers/$id/stats'),
      headers: _headers(token),
    );
    if (res.statusCode == 200) {
      return DriverStatusStats.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to get stats: ${res.statusCode}');
  }

  Future<void> updateStatus(String newStatus) async {
    final token = await _token();
    final id = await _driverId();
    final res = await http.patch(
      Uri.parse('$_base/drivers/$id/status'),
      headers: _headers(token),
      body: jsonEncode({'status': newStatus}),
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Failed to update status: ${res.statusCode}');
    }
  }
}
