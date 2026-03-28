import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'new_order_screen.dart';
import 'order_history_screen.dart';

class RetailerScreen extends StatelessWidget {
  const RetailerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Brand Colors
    const Color bgColor = Color(0xFFF5F7FA);
    const Color textColor = Color(0xFF1E293B);
    const Color subtleText = Color(0xFF64748B);

    // Card Colors from Mockup
    const Color purpleCard = Color(0xFF9F7AEA);
    const Color yellowCard = Color(0xFFFCD34D);
    const Color tealCard = Color(0xFF4ADE80);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 100, // 🚨 Increased height for the bar
        title: Padding(
          padding: const EdgeInsets.only(top: 10.0), // 🚨 Added padding
          child: Image.asset(
            'assets/images/nestle_logo.png',
            height: 70, // 🚨 Increased logo height (was 40)
            fit: BoxFit.contain,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              radius: 18,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.person, color: Colors.black54, size: 20),
                onPressed: () {},
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            onPressed: () async {
              await AuthService().logout();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Retailer',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const Text(
              'Welcome, Retailer',
              style: TextStyle(fontSize: 15, color: subtleText),
            ),
            const SizedBox(height: 24),

            // Search Bar
            Container(
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
              child: const TextField(
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: InputBorder.none,
                  hintText: 'Search order',
                  hintStyle: TextStyle(color: subtleText),
                  suffixIcon: Icon(Icons.search, color: subtleText),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 1. Standard Order Card (Purple) - Active
            _buildOrderCard(
              context: context,
              color: purpleCard,
              icon: Icons.description,
              title: 'Create Standard Order',
              subtitle: 'Place a regular order with 48-hour delivery window',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const NewOrderScreen()),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Urgent Order Card (Yellow) - Placeholder
            _buildOrderCard(
              context: context,
              color: yellowCard,
              icon: Icons.access_time_filled,
              title: 'Create Urgent Order',
              subtitle: 'Priority-based urgent requests',
              textColor: textColor, // Yellow needs dark text for contrast
              iconBgColor: Colors.black.withOpacity(0.05),
              onTap: () {
                // TODO: Link to Urgent Order Screen in Sprint 2
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Urgent Orders coming in Sprint 2!'),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // 3. Quick Order Card (Teal) - Placeholder
            _buildOrderCard(
              context: context,
              color: tealCard,
              icon: Icons.inventory,
              title: 'Quick Order',
              subtitle: 'Reorder from your past orders instantly',
              textColor: textColor, // Teal needs dark text for contrast
              iconBgColor: Colors.black.withOpacity(0.05),
              onTap: () {
                // TODO: Link to Quick Order Screen in Sprint 2
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Quick Orders coming in Sprint 2!'),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Order History Section (Expandable style)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => const OrderHistoryScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: purpleCard.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: purpleCard.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Order History',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: purpleCard,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_right,
                      color: purpleCard.withOpacity(0.7),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32), // Bottom padding
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: textColor,
          unselectedItemColor: Colors.grey.shade400,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.menu), label: ''),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 28),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.headset_mic_outlined),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              label: '',
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build the colored action cards cleanly
  Widget _buildOrderCard({
    required BuildContext context,
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color textColor = Colors.white,
    Color iconBgColor = Colors.black12,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: textColor.withOpacity(0.9), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: textColor.withOpacity(0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
