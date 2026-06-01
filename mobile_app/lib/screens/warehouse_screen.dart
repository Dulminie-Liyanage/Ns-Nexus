import 'package:flutter/material.dart';
import 'inventory_tab.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

// WM only owns Inventory — PO feedback
class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});
  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        title: Image.asset('assets/images/nestle_logo.png',
            height: 50, fit: BoxFit.contain),
        actions: [
          const CircleAvatar(
              backgroundColor: Color(0xFFE2E8F0),
              radius: 18,
              child: Icon(Icons.person, color: Colors.black54, size: 20)),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService().logout();
              if (!mounted) return;
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      // WM only sees inventory management
      body: const InventoryTab(),
    );
  }
}