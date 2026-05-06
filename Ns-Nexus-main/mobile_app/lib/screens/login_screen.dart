import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'retailer_screen.dart';
import 'warehouse_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLocked = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    if (_isLocked) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter both email and password';
          _isLoading = false;
        });
        return;
      }

      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
      if (!emailRegex.hasMatch(email)) {
        setState(() {
          _errorMessage = 'Please enter a valid email address';
          _isLoading = false;
        });
        return;
      }

      final response = await _authService.login(email, password);

      if (!mounted) return;

      final user = response['user'];
      final role = user['role'];

      if (role == 'retailer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RetailerScreen()),
        );
      } else if (role == 'warehouse_manager') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WarehouseScreen()),
        );
      } else {
        setState(() {
          _errorMessage = 'Unknown role: $role';
        });
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        if (e.statusCode == 403) {
          _isLocked = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Brand Colors
    const Color brandBlue = Color(0xFF0056B3);
    const Color bgColor = Color(0xFFF5F7FA);
    const Color textColor = Color(0xFF1E293B);
    const Color subtleText = Color(0xFF64748B);

    // Tinted light blue for the input fields for better contrast
    const Color inputFillColor = Color(0xFFE6EFFF);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Logo Section (Using Actual Image Asset)
                Center(
                  child: Image.asset(
                    'assets/images/nestle_logo.png',
                    height:
                        80, // Adjust height if needed to match mockup perfectly
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 48),

                // 2. Title
                const Text(
                  'Sign In to Your Account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // 3. Email Input
                const Text(
                  'Email',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'yourmail@gmail.com',
                    hintStyle: const TextStyle(color: subtleText),
                    filled: true,
                    fillColor: inputFillColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 4. Password Input
                const Text(
                  'Password',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'your password',
                    hintStyle: const TextStyle(color: subtleText),
                    filled: true,
                    fillColor: inputFillColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Remember Me / Forgot Password Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: false,
                            onChanged: (value) {},
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Remember me',
                          style: TextStyle(color: subtleText),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Forgot Password',
                        style: TextStyle(
                          color: brandBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 6. Error Message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // 7. Sign In Button
                ElevatedButton(
                  onPressed: (_isLoading || _isLocked) ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: brandBlue.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
