import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// PO-02: Supply Disruption Alert Banner
// Shows active disruptions before retailer places order
// ─────────────────────────────────────────────────────────────────────────────
class DisruptionBanner extends StatefulWidget {
  const DisruptionBanner({super.key});

  @override
  State<DisruptionBanner> createState() => _DisruptionBannerState();
}

class _DisruptionBannerState extends State<DisruptionBanner> {
  static const _base = 'http://15.235.160.20:25568';
  List<dynamic> _disruptions = [];
  bool _dismissed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('sessionToken') ?? prefs.getString('token') ?? '';
      final res = await http.get(
        Uri.parse('$_base/orders/disruptions'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
      final data = jsonDecode(res.body);
      if (mounted) {
        setState(() {
          _disruptions = data['disruptions'] ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':   return Colors.red.shade700;
      case 'medium': return Colors.orange.shade700;
      default:       return Colors.yellow.shade800;
    }
  }

  Color _severityBg(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':   return Colors.red.shade50;
      case 'medium': return Colors.orange.shade50;
      default:       return Colors.yellow.shade50;
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'flood':     return Icons.water_outlined;
      case 'transport': return Icons.local_shipping_outlined;
      case 'warehouse': return Icons.warehouse_outlined;
      default:          return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _dismissed || _disruptions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: _disruptions.map((d) {
          final severity = d['Severity']?.toString() ?? 'medium';
          final type = d['DisruptionType']?.toString() ?? 'other';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _severityBg(severity),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _severityColor(severity).withAlpha(80)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_typeIcon(type), color: _severityColor(severity), size: 20),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d['Title']?.toString() ?? 'Disruption Alert',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _severityColor(severity))),
                  const SizedBox(height: 2),
                  Text(d['Message']?.toString() ?? '',
                      style: TextStyle(fontSize: 12, color: _severityColor(severity))),
                ],
              )),
              GestureDetector(
                onTap: () => setState(() => _dismissed = true),
                child: Icon(Icons.close, size: 16,
                    color: _severityColor(severity).withAlpha(150)),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WM/Admin — Manage Disruptions Screen
// ─────────────────────────────────────────────────────────────────────────────
class ManageDisruptionsScreen extends StatefulWidget {
  const ManageDisruptionsScreen({super.key});
  @override
  State<ManageDisruptionsScreen> createState() => _ManageDisruptionsScreenState();
}

class _ManageDisruptionsScreenState extends State<ManageDisruptionsScreen> {
  static const _base = 'http://15.235.160.20:25568';
  List<dynamic> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sessionToken') ?? prefs.getString('token') ?? '';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = await _token();
      final res = await http.get(
        Uri.parse('$_base/orders/disruptions'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      setState(() { _list = data['disruptions'] ?? []; _loading = false; });
    } catch (_) {
      setState(() { _list = []; _loading = false; });
    }
  }

  Future<void> _deactivate(dynamic id) async {
    try {
      final token = await _token();
      await http.delete(
        Uri.parse('$_base/orders/disruptions/$id'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      _load();
    } catch (_) {}
  }

  void _showCreate() {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String type = 'transport';
    String severity = 'medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Create Disruption Alert',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
            IconButton(onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 14),
          TextField(controller: titleCtrl,
              decoration: _inp('Title *')),
          const SizedBox(height: 10),
          TextField(controller: msgCtrl, maxLines: 3,
              decoration: _inp('Message to retailers *')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              value: type, decoration: _inp('Type'),
              items: const [
                DropdownMenuItem(value: 'flood', child: Text('🌊 Flood')),
                DropdownMenuItem(value: 'transport', child: Text('🚚 Transport')),
                DropdownMenuItem(value: 'warehouse', child: Text('🏭 Warehouse')),
                DropdownMenuItem(value: 'other', child: Text('⚠️ Other')),
              ],
              onChanged: (v) => setS(() => type = v!),
            )),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String>(
              value: severity, decoration: _inp('Severity'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('🟡 Low')),
                DropdownMenuItem(value: 'medium', child: Text('🟠 Medium')),
                DropdownMenuItem(value: 'high', child: Text('🔴 High')),
              ],
              onChanged: (v) => setS(() => severity = v!),
            )),
          ]),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty || msgCtrl.text.isEmpty) return;
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('sessionToken') ?? '';
                final userId = prefs.getString('userId') ?? '';
                await http.post(
                  Uri.parse('$_base/orders/disruptions'),
                  headers: {'Content-Type': 'application/json',
                      'Authorization': 'Bearer $token'},
                  body: jsonEncode({
                    'title': titleCtrl.text.trim(),
                    'message': msgCtrl.text.trim(),
                    'disruptionType': type,
                    'severity': severity,
                    'createdBy': userId,
                  }),
                ).timeout(const Duration(seconds: 10));
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Broadcast Alert',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      )),
    );
  }

  InputDecoration _inp(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('Supply Disruptions',
            style: TextStyle(color: Color(0xFF1E293B),
                fontWeight: FontWeight.w700, fontSize: 18)),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreate,
        backgroundColor: Colors.red.shade700,
        icon: const Icon(Icons.add_alert_outlined, color: Colors.white),
        label: const Text('New Alert',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_outline, size: 56,
                      color: Colors.green.shade300),
                  const SizedBox(height: 12),
                  const Text('No active disruptions',
                      style: TextStyle(fontSize: 16, color: Color(0xFF1E293B))),
                  const SizedBox(height: 6),
                  Text('All regions operating normally',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final d = _list[i];
                    final severity = d['Severity']?.toString() ?? 'medium';
                    final type = d['DisruptionType']?.toString() ?? 'other';
                    final icons = {
                      'flood': Icons.water_outlined,
                      'transport': Icons.local_shipping_outlined,
                      'warehouse': Icons.warehouse_outlined,
                    };
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200)),
                      child: Row(children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10)),
                          child: Icon(icons[type] ?? Icons.warning_amber_rounded,
                              color: Colors.red.shade600, size: 22)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d['Title']?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w700,
                                  fontSize: 14, color: Color(0xFF1E293B))),
                          Text(d['Message']?.toString() ?? '',
                              style: const TextStyle(fontSize: 12,
                                  color: Color(0xFF64748B)), maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: severity == 'high'
                                  ? Colors.red.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              '${severity.toUpperCase()} severity',
                              style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: severity == 'high'
                                    ? Colors.red.shade700 : Colors.orange.shade700)),
                          ),
                        ])),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: Colors.red.shade400),
                          onPressed: () => _deactivate(d['DisruptionID']),
                        ),
                      ]),
                    );
                  },
                ),
    );
  }
}