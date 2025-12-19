import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/main_scaffold.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'my_job_orders_page.dart';
import 'clw_accounts_page.dart';
import 'water_conservation_tips_page.dart';
import 'help_page.dart';
import 'settings_page.dart';
import 'login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  final int currentIndex;

  const ProfilePage({super.key, required this.currentIndex});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _firstName;
  String? _lastName;
  String? _email;
  String? _profileImage;
  String? _username;

  final ImagePicker _picker = ImagePicker();
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
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
      if (user != null) {
        setState(() {
          _firstName = user['first_name'] ?? '';
          _lastName = user['last_name'] ?? '';
          _email = user['email'] ?? '';
          _profileImage = user['profile_image'];
          _username = user['username'] ?? '';
        });
      }
    }
  }

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
      });
      _showImagePreviewDialog();
    }
  }

  void _showImagePreviewDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Profile Image Preview",
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 340.w,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Change Profile Picture',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C9CD9),
                    ),
                  ),
                  SizedBox(height: 18.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child:
                          _pickedImage != null
                              ? Image.file(
                                _pickedImage!,
                                width: 140.w,
                                height: 140.w,
                                fit: BoxFit.cover,
                              )
                              : Container(
                                width: 140.w,
                                height: 140.w,
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.person,
                                  size: 60.sp,
                                  color: Colors.grey[400],
                                ),
                              ),
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _pickedImage = null;
                          });
                        },
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                        label: Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[400],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 22.w,
                            vertical: 12.h,
                          ),
                        ),
                      ),
                      SizedBox(width: 18.w),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _uploadAndSaveProfileImage();
                        },
                        icon: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                        label: Text(
                          'Update',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2C9CD9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 22.w,
                            vertical: 12.h,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: child);
      },
    );
  }

  Future<void> _uploadAndSaveProfileImage() async {
    if (_pickedImage == null) return;
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    if (customerId.isEmpty) return;

    final uri = Uri.parse(
      'https://aquafixsansimon.com/api/upload_profile_image.php',
    );
    final request =
        http.MultipartRequest('POST', uri)
          ..fields['user_type'] = 'customer'
          ..fields['user_id'] = customerId
          ..files.add(
            await http.MultipartFile.fromPath(
              'profile_image',
              _pickedImage!.path,
            ),
          );
    final response = await request.send();

    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final respJson = json.decode(respStr);
      if (respJson['profile_image'] != null) {
        setState(() {
          _profileImage = respJson['profile_image'];
          _pickedImage = null;
        });
        // Update in DB
        await http.put(
          Uri.parse('https://aquafixsansimon.com/api/customers.php'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            "customer_id": customerId,
            "profile_image": respJson['profile_image'],
          }),
        );
      }
    }
    _loadProfile();
  }

  String _capitalizeFirst(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0] + text.substring(1);
  }

  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 20.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout, color: Color(0xFF2C9CD9), size: 48.sp),
                  SizedBox(height: 16.h),
                  Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Are you sure you want to sign out?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16.sp, color: Colors.black54),
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF2C9CD9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('customer_id');
      await prefs.remove('plumber_id');
      _navigateWithSlide(context, const LoginPage(), clearStack: true);
    }
  }

  Future<void> _confirmChangeProfileImage() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 20.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image, color: Color(0xFF2C9CD9), size: 48.sp),
                  SizedBox(height: 16.h),
                  Text(
                    'Change Profile Picture',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Are you sure you want to change your profile picture?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16.sp, color: Colors.black54),
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF2C9CD9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Change',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
    if (result == true) {
      await _pickProfileImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    const buttonColor = Color(0xFF2C9CD9);
    final double safeTop = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: MainScaffold(
        currentIndex: widget.currentIndex,
        body: Padding(
          padding: EdgeInsets.only(top: safeTop, left: 34.w, right: 34.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 40.h),
              Text(
                'Profile',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 16.h),

              // Profile Picture with Border and Edit Icon
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: EdgeInsets.all(2.r),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: buttonColor, width: 2.w),
                    ),
                    child: CircleAvatar(
                      radius: 50.r,
                      backgroundImage:
                          (_profileImage != null && _profileImage!.isNotEmpty)
                              ? NetworkImage(
                                'https://aquafixsansimon.com/uploads/profiles/customers/$_profileImage',
                              )
                              : const AssetImage('assets/profiles/default.jpg')
                                  as ImageProvider,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap:
                          _confirmChangeProfileImage, // <-- use confirmation dialog
                      child: Container(
                        decoration: BoxDecoration(
                          color: buttonColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16.h),
              Text(
                _capitalizeFirst(_username),
                style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text(
                _email ?? '',
                style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
              ),
              SizedBox(height: 20.h),

              // Menu Items
              _buildMenuItem(
                context,
                icon: Icons.assignment_outlined,
                title: 'My Job Orders',
                targetPage: const MyJobOrdersPage(),
                iconColor: buttonColor,
              ),
              _buildDivider(),
              _buildMenuItem(
                context,
                icon: Icons.person_outlined,
                title: 'CLW Accounts',
                targetPage: const SavedAccountsPage(),
                iconColor: buttonColor,
              ),
              _buildDivider(),
              _buildMenuItem(
                context,
                icon: Icons.water_drop_outlined,
                title: 'Water Conservation Tips',
                targetPage: const WaterConservationTipsPage(),
                iconColor: buttonColor,
              ),
              _buildDivider(),
              _buildMenuItem(
                context,
                icon: Icons.help_outline,
                title: 'Help',
                targetPage: const HelpPage(),
                iconColor: buttonColor,
              ),
              _buildDivider(),
              _buildMenuItem(
                context,
                icon: Icons.settings_outlined,
                title: 'Settings',
                targetPage: const SettingsPage(),
                iconColor: buttonColor,
              ),
              _buildDivider(),

              const Spacer(),

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await _confirmLogout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    'Sign Out',
                    style: TextStyle(fontSize: 16.sp, color: Colors.white),
                  ),
                ),
              ),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget targetPage,
    required Color iconColor,
  }) {
    return InkWell(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => targetPage),
          ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 15.h),
        child: Row(
          children: [
            Icon(icon, size: 20.sp, color: iconColor),
            SizedBox(width: 15.w),
            Expanded(child: Text(title, style: TextStyle(fontSize: 15.sp))),
            Icon(Icons.arrow_forward_ios, size: 15.sp, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1.h, color: Colors.grey[300]);
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
