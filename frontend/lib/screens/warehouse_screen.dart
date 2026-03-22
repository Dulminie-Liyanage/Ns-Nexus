import 'package:flutter/material.dart';

class WarehouseScreen extends StatelessWidget {
  const WarehouseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Warehouse Dashboard'),
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Welcome Warehouse Manager!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
