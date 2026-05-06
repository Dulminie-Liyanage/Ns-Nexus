import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── ShipmentModel — represents a single shipment record ──────────────────────
class ShipmentModel {
  final String id;
  final String status;
  final String departureTime;
  final double totalWeight;
  final String vehicleType;
  final String createdAt;
  final int orderCount;
  final String? driverName;
  final String? driverPhone;
  final String? driverStatus;

  ShipmentModel({
    required this.id,
    required this.status,
    required this.departureTime,
    required this.totalWeight,
    required this.vehicleType,
    required this.createdAt,
    required this.orderCount,
    this.driverName,
    this.driverPhone,
    this.driverStatus,
  });

  factory ShipmentModel.fromJson(Map<String, dynamic> json) {
    return ShipmentModel(
      id:
          json['ShipmentID']?.toString() ??
          json['shipmentId']?.toString() ??
          '',
      status: json['Status'] ?? json['status'] ?? 'pending',
      departureTime:
          json['DepartureTime']?.toString() ??
          json['departureTime']?.toString() ??
          '',
      totalWeight:
          double.tryParse(json['TotalWeight']?.toString() ?? '0') ?? 0.0,
      vehicleType: json['VehicleType'] ?? json['vehicleType'] ?? 'Van',
      createdAt: json['CreatedAt']?.toString() ?? '',
      orderCount: int.tryParse(json['orderCount']?.toString() ?? '0') ?? 0,
      driverName: json['DriverName'],
      driverPhone: json['DriverPhone'],
      driverStatus: json['DriverStatus'],
    );
  }

  /// Human-readable status label for display
  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }
}

// ── CapacityResult — result of capacity check before creating shipment ────────
class CapacityResult {
  final bool sufficient;
  final double totalWeight;
  final double totalVolume;
  final double maxWeight;
  final double maxVolume;

  CapacityResult({
    required this.sufficient,
    required this.totalWeight,
    required this.totalVolume,
    required this.maxWeight,
    required this.maxVolume,
  });

  factory CapacityResult.fromJson(Map<String, dynamic> json) {
    return CapacityResult(
      sufficient: json['sufficient'] ?? false,
      totalWeight:
          double.tryParse(json['totalWeight']?.toString() ?? '0') ?? 0.0,
      totalVolume:
          double.tryParse(json['totalVolume']?.toString() ?? '0') ?? 0.0,
      maxWeight: double.tryParse(json['maxWeight']?.toString() ?? '0') ?? 0.0,
      maxVolume: double.tryParse(json['maxVolume']?.toString() ?? '0') ?? 0.0,
    );
  }
}

// ── ShipmentService ───────────────────────────────────────────────────────────
class ShipmentService {
  static const String _base = 'http://15.235.160.20:25568';

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sessionToken') ?? '';
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// POST /shipments/check-capacity
  /// Calculates total weight of [orderIds] and checks against vehicle limit.
  Future<CapacityResult> checkCapacity(List<String> orderIds) async {
    final token = await _token();
    final res = await http
        .post(
          Uri.parse('$_base/shipments/check-capacity'),
          headers: _headers(token),
          body: jsonEncode({
            'orderIds': orderIds
                .map((id) => int.tryParse(id) ?? 0)
                .where((id) => id > 0)
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return CapacityResult.fromJson(jsonDecode(res.body));
    }
    throw Exception('Capacity check failed: ${res.statusCode}');
  }

  /// POST /shipments
  /// Creates a shipment with the selected orders, departure time, and driver.
  Future<ShipmentModel> createShipment({
    required List<String> orderIds,
    required DateTime departureTime,
    String? driverId,
    String vehicleType = 'Van',
  }) async {
    final token = await _token();
    final res = await http
        .post(
          Uri.parse('$_base/shipments'),
          headers: _headers(token),
          body: jsonEncode({
            'orderIds': orderIds
                .map((id) => int.tryParse(id) ?? 0)
                .where((id) => id > 0)
                .toList(),
            'departureTime': departureTime.toIso8601String(),
            'driverId': driverId,
            'vehicleType': vehicleType,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200 || res.statusCode == 201) {
      return ShipmentModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw Exception(
      err['message'] ?? 'Failed to create shipment: ${res.statusCode}',
    );
  }

  /// GET /shipments
  /// Returns all shipments with driver info and order count for 3PL status view.
  Future<List<ShipmentModel>> getShipments() async {
    final token = await _token();
    final res = await http
        .get(Uri.parse('$_base/shipments'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List list = data['shipments'] ?? data;
      return list.map((e) => ShipmentModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load shipments: ${res.statusCode}');
  }

  /// GET /shipments/:id/orders
  /// Returns all orders inside a specific shipment with retailer details.
  Future<List<dynamic>> getShipmentOrders(String shipmentId) async {
    final token = await _token();
    final res = await http
        .get(
          Uri.parse('$_base/shipments/$shipmentId/orders'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['orders'] ?? [];
    }
    throw Exception('Failed to load shipment orders: ${res.statusCode}');
  }
}
