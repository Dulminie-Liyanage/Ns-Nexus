import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Calculate loyalty rank from order count if not provided by backend
String _calcRank(dynamic totalOrders) {
  final count = int.tryParse(totalOrders?.toString() ?? '0') ?? 0;
  if (count >= 10) return 'Gold';
  if (count >= 5) return 'Silver';
  return 'Bronze';
}

class OrderModel {
  final String id;
  final String retailerName;
  final String retailerId;
  final String loyaltyRank;
  final bool isUrgent;
  final bool stockSufficient;
  final String status;
  final List<Map<String, dynamic>> items;
  final String? deliveryAddress;
  final String? phone;
  final List<AuditStage> auditTrail;

  OrderModel({
    required this.id,
    required this.retailerName,
    required this.retailerId,
    required this.loyaltyRank,
    required this.isUrgent,
    required this.stockSufficient,
    required this.status,
    required this.items,
    this.deliveryAddress,
    this.phone,
    required this.auditTrail,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? [];
    final auditRaw = json['auditTrail'] ?? json['audit_trail'] ?? [];
    return OrderModel(
      id: json['OrderID']?.toString() ?? json['id']?.toString() ?? '',
      retailerName:
          json['RetailerName'] ??
          json['retailerName'] ??
          json['ShopName'] ??
          '',
      retailerId:
          json['RetailerID']?.toString() ??
          json['retailerId']?.toString() ??
          '',
      loyaltyRank:
          json['loyaltyRank'] ??
          json['loyalty_rank'] ??
          _calcRank(
            int.tryParse(json['approvedCount']?.toString() ?? '0') ?? 0,
          ),
      isUrgent:
          (json['IsUrgent'] ?? json['isUrgent'] ?? 0) == 1 ||
          json['IsUrgent'] == true,
      stockSufficient:
          json['stockSufficient'] ?? json['stock_sufficient'] ?? true,
      status: json['Status'] ?? json['status'] ?? '',
      items: itemsRaw.map((e) => Map<String, dynamic>.from(e)).toList(),
      deliveryAddress: json['deliveryAddress'] ?? json['delivery_address'],
      phone: json['phone'],
      auditTrail: (auditRaw as List)
          .map((e) => AuditStage.fromJson(e))
          .toList(),
    );
  }
}

class AuditStage {
  final int stage;
  final String label;
  final String status;
  final String? actor;
  final String? timestamp;

  AuditStage({
    required this.stage,
    required this.label,
    required this.status,
    this.actor,
    this.timestamp,
  });

  factory AuditStage.fromJson(Map<String, dynamic> json) {
    return AuditStage(
      stage: json['stage'] ?? 0,
      label: json['label'] ?? '',
      status: json['status'] ?? 'pending',
      actor: json['actor'],
      timestamp: json['timestamp'],
    );
  }
}

class DeliveryStop {
  final String orderId;
  final String retailerName;
  final String address;
  final String phone;
  final String status;
  final int stopNumber;

  DeliveryStop({
    required this.orderId,
    required this.retailerName,
    required this.address,
    required this.phone,
    required this.status,
    required this.stopNumber,
  });

  factory DeliveryStop.fromJson(Map<String, dynamic> json) {
    return DeliveryStop(
      orderId: json['OrderID']?.toString() ?? json['orderId']?.toString() ?? '',
      retailerName: json['RetailerName'] ?? json['retailerName'] ?? '',
      address: json['Address'] ?? json['address'] ?? '',
      phone: json['Phone'] ?? json['phone'] ?? '',
      status: json['Status'] ?? json['status'] ?? 'pending',
      stopNumber: json['stopNumber'] ?? json['stop_number'] ?? 0,
    );
  }
}

class DailyReport {
  final int totalOrders;
  final int approvedOrders;
  final int rejectedOrders;
  final int pendingOrders;
  final double totalValue;
  final List<Map<String, dynamic>> ordersByRetailer;
  final List<Map<String, dynamic>> lowStockItems;
  final String generatedAt;

  DailyReport({
    required this.totalOrders,
    required this.approvedOrders,
    required this.rejectedOrders,
    required this.pendingOrders,
    required this.totalValue,
    required this.ordersByRetailer,
    required this.lowStockItems,
    required this.generatedAt,
  });

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    int safeInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
    return DailyReport(
      totalOrders: safeInt(json['totalOrders']),
      approvedOrders: safeInt(json['approvedOrders']),
      rejectedOrders: safeInt(json['rejectedOrders']),
      pendingOrders: safeInt(json['pendingOrders']),
      totalValue: double.tryParse(json['totalValue']?.toString() ?? '0') ?? 0.0,
      ordersByRetailer: List<Map<String, dynamic>>.from(
        json['ordersByRetailer'] ?? [],
      ),
      lowStockItems: List<Map<String, dynamic>>.from(
        json['lowStockItems'] ?? [],
      ),
      generatedAt: json['generatedAt'] ?? '',
    );
  }
}

class OrderService {
  static const String _base = 'http://15.235.160.20:25568';

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sessionToken') ?? '';
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ── SPRINT 1: order_history_screen.dart ─────────────────────────────────────
  // GET /orders/retailer/:userId
  // Response: { orders: [...] }
  Future<List<dynamic>> fetchOrderHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    final token = await _token();
    final res = await http.get(
      Uri.parse('$_base/orders/retailer/$userId'),
      headers: _headers(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['orders'] ?? data) as List<dynamic>;
    }
    throw Exception('Failed to load order history: ${res.statusCode}');
  }

  // ── SPRINT 1: order_history_screen + order_review_screen ────────────────────
  // GET /orders/:id/items
  // Response: { items: [...] }
  Future<List<dynamic>> fetchOrderItems(dynamic orderId) async {
    final token = await _token();
    final res = await http.get(
      Uri.parse('$_base/orders/$orderId/items'),
      headers: _headers(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['items'] ?? data) as List<dynamic>;
    }
    throw Exception('Failed to load order items: ${res.statusCode}');
  }

  // ── SPRINT 1: order_review_screen.dart ──────────────────────────────────────
  // PUT /orders/:id
  // Body: { status, rejection_reason?, items? }
  Future<void> updateOrderStatus(
    dynamic orderId,
    String status, {
    List<Map<String, dynamic>>? items,
    String? rejectionReason,
  }) async {
    final token = await _token();
    final Map<String, dynamic> body = {'status': status};
    if (items != null) body['items'] = items;
    if (rejectionReason != null) body['rejection_reason'] = rejectionReason;
    final res = await http.put(
      Uri.parse('$_base/orders/$orderId'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(
        err['message'] ?? 'Failed to update order: ${res.statusCode}',
      );
    }
  }

  // ── US-10: Check if retailer has priority status for urgent orders ──────────
  // GET /users/:id/priority
  Future<bool> checkPriorityStatus(String userId) async {
    final token = await _token();
    final res = await http.get(
      Uri.parse('$_base/users/$userId/priority'),
      headers: _headers(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['isPriority'] == true;
    }
    return false;
  }

  // ── SPRINT 1: order_screen.dart ──────────────────────────────────────────────
  // POST /orders  — 4 positional args
  Future<void> placeOrder(
    dynamic retailerId,
    List<Map<String, dynamic>> items,
    String deliveryDate,
    dynamic isUrgent,
  ) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse('$_base/orders'),
      headers: _headers(token),
      body: jsonEncode({
        'retailer_id': retailerId,
        'items': items,
        'delivery_date': deliveryDate,
        'is_urgent': isUrgent,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      final err = jsonDecode(res.body);
      throw Exception(
        err['message'] ?? 'Failed to place order: ${res.statusCode}',
      );
    }
  }

  // ── SPRINT 1: wm_dashboard_tab.dart ─────────────────────────────────────────
  // GET /orders  or  GET /orders?status=...
  // Response: { orders: [...] }
  Future<List<dynamic>> fetchAllOrders({String? initialFilter}) async {
    final token = await _token();
    final query = (initialFilter != null && initialFilter.isNotEmpty)
        ? '?status=$initialFilter'
        : '';
    final res = await http.get(
      Uri.parse('$_base/orders$query'),
      headers: _headers(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['orders'] ?? data) as List<dynamic>;
    }
    throw Exception('Failed to load orders: ${res.statusCode}');
  }

  // ── SPRINT 2: warehouse_orders_screen.dart ───────────────────────────────────
  // GET /orders — filter pending client-side
  Future<List<OrderModel>> getPendingOrders() async {
    final orders = await fetchAllOrders();
    return orders
        .map((e) => OrderModel.fromJson(e))
        .where((o) => o.status.toLowerCase() == 'pending')
        .toList();
  }

  // ── SPRINT 2: warehouse_orders_screen bottom sheet ───────────────────────────
  // PUT /orders/:id  (maps to existing updateOrderStatus)
  Future<void> reviewOrder({
    required String orderId,
    required String action,
    required String reason,
  }) async {
    final statusMap = {
      'approve': 'approved',
      'partial': 'partially_approved',
      'reject': 'rejected',
    };
    await updateOrderStatus(
      orderId,
      statusMap[action] ?? action,
      rejectionReason: action == 'reject' ? reason : null,
    );
  }

  // ── Driver assignment screen — orders approved but no driver yet (stage 2-3)
  Future<List<OrderModel>> getApprovedOrders() async {
    final orders = await fetchAllOrders();
    return orders
        .map((e) => OrderModel.fromJson(e))
        .where(
          (o) =>
              o.status.toLowerCase() == 'approved' ||
              o.status.toLowerCase() == 'packing',
        )
        .toList();
  }

  // ── Shipment screen — orders with driver assigned, ready to ship (stage 4+)
  Future<List<OrderModel>> getAssignedOrders() async {
    final orders = await fetchAllOrders();
    return orders
        .map((e) => OrderModel.fromJson(e))
        .where(
          (o) =>
              o.status.toLowerCase() == 'assigned' ||
              o.status.toLowerCase() == 'in_3pl_transit' ||
              o.status.toLowerCase() == 'ready_to_ship',
        )
        .toList();
  }

  // ── SPRINT 2: driver_assignment_screen.dart ──────────────────────────────────
  // POST /orders/:id/next-stage
  Future<void> assignDriver({
    required String orderId,
    required String driverId,
    required String vehicleType,
  }) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse('$_base/orders/$orderId/next-stage'),
      headers: _headers(token),
      body: jsonEncode({'driver_id': driverId, 'vehicle_type': vehicleType}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to assign driver: ${res.statusCode}');
    }
  }

  // ── SPRINT 2: delivery_schedule_screen.dart ──────────────────────────────────
  // GET /orders/driver/:userId  (new backend route needed)
  Future<List<DeliveryStop>> getTodayStops() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    final token = await _token();
    final res = await http.get(
      Uri.parse('$_base/orders/driver/$userId'),
      headers: _headers(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List list = (data['orders'] ?? data) as List;
      return list.map((e) => DeliveryStop.fromJson(e)).toList();
    }
    throw Exception('Failed to load stops: ${res.statusCode}');
  }

  // ── SPRINT 2: delivery_schedule_screen.dart ──────────────────────────────────
  // POST /orders/:id/next-stage
  Future<void> markDelivered(String orderId) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse('$_base/orders/$orderId/next-stage'),
      headers: _headers(token),
      body: jsonEncode({'status': 'delivered'}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to mark delivered: ${res.statusCode}');
    }
  }

  // ── SPRINT 2: audit_trail_screen.dart ───────────────────────────────────────
  Future<OrderModel> getOrderWithAudit(String orderId) async {
    final token = await _token();
    final res = await http.get(
      Uri.parse('$_base/orders/$orderId/items'),
      headers: _headers(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return OrderModel.fromJson(data);
    }
    throw Exception('Failed to load order: ${res.statusCode}');
  }

  Future<List<OrderModel>> getMyOrders() async {
    final orders = await fetchOrderHistory();
    return orders.map((e) => OrderModel.fromJson(e)).toList();
  }

  // ── WM: advance order to next stage (close order at stage 7) ───────────────
  // POST /orders/:id/next-stage
  Future<void> advanceStage(String orderId) async {
    final token = await _token();
    final res = await http.post(
      Uri.parse('$_base/orders/$orderId/next-stage'),
      headers: _headers(token),
      body: jsonEncode({}),
    );
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(
        err['message'] ?? 'Failed to advance stage: \${res.statusCode}',
      );
    }
  }

  // ── SPRINT 2: daily_report_list_screen.dart ──────────────────────────────────
  // GET /orders/report/daily  (new backend route needed)
  Future<DailyReport> getDailyReport() async {
    final token = await _token();
    final res = await http.get(
      Uri.parse('$_base/orders/report/daily'),
      headers: _headers(token),
    );
    if (res.statusCode == 200) {
      return DailyReport.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load report: ${res.statusCode}');
  }
}
