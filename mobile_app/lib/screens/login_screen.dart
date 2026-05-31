import 'package:flutter/material.dart';
import 'sales_manager_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'retailer_screen.dart';
import 'warehouse_screen.dart';
import 'admin_user_management_screen.dart';
import 'driver_status_screen.dart';
import 'delivery_schedule_screen.dart';
import 'driver_profile_screen.dart';
import 'shipment_management_screen.dart';
import 'audit_trail_screen.dart';
import 'analiytics_dashboard_screen.dart';
import 'driver_performance_screen.dart';
import 'demand_analiysis_screen.dart';
import 'warehouse_orders_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLocked = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    if (_isLocked) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        setState(() { _errorMessage = 'Please enter both email and password'; _isLoading = false; });
        return;
      }
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
        setState(() { _errorMessage = 'Please enter a valid email address'; _isLoading = false; });
        return;
      }

      final response = await _authService.login(email, password);
      if (!mounted) return;

      final user = response['user'];
      final role = (user['role'] ?? '').toString().toLowerCase();

      // Save extra session data to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', user['name']?.toString() ?? '');
      await prefs.setString('userEmail', email);
      // Save priority status for retailers — used to show/hide urgent order card
      // Backend returns priorityStatus as bool (true/false) — convert to '1'/'0'
      final ps = user['PriorityStatus'] ?? user['priorityStatus'] ?? false;
      await prefs.setString('priorityStatus', (ps == true || ps == 1) ? '1' : '0');
      // Save userId so notification and analytics screens can use it
      final uid = user['UserID'] ?? user['userId'] ?? user['id'] ?? '';
      await prefs.setString('userId', uid.toString());

      if (!mounted) return;

      if (role == 'retailer') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const RetailerScreen()));
      } else if (role == 'warehouse_manager' || role == 'wm') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const WarehouseScreen()));
      } else if (role == 'admin') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const AdminUserManagementScreen()));
      } else if (role == 'driver') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const DriverHomeScreen()));
      } else if (role == 'sales_manager') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const SalesManagerScreen()));
      } else if (role == '3pl_manager' || role == 'logistics_manager' || role == 'lm') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const LogisticsHomeScreen()));
      } else {
        setState(() => _errorMessage = 'Login failed — unrecognised role: "$role"');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        if (e.statusCode == 403) _isLocked = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF0056B3);
    const Color bgColor = Color(0xFFF5F7FA);
    const Color textColor = Color(0xFF1E293B);
    const Color subtleText = Color(0xFF64748B);
    const Color inputFillColor = Color(0xFFE6EFFF);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Image.asset('assets/images/nestle_logo.png',
                    height: 80, fit: BoxFit.contain)),
                const SizedBox(height: 48),
                const Text('Sign In to Your Account',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                        color: textColor),
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                const Text('Email',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'yourmail@gmail.com',
                    hintStyle: const TextStyle(color: subtleText),
                    filled: true, fillColor: inputFillColor,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Password',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'your password',
                    hintStyle: const TextStyle(color: subtleText),
                    filled: true, fillColor: inputFillColor,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      SizedBox(width: 24, height: 24,
                          child: Checkbox(value: false, onChanged: (v) {},
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)))),
                      const SizedBox(width: 8),
                      const Text('Remember me',
                          style: TextStyle(color: subtleText)),
                    ]),
                    TextButton(
                        onPressed: () {},
                        child: const Text('Forgot Password',
                            style: TextStyle(color: brandBlue,
                                fontWeight: FontWeight.w600))),
                  ],
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center),
                  ),
                ElevatedButton(
                  onPressed: (_isLoading || _isLocked) ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: brandBlue.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Text('Sign In',
                          style: TextStyle(fontSize: 18,
                              fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Driver home — 3 tabs: Status, Schedule, Profile ───────────────────────────
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _currentIndex = 0;
  // Key forces DriverStatusScreen to rebuild when switching back to status tab
  Key _statusKey = UniqueKey();

  void _onTabTap(int i) {
    // Rebuild status screen every time driver taps back to it
    // so it fetches fresh status from DB immediately
    if (i == 0) {
      setState(() {
        _currentIndex = 0;
        _statusKey = UniqueKey();
      });
    } else {
      setState(() => _currentIndex = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DriverStatusScreen(key: _statusKey),
      const DeliveryScheduleScreen(),
      const DriverProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
        selectedItemColor: const Color(0xFF0056B3),
        unselectedItemColor: Colors.grey.shade400,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.toggle_on_outlined), label: 'My Status'),
          BottomNavigationBarItem(
              icon: Icon(Icons.route_outlined), label: 'Schedule'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

// ── Logistics manager home — 2 tabs: Shipments + Order Tracking ───────────────
class LogisticsHomeScreen extends StatefulWidget {
  const LogisticsHomeScreen({super.key});
  @override
  State<LogisticsHomeScreen> createState() => _LogisticsHomeScreenState();
}

class _LogisticsHomeScreenState extends State<LogisticsHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const WarehouseOrdersScreen(),              // PO-01: full order pipeline
      const AuditTrailScreen(onlyShipped: false), // full audit trail for 3PL
      const ShipmentManagementScreen(),           // shipment management
      const DriverPerformanceScreen(),            // driver analytics
      const DemandAnalysisScreen(),               // demand trends
    ];
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) { if (i >= 0 && i < 5) setState(() => _currentIndex = i); },
        selectedItemColor: const Color(0xFF0056B3),
        unselectedItemColor: Colors.grey.shade400,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              label: 'Orders'),
          BottomNavigationBarItem(
              icon: Icon(Icons.timeline_outlined),
              label: 'Audit Trail'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'Shipments'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              label: 'Performance'),
          BottomNavigationBarItem(
              icon: Icon(Icons.trending_up_outlined),
              label: 'Demand'),
        ],
      ),
    );
  }
}