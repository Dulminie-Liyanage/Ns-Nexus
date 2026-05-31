import 'package:flutter/material.dart';
import '../services/driver_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class DriverStatusScreen extends StatefulWidget {
  const DriverStatusScreen({super.key});

  @override
  State<DriverStatusScreen> createState() => _DriverStatusScreenState();
}

class _DriverStatusScreenState extends State<DriverStatusScreen> {
  final _svc = DriverService();
  String _currentStatus = 'OFFLINE';
  DriverStatusStats? _stats;
  bool _loading = true;
  bool _updating = false;

  static const _statuses = ['AVAILABLE', 'BUSY', 'ON_BREAK', 'OFFLINE'];
  static const _statusLabels = {
    'AVAILABLE': 'Available',
    'BUSY': 'Busy',
    'ON_BREAK': 'On break',
    'OFFLINE': 'Offline',
  };
  static const _statusColors = {
    'AVAILABLE': Color(0xFF3B6D11),
    'BUSY': Color(0xFFA32D2D),
    'ON_BREAK': Color(0xFF854F0B),
    'OFFLINE': Color(0xFF5F5E5A),
  };
  static const _statusBg = {
    'AVAILABLE': Color(0xFFEAF3DE),
    'BUSY': Color(0xFFFCEBEB),
    'ON_BREAK': Color(0xFFFAEEDA),
    'OFFLINE': Color(0xFFF1EFE8),
  };
  static const _statusIcons = {
    'AVAILABLE': Icons.check_circle_outline,
    'BUSY': Icons.local_shipping_outlined,
    'ON_BREAK': Icons.coffee_outlined,
    'OFFLINE': Icons.power_settings_new,
  };
  static const _statusDesc = {
    'AVAILABLE': 'Ready to accept new orders',
    'BUSY': 'Currently delivering — auto set',
    'ON_BREAK': 'Temporarily away',
    'OFFLINE': 'Not working',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status = await _svc.getCurrentStatus();
      final stats = await _svc.getStatusStats();
      setState(() {
        _currentStatus = status;
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    if (newStatus == _currentStatus) return;
    setState(() => _updating = true);
    try {
      // Save to DB
      await _svc.updateStatus(newStatus);
      // Confirm from DB — shows actual saved value
      final confirmedStatus = await _svc.getCurrentStatus();
      setState(() {
        _currentStatus = confirmedStatus;
        _updating = false;
      });
      _snack(
        'Status updated to ${_statusLabels[confirmedStatus] ?? confirmedStatus}.',
      );
    } catch (e) {
      setState(() => _updating = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[_currentStatus] ?? Colors.grey;
    final bg = _statusBg[_currentStatus] ?? Colors.grey.shade50;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        title: Image.asset(
          'assets/images/nestle_logo.png',
          height: 50,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: _load,
          ),
          const CircleAvatar(
            backgroundColor: Color(0xFFE2E8F0),
            radius: 18,
            child: Icon(Icons.person, color: Colors.black54, size: 20),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService().logout();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Status',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Current status card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current status',
                          style: TextStyle(
                            fontSize: 13,
                            color: color.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _statusIcons[_currentStatus],
                              color: color,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _statusLabels[_currentStatus] ?? _currentStatus,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                            if (_updating) ...[
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: color,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _statusDesc[_currentStatus] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: color.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Change status
                  const Text(
                    'Change status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ..._statuses.map((s) {
                    final isCurrent = s == _currentStatus;
                    final sColor = _statusColors[s]!;
                    final sBg = _statusBg[s]!;
                    return GestureDetector(
                      onTap: _updating ? null : () => _changeStatus(s),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isCurrent ? sBg : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? sColor.withOpacity(0.4)
                                : Colors.grey.shade200,
                            width: isCurrent ? 1.5 : 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: sBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _statusIcons[s],
                                color: sColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _statusLabels[s] ?? s,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: isCurrent
                                          ? sColor
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    _statusDesc[s] ?? '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isCurrent)
                              Icon(Icons.check_circle, color: sColor, size: 22),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  // Today's stats
                  if (_stats != null) ...[
                    const Text(
                      "Today's activity",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.2,
                      children: [
                        _StatCard(
                          'Active time',
                          _stats!.activeFormatted,
                          Colors.green.shade600,
                        ),
                        _StatCard(
                          'Delivery time',
                          _stats!.deliveryFormatted,
                          Colors.blue.shade600,
                        ),
                        _StatCard(
                          'Break time',
                          _stats!.breakFormatted,
                          Colors.orange.shade600,
                        ),
                        _StatCard(
                          'Offline time',
                          _stats!.offlineFormatted,
                          Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
