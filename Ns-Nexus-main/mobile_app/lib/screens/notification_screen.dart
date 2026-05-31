import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/analiytics_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _svc = AnalyticsService();
  List<dynamic> _notifications = [];
  int _unread = 0;
  bool _loading = true;
  String? _error;
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId') ?? '';
      if (_userId.isEmpty || _userId == 'null' || _userId == '0') {
        throw Exception('Session not found. Please log in again.');
      }

      final data = await _svc.getNotifications(_userId);
      setState(() {
        _notifications = data['notifications'] ?? [];
        _unread = data['unreadCount'] ?? 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _svc.markAllRead(_userId);
      setState(() {
        _notifications = _notifications
            .map((n) => {...n, 'IsRead': 1})
            .toList();
        _unread = 0;
      });
    } catch (_) {}
  }

  Color _iconColor(String title) {
    if (title.contains('Approved') || title.contains('Delivered'))
      return Colors.green.shade600;
    if (title.contains('Rejected')) return Colors.red.shade600;
    if (title.contains('Transit') || title.contains('Ship'))
      return Colors.blue.shade600;
    if (title.contains('Packing')) return Colors.orange.shade600;
    return const Color(0xFF0056B3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            if (_unread > 0)
              Text(
                '$_unread unread',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Color(0xFF0056B3), fontSize: 13),
              ),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 56,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You\'ll be notified when your order status changes',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _notifications.length,
                itemBuilder: (context, i) {
                  final n = _notifications[i];
                  final isRead = (n['IsRead'] ?? 0) == 1;
                  final title = n['Title'] ?? n['title'] ?? 'Order Update';
                  final message = n['Message'] ?? n['message'] ?? '';
                  final orderId = n['OrderID'] ?? n['order_id'];
                  final createdAt = n['CreatedAt']?.toString() ?? '';
                  final dateStr = createdAt.isNotEmpty
                      ? createdAt.split('T')[0]
                      : '';

                  return GestureDetector(
                    onTap: () async {
                      if (!isRead) {
                        await _svc.markRead(n['NotificationID'].toString());
                        setState(() {
                          _notifications[i] = {...n, 'IsRead': 1};
                          if (_unread > 0) _unread--;
                        });
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isRead ? Colors.white : const Color(0xFFE6EFFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isRead
                              ? Colors.grey.shade200
                              : const Color(0xFF0056B3).withOpacity(0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _iconColor(title).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              title.isNotEmpty ? title[0] : '📦',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            fontWeight: isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            fontSize: 14,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              message,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            if (orderId != null || dateStr.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (orderId != null)
                                    Text(
                                      'Order #$orderId  ',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF0056B3),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        trailing: isRead
                            ? null
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0056B3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
