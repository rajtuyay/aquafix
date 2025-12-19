import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

// Import the target pages
import 'edit_profile_page.dart';
import 'security_page.dart';

Future<void> saveNotifEnabled(bool value, {String? userId}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('notif_enabled', value);

  if (userId != null) {
    try {
      final databaseRef = FirebaseDatabase.instance.ref();
      await databaseRef
          .child('settings')
          .child('customers')
          .child(userId)
          .child('notifications_enabled')
          .set(value);
    } catch (e) {
      print('Firebase update error: $e');
    }
  }
}

Future<void> saveNewsletterSubscribed(bool value, {String? userId}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('newsletter_subscribed', value);

  if (userId != null) {
    try {
      final databaseRef = FirebaseDatabase.instance.ref();
      await databaseRef
          .child('settings')
          .child('customers')
          .child(userId)
          .child('newsletter_subscribed')
          .set(value);
    } catch (e) {
      print('Firebase update error: $e');
    }
  }
}

Future<void> saveLocationAccess(bool value, {String? userId}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('location_access', value);

  if (userId != null) {
    try {
      final databaseRef = FirebaseDatabase.instance.ref();
      await databaseRef
          .child('settings')
          .child('customers')
          .child(userId)
          .child('location_access')
          .set(value);
    } catch (e) {
      print('Firebase update error: $e');
    }
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifEnabled = true; // default: true
  bool _newsletterSubscribed = false; // default: false
  bool _locationAccess = false; // default: false
  String? _userId;
  bool _isLoading = true; // Add loading state

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    // Check actual permission status
    final permissionStatus = await Permission.location.status;
    final hasLocationPermission = permissionStatus.isGranted;
    setState(() {
      _notifEnabled = prefs.getBool('notif_enabled') ?? true;
      _newsletterSubscribed = prefs.getBool('newsletter_subscribed') ?? false;
      // Use actual permission status for the toggle
      _locationAccess = hasLocationPermission;
      _userId = customerId;
      _isLoading = false; // Done loading
    });
    // Optionally, you can load from Firebase here if you want to sync settings from the cloud.
    // Otherwise, just rely on SharedPreferences for local state.
  }

  Future<void> _toggleNotif(bool value) async {
    setState(() => _notifEnabled = value);
    await saveNotifEnabled(value, userId: _userId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Push notifications enabled.'
              : 'Push notifications disabled.',
        ),
      ),
    );
  }

  Future<void> _toggleNewsletter(bool value) async {
    setState(() => _newsletterSubscribed = value);
    await saveNewsletterSubscribed(value, userId: _userId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Subscribed to newsletters.'
              : 'Unsubscribed from newsletters.',
        ),
      ),
    );
  }

  Future<void> _toggleLocation(bool value) async {
    if (value) {
      // User wants to turn ON → show OS permission popup
      final status = await Permission.location.request();
      if (status.isGranted) {
        setState(() => _locationAccess = true);
        await saveLocationAccess(true, userId: _userId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location access enabled.')),
        );
      } else {
        setState(() => _locationAccess = false);
      }
    } else {
      // User wants to turn OFF → show confirmation popup
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Turn Off Location Access?'),
              content: const Text(
                'This will disable location-based features. Do you want to continue?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yes, Disable'),
                ),
              ],
            ),
      );

      if (confirm == true) {
        setState(() => _locationAccess = false);
        await saveLocationAccess(false, userId: _userId);
      } else {
        // Revert toggle back to ON
        setState(() => _locationAccess = true);
      }
    }
  }

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
              _sectionTitle("Account"),
              _simpleTile('Edit Profile', Icons.person, () {
                _navigateWithSlide(context, const EditProfilePage());
              }),
              _simpleTile('Security Settings', Icons.lock, () {
                _navigateWithSlide(context, const SecurityPage());
              }),

              _sectionTitle("Notifications"),
              _settingsTile(
                title: "Push Notifications",
                value: _notifEnabled,
                onChanged: _toggleNotif,
              ),
              _settingsTile(
                title: "Subscribe to Newsletters",
                value: _newsletterSubscribed,
                onChanged: _toggleNewsletter,
              ),

              _sectionTitle("Privacy"),
              _settingsTile(
                title: "Allow Location Access",
                value: _locationAccess,
                onChanged: _toggleLocation,
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
