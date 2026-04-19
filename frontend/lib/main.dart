import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/retailer_screen.dart';
import 'screens/warehouse_screen.dart';
import 'screens/place_order_screen.dart';
import 'screens/my_orders_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NS Nexus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A73E8)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/warehouse': (context) => const WarehouseScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/retailer') {
          final user = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => RetailerScreen(user: user),
          );
        }
        if (settings.name == '/place-order') {
          final user = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => PlaceOrderScreen(user: user),
          );
        }
        if (settings.name == '/my-orders') {
          final user = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => MyOrdersScreen(user: user),
          );
        }
        return null;
      },
    );
  }
}
