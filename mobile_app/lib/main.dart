import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/retailer_screen.dart';
import 'screens/warehouse_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool hasToken = prefs.containsKey('sessionToken');
  final String? role = prefs.getString('role');

  runApp(MyApp(hasToken: hasToken, role: role));
}

class MyApp extends StatelessWidget {
  final bool hasToken;
  final String? role;

  const MyApp({super.key, required this.hasToken, this.role});

  @override
  Widget build(BuildContext context) {
    Widget homeScreen;
    if (hasToken && role == 'retailer') {
      homeScreen = const RetailerScreen();
    } else if (hasToken && role == 'warehouse_manager') {
      homeScreen = const WarehouseScreen();
    } else {
      homeScreen = const LoginScreen();
    }

    return MaterialApp(
      title: 'Flutter Login Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: homeScreen,
    );
  }
}
