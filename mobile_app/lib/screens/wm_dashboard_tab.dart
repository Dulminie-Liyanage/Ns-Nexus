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
        final int delivered = allOrders
            .where((o) => o['Status'].toString().toLowerCase() == 'delivered')
            .length;
        final fulfillment = total > 0
            ? ((delivered / total) * 100).toStringAsFixed(0)
            : '0';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────────
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

              // ── Quick stats row ──────────────────────────────────────────────
              Row(
                children: [
                  _buildMiniStat(
                    'Total',
                    '$total',
                    Icons.receipt_long_outlined,
                    const Color(0xFF0056B3),
                  ),
                  const SizedBox(width: 10),
                  _buildMiniStat(
                    'Delivered',
                    '$delivered',
                    Icons.check_circle_outline,
                    greenCard,
                  ),
                  const SizedBox(width: 10),
                  _buildMiniStat(
                    'Fulfillment',
                    '$fulfillment%',
                    Icons.pie_chart_outline,
                    const Color(0xFF7C3AED),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Order cards ─────────────────────────────────────────────────
              _buildWMCard(
                color: greenCard,
                icon: Icons.inventory_2_outlined,
                title: 'Total Orders',
                subtitle: '$total processed last 30 days',
                onTap: () => widget.onTabChange(2, filter: 'all'),
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
              const SizedBox(height: 28),

              // ── Tools section ────────────────────────────────────────────────
              const Text(
                'Tools & Reports',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),

              // Analytics Dashboard card
              _buildToolCard(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0056B3), Color(0xFF1E88E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                icon: Icons.analytics_outlined,
                title: 'Analytics Dashboard',
                subtitle: 'Fulfillment rate • Demand • Bottleneck',
                onTap: () => widget.onTabChange(5),
              ),
              const SizedBox(height: 12),

              // Audit Trail card
              _buildToolCard(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade600, Colors.teal.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                icon: Icons.timeline_outlined,
                title: 'Audit Trail',
                subtitle: 'Track all 7 pipeline stages',
                onTap: () => widget.onTabChange(3),
              ),
              const SizedBox(height: 12),

              // Daily Report card
              _buildToolCard(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade600,
                    Colors.deepPurple.shade400,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                icon: Icons.bar_chart_outlined,
                title: 'Daily Report',
                subtitle: 'Generate and view daily summaries',
                onTap: () => widget.onTabChange(4),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ── Mini stat card ───────────────────────────────────────────────────────
  Widget _buildMiniStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tool / shortcut card with gradient ───────────────────────────────────
  Widget _buildToolCard({
    required Gradient gradient,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────────────────────
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

  // ── Original order card ──────────────────────────────────────────────────
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
