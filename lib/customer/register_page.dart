import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'login_page.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _obscurePassword = true;
  bool _agreeToTerms = false;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneDigitsController = TextEditingController();

  String? _errorText;
  DateTime? _selectedBirthday;

  bool _validateName(String value) {
    // Only letters and spaces, at least 2 characters
    return RegExp(r"^[A-Za-z\s]{2,}$").hasMatch(value);
  }

  bool _validateEmail(String value) {
    // Simple email validation
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value);
  }

  String? _validatePassword(String value) {
    // At least 8 chars, 1 uppercase, 1 lowercase, 1 number, 1 special char
    if (value.length < 8) return "Password must be at least 8 characters";
    if (!RegExp(r'[A-Z]').hasMatch(value))
      return "Add at least 1 uppercase letter";
    if (!RegExp(r'[a-z]').hasMatch(value))
      return "Add at least 1 lowercase letter";
    if (!RegExp(r'\d').hasMatch(value)) return "Add at least 1 number";
    if (!RegExp(
      r'[!@#\$&*~^%\(\)_\-\+=\[\]\{\}\|\\:;\<>,\.\?\/]',
    ).hasMatch(value)) {
      return "Add at least 1 special character";
    }
    return null; // Password is valid
  }

  bool _isValidBirthday(DateTime birthday) {
    final today = DateTime.now();
    final age =
        today.year -
        birthday.year -
        ((today.month < birthday.month ||
                (today.month == birthday.month && today.day < birthday.day))
            ? 1
            : 0);
    return age >= 18;
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final firstAllowed = DateTime(now.year - 100); // 100 years ago
    final lastAllowed = DateTime(now.year - 18, now.month, now.day); // 18+ only
    final picked = await showDatePicker(
      context: context,
      initialDate: lastAllowed,
      firstDate: firstAllowed,
      lastDate: lastAllowed,
      helpText: 'Select your birthday',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            // Hide year selection for years > 2006
            colorScheme: ColorScheme.light(primary: Color(0xFF2C9CD9)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedBirthday = picked);
  }

  Future<bool> _sendOtp(String email) async {
    final resp = await http.post(
      Uri.parse('https://aquafixsansimon.com/api/send_otp.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    );
    if (resp.statusCode == 200) {
      final body = resp.body ?? '';
      if (body.trim().isNotEmpty && !body.trim().startsWith('<')) {
        final result = json.decode(body);
        return result['success'] == true;
      }
    }
    return false;
  }

  Future<bool> _verifyOtp(String email, String otp) async {
    final resp = await http.post(
      Uri.parse('https://aquafixsansimon.com/api/send_otp.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'otp': otp}),
    );
    if (resp.statusCode == 200) {
      final body = resp.body ?? '';
      if (body.trim().isNotEmpty && !body.trim().startsWith('<')) {
        final result = json.decode(body);
        return result['success'] == true;
      }
    }
    return false;
  }

  Future<bool> _showOtpModal(String email) async {
    final otpControllers = List.generate(6, (_) => TextEditingController());
    final focusNodes = List.generate(6, (_) => FocusNode());
    bool verified = false;
    bool sending = false;
    String? error;
    String? info;
    int resendSeconds = 30;
    bool canResend = false;
    bool cancelled = false;

    void startResendTimer(StateSetter setState) {
      resendSeconds = 30;
      canResend = false;
      setState(() {});
      Future.doWhile(() async {
        await Future.delayed(const Duration(seconds: 1));
        if (resendSeconds > 0) {
          resendSeconds--;
          setState(() {});
          return true;
        } else {
          canResend = true;
          setState(() {});
          return false;
        }
      });
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (resendSeconds == 30 && !canResend) {
              startResendTimer(setState);
            }
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              insetPadding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: 24.h,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.grey[600],
                            size: 24.sp,
                          ),
                          onPressed: () {
                            cancelled = true;
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                    Icon(
                      Icons.mark_email_unread_rounded,
                      color: Color(0xFF2C9CD9),
                      size: 48.sp,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Verify Your Email',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20.sp,
                        color: Color(0xFF2C9CD9),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Enter the 6-digit code sent to',
                      style: TextStyle(fontSize: 15.sp, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Color(0xFF2C9CD9),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 18.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (i) {
                        return Container(
                          width: 40.w,
                          margin: EdgeInsets.symmetric(horizontal: 4.w),
                          child: TextField(
                            controller: otpControllers[i],
                            focusNode: focusNodes[i],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: BorderSide(
                                  color: Color(0xFF2C9CD9),
                                  width: 1.5,
                                ),
                              ),
                              filled: true,
                              fillColor: Color(0xFFF5F8FA),
                            ),
                            onChanged: (val) {
                              if (val.length == 1 && i < 5) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(focusNodes[i + 1]);
                              }
                              if (val.isEmpty && i > 0) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(focusNodes[i - 1]);
                              }
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 12.h),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(color: Colors.red, fontSize: 13.sp),
                      ),
                    if (info != null)
                      Text(
                        info!,
                        style: TextStyle(color: Colors.green, fontSize: 13.sp),
                      ),
                    SizedBox(height: 10.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't get the code?",
                          style: TextStyle(fontSize: 13.sp),
                        ),
                        SizedBox(width: 6.w),
                        TextButton(
                          onPressed:
                              canResend && !sending
                                  ? () async {
                                    setState(() => sending = true);
                                    final ok = await _sendOtp(email);
                                    setState(() {
                                      sending = false;
                                      info =
                                          ok
                                              ? "OTP resent!"
                                              : "Failed to resend OTP.";
                                      error = null;
                                    });
                                    startResendTimer(setState);
                                  }
                                  : null,
                          child: Text(
                            canResend ? "Resend" : "Resend (${resendSeconds}s)",
                            style: TextStyle(
                              color:
                                  canResend ? Color(0xFF2C9CD9) : Colors.grey,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 18.h),
                    SizedBox(
                      width: double.infinity,
                      height: 44.h,
                      child: ElevatedButton(
                        onPressed:
                            sending
                                ? null
                                : () async {
                                  setState(() {
                                    sending = true;
                                    error = null;
                                    info = null;
                                  });
                                  final otp =
                                      otpControllers.map((c) => c.text).join();
                                  if (otp.length != 6) {
                                    setState(() {
                                      error = "Enter all 6 digits.";
                                      sending = false;
                                    });
                                    return;
                                  }
                                  final ok = await _verifyOtp(email, otp);
                                  setState(() => sending = false);
                                  if (ok) {
                                    verified = true;
                                    Navigator.of(context).pop();
                                  } else {
                                    setState(
                                      () => error = "Invalid OTP. Try again.",
                                    );
                                  }
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2C9CD9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.r),
                          ),
                        ),
                        child:
                            sending
                                ? SizedBox(
                                  width: 22.sp,
                                  height: 22.sp,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                                : Text(
                                  'Verify',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15.sp,
                                    color: Colors.white,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    // If cancelled, return false so registration is not completed
    return verified && !cancelled;
  }

  // Capitalize each word in a name
  String _capitalizeWords(String input) {
    return input
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              word[0].toUpperCase() +
              (word.length > 1 ? word.substring(1).toLowerCase() : ''),
        )
        .join(' ');
  }

  String? _validatePhone(String value) {
    // Must be exactly 10 digits
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return "Phone number must be 10 digits";
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Phone number controller logic: always keep "+63 " prefix
    String? _prevPhoneText;
    _phoneDigitsController.addListener(() {
      final oldText = _phoneDigitsController.text;
      final digits = oldText.replaceAll(RegExp(r'\D'), '');
      String formatted = digits;
      if (digits.length > 10) formatted = digits.substring(0, 10);
      if (formatted != digits) {
        _phoneDigitsController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
      _prevPhoneText = formatted;
    });
  }

  void _register() async {
    setState(() => _errorText = null);

    // Birthday validation
    if (_selectedBirthday == null) {
      setState(() => _errorText = "Birthday is required.");
      return;
    }
    if (!_isValidBirthday(_selectedBirthday!)) {
      setState(() => _errorText = "You must be at least 18 years old.");
      return;
    }

    // Phone validation
    final phoneDigits = _phoneDigitsController.text.trim();
    final phoneError = _validatePhone(phoneDigits);
    if (phoneError != null) {
      setState(() => _errorText = phoneError);
      return;
    }
    final phoneFull = "+63 $phoneDigits";

    if (!_agreeToTerms) return;
    if (!_validateName(_firstNameController.text.trim())) {
      setState(
        () => _errorText = "First name must only contain letters and spaces.",
      );
      return;
    }
    if (!_validateName(_lastNameController.text.trim())) {
      setState(
        () => _errorText = "Last name must only contain letters and spaces.",
      );
      return;
    }
    if (!_validateEmail(_emailController.text.trim())) {
      setState(() => _errorText = "Enter a valid email address.");
      return;
    }
    final passwordError = _validatePassword(_passwordController.text.trim());
    if (passwordError != null) {
      setState(() => _errorText = passwordError);
      return;
    }

    // Get and format names
    final firstNameRaw = _firstNameController.text.trim();
    final lastNameRaw = _lastNameController.text.trim();
    final firstName = _capitalizeWords(
      firstNameRaw,
    ).substring(0, firstNameRaw.length > 35 ? 35 : firstNameRaw.length);
    final lastName = _capitalizeWords(
      lastNameRaw,
    ).substring(0, lastNameRaw.length > 35 ? 35 : lastNameRaw.length);

    // Check if username already exists (robust)
    final String usernameInput = _usernameController.text.trim();
    bool usernameExists = false;
    if (usernameInput.isNotEmpty) {
      try {
        final resp = await http.get(
          Uri.parse(
            'https://aquafixsansimon.com/api/customers.php?username=${Uri.encodeComponent(usernameInput)}',
          ),
        );
        if (resp.statusCode == 200) {
          final body = resp.body ?? '';
          if (body.trim().isNotEmpty && !body.trim().startsWith('<')) {
            final decoded = json.decode(body);
            if (decoded is List) {
              usernameExists = decoded.any(
                (u) =>
                    (u?['username'] ?? '').toString().toLowerCase() ==
                    usernameInput.toLowerCase(),
              );
            } else if (decoded is Map) {
              final possibleUsername =
                  (decoded['username'] ?? '').toString().toLowerCase();
              usernameExists = possibleUsername == usernameInput.toLowerCase();
            }
          } else {
            usernameExists = false;
          }
        }
      } catch (_) {
        usernameExists = false; // don't block on ambiguous failure
      }
    }

    if (usernameExists) {
      setState(() {
        _errorText = "Username already exists. Please choose another.";
      });
      return;
    }

    // Check if email already exists (robust)
    final String emailInput = _emailController.text.trim().toLowerCase();
    bool emailExists = false;
    try {
      final resp = await http.get(
        Uri.parse(
          'https://aquafixsansimon.com/api/customers.php?email=${Uri.encodeComponent(emailInput)}',
        ),
      );
      if (resp.statusCode == 200) {
        final body = resp.body ?? '';
        // If server returned HTML (error page) or non-JSON, do not block registration
        if (body.trim().isNotEmpty && !body.trim().startsWith('<')) {
          final decoded = json.decode(body);
          if (decoded is List) {
            emailExists = decoded.any(
              (u) => (u?['email'] ?? '').toString().toLowerCase() == emailInput,
            );
          } else if (decoded is Map) {
            final possibleEmail =
                (decoded['email'] ?? decoded['email_address'] ?? '')
                    .toString()
                    .toLowerCase();
            emailExists = possibleEmail == emailInput;
          }
        } else {
          // Non-JSON response (HTML/error) — treat as not existing to avoid false positive
          emailExists = false;
        }
      }
    } catch (e) {
      // Network / decoding error — do not block registration on ambiguous failure
      emailExists = false;
    }

    if (emailExists) {
      setState(() {
        _errorText = "Email already exists. Please use another one.";
      });
      return;
    }

    // Show loading dialog before sending OTP (step 1)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 8),
                  Text(
                    'Sending OTP',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 24),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          strokeWidth: 7,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF2C9CD9),
                          ),
                        ),
                      ),
                      // Show step number "1" for OTP
                      Text(
                        '1',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C9CD9),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Please wait while we send your OTP...',
                      style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),
          ),
    );

    // Send OTP before registration
    final emailForOtp = _emailController.text.trim();
    final otpSent = await _sendOtp(emailForOtp);

    // Hide loading dialog after sending OTP
    Navigator.of(context, rootNavigator: true).pop();

    if (!otpSent) {
      setState(() {
        _errorText =
            "Failed to send OTP. Please check your email and try again.";
      });
      return;
    }
    final verified = await _showOtpModal(emailForOtp);
    if (!verified) {
      setState(() => _errorText = "Email verification failed.");
      return;
    }

    // Show circular progress bar modal for registration (step 2)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 8),
                  Text(
                    'Registering Account',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 24),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          strokeWidth: 7,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF2C9CD9),
                          ),
                        ),
                      ),
                      // Show step number "2" for registration
                      Text(
                        '2',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C9CD9),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Please wait while we process your registration...',
                      style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),
          ),
    );

    // Prepare data for backend (send all required fields)
    final data = {
      "username": _usernameController.text.trim().substring(
        0,
        _usernameController.text.trim().length > 15
            ? 15
            : _usernameController.text.trim().length,
      ),
      "password": _passwordController.text.trim().substring(
        0,
        _passwordController.text.trim().length > 25
            ? 25
            : _passwordController.text.trim().length,
      ),
      "email": _emailController.text.trim().substring(
        0,
        _emailController.text.trim().length > 30
            ? 30
            : _emailController.text.trim().length,
      ),
      "first_name": firstName,
      "last_name": lastName,
      "aquafix_no": "",
      "contact_no": phoneFull,
      "birthday":
          _selectedBirthday != null
              ? DateFormat('yyyy-MM-dd').format(_selectedBirthday!)
              : "",
      "gender": "",
      "profile_image": "default.jpg",
    };

    final response = await http.post(
      Uri.parse('https://aquafixsansimon.com/api/customers.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );

    Navigator.of(context, rootNavigator: true).pop(); // Hide progress modal

    if (response.statusCode == 200) {
      // Show success message before navigating
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account created and verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 1200));

        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 700),
            pageBuilder: (_, __, ___) => const LoginPage(),
            transitionsBuilder: (context, animation, _, child) {
              final curvedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              );
              return FadeTransition(opacity: curvedAnimation, child: child);
            },
          ),
        );
      }
    } else {
      setState(() {
        _errorText = "Registration failed. Please try again.";
      });
    }
  }

  void _showTermsModal() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Terms & Conditions",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18.sp,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 22.sp),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      "Welcome to AquaFix!\n\n"
                      "By using this app, you agree to the following terms:\n"
                      "• Use the app for lawful purposes only.\n"
                      "• Do not misuse or attempt to disrupt our services.\n"
                      "• We reserve the right to update these terms at any time.\n\n"
                      "For the full terms, please visit our website or contact support.",
                      style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                    ),
                    SizedBox(height: 18.h),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D9FD0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          "Close",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                          ),
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

  void _showPrivacyModal() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Privacy Policy",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18.sp,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 22.sp),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      "Your privacy is important to us.\n\n"
                      "• We collect only necessary information to provide our services.\n"
                      "• Your data is stored securely and not shared with third parties except as required by law.\n"
                      "• You may request deletion of your data at any time.\n\n"
                      "For more details, please contact our support team.",
                      style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                    ),
                    SizedBox(height: 18.h),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D9FD0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          "Close",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Back button at top-left with padding
            Padding(
              padding: EdgeInsets.only(left: 8.w),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: const Color.fromRGBO(2, 73, 154, 1),
                    size: 24.sp,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 700),
                        pageBuilder: (_, __, ___) => const LoginPage(),
                        transitionsBuilder: (
                          context,
                          animation,
                          secondaryAnimation,
                          child,
                        ) {
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
                ),
              ),
            ),

            // Expanded scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo & Title
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
                              'Create an ',
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
                    SizedBox(height: 20.h),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _firstNameController,
                            hintText: 'First Name',
                            icon: Icons.person_outline,
                            keyboardType: TextInputType.name,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z\s]'),
                              ),
                            ],
                            maxLength: 35,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildTextField(
                            controller: _lastNameController,
                            hintText: 'Last Name',
                            icon: Icons.person_outline,
                            keyboardType: TextInputType.name,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z\s]'),
                              ),
                            ],
                            maxLength: 35,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    // Email Address Field
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'Email Address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 45,
                    ),
                    SizedBox(height: 12.h),

                    // Birthday field
                    GestureDetector(
                      onTap: _pickBirthday,
                      child: AbsorbPointer(
                        child: TextField(
                          readOnly: true,
                          controller: TextEditingController(
                            text:
                                _selectedBirthday != null
                                    ? DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(_selectedBirthday!)
                                    : '',
                          ),
                          style: TextStyle(fontSize: 15.sp),
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.cake_outlined, size: 20.sp),
                            hintText: 'Birthday',
                            filled: true,
                            fillColor: const Color.fromARGB(255, 245, 245, 245),
                            contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: Icon(Icons.calendar_today, size: 16.sp),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Phone number field (+63 fixed, styled like other textfields)
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 14.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 245, 245, 245),
                            borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(12.r),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "+63",
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _phoneDigitsController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(10),
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: TextStyle(fontSize: 15.sp),
                            decoration: InputDecoration(
                              hintText: "Phone Number",
                              filled: true,
                              fillColor: const Color.fromARGB(
                                255,
                                245,
                                245,
                                245,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 8.h,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.horizontal(
                                  right: Radius.circular(12.r),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              counterText: '',
                              errorText:
                                  _errorText != null &&
                                          (_errorText!.contains('Phone number'))
                                      ? _errorText
                                      : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    _buildTextField(
                      controller: _usernameController,
                      hintText: 'Username',
                      icon: Icons.person_3_outlined,
                      maxLength: 15,
                    ),
                    SizedBox(height: 12.h),

                    // Password field
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(fontSize: 15.sp),
                      inputFormatters: [LengthLimitingTextInputFormatter(25)],
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
                        counterText: '',
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
                    if (_errorText != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8.h),
                        child: Text(
                          _errorText!,
                          style: TextStyle(color: Colors.red, fontSize: 13.sp),
                        ),
                      ),

                    if (_errorText != null &&
                        (_errorText!.contains('Birthday') ||
                            _errorText!.contains('18 years')))
                      Padding(
                        padding: EdgeInsets.only(top: 8.h),
                        child: Text(
                          _errorText!,
                          style: TextStyle(color: Colors.red, fontSize: 13.sp),
                        ),
                      ),
                    // Terms and checkbox
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.9,
                          child: Checkbox(
                            value: _agreeToTerms,
                            onChanged: (value) {
                              setState(() {
                                _agreeToTerms = value ?? false;
                              });
                            },
                            activeColor: const Color(0xFF2C9CD9),
                          ),
                        ),
                        Expanded(
                          child: Wrap(
                            children: [
                              Text(
                                'By clicking, you agree to our ',
                                style: TextStyle(fontSize: 13.sp),
                              ),
                              GestureDetector(
                                onTap: _showTermsModal,
                                child: Text(
                                  'Terms of Service',
                                  style: TextStyle(
                                    color: const Color(0xFF2C9CD9),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.sp,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              Text(' and ', style: TextStyle(fontSize: 13.sp)),
                              GestureDetector(
                                onTap: _showPrivacyModal,
                                child: Text(
                                  'Privacy Policy',
                                  style: TextStyle(
                                    color: const Color(0xFF2C9CD9),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.sp,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // Register button
                    SizedBox(
                      width: double.infinity,
                      height: 44.h,
                      child: ElevatedButton(
                        onPressed: _agreeToTerms ? _register : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C9CD9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.r),
                          ),
                        ),
                        child: Text(
                          'Register',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: [
        ...?inputFormatters,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      style: TextStyle(fontSize: 15.sp),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 20.sp),
        hintText: hintText,
        filled: true,
        fillColor: const Color.fromARGB(255, 245, 245, 245),
        contentPadding: EdgeInsets.fromLTRB(0, 8.h, 8.w, 8.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        counterText: '', // Hide counter
      ),
    );
  }
}
