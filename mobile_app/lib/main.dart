import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/retailer_screen.dart';
import 'screens/warehouse_screen.dart';
import 'screens/admin_user_management_screen.dart';

/// Entry point of the NS Nexus application.
/// Reads the persisted session token and role from SharedPreferences
/// to decide which home screen to show on launch.
void main() async {
  // Must be called before any platform plugin (SharedPreferences) is used
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Check if a session token was saved from a previous login
  final bool hasToken = prefs.containsKey('sessionToken');

  // Retrieve the stored role to route to the correct home screen
  final String? role = prefs.getString('role');

  runApp(MyApp(hasToken: hasToken, role: role));
}

/// Root widget. Routes to the correct screen based on session state and role.
class MyApp extends StatelessWidget {
  final bool hasToken;
  final String? role;

  const MyApp({super.key, required this.hasToken, this.role});

  @override
  Widget build(BuildContext context) {
    // Determine home screen based on saved role.
    // If no token or unrecognised role → LoginScreen.
    // Driver and 3PL Manager home screens are defined inside LoginScreen
    // and are navigated to after login — they don't need a restore route
    // here because they are stateful and always re-fetch data on open.
    Widget homeScreen;
    if (hasToken && role == 'retailer') {
      homeScreen = const RetailerScreen();
    } else if (hasToken && role == 'warehouse_manager') {
      homeScreen = const WarehouseScreen();
    } else if (hasToken && role == 'admin') {
      homeScreen = const AdminUserManagementScreen();
    } else {
      // Covers: no token, driver, 3pl_manager, or any unknown role
      // Driver and 3PL screens are always reached via login for fresh data
      homeScreen = const LoginScreen();
    }

    return MaterialApp(
      title: 'NS Nexus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0056B3)),
        useMaterial3: true,
      ),
      home: homeScreen,
    );
  }
}
