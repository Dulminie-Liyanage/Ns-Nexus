import 'package:flutter/material.dart';
import 'wm_dashboard_tab.dart';
import 'inventory_tab.dart';
import 'warehouse_orders_screen.dart';
import 'audit_trail_screen.dart';
import 'daily_report_list_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  int _currentIndex = 0;
  String? _activeFilter;

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return WMDashboardTab(
          onTabChange: (index, {filter}) {
            setState(() {
              _currentIndex = index;
              _activeFilter = filter;
            });
          },
        );
      case 1:
        return const InventoryTab();
      case 2:
        // Use ValueKey so widget rebuilds when filter changes
        return WarehouseOrdersScreen(
          key: ValueKey(_activeFilter ?? 'all'),
          initialFilter: _activeFilter,
        );
      case 3:
        return const AuditTrailScreen();
      case 4:
        return const DailyReportListScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        title: Image.asset(
          'assets/images/nestle_logo.png',
          height: 50,
          fit: BoxFit.contain,
        ),
        actions: [
          const CircleAvatar(
            backgroundColor: Color(0xFFE2E8F0),
            radius: 18,
            child: Icon(Icons.person, color: Colors.black54, size: 20),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
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
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() {
          _currentIndex = index;
          if (index != 2) _activeFilter = null;
        }),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFD4A017),
        unselectedItemColor: Colors.grey.shade400,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline_outlined),
            label: 'Audit',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Report',
          ),
        ],
      ),
    );
  }
}
