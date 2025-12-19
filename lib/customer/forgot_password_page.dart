import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'verify_otp_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;
  String? _infoText;

  Future<void> _sendOtp() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
      _infoText = null;
    });

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorText = "Please enter your email address.";
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://aquafixsansimon.com/api/forgot_password.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      final result = json.decode(response.body);

      if (response.statusCode == 200 && result['success'] == true) {
        setState(() {
          _infoText = "OTP sent to your email.";
        });
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => VerifyOtpPage(email: email)),
        );
      } else {
        setState(() {
          _errorText = result['message'] ?? "Failed to send OTP.";
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C9CD9),
        title: Text(
          "Forgot Password",
          style: TextStyle(fontSize: 18.sp, color: Colors.white),
        ),
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_reset, size: 64.sp, color: const Color(0xFF2C9CD9)),
            SizedBox(height: 24.h),
            Text(
              "Enter your email address to receive an OTP.",
              style: TextStyle(fontSize: 16.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email_outlined),
                hintText: "Email Address",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                filled: true,
                fillColor: const Color.fromARGB(255, 245, 245, 245),
              ),
            ),
            SizedBox(height: 16.h),
            if (_errorText != null)
              Text(
                _errorText!,
                style: TextStyle(color: Colors.red, fontSize: 13.sp),
              ),
            if (_infoText != null)
              Text(
                _infoText!,
                style: TextStyle(color: Colors.green, fontSize: 13.sp),
              ),
            SizedBox(height: 22.h),
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C9CD9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.r),
                  ),
                  elevation: 2,
                ),
                child:
                    _isLoading
                        ? SizedBox(
                          width: 22.sp,
                          height: 22.sp,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                        : Text(
                          "Send OTP",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16.sp,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10.h),
            Text(
              "Can't recover your password?",
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6.h),
            Text(
              "Contact our support team for assistance.",
              style: TextStyle(fontSize: 13.sp, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10.h),
            GestureDetector(
              onTap: () async {
                final Uri emailUri = Uri(
                  scheme: 'mailto',
                  path: 'support@aquafixsansimon.com',
                  query: 'subject=Password Recovery Assistance',
                );
                try {
                  await launchUrl(
                    emailUri,
                    mode: LaunchMode.externalApplication,
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not open email app.')),
                  );
                }
              },
              child: Text(
                "Email Support",
                style: TextStyle(
                  color: const Color(0xFF2C9CD9),
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
