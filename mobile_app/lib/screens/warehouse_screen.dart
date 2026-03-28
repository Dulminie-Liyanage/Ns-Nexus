import 'package:flutter/material.dart';
import 'wm_dashboard_tab.dart';
import 'inventory_tab.dart';
import 'warehouse_orders_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  int _currentIndex = 0;
  String? _activeFilter; // Stores 'pending' or 'urgent' from the dashboard

  @override
  Widget build(BuildContext context) {
    final List<Widget> _tabs = [
      // Index 0: Overview
      WMDashboardTab(
        onTabChange: (index, {filter}) {
          setState(() {
            _currentIndex = index;
            _activeFilter = filter;
          });
        },
      ),
      // Index 1: Products
      const InventoryTab(),
      // Index 2: Orders
      WarehouseOrdersScreen(initialFilter: _activeFilter),
      // Index 3: Profile
      const Center(child: Text("Profile Page")),
    ];

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
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() {
          _currentIndex = index;
          _activeFilter = null; // Clear filter if clicking tab manually
        }),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFD4A017), // Nestle Gold
        unselectedItemColor: Colors.grey.shade400,
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
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
