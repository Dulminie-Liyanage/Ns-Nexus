import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Recursively convert numeric strings to num in API responses
// Also casts all Map keys to String to avoid LinkedMap<dynamic,dynamic> errors
dynamic _sanitize(dynamic obj) {
  if (obj is Map) {
    return Map<String, dynamic>.fromEntries(
      obj.entries.map((e) => MapEntry(e.key.toString(), _sanitize(e.value))),
    );
  } else if (obj is List) {
    return obj.map(_sanitize).toList();
  } else if (obj is String) {
    final i = int.tryParse(obj);
    if (i != null) return i;
    final d = double.tryParse(obj);
    if (d != null) return d;
  }
  return obj;
}

class AnalyticsService {
  static const String _base = 'http://15.235.160.20:25568';

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sessionToken') ?? prefs.getString('token') ?? '';
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  String _rangeQuery({String? range, String? start, String? end}) {
    if (start != null && end != null) return '?start=$start&end=$end';
    if (range != null) return '?range=$range';
    return '';
  }

  // ── Dashboard (Admin / WM) ────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard({
    String? range,
    String? start,
    String? end,
  }) async {
    final token = await _token();
    final q = _rangeQuery(range: range, start: start, end: end);
    final res = await http
        .get(
          Uri.parse('$_base/analytics/dashboard$q'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200)
      return _sanitize(jsonDecode(res.body)) as Map<String, dynamic>;
    throw Exception('Dashboard fetch failed: ${res.statusCode}');
  }

  // ── Product Demand (Manager) ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getDemand({
    String? range,
    String? start,
    String? end,
  }) async {
    final token = await _token();
    final q = _rangeQuery(range: range, start: start, end: end);
    final res = await http
        .get(Uri.parse('$_base/analytics/demand$q'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200)
      return _sanitize(jsonDecode(res.body)) as Map<String, dynamic>;
    throw Exception('Demand fetch failed: ${res.statusCode}');
  }

  // ── Bottleneck Analysis (WM) ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getBottleneck({
    String? range,
    String? start,
    String? end,
  }) async {
    final token = await _token();
    final q = _rangeQuery(range: range, start: start, end: end);
    final res = await http
        .get(
          Uri.parse('$_base/analytics/bottleneck$q'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200)
      return _sanitize(jsonDecode(res.body)) as Map<String, dynamic>;
    throw Exception('Bottleneck fetch failed: ${res.statusCode}');
  }

  // ── Driver Performance (3PL Manager) ─────────────────────────────────────
  Future<Map<String, dynamic>> getDriverPerformance({
    String? range,
    String? start,
    String? end,
  }) async {
    final token = await _token();
    final q = _rangeQuery(range: range, start: start, end: end);
    final res = await http
        .get(Uri.parse('$_base/analytics/drivers$q'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200)
      return _sanitize(jsonDecode(res.body)) as Map<String, dynamic>;
    throw Exception('Driver performance fetch failed: ${res.statusCode}');
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getNotifications(String retailerId) async {
    final token = await _token();
    final res = await http
        .get(
          Uri.parse('$_base/notifications/$retailerId'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200)
      return _sanitize(jsonDecode(res.body)) as Map<String, dynamic>;
    throw Exception('Notifications fetch failed: ${res.statusCode}');
  }

  Future<void> markAllRead(String retailerId) async {
    final token = await _token();
    await http
        .patch(
          Uri.parse('$_base/notifications/$retailerId/read-all'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<void> markRead(String notificationId) async {
    final token = await _token();
    await http
        .patch(
          Uri.parse('$_base/notifications/$notificationId/read'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));
  }

  // ── Stage override (US-18) ────────────────────────────────────────────────
  Future<void> overrideStage(String orderId, int stage) async {
    final token = await _token();
    final res = await http
        .put(
          Uri.parse('$_base/orders/$orderId/stage-override'),
          headers: _headers(token),
          body: jsonEncode({'stage': stage}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['message'] ?? 'Override failed: ${res.statusCode}');
    }
  }

  Future<void> batchOverride(List<String> orderIds, int stage) async {
    final token = await _token();
    final res = await http
        .put(
          Uri.parse('$_base/orders/batch-override'),
          headers: _headers(token),
          body: jsonEncode({
            'orderIds': orderIds.map(int.parse).toList(),
            'stage': stage,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(
        err['message'] ?? 'Batch override failed: ${res.statusCode}',
      );
    }
  }

  // ── Digital delivery confirmation (US-17) ─────────────────────────────────
  Future<void> confirmDelivery({
    required String orderId,
    String? signature,
    String? photo,
    double? lat,
    double? lng,
  }) async {
    final token = await _token();
    final res = await http
        .put(
          Uri.parse('$_base/orders/$orderId/confirm-delivery'),
          headers: _headers(token),
          body: jsonEncode({
            'signature': signature,
            'photo': photo,
            'lat': lat,
            'lng': lng,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(
        err['message'] ?? 'Confirmation failed: ${res.statusCode}',
      );
    }
  }
}
