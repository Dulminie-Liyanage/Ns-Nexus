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

  factory DeliveryStop.fromJson(Map<String, dynamic> json, {int index = 0}) {
    // OrderID comes as integer from MariaDB — convert to string
    final orderId =
        json['OrderID']?.toString() ?? json['orderId']?.toString() ?? '';
    return DeliveryStop(
      orderId: orderId,
      retailerName:
          json['RetailerName'] ??
          json['ShopName'] ??
          json['retailerName'] ??
          '',
      address: json['Address'] ?? json['address'] ?? '',
      phone: json['Phone'] ?? json['phone'] ?? '',
      status:
          json['DeliveryStatus'] ??
          json['Status'] ??
          json['status'] ??
          'assigned',
      // stopNumber from DB or fallback to list index + 1
      stopNumber:
          int.tryParse(json['stopNumber']?.toString() ?? '') ??
          int.tryParse(json['stop_number']?.toString() ?? '') ??
          index + 1,
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

  // Cache SharedPreferences so it is only loaded once per session
  static Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sessionToken') ?? prefs.getString('token') ?? '';
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ── SPRINT 1: order_history_screen.dart ─────────────────────────────────────
  // GET /orders/retailer/:userId
  // Response: { orders: [...] }
  Future<List<dynamic>> fetchOrderHistory() async {
    final prefs = await _getPrefs();
    final userId = prefs.getString('userId') ?? '';
    final token = await _token();
    final res = await http
        .get(
          Uri.parse('$_base/orders/retailer/$userId'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));
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
    final res = await http
        .get(
          Uri.parse('$_base/orders/$orderId/items'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['items'] ?? data) as List<dynamic>;
    }
    throw Exception('Failed to load order items: ${res.statusCode}');
  }

  // ── SPRINT 3 US-19: Quick Order ─────────────────────────────────────────────
  // Fetches the last approved order for this retailer and returns:
  // { 'orderId': id, 'cart': Map<productId, qty> }
  // Uses QtyRequested (retailer's original intent).
  // If no approved order exists, returns empty cart so QuickOrderScreen
  // still opens and shows all products for a fresh order.
  Future<Map<String, dynamic>> fetchLastApprovedOrderCart() async {
    try {
      final history = await fetchOrderHistory();
      // Find the most recent approved/delivered order
      final approved = history.where((o) {
        final s = (o['Status'] ?? '').toString().toLowerCase();
        return [
          'approved',
          'partially_approved',
          'delivered',
          'packing',
          'in_3pl_transit',
          'ready_to_ship',
          'out_for_delivery',
        ].contains(s);
      }).toList();

      if (approved.isEmpty) return {'orderId': null, 'cart': <String, int>{}};

      // Sort by OrderID descending to get latest
      approved.sort((a, b) {
        final aId = int.tryParse((a['OrderID'] ?? 0).toString()) ?? 0;
        final bId = int.tryParse((b['OrderID'] ?? 0).toString()) ?? 0;
        return bId.compareTo(aId);
      });

      final lastOrder = approved.first;
      final orderId = lastOrder['OrderID'];
      final items = await fetchOrderItems(orderId);

      final Map<String, int> cart = {};
      for (final item in items) {
        final productId = (item['ProductID'] ?? item['productId'] ?? '')
            .toString();
        final qty =
            int.tryParse(
              (item['QtyRequested'] ?? item['Quantity'] ?? 0).toString(),
            ) ??
            0;
        if (productId.isNotEmpty && qty > 0) cart[productId] = qty;
      }
      return {'orderId': orderId, 'cart': cart};
    } catch (_) {
      return {'orderId': null, 'cart': <String, int>{}};
    }
  }

  // ── SPRINT 3 US-19: Quick Reorder (from history button) ──────────────────────
  // Fetches order items and returns them as a Map<productId, qty>
  // so OrderScreen can pre-populate the cart with previous quantities.
  // Current prices come from the products endpoint (already loaded in OrderScreen).
  Future<Map<String, int>> fetchReorderCart(dynamic orderId) async {
    final items = await fetchOrderItems(orderId);
    final Map<String, int> cart = {};
    for (final item in items) {
      final productId = (item['ProductID'] ?? item['productId'] ?? '')
          .toString();
      // Use QtyRequested — the retailer's original intent, not WM-approved qty
      final qty =
          int.tryParse(
            (item['QtyRequested'] ?? item['Quantity'] ?? 0).toString(),
          ) ??
          0;
      if (productId.isNotEmpty && qty > 0) {
        cart[productId] = qty;
      }
    }
    return cart;
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
    final res = await http
        .put(
          Uri.parse('$_base/orders/$orderId'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
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
    final res = await http
        .get(
          Uri.parse('$_base/users/$userId/priority'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));
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
    final res = await http
        .post(
          Uri.parse('$_base/orders'),
          headers: _headers(token),
          body: jsonEncode({
            'retailer_id': retailerId,
            'items': items,
            'delivery_date': deliveryDate,
            'is_urgent': isUrgent,
          }),
        )
        .timeout(const Duration(seconds: 15));
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
    final res = await http
        .get(Uri.parse('$_base/orders$query'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));
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
  // Driver assignment screen — only approved orders (WM approved, no driver yet)
  Future<List<OrderModel>> getApprovedOrders() async {
    final orders = await fetchAllOrders();
    return orders
        .map((e) => OrderModel.fromJson(e))
        .where((o) => o.status.toLowerCase() == 'approved')
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
    final res = await http
        .post(
          Uri.parse('$_base/orders/$orderId/next-stage'),
          headers: _headers(token),
          body: jsonEncode({
            'driver_id': driverId,
            'vehicle_type': vehicleType,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Failed to assign driver: ${res.statusCode}');
    }
  }

  // ── SPRINT 2: delivery_schedule_screen.dart ──────────────────────────────────
  // GET /orders/driver/:userId  (new backend route needed)
  Future<List<DeliveryStop>> getTodayStops() async {
    final prefs = await _getPrefs();
    final userId = prefs.getString('userId') ?? '';
    final token = await _token();
    final res = await http
        .get(
          Uri.parse('$_base/orders/driver/$userId'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List list = (data['orders'] ?? data) as List;
      return list
          .asMap()
          .entries
          .map((e) => DeliveryStop.fromJson(e.value, index: e.key))
          .toList();
    }
    throw Exception('Failed to load stops: ${res.statusCode}');
  }

  // ── SPRINT 2: delivery_schedule_screen.dart ──────────────────────────────────
  // POST /orders/:id/next-stage
  Future<void> markDelivered(String orderId) async {
    final token = await _token();
    final res = await http
        .post(
          Uri.parse('$_base/orders/$orderId/next-stage'),
          headers: _headers(token),
          body: jsonEncode({'status': 'delivered'}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Failed to mark delivered: ${res.statusCode}');
    }
  }

  // ── SPRINT 2: audit_trail_screen.dart ───────────────────────────────────────
  Future<OrderModel> getOrderWithAudit(String orderId) async {
    final token = await _token();
    final res = await http
        .get(
          Uri.parse('$_base/orders/$orderId/items'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));
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
    final res = await http
        .post(
          Uri.parse('$_base/orders/$orderId/next-stage'),
          headers: _headers(token),
          body: jsonEncode({}),
        )
        .timeout(const Duration(seconds: 15));
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
    final res = await http
        .get(Uri.parse('$_base/orders/report/daily'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return DailyReport.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load report: ${res.statusCode}');
  }
}
