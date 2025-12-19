import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'register_page.dart';
import '../plumber/task_page.dart';
import 'home_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'forgot_password_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorText;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    FirebaseMessaging.instance.getToken().then((token) {
      print('FCM Token: $token');
    });
  }

  Future<void> _registerFcmTokenAfterLogin(
    String userType,
    String userId,
  ) async {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await http.post(
        Uri.parse('https://aquafixsansimon.com/api/save_fcm_token.php'),
        body: {'user_type': userType, 'user_id': userId, 'fcm_token': fcmToken},
      );
    }
  }

  Future<void> _login() async {
    setState(() {
      _errorText = null;
      _isLoading = true;
    });
    final input = _usernameController.text.trim();
    final data = {
      "username": input,
      "email": input,
      "password": _passwordController.text.trim(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customer_id');
    await prefs.remove('plumber_id');
    try {
      // Try customer login first
      final customerResponse = await http.post(
        Uri.parse('https://aquafixsansimon.com/api/customers.php?action=login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      print(
        'Customer login response: ${customerResponse.statusCode} ${customerResponse.body}',
      ); // DEBUG
      if (customerResponse.statusCode == 200) {
        final result = json.decode(customerResponse.body);
        final user = result['user'];
        if (user != null && user['customer_id'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('customer_id', user['customer_id'].toString());
          // Register FCM token for customer
          await _registerFcmTokenAfterLogin(
            'customer',
            user['customer_id'].toString(),
          );

          // Check if tutorial flags exist in Firebase, if not, create them
          final customerId = user['customer_id'].toString();
          final dbRef = FirebaseDatabase.instance.ref('tutorials/$customerId');
          final snapshot = await dbRef.get();
          if (!snapshot.exists) {
            await dbRef.set({
              "home": true,
              "plumber": true,
              "jo_request": true,
              "water_analysis": true,
            });
          }

          // Go to customer home page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage(currentIndex: 0)),
          );
          return;
        }
      }

      // If not found in customers, try plumber login
      final plumberResponse = await http.post(
        Uri.parse('https://aquafixsansimon.com/api/plumbers.php?action=login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      print(
        'Plumber login response: ${plumberResponse.statusCode} ${plumberResponse.body}',
      ); // DEBUG
      if (plumberResponse.statusCode == 200) {
        final result = json.decode(plumberResponse.body);
        final user = result['user'];
        final requirePasswordChange = result['require_password_change'] == true;
        if (user != null && user['plumber_id'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('plumber_id', user['plumber_id'].toString());
          // Register FCM token for plumber
          await _registerFcmTokenAfterLogin(
            'plumber',
            user['plumber_id'].toString(),
          );
          // Go to plumber task page, pass requirePasswordChange
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (context) => TaskPage(
                    currentIndex: 0,
                    requirePasswordChange: requirePasswordChange,
                    plumberId: user['plumber_id'].toString(),
                  ),
            ),
          );
          return;
        }
      } else if (plumberResponse.statusCode == 403) {
        // Deactivated account
        setState(() {
          _errorText = "Your account is deactivated. Please contact support.";
        });
        return;
      }

      // If both fail, show error
      setState(() {
        _errorText = "Invalid credentials. Please try again.";
      });
    } catch (e) {
      setState(() {
        _errorText = "Network error. Please try again.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _goToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Hero(
                  tag: 'logoHero',
                  child: Image.asset(
                    'assets/logo.png',
                    width: 150.w,
                    height: 150.h,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Hero(
                      tag: 'heroTitleMain',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          'Log to your ',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cambria',
                            color: Color.fromRGBO(2, 73, 154, 1),
                          ),
                        ),
                      ),
                    ),
                    Hero(
                      tag: 'heroTitleAccount',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          'Account',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cambria',
                            color: Color.fromRGBO(2, 73, 154, 1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32.h),

                // Username Field
                TextField(
                  controller: _usernameController,
                  style: TextStyle(fontSize: 15.sp),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.person_3_outlined, size: 20.sp),
                    hintText: 'Username or Email',
                    filled: true,
                    fillColor: const Color.fromARGB(255, 245, 245, 245),
                    contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                // Password Field with Eye Icon
                TextField(
                  controller: _passwordController,
                  style: TextStyle(fontSize: 15.sp),
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.lock_outline, size: 20.sp),
                    hintText: 'Password',
                    filled: true,
                    fillColor: const Color.fromARGB(255, 245, 245, 245),
                    contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                        size: 20.sp,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),

                // Forgot Password Link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _goToForgotPassword,
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: const Color(0xFF2C9CD9),
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ),

                if (_errorText != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        _errorText!,
                        style: TextStyle(color: Colors.red, fontSize: 13.sp),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                SizedBox(height: 12.h),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C9CD9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.r),
                      ),
                    ),
                    child:
                        _isLoading
                            ? SizedBox(
                              width: 22.sp,
                              height: 22.sp,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                            : Text(
                              'Login',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15.sp,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),

                SizedBox(height: 16.h),

                // Sign Up Prompt
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?  ",
                      style: TextStyle(fontSize: 14.sp),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            transitionDuration: const Duration(
                              milliseconds: 700,
                            ),
                            pageBuilder: (_, __, ___) => const RegisterPage(),
                            transitionsBuilder: (context, animation, _, child) {
                              final curvedAnimation = CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeInOut,
                              );
                              return FadeTransition(
                                opacity: curvedAnimation,
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          color: const Color(0xFF2C9CD9),
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
