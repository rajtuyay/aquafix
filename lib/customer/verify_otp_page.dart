import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

class VerifyOtpPage extends StatefulWidget {
  final String email;
  const VerifyOtpPage({super.key, required this.email});

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final TextEditingController _newPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;
  String? _infoText;
  bool _otpVerified = false;

  // Add password visibility state
  bool _obscureNewPassword = true;

  String get _otp => _otpControllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
      _infoText = null;
    });

    final otp = _otp;
    if (otp.length != 6) {
      setState(() {
        _errorText = "Please enter the 6-digit OTP.";
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://aquafixsansimon.com/api/verify_otp.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': widget.email, 'otp': otp}),
      );
      final result = json.decode(response.body);

      if (response.statusCode == 200 && result['success'] == true) {
        setState(() {
          _infoText = "OTP verified. Please enter your new password.";
          _otpVerified = true;
        });
      } else {
        setState(() {
          _errorText = result['message'] ?? "Invalid OTP.";
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

  Future<void> _resetPassword() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
      _infoText = null;
    });

    final otp = _otp;
    final newPassword = _newPasswordController.text.trim();

    // Strong password validation
    final passwordRegex = RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$&*~]).{8,}$');
    if (!passwordRegex.hasMatch(newPassword)) {
      setState(() {
        _errorText =
            "Password must be at least 8 characters, include 1 uppercase letter, 1 number, and 1 special character.";
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://aquafixsansimon.com/api/verify_otp.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.email,
          'otp': otp,
          'new_password': newPassword,
        }),
      );
      final result = json.decode(response.body);

      if (response.statusCode == 200 && result['success'] == true) {
        setState(() {
          _infoText = "Password updated successfully. You may now log in.";
        });
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        });
      } else {
        setState(() {
          _errorText = result['message'] ?? "Failed to reset password.";
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

  Widget _buildOtpFields() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        return Container(
          width: 40.w,
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          child: TextField(
            controller: _otpControllers[i],
            focusNode: _focusNodes[i],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              filled: true,
              fillColor: const Color.fromARGB(255, 245, 245, 245),
              hintText: '${i + 1}',
              hintStyle: TextStyle(color: Colors.grey[400]), // Light grey hint
            ),
            enabled: !_otpVerified,
            onChanged: (val) {
              if (val.length == 1 && i < 5) {
                FocusScope.of(context).requestFocus(_focusNodes[i + 1]);
              }
              if (val.isEmpty && i > 0) {
                FocusScope.of(context).requestFocus(_focusNodes[i - 1]);
              }
            },
            inputFormatters: [
              // Only allow numbers
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C9CD9),
        title: Text(
          "OTP Verification",
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
            Icon(
              Icons.verified_user,
              size: 64.sp,
              color: const Color(0xFF2C9CD9),
            ),
            SizedBox(height: 24.h),
            Text(
              _otpVerified
                  ? "Enter your new password."
                  : "Enter the 6-digit OTP sent to your email.",
              style: TextStyle(fontSize: 16.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            _buildOtpFields(),
            if (_otpVerified) ...[
              SizedBox(height: 16.h),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock),
                  hintText: "New Password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 245, 245, 245),
                  // Add show/hide password icon
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                  ),
                ),
              ),
            ],
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
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              height: 44.h,
              child: ElevatedButton(
                onPressed:
                    _isLoading
                        ? null
                        : _otpVerified
                        ? _resetPassword
                        : _verifyOtp,
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
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                        : Text(
                          _otpVerified ? "Reset Password" : "Verify OTP",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
