import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _twoFactorEnabled = false;
  bool _loginNotifEnabled = true;

  InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 14.sp),
      hintStyle: TextStyle(fontSize: 14.sp),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      suffixIcon: suffixIcon,
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 8.h, top: 18.h),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Future<void> _saveSecurityChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';

    // Only send fields that are being updated
    final data = {
      "customer_id": customerId,
      "email": _emailController.text.trim(),
    };

    // Only include password fields if user wants to change password
    if (_currentPasswordController.text.trim().isNotEmpty &&
        _newPasswordController.text.trim().isNotEmpty) {
      data["current_password"] = _currentPasswordController.text.trim();
      data["new_password"] = _newPasswordController.text.trim();
    }

    final response = await http.put(
      Uri.parse(
        'https://aquafixsansimon.com/api/customers.php?action=security',
      ),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Security settings updated!')),
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } else {
      String msg = "Failed to update security settings.";
      try {
        final res = json.decode(response.body);
        if (res['error'] != null) msg = res['error'];
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    if (customerId.isEmpty) return;

    final response = await http.get(
      Uri.parse('https://aquafixsansimon.com/api/customers.php'),
    );
    if (response.statusCode == 200) {
      final List users = json.decode(response.body);
      final user = users.firstWhere(
        (u) => u['customer_id'].toString() == customerId,
        orElse: () => null,
      );
      if (user != null && user['email'] != null) {
        setState(() {
          _emailController.text = user['email'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C9CD9),
        title: Text(
          'Security',
          style: TextStyle(
            fontSize: 16.sp,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 22.sp, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Scrollbar(
        thumbVisibility: true,
        thickness: 6.w,
        radius: Radius.circular(10.r),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 2.w, 20.w, 20.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Change Email
                _sectionTitle("Change Email"),
                TextFormField(
                  controller: _emailController,
                  style: TextStyle(fontSize: 14.sp),
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('Email'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),

                // Change Password
                _sectionTitle("Change Password"),
                TextFormField(
                  controller: _currentPasswordController,
                  style: TextStyle(fontSize: 14.sp),
                  obscureText: _obscureCurrent,
                  decoration: _inputDecoration(
                    'Current Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20.sp,
                      ),
                      onPressed: () {
                        setState(() => _obscureCurrent = !_obscureCurrent);
                      },
                    ),
                  ),
                  validator: (value) {
                    // Only require if new password is being set
                    if (_newPasswordController.text.trim().isNotEmpty &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Current password is required to change password';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _newPasswordController,
                  style: TextStyle(fontSize: 14.sp),
                  obscureText: _obscureNew,
                  decoration: _inputDecoration(
                    'New Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew ? Icons.visibility_off : Icons.visibility,
                        size: 20.sp,
                      ),
                      onPressed: () {
                        setState(() => _obscureNew = !_obscureNew);
                      },
                    ),
                  ),
                  validator: (value) {
                    // Only require if current password is being set
                    if (_currentPasswordController.text.trim().isNotEmpty &&
                        (value == null || value.trim().isEmpty)) {
                      return 'New password is required';
                    }
                    if (value != null && value.isNotEmpty && value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _confirmPasswordController,
                  style: TextStyle(fontSize: 14.sp),
                  obscureText: _obscureConfirm,
                  decoration: _inputDecoration(
                    'Confirm New Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20.sp,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                    ),
                  ),
                  validator: (value) {
                    // Only require if new password is being set
                    if (_newPasswordController.text.trim().isNotEmpty &&
                        value != _newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                // Additional Settings
                _sectionTitle("Additional Security Settings"),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Enable Two-Factor Authentication for Secure Login',
                    style: TextStyle(fontSize: 14.sp),
                  ),
                  value: _twoFactorEnabled,
                  onChanged: (value) {
                    setState(() {
                      _twoFactorEnabled = value;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Login Notifications',
                    style: TextStyle(fontSize: 14.sp),
                  ),
                  value: _loginNotifEnabled,
                  onChanged: (value) {
                    setState(() {
                      _loginNotifEnabled = value;
                    });
                  },
                ),

                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 30.h),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saveSecurityChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C9CD9),
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'SAVE CHANGES',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
