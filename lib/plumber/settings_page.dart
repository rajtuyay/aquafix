import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

// Import the target pages
import 'edit_profile_page.dart';
import 'security_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _availabilityEnabled = true;
  String _status = 'Available';
  bool _notifEnabled = true;
  bool _newsletterSubscribed = false;
  bool _locationAccess = false;
  String? _plumberId;
  bool _isLoading = true; // Add loading state

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final plumberId = prefs.getString('plumber_id');
    bool availabilityEnabled = true;
    String status = 'Available';

    // Load from Firebase if plumberId exists
    if (plumberId != null && plumberId.isNotEmpty) {
      try {
        final databaseRef = FirebaseDatabase.instance.ref();
        // Fetch each value individually from the new structure
        final availSnap =
            await databaseRef
                .child('settings')
                .child('plumbers')
                .child(plumberId)
                .child('availability_status')
                .get();
        if (availSnap.exists) {
          final avail = availSnap.value;
          if (avail == 'Not Available') {
            availabilityEnabled = false;
            status = 'Not Available';
          } else {
            availabilityEnabled = true;
            status = 'Available';
          }
        }
        // Optionally, you can load other settings here if you want to sync from Firebase
      } catch (e) {
        print('Firebase load error: $e');
      }
    }

    setState(() {
      _notifEnabled = prefs.getBool('notif_enabled') ?? true;
      _newsletterSubscribed = prefs.getBool('newsletter_subscribed') ?? false;
      _locationAccess = prefs.getBool('location_access') ?? false;
      _plumberId = plumberId;
      _availabilityEnabled = availabilityEnabled;
      _status = status;
      _isLoading = false; // Done loading
    });
    // Optionally, load from Firebase if you want to sync from the cloud.
  }

  Future<void> _saveNotifEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_enabled', value);
    if (_plumberId != null) {
      try {
        final databaseRef = FirebaseDatabase.instance.ref();
        await databaseRef
            .child('settings')
            .child('plumbers')
            .child(_plumberId!)
            .child('notifications_enabled')
            .set(value);
      } catch (e) {
        print('Firebase update error: $e');
      }
    }
  }

  Future<void> _saveNewsletterSubscribed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('newsletter_subscribed', value);
    if (_plumberId != null) {
      try {
        final databaseRef = FirebaseDatabase.instance.ref();
        await databaseRef
            .child('settings')
            .child('plumbers')
            .child(_plumberId!)
            .child('newsletter_subscribed')
            .set(value);
      } catch (e) {
        print('Firebase update error: $e');
      }
    }
  }

  Future<void> _saveLocationAccess(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_access', value);
    if (_plumberId != null) {
      try {
        final databaseRef = FirebaseDatabase.instance.ref();
        await databaseRef
            .child('settings')
            .child('plumbers')
            .child(_plumberId!)
            .child('location_access')
            .set(value);
      } catch (e) {
        print('Firebase update error: $e');
      }
    }
  }

  Future<void> _toggleLocationAccess(bool value) async {
    if (value) {
      final status = await Permission.location.request();
      if (status.isGranted) {
        setState(() => _locationAccess = true);
        await _saveLocationAccess(true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location access enabled.')),
        );
      } else {
        setState(() => _locationAccess = false);
        await _saveLocationAccess(false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location access denied.')),
        );
      }
    } else {
      setState(() => _locationAccess = false);
      await _saveLocationAccess(false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location access disabled.')),
      );
      // Do not open app settings
    }
  }

  // void _toggleAvailability(bool newValue) async {
  //   setState(() {
  //     _availabilityEnabled = newValue;
  //     _status = _availabilityEnabled ? 'Available' : 'Not Available';
  //   });

  //   if (_plumberId != null && _plumberId!.isNotEmpty) {
  //     // Update in MySQL via API
  //     try {
  //       final response = await http.post(
  //         Uri.parse(
  //           'https://aquafixsansimon.com/api/plumbers.php?action=update_availability',
  //         ),
  //         headers: {'Content-Type': 'application/json'},
  //         body: jsonEncode({
  //           'plumber_id': int.tryParse(_plumberId!) ?? _plumberId!,
  //           'availability_status': _status,
  //         }),
  //       );
  //       print(
  //         'Update availability response: ${response.statusCode} ${response.body}',
  //       );
  //     } catch (e) {
  //       print('API update error: $e');
  //     }
  //   } else {
  //     print('Plumber ID is null or empty, cannot update availability.');
  //   }
  // }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 20.h, bottom: 8.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _settingsTile({
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: TextStyle(fontSize: 14.sp)),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _simpleTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 22.sp, color: Colors.black54),
      title: Text(title, style: TextStyle(fontSize: 14.sp)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16.sp, color: Colors.grey),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF2C9CD9),
          title: Text(
            'Settings',
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C9CD9),
        title: Text(
          'Settings',
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
        radius: Radius.circular(10.r),
        thickness: 6.w,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 2.w, 20.w, 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // _sectionTitle("Availability Status"),
              // SwitchListTile(
              //   contentPadding: EdgeInsets.zero,
              //   title: Text(_status),
              //   value: _availabilityEnabled,
              //   onChanged: _toggleAvailability,
              // ),
              _sectionTitle("Notifications"),
              _settingsTile(
                title: "Push Notifications",
                value: _notifEnabled,
                onChanged: (val) async {
                  setState(() => _notifEnabled = val);
                  await _saveNotifEnabled(val);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        val
                            ? 'Push notifications enabled.'
                            : 'Push notifications disabled.',
                      ),
                    ),
                  );
                },
              ),
              _settingsTile(
                title: "Subscribe to Newsletters",
                value: _newsletterSubscribed,
                onChanged: (val) async {
                  setState(() => _newsletterSubscribed = val);
                  await _saveNewsletterSubscribed(val);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        val
                            ? 'Subscribed to newsletters.'
                            : 'Unsubscribed from newsletters.',
                      ),
                    ),
                  );
                },
              ),

              _sectionTitle("Privacy"),
              _settingsTile(
                title: "Allow Location Access",
                value: _locationAccess,
                onChanged: (val) async {
                  await _toggleLocationAccess(val);
                },
              ),

              _sectionTitle("About"),
              _simpleTile('Terms & Conditions', Icons.description, () {
                showDialog(
                  context: context,
                  builder:
                      (context) => Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 22.h,
                          ),
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
                                      onPressed:
                                          () => Navigator.of(context).pop(),
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
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 18.h),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2D9FD0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
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
              }),
              _simpleTile('Privacy Policy', Icons.privacy_tip, () {
                showDialog(
                  context: context,
                  builder:
                      (context) => Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 22.h,
                          ),
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
                                      onPressed:
                                          () => Navigator.of(context).pop(),
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
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 18.h),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2D9FD0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
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
              }),
              _simpleTile('App Version', Icons.info, () {
                showAboutDialog(
                  context: context,
                  applicationName: 'AquaFix',
                  applicationVersion: '1.0.0',
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateWithSlide(
    BuildContext context,
    Widget page, {
    bool clearStack = false,
  }) {
    final route = PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: Curves.easeInOut));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );

    if (clearStack) {
      Navigator.pushAndRemoveUntil(context, route, (_) => false);
    } else {
      Navigator.push(context, route);
    }
  }
}
