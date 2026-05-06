import 'package:flutter/material.dart';
import '../services/order_service.dart';

class WMDashboardTab extends StatefulWidget {
  final void Function(int index, {String? filter}) onTabChange;

  const WMDashboardTab({super.key, required this.onTabChange});

  @override
  State<WMDashboardTab> createState() => _WMDashboardTabState();
}

class _WMDashboardTabState extends State<WMDashboardTab> {
  final OrderService _orderService = OrderService();
  late Future<List<dynamic>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _orderService.fetchAllOrders();
  }

  @override
  Widget build(BuildContext context) {
    const Color greenCard = Color.fromARGB(255, 75, 154, 105);
    const Color navyCard = Color.fromARGB(255, 41, 33, 77);
    const Color crimsonCard = Color.fromARGB(255, 162, 58, 58);

    return FutureBuilder<List<dynamic>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: greenCard),
          );
        }

        final allOrders = snapshot.data ?? [];
        final int total = allOrders.length;
        final int pending = allOrders
            .where((o) => o['Status'].toString().toLowerCase() == 'pending')
            .length;
        final int urgent = allOrders
            .where((o) => o['IsUrgent'] == 1 || o['is_urgent'] == 1)
            .length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Warehouse',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Text(
                'Manager Dashboard',
                style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              _buildSearchBar('Search shipments or orders'),
              const SizedBox(height: 24),
              _buildWMCard(
                color: greenCard,
                icon: Icons.inventory_2_outlined,
                title: 'Total Orders',
                subtitle: '$total processed last 30 days',
                onTap: () => widget.onTabChange(2, filter: null),
              ),
              const SizedBox(height: 16),
              _buildWMCard(
                color: navyCard,
                icon: Icons.local_shipping_outlined,
                title: 'Pending Shipments',
                subtitle: '$pending orders awaiting dispatch',
                onTap: () => widget.onTabChange(2, filter: 'pending'),
              ),
              const SizedBox(height: 16),
              _buildWMCard(
                color: crimsonCard,
                icon: Icons.notification_important_outlined,
                title: 'Urgent Orders',
                subtitle: '$urgent high-priority requests',
                onTap: () => widget.onTabChange(2, filter: 'urgent'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF64748B)),
          suffixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _buildWMCard({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white54,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
