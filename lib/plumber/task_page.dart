import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/main_scaffold.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'chat_detail_page.dart';
import 'notification_page.dart';
import 'jo_report_form.dart';
import 'map_page.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:location/location.dart';
import 'dart:io'; // For File operations
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class TaskPage extends StatefulWidget {
  final int currentIndex;
  final bool requirePasswordChange;
  final String? plumberId;

  const TaskPage({
    super.key,
    required this.currentIndex,
    this.requirePasswordChange = false,
    this.plumberId,
  });

  @override
  _TaskPage createState() => _TaskPage();
}

class _TaskPage extends State<TaskPage> {
  String selectedFilter = 'Status: All';
  String selectedPriority = 'Priority: All'; // default to All now
  List<dynamic> jobOrders = [];
  List<dynamic> filteredJobOrders = [];
  String _searchText = '';
  bool _loading = true;

  List<dynamic> _notifications = [];
  int _unreadCount = 0;

  StreamSubscription<DatabaseEvent>? _notifSubscription;

  @override
  void initState() {
    super.initState();
    _fetchJobOrders();
    _listenToPlumberNotifications();
    // Show password change modal if required
    if (widget.requirePasswordChange && widget.plumberId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showForcePasswordChangeModal(context, widget.plumberId!);
      });
    }
  }

  Future<void> _showNotificationsModal(BuildContext context) async {
    _setAllPlumberNotificationsViewed();
    setState(() {
      _unreadCount = 0;
    });

    final screenSize = MediaQuery.of(context).size;

    final sortedNotifications = List<Map<String, dynamic>>.from(_notifications);
    sortedNotifications.sort((a, b) {
      final aTime = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
      final bTime = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    final limitedNotifications = sortedNotifications.take(5).toList();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Center(
          child: Material(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFFF7F8FA),
            child: SizedBox(
              width: screenSize.width * 0.88,
              height: screenSize.height * 0.8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18.0, 0, 18.0, 18.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 36, 36, 36),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => NotificationPage(
                                      notifications: sortedNotifications,
                                    ),
                              ),
                            );
                          },
                          child: Text(
                            'View All',
                            style: TextStyle(
                              color: Color(0xFF2D9FD0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child:
                          limitedNotifications.isEmpty
                              ? Center(
                                child: Text(
                                  'No notifications yet.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                              : ListView.separated(
                                itemCount: limitedNotifications.length,
                                separatorBuilder:
                                    (_, __) => SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  final notif = limitedNotifications[index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 12.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.notifications_active,
                                                color: Color(0xFF2D9FD0),
                                                size: 20,
                                              ),
                                              SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  notif['title'] ?? '',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            notif['body'] ?? '',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                            textAlign: TextAlign.justify,
                                          ),
                                          SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 15,
                                                color: Colors.grey[500],
                                              ),
                                              SizedBox(width: 2),
                                              Text(
                                                notif['timestamp'] != null
                                                    ? notif['timestamp']
                                                        .toString()
                                                        .substring(0, 16)
                                                    : '',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    // Reset unread count when modal is opened
    if (!mounted) return;
    setState(() {
      _unreadCount = 0;
    });
    // Persist unread count if needed
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('unread_count', 0);
  }

  void _setAllPlumberNotificationsViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final plumberId = prefs.getString('plumber_id');
    if (plumberId == null || plumberId.isEmpty) return;
    final dbRef = FirebaseDatabase.instance.ref(
      'notification_plumber/$plumberId',
    );
    final snapshot = await dbRef.get();
    if (snapshot.value is Map) {
      final notifMap = snapshot.value as Map;
      for (final key in notifMap.keys) {
        final notif = notifMap[key];
        if (notif is Map && notif['viewed'] != true) {
          await dbRef.child(key).update({'viewed': true});
        }
      }
    }
  }

  void _listenToPlumberNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final plumberId = prefs.getString('plumber_id');
    if (plumberId == null || plumberId.isEmpty) return;
    final dbRef = FirebaseDatabase.instance.ref(
      'notification_plumber/$plumberId',
    );
    _notifSubscription?.cancel();
    _notifSubscription = dbRef.onValue.listen((event) async {
      final data = event.snapshot.value;
      List<Map<String, dynamic>> notifs = [];
      if (data is Map) {
        notifs =
            data.values.where((v) => v is Map).map((v) {
              return {
                'title': v['title'] ?? '',
                'body': v['body'] ?? '',
                'timestamp': v['timestamp'] ?? '',
                'viewed': v['viewed'] ?? false,
              };
            }).toList();
      } else if (data is List) {
        notifs =
            data.where((v) => v != null).map((v) {
              return {
                'title': v['title'] ?? '',
                'body': v['body'] ?? '',
                'timestamp': v['timestamp'] ?? '',
                'viewed': v['viewed'] ?? false,
              };
            }).toList();
      }
      notifs = notifs.reversed.toList(); // Newest first
      int unreadCount = notifs.where((n) => n['viewed'] == false).length;
      if (!mounted) return;
      setState(() {
        _notifications = notifs;
        _unreadCount = unreadCount;
      });
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt('unread_count', unreadCount);
    });
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchJobOrders() async {
    setState(() {
      _loading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final plumberId = prefs.getString('plumber_id') ?? '';
    if (plumberId.isEmpty) {
      setState(() {
        jobOrders = [];
        filteredJobOrders = [];
        _loading = false;
      });
      return;
    }
    final response = await http.get(
      Uri.parse(
        'https://aquafixsansimon.com/api/job_orders.php?plumber_id=$plumberId',
      ),
    );
    if (response.statusCode == 200) {
      final List<dynamic> orders = json.decode(response.body);

      // NEW: fetch customers and merge phone numbers into job orders
      try {
        final custResp = await http.get(
          Uri.parse('https://aquafixsansimon.com/api/customers.php'),
        );
        if (custResp.statusCode == 200) {
          final List<dynamic> customers = json.decode(custResp.body);
          final Map<String, String> phoneMap = {};
          for (var c in customers) {
            final id = c['customer_id']?.toString() ?? '';
            final phone =
                (c['customer_phone'] ?? c['contact_no'] ?? '').toString();
            if (id.isNotEmpty) phoneMap[id] = phone;
          }
          // Merge phone into each order
          for (var job in orders) {
            final cid = job['customer_id']?.toString();
            if (cid != null && cid.isNotEmpty && phoneMap.containsKey(cid)) {
              job['customer_phone'] = phoneMap[cid];
            }
            // Keep any existing contact_no on job as fallback
            job['customer_phone'] = job['customer_phone'] ?? job['contact_no'];
          }
        } else {
          print('Failed to fetch customers.php: ${custResp.statusCode}');
        }
      } catch (e) {
        print('Error fetching customers.php: $e');
      }
      // END new merging logic

      if (!mounted) return;
      setState(() {
        jobOrders = orders;
        _applyFilterAndSearch();
        _loading = false;
      });
    } else {
      if (!mounted) return;
      setState(() {
        jobOrders = [];
        filteredJobOrders = [];
        _loading = false;
      });
    }
  }

  void _applyFilterAndSearch() {
    List<dynamic> filtered = jobOrders;
    // Remove "Pending" from the list (do not display cards for pending)
    filtered =
        filtered.where((job) {
          final jobStatus = (job['status'] ?? '').toString().toLowerCase();
          return jobStatus != 'pending';
        }).toList();
    // Filter by status
    if (selectedFilter != 'Status: All') {
      filtered =
          filtered.where((job) {
            final jobStatus = (job['status'] ?? '').toString().toLowerCase();
            return jobStatus == selectedFilter.toLowerCase() &&
                jobStatus != 'pending';
          }).toList();
    }
    // Filter by priority (skip if All)
    if (selectedPriority != 'Priority: All') {
      filtered =
          filtered.where((job) {
            final priority =
                (job['priority'] ?? 'urgent').toString().toLowerCase();
            return priority == selectedPriority.toLowerCase();
          }).toList();
    }
    // Filter by search
    if (_searchText.trim().isNotEmpty) {
      filtered =
          filtered.where((job) {
            final customerName =
                ((job['customer_first_name'] ?? '') +
                        ' ' +
                        (job['customer_last_name'] ?? ''))
                    .toLowerCase()
                    .trim();
            final jobId = (job['jo_number'] ?? '').toString().toLowerCase();
            return customerName.contains(_searchText.toLowerCase()) ||
                jobId.contains(_searchText.toLowerCase());
          }).toList();
    }
    filteredJobOrders = filtered;
  }

  void _sortJobOrders(String filter) {
    setState(() {
      selectedFilter = filter;
      _applyFilterAndSearch();
    });
  }

  void _sortPriority(String priority) {
    setState(() {
      selectedPriority = priority;
      _applyFilterAndSearch();
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchText = value;
      _applyFilterAndSearch();
    });
  }

  Future<void> _showForcePasswordChangeModal(
    BuildContext context,
    String plumberId,
  ) async {
    TextEditingController _newPasswordController = TextEditingController();
    TextEditingController _confirmPasswordController = TextEditingController();
    bool _isLoading = false;
    String? _errorText;
    bool _showNewPassword = false;
    bool _showConfirmPassword = false;

    // Password validation function
    bool _isValidPassword(String password) {
      final hasUppercase = password.contains(RegExp(r'[A-Z]'));
      final hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      final hasNumber = password.contains(RegExp(r'[0-9]'));
      final hasMinLength = password.length >= 8;
      return hasUppercase && hasSpecial && hasNumber && hasMinLength;
    }

    // Use StatefulBuilder for modal state
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing modal
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            // Exit the app when back button is pressed
            if (!didPop) {
              SystemNavigator.pop();
            }
          },
          child: StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Container(
                  padding: EdgeInsets.all(24),
                  constraints: BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_reset,
                        color: Color(0xFF2C9CD9),
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Change Your Password",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C9CD9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "For your security, please set a new password before proceeding.",
                        style: TextStyle(fontSize: 15, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 18),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: !_showNewPassword,
                        decoration: InputDecoration(
                          labelText: "New Password",
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showNewPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey,
                              size: 20.sp,
                            ),
                            onPressed: () {
                              setState(() {
                                _showNewPassword = !_showNewPassword;
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: !_showConfirmPassword,
                        decoration: InputDecoration(
                          labelText: "Confirm Password",
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey,
                              size: 20.sp,
                            ),
                            onPressed: () {
                              setState(() {
                                _showConfirmPassword = !_showConfirmPassword;
                              });
                            },
                          ),
                        ),
                      ),
                      if (_errorText != null)
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            _errorText!,
                            style: TextStyle(color: Colors.red, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF2C9CD9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed:
                              _isLoading
                                  ? null
                                  : () async {
                                    setState(() {
                                      _errorText = null;
                                      _isLoading = true;
                                    });
                                    final newPassword =
                                        _newPasswordController.text.trim();
                                    final confirmPassword =
                                        _confirmPasswordController.text.trim();
                                    if (newPassword.isEmpty ||
                                        confirmPassword.isEmpty) {
                                      setState(() {
                                        _errorText =
                                            "Please fill in both fields.";
                                        _isLoading = false;
                                      });
                                      return;
                                    }
                                    // Password validation
                                    if (!_isValidPassword(newPassword)) {
                                      setState(() {
                                        _errorText =
                                            "Password must be at least 8 characters, include 1 uppercase letter, 1 number, and 1 special character.";
                                        _isLoading = false;
                                      });
                                      return;
                                    }
                                    if (newPassword != confirmPassword) {
                                      setState(() {
                                        _errorText = "Passwords do not match.";
                                        _isLoading = false;
                                      });
                                      return;
                                    }
                                    // Send password update to API
                                    final response = await http.put(
                                      Uri.parse(
                                        'https://aquafixsansimon.com/api/plumbers.php',
                                      ),
                                      headers: {
                                        'Content-Type': 'application/json',
                                      },
                                      body: json.encode({
                                        'plumber_id': int.tryParse(plumberId),
                                        'password': newPassword,
                                      }),
                                    );
                                    if (response.statusCode == 200) {
                                      Navigator.of(
                                        context,
                                      ).pop(); // Close modal
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Password updated successfully!",
                                          ),
                                          backgroundColor: Color(0xFF2C9CD9),
                                        ),
                                      );
                                    } else {
                                      setState(() {
                                        _errorText =
                                            "Failed to update password. Please try again.";
                                        _isLoading = false;
                                      });
                                    }
                                  },
                          child:
                              _isLoading
                                  ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                  : Text(
                                    "Update Password",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double safeTop = MediaQuery.of(context).padding.top;
    final double headerHeight = 64.h;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: MainScaffold(
        currentIndex: widget.currentIndex,
        body: Column(
          children: [
            Container(
              height: headerHeight + safeTop,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/homepage-header.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, safeTop, 20.w, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Plumber Tasks',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // --- Notification Button (copied from home_page.dart) ---
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _unreadCount = 0; // Reset when modal is opened
                            });
                            _showNotificationsModal(context);
                          },
                          borderRadius: BorderRadius.circular(30.r),
                          child: Icon(
                            Icons.notifications,
                            color: const Color.fromARGB(255, 255, 255, 255),
                            size: 22.sp,
                          ),
                        ),
                        if (_unreadCount > 0)
                          Positioned(
                            top: -9,
                            right: -9,
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: BoxConstraints(
                                minWidth: 17,
                                minHeight: 17,
                              ),
                              child: Text(
                                '$_unreadCount',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  SizedBox(height: 16.h),
                  // --- DROPDOWN ROW: Status + Priority ---
                  Row(
                    children: [
                      // Status Dropdown
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 10.h,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade700),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: DropdownButton<String>(
                            value: selectedFilter,
                            isExpanded: true,
                            isDense: true,
                            icon: Icon(Icons.arrow_drop_down, size: 24.sp),
                            items:
                                [
                                      'Status: All',
                                      'Dispatched',
                                      'Accomplished',
                                      'Cancelled',
                                    ]
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(
                                          e,
                                          style: TextStyle(fontSize: 15.sp),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                _sortJobOrders(newValue);
                              }
                            },
                            underline: SizedBox(),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Priority Dropdown
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 10.h,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade700),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: DropdownButton<String>(
                            value: selectedPriority,
                            isExpanded: true,
                            isDense: true,
                            icon: Icon(Icons.arrow_drop_down, size: 24.sp),
                            items:
                                ['Priority: All', 'Urgent', 'Non-urgent']
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(
                                          e,
                                          style: TextStyle(fontSize: 15.sp),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                _sortPriority(newValue);
                              }
                            },
                            underline: SizedBox(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  TextField(
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search by Customer Name or JO No.',
                      hintStyle: TextStyle(fontSize: 15.sp),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: Colors.grey.shade100),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child:
                      _loading
                          ? const Center(child: CircularProgressIndicator())
                          : filteredJobOrders.isEmpty
                          ? Center(
                            child: Text(
                              "No job orders found.",
                              style: TextStyle(
                                fontSize: 15.sp,
                                color: Colors.grey,
                              ),
                            ),
                          )
                          : ListView(
                            children:
                                filteredJobOrders
                                    .map(
                                      (job) => _buildJobCard(
                                        status: job['status'] ?? '',
                                        statusColor: _getStatusColor(
                                          job['status'] ?? '',
                                        ),
                                        date: _formatDate(
                                          (() {
                                            final status =
                                                (job['status'] ?? '')
                                                    .toString()
                                                    .toLowerCase();

                                            if (status == 'pending') {
                                              return job['created_at'];
                                            } else if (status == 'dispatched') {
                                              return job['dispatched_at'];
                                            } else if (status ==
                                                'accomplished') {
                                              print(
                                                '${job['jo_number']} ${job['accomplished_at']}',
                                              );
                                              return job['accomplished_at'];
                                            } else if (status == 'cancelled') {
                                              return job['cancelled_at'];
                                            }
                                            return job['created_at'];
                                          })(),
                                          job['created_at'],
                                        ),
                                        jobId:
                                            (job['jo_number'] ?? '').toString(),
                                        title: job['category'] ?? '',
                                        customer: job['account_name'] ?? '',
                                        address: _formatAddress(job),
                                        jobOrderId: job['job_order_id'],
                                      ),
                                    )
                                    .toList(),
                          ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date, dynamic createdAt, [dynamic _]) {
    String? raw = date?.toString();
    if (raw == null || raw.isEmpty || raw == 'null') {
      raw = createdAt?.toString();
    }
    if (raw == null || raw.isEmpty || raw == 'null') return '';
    try {
      final dt = DateTime.parse(raw);
      final formattedDate = "${_monthName(dt.month)} ${dt.day}, ${dt.year}";
      final formattedTime =
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      return "$formattedDate $formattedTime";
    } catch (_) {
      return raw;
    }
  }

  String _monthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month];
  }

  String _formatAddress(dynamic job) {
    final label = job['account_label'] ?? '';
    final street = job['street'] ?? '';
    final barangay = job['barangay'] ?? '';
    final municipality = job['municipality'] ?? '';
    final province = job['province'] ?? '';
    String address = [
      label,
      street,
      barangay,
      municipality,
      province,
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ');
    // Truncate to 42 chars, add ellipsis if needed
    if (address.length > 42) {
      address = address.substring(0, 42).trimRight() + '...';
    }
    return address;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accomplished':
        return Colors.green;
      case 'dispatched':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildJobCard({
    required String status,
    required Color statusColor,
    required String date,
    required String jobId,
    required String title,
    required String customer,
    required String address,
    required dynamic jobOrderId,
  }) {
    final statusLower = status.toLowerCase();
    final isDispatched = statusLower == 'dispatched';
    final isAccomplished = statusLower == 'accomplished';
    final isCancelled = statusLower == 'cancelled';

    // Always display customer name from tbl_customers (first + last name)
    String displayCustomer = customer;
    String? customerPhone;
    final job = jobOrders.firstWhere(
      (j) => (j['job_order_id']?.toString() == jobOrderId.toString()),
      orElse: () => null,
    );
    if (job != null) {
      if (job['customer_first_name'] != null &&
          job['customer_last_name'] != null) {
        displayCustomer =
            "${job['customer_first_name']} ${job['customer_last_name']}".trim();
      }
      // Try both customer_phone and contact_no
      if (job['customer_phone'] != null &&
          job['customer_phone'].toString().isNotEmpty) {
        customerPhone = job['customer_phone'].toString();
      } else if (job['contact_no'] != null &&
          job['contact_no'].toString().isNotEmpty) {
        customerPhone = job['contact_no'].toString();
      }
    }

    String priorityLabel = 'Urgent';
    Color priorityColor = Colors.red;
    if (job != null) {
      final prio = (job['priority'] ?? 'urgent').toString().toLowerCase();
      if (prio == 'non-urgent') {
        priorityLabel = 'Non-urgent';
        priorityColor = Colors.orange;
      }
    }

    return GestureDetector(
      onTap:
          isDispatched || isAccomplished || isCancelled
              ? () => _showJobOrderDetailsModal(context, jobOrderId)
              : null,
      child: Card(
        margin: EdgeInsets.only(bottom: 12.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        elevation: 3,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.w),
          child: Stack(
            children: [
              // Main card content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: status and date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                            child: Text(
                              status[0].toUpperCase() + status.substring(1),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                            child: Text(
                              priorityLabel,
                              style: TextStyle(
                                color: priorityColor,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatDate(
                          (() {
                            final statusLower = status.toLowerCase();
                            if (statusLower == 'pending') {
                              return job['created_at'];
                            } else if (statusLower == 'dispatched') {
                              return job['dispatched_at'];
                            } else if (statusLower == 'accomplished') {
                              return job['accomplished_at'];
                            } else if (statusLower == 'cancelled') {
                              return job['cancelled_at'];
                            }
                            return job['created_at'];
                          })(),
                          job['created_at'],
                        ),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color.fromARGB(255, 98, 98, 98),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '$jobId $title',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(displayCustomer, style: TextStyle(fontSize: 13.sp)),
                  SizedBox(height: 2.h),
                  Text(
                    address,
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isDispatched) ...[
                        // --- Call Button (left of Message) ---
                        if (customerPhone != null && customerPhone.isNotEmpty)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.only(right: 8.w),
                              minimumSize: Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () async {
                              final uri = Uri(
                                scheme: 'tel',
                                path: customerPhone,
                              );
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Cannot launch dialer.'),
                                  ),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                Icon(
                                  Icons.call,
                                  color: Color(
                                    0xFF00897B,
                                  ), // changed to match Add Report green
                                  size: 16.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  "Call",
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: Color(
                                      0xFF00897B,
                                    ), // changed to match Add Report green
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // --- Message Button ---
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.only(left: 8.w),
                            minimumSize: Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed:
                              () => _openChatWithCustomer(context, jobOrderId),
                          child: Row(
                            children: [
                              Icon(
                                Icons.message,
                                color: Color(0xFF2196F3),
                                size: 16.sp,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                "Message",
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Color(0xFF2196F3),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FutureBuilder<http.Response>(
                          future: http.get(
                            Uri.parse(
                              'https://aquafixsansimon.com/api/report_draft_status.php?job_order_id=$jobOrderId${job?['plumber_id'] != null ? '&plumber_id=${job?['plumber_id']}' : ''}',
                            ),
                          ),
                          builder: (context, snapshot) {
                            print(
                              'FutureBuilder for jobOrderId: $jobOrderId, plumberId: ${job?['plumber_id']}',
                            );

                            bool showAddReport = true;
                            if (snapshot.hasData &&
                                snapshot.data != null &&
                                snapshot.data!.statusCode == 200) {
                              final report = json.decode(snapshot.data!.body);
                              final isDraft =
                                  int.tryParse(report['is_draft'].toString()) ??
                                  1;
                              print('is_draft parsed value: $isDraft');
                              // Only show Add Report if is_draft == 1
                              showAddReport = isDraft == 1;
                            } else if (snapshot.hasData &&
                                snapshot.data != null &&
                                snapshot.data!.statusCode == 404) {
                              // No report found, allow Add Report
                              showAddReport = true;
                            }
                            if (showAddReport) {
                              return TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.only(left: 14.w),
                                  minimumSize: Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () async {
                                  final plumberIdRaw = job?['plumber_id'];
                                  final jobOrderIdRaw = job?['job_order_id'];
                                  final plumberId =
                                      plumberIdRaw != null
                                          ? int.tryParse(
                                            plumberIdRaw.toString(),
                                          )
                                          : null;
                                  final jobOrderIdVal =
                                      jobOrderIdRaw != null
                                          ? int.tryParse(
                                            jobOrderIdRaw.toString(),
                                          )
                                          : null;
                                  if (plumberId != null &&
                                      jobOrderIdVal != null) {
                                    // Use await and check result
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => JOReportForm(
                                              plumberId: plumberId,
                                              jobOrderId: jobOrderIdVal,
                                            ),
                                      ),
                                    );
                                    // If result is true (submitted or saved), refresh job orders
                                    if (result == true && mounted) {
                                      _fetchJobOrders();
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Missing plumber or job order ID.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.assignment,
                                      color: const Color(0xFF325CA1),
                                      size: 16.sp,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      "Add Report",
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: const Color(0xFF325CA1),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return SizedBox.shrink();
                            }
                          },
                        ),
                      ] else if (isAccomplished || isCancelled) ...[
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.only(bottom: 0),
                            minimumSize: Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed:
                              () => _showJobOrderDetailsModal(
                                context,
                                jobOrderId,
                              ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Color(0xFF2D9FD0),
                                size: 16.sp,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                "View Details",
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Color(0xFF2D9FD0),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              // Overlay: Centered Navigate button
              if (isDispatched)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: -7.w,
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton(
                        icon: Stack(
                          alignment: Alignment.center,
                          children: [
                            // White circle background (button)
                            Container(
                              width: 34.sp,
                              height: 34.sp,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 3,
                                    offset: Offset(0, 0),
                                  ),
                                ],
                              ),
                            ),
                            // Pin icon, slightly lower to overlap the circle
                            Positioned(
                              bottom: 5.sp,
                              child: Icon(
                                Icons.location_on,
                                color: Color(0xFF2D9FD0),
                                size: 25.sp,
                              ),
                            ),
                            // Custom painted oval/circle below the button
                            Positioned(
                              bottom: 3.sp,
                              child: CustomPaint(
                                size: Size(12.sp, 6.sp),
                                painter: _CircleBelowPainter(),
                              ),
                            ),
                          ],
                        ),
                        tooltip: "Navigate",
                        onPressed: () async {
                          final job = jobOrders.firstWhere(
                            (j) =>
                                (j['job_order_id']?.toString() ==
                                    jobOrderId.toString()),
                            orElse: () => null,
                          );
                          if (job != null) {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('Start Navigation'),
                                    content: const Text(
                                      'Do you want to start navigating to the customer? Your location will be shared in real-time.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: Color(
                                            0xFF2D9FD0,
                                          ), // Use your app's primary color
                                        ),
                                        onPressed:
                                            () => Navigator.pop(context, true),
                                        child: const Text('Start'),
                                      ),
                                    ],
                                  ),
                            );
                            if (confirmed != true) return;

                            // Start sending plumber location to Firebase
                            final prefs = await SharedPreferences.getInstance();
                            final plumberId = prefs.getString('plumber_id');
                            if (plumberId != null && plumberId.isNotEmpty) {
                              // Use Location package to get real-time updates
                              final location = Location();
                              // Optionally, cancel previous subscription if you keep it globally
                              location.changeSettings(
                                accuracy: LocationAccuracy.high,
                                interval: 2000,
                                distanceFilter: 2,
                              );
                              // Start sending location to Firebase
                              location.onLocationChanged.listen((locationData) {
                                if (locationData.latitude != null &&
                                    locationData.longitude != null) {
                                  FirebaseDatabase.instance
                                      .ref('locations/plumbers/$plumberId')
                                      .set({
                                        'lat': locationData.latitude,
                                        'lng': locationData.longitude,
                                        'timestamp':
                                            DateTime.now().toIso8601String(),
                                      });
                                }
                              });
                            }

                            // Now go to MapPage as before
                            final customerId = job['customer_id']?.toString();
                            double? customerLat;
                            double? customerLng;
                            String? customerProfileImage;
                            if (customerId != null && customerId.isNotEmpty) {
                              final ref = FirebaseDatabase.instance.ref(
                                'locations/customers/$customerId',
                              );
                              final snapshot = await ref.get();
                              final data = snapshot.value;
                              if (data is Map) {
                                customerLat = (data['lat'] as num?)?.toDouble();
                                customerLng = (data['lng'] as num?)?.toDouble();
                              }
                              // Fetch customer profile image from tbl_customers
                              final customerRes = await http.get(
                                Uri.parse(
                                  'https://aquafixsansimon.com/api/customers.php',
                                ),
                              );
                              if (customerRes.statusCode == 200) {
                                final List users = json.decode(
                                  customerRes.body,
                                );
                                final user = users.firstWhere(
                                  (u) =>
                                      u['customer_id'].toString() == customerId,
                                  orElse: () => null,
                                );
                                if (user != null &&
                                    user['profile_image'] != null &&
                                    user['profile_image']
                                        .toString()
                                        .isNotEmpty) {
                                  customerProfileImage = user['profile_image'];
                                }
                              }
                            }
                            if (!mounted) return;
                            if (customerLat != null && customerLng != null) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => MapPage(
                                        currentIndex: 1,
                                        customerLat: customerLat,
                                        customerLng: customerLng,
                                        customerId: customerId,
                                        customerProfileImage:
                                            customerProfileImage,
                                      ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Customer location not available.',
                                  ),
                                ),
                              );
                            }
                          } else {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Customer location not available.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildMaterialTable(List<Map<String, dynamic>> materials) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                flex: 2,
                child: Text(
                  "Name",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  "Size",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  "Qty",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  "Price",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  "Total",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const Divider(),
          if (materials.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("No material added."),
            )
          else
            ...materials.map((mat) {
              final unitPrice =
                  double.tryParse(mat['unit_price'].toString())?.toInt() ?? 0;
              final qty = int.tryParse(mat['qty']?.toString() ?? '0') ?? 0;
              final total = unitPrice * qty;

              return Padding(
                padding: EdgeInsets.symmetric(vertical: 3.h),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        mat['material_name'] ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        mat['size'] ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        mat['qty']?.toString() ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        "₱$unitPrice",
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        "₱$total",
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Future<void> _showJobOrderDetailsModal(
    BuildContext context,
    dynamic jobOrderId,
  ) async {
    final job = jobOrders.firstWhere(
      (j) => (j['job_order_id']?.toString() == jobOrderId.toString()),
      orElse: () => null,
    );
    if (job == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job order details not found.')),
      );
      return;
    }

    List<dynamic> attachments = [];

    // If status is "Accomplished", show Report Details modal
    if ((job['status'] ?? '').toString().toLowerCase() == 'accomplished') {
      Map<String, dynamic>? report;
      List<dynamic> materials = [];
      try {
        // Fetch report details
        final reportUrl =
            'https://aquafixsansimon.com/api/report_details.php?job_order_id=${job['job_order_id']}';
        print('Fetching report: $reportUrl'); // DEBUG
        final reportResp = await http.get(Uri.parse(reportUrl));
        print('Report response: ${reportResp.body}'); // DEBUG
        if (reportResp.statusCode == 200) {
          final decoded = json.decode(reportResp.body);
          if (decoded is Map<String, dynamic>) {
            report = decoded;
            materials = report['materials'] ?? [];
          }
        }

        // Fetch attachments
        final attResp = await http.get(
          Uri.parse(
            'https://aquafixsansimon.com/api/jo_media_list.php?job_order_id=${job['job_order_id']}',
          ),
        );
        if (attResp.statusCode == 200) {
          final decoded = json.decode(attResp.body);
          if (decoded is List && decoded.isNotEmpty) {
            attachments = decoded;
          }
        }
      } catch (e) {
        print('Error fetching report or attachments: $e');
      }

      // Show Report Details modal
      await showDialog(
        context: context,
        builder: (context) {
          final bool clwAccountMissing =
              (job['account_label'] ?? '').toString().trim().isEmpty &&
              (job['account_number'] ?? '').toString().trim().isEmpty &&
              (job['account_name'] ?? '').toString().trim().isEmpty;
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(18.w),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Report Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17.sp,
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Divider(),
                    // Small header with job order info
                    Text(
                      'Job Order #: ${job['jo_number'] ?? ''}',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (clwAccountMissing) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'This account was deleted and details are no longer available.',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(height: 4.h),
                      _buildRichText('Account Name: ', job['account_name']),
                      SizedBox(height: 4.h),
                      _buildRichText('Account Number: ', job['account_number']),
                      SizedBox(height: 4.h),
                      _buildRichText(
                        'Meter Number: ',
                        job['meter_no']?.toString(),
                      ),
                      Divider(),
                    ],
                    _buildRichText('Status: ', job['status']),
                    SizedBox(height: 4.h),
                    // Main report details from tbl_report
                    if (report != null) ...[
                      _buildRichText('Category: ', report['category']),
                      SizedBox(height: 4.h),
                      _buildRichText('Root Cause: ', report['root_cause']),
                      SizedBox(height: 4.h),
                      _buildRichText('Action Taken: ', report['action_taken']),
                      SizedBox(height: 4.h),
                      _buildRichText(
                        'Date Time Started: ',
                        report['date_time_started'],
                      ),
                      SizedBox(height: 4.h),

                      SizedBox(height: 4.h),
                      _buildRichText(
                        'Date Time Finished: ',
                        report['date_time_finished'],
                      ),
                      SizedBox(height: 4.h),
                      _buildRichText(
                        'Accomplished By: ',
                        report['accomplished_by'],
                      ),
                      SizedBox(height: 4.h),
                      _buildRichText('Remarks: ', report['remarks']),
                      Divider(),
                      Text(
                        'Materials Used',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      // Cast materials to List<Map<String, dynamic>>
                      buildMaterialTable(
                        materials.cast<Map<String, dynamic>>(),
                      ),
                      SizedBox(height: 18.h),
                      Text(
                        'Attachments',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      // Fix FutureBuilder type error: use Future<http.Response?>
                      FutureBuilder<http.Response?>(
                        future:
                            (() async {
                              // Fetch report media using report_id
                              if (report != null &&
                                  report['report_id'] != null) {
                                final resp = await http.get(
                                  Uri.parse(
                                    'https://aquafixsansimon.com/api/report_media_list.php?report_id=${report['report_id']}',
                                  ),
                                );
                                return resp;
                              }
                              return null;
                            })(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data == null) {
                            return Text(
                              'No media found.',
                              style: TextStyle(color: Colors.grey),
                            );
                          }
                          final resp = snapshot.data!;
                          if (resp.statusCode != 200) {
                            return Text(
                              'No media found.',
                              style: TextStyle(color: Colors.grey),
                            );
                          }
                          final List mediaList = json.decode(resp.body);
                          if (mediaList.isEmpty) {
                            return Text(
                              'No media found.',
                              style: TextStyle(color: Colors.grey),
                            );
                          }
                          int imageCount = 1;
                          int videoCount = 1;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                mediaList.map<Widget>((att) {
                                  final isImage = att['media_type'] == 'image';
                                  final isVideo = att['media_type'] == 'video';
                                  final fileName = att['file_path'] ?? '';
                                  final url =
                                      fileName != null &&
                                              fileName.toString().isNotEmpty
                                          ? 'https://aquafixsansimon.com/uploads/report_media/$fileName'
                                          : null;
                                  String displayLabel;
                                  if (isImage) {
                                    displayLabel =
                                        'Image_${imageCount.toString().padLeft(2, '0')}';
                                    imageCount++;
                                  } else if (isVideo) {
                                    displayLabel =
                                        'Video_${videoCount.toString().padLeft(2, '0')}';
                                    videoCount++;
                                  } else {
                                    displayLabel = fileName;
                                  }
                                  // Debug print for video/image URLs
                                  print(
                                    'Attachment: type=${att['media_type']}, fileName=$fileName, url=$url',
                                  );
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 8.h),
                                    child: GestureDetector(
                                      onTap: () {
                                        if (url == null || url.isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Media file is missing or invalid.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        if (isImage) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => _FullImageViewNetwork(
                                                    imageUrl: url,
                                                  ),
                                            ),
                                          );
                                        } else if (isVideo) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => _FullVideoViewNetwork(
                                                    videoUrl: url,
                                                  ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Row(
                                        children: [
                                          Icon(
                                            isImage
                                                ? Icons.image
                                                : Icons.videocam,
                                            color:
                                                isImage
                                                    ? Colors.blue
                                                    : Colors.red,
                                            size: 22.sp,
                                          ),
                                          SizedBox(width: 8.w),
                                          Flexible(
                                            child: Text(
                                              displayLabel,
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                color: Colors.blueAccent,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                          );
                        },
                      ),
                    ] else ...[
                      Text(
                        'No report found for this job order.',
                        style: TextStyle(fontSize: 14.sp, color: Colors.red),
                      ),
                    ],
                    SizedBox(height: 10.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D9FD0),
                          minimumSize: Size.fromHeight(40.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 15.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      // Return so we don’t show the other modal
      return;
    }

    // Fetch attachments for normal job order
    try {
      final attResp = await http.get(
        Uri.parse(
          'https://aquafixsansimon.com/api/jo_media_list.php?job_order_id=${job['job_order_id']}',
        ),
      );
      if (attResp.statusCode == 200) {
        final decoded = json.decode(attResp.body);
        if (decoded is List && decoded.isNotEmpty) {
          attachments = decoded;
        }
      }
    } catch (_) {}

    final bool clwAccountMissing =
        (job['account_label'] ?? '').toString().trim().isEmpty &&
        (job['account_number'] ?? '').toString().trim().isEmpty &&
        (job['account_name'] ?? '').toString().trim().isEmpty;
    // Show Job Order Details modal
    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(18.w),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Job Order Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17.sp,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Divider(),
                  Text(
                    'Job Order #: ${job['jo_number'] ?? ''}',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  if (clwAccountMissing) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'This account was deleted and details are no longer available.',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(height: 8.h),
                    _buildRichText('Account Name: ', job['account_name']),
                    SizedBox(height: 8.h),
                    _buildRichText('Account Number: ', job['account_number']),
                    SizedBox(height: 8.h),
                    _buildRichText(
                      'Meter Number: ',
                      job['meter_no']?.toString(),
                    ),
                    SizedBox(height: 8.h),
                    _buildRichText(
                      'Address: ',
                      [
                            job['account_label'],
                            job['street'],
                            job['barangay'],
                            job['municipality'],
                            job['province'],
                          ]
                          .where(
                            (e) => e != null && e.toString().trim().isNotEmpty,
                          )
                          .join(', '),
                    ),
                  ],

                  _buildRichText('Reason/Issue: ', job['category']),
                  if ((job['other_issue'] ?? '').toString().isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    _buildRichText('Other Issue: ', job['other_issue']),
                  ],
                  SizedBox(height: 8.h),
                  _buildRichText('Status: ', job['status']),
                  SizedBox(height: 8.h),
                  _buildRichText(
                    'Date: ',
                    _formatDate(job['date'], job['created_at']),
                  ),
                  SizedBox(height: 8.h),
                  _buildRichText('Address: ', _formatAddress(job)),
                  if ((job['notes'] ?? '').toString().isNotEmpty)
                    SizedBox(height: 8.h),
                  _buildRichText('Notes: ', job['notes']),
                  SizedBox(height: 18.h),
                  Text(
                    'Attachments',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  if (attachments.isEmpty)
                    Text(
                      'No attachments.',
                      style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                    )
                  else
                    _buildAttachmentList(attachments),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D9FD0),
                        minimumSize: Size.fromHeight(40.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRichText(String label, String? value) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 15.sp, color: Colors.black),
        children: [
          TextSpan(
            text: label,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.sp),
          ),
          TextSpan(text: value ?? ''),
        ],
      ),
    );
  }

  Widget _buildAttachmentList(List attachments) {
    int imageCount = 1;
    int videoCount = 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          attachments.map<Widget>((att) {
            final isImage = att['media_type'] == 'image';
            final isVideo = att['media_type'] == 'video';
            final fileName = att['file_path'] ?? '';
            final url =
                'https://aquafixsansimon.com/uploads/jo_media/$fileName';
            String displayLabel;
            if (isImage) {
              displayLabel = 'Image_${imageCount.toString().padLeft(2, '0')}';
              imageCount++;
            } else if (isVideo) {
              displayLabel = 'Video_${videoCount.toString().padLeft(2, '0')}';
              videoCount++;
            } else {
              displayLabel = fileName;
            }
            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: GestureDetector(
                onTap: () {
                  if (isImage) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _FullImageViewNetwork(imageUrl: url),
                      ),
                    );
                  } else if (isVideo) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _FullVideoViewNetwork(videoUrl: url),
                      ),
                    );
                  }
                },
                child: Row(
                  children: [
                    Icon(
                      isImage ? Icons.image : Icons.videocam,
                      color: isImage ? Colors.blue : Colors.red,
                      size: 22.sp,
                    ),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        displayLabel,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.blueAccent,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Future<void> _openChatWithCustomer(
    BuildContext context,
    dynamic jobOrderId,
  ) async {
    final job = jobOrders.firstWhere(
      (j) => (j['job_order_id']?.toString() == jobOrderId.toString()),
      orElse: () => null,
    );
    if (job == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Job order not found.')));
      return;
    }
    final customerId = job['customer_id']?.toString() ?? '';
    final plumberId = job['plumber_id']?.toString() ?? '';
    if (customerId.isEmpty || plumberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing customer or plumber ID.')),
      );
      return;
    }
    // 1. Check if chat exists
    final chatRes = await http.get(
      Uri.parse(
        'https://aquafixsansimon.com/api/chats_util.php?customer_id=$customerId&plumber_id=$plumberId',
      ),
    );
    int? chatId;
    if (chatRes.statusCode == 200) {
      final chatData = json.decode(chatRes.body);
      if (chatData['chat_id'] != null) {
        chatId = int.tryParse(chatData['chat_id'].toString());
      }
    }
    // 2. If not, create chat
    if (chatId == null) {
      final createRes = await http.post(
        Uri.parse('https://aquafixsansimon.com/api/chats_util.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'customer_id': customerId, 'plumber_id': plumberId}),
      );
      if (createRes.statusCode == 200) {
        final chatData = json.decode(createRes.body);
        chatId = int.tryParse(chatData['chat_id'].toString());
      }
    }
    if (chatId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to start chat.')));
      return;
    }
    final customerName = job['customer_name'] ?? 'Customer';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ChatDetailPage(
              userName: customerName,
              chatId: chatId,
              customerId: int.tryParse(customerId),
              plumberId: int.tryParse(plumberId),
            ),
      ),
    );
  }
}

// Add this class at the bottom of the file (outside the TaskPage class)
class _PinOutlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint paint =
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2;

    // Draw pin outline (rough approximation)
    Path pin = Path();
    pin.moveTo(w * 0.5, h * 0.08);
    pin.cubicTo(w * 0.85, h * 0.08, w * 0.95, h * 0.38, w * 0.5, h * 0.95);
    pin.cubicTo(w * 0.05, h * 0.38, w * 0.15, h * 0.08, w * 0.5, h * 0.08);
    canvas.drawPath(pin, paint);

    // Draw center circle
    canvas.drawCircle(Offset(w * 0.5, h * 0.38), w * 0.14, paint);

    // Draw oval base
    Rect ovalRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.97),
      width: w * 0.55,
      height: h * 0.13,
    );
    canvas.drawOval(ovalRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Add this class at the bottom of the file (outside the TaskPage class)
class _CircleBelowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..color = Colors.black12
          ..style = PaintingStyle.fill;
    // Draw an oval (shadow) below the button
    Rect ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width,
      height: size.height * 0.7,
    );
    canvas.drawOval(ovalRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Add these classes at the bottom of the file (outside TaskPage class):

class _FullImageViewNetwork extends StatelessWidget {
  final String imageUrl;
  const _FullImageViewNetwork({required this.imageUrl, Key? key})
    : super(key: key);

  Future<void> _downloadImage(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/downloaded_image.jpg');
        await file.writeAsBytes(bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image downloaded to ${file.path}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to download image')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: Colors.white),
            onPressed: () => _downloadImage(context),
            tooltip: 'Download',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: 80.h),
        child: Center(
          child: InteractiveViewer(
            panEnabled: true,
            scaleEnabled: true,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              width: 1.sw,
              height: 0.8.sh,
            ),
          ),
        ),
      ),
    );
  }
}

class _FullVideoViewNetwork extends StatefulWidget {
  final String videoUrl;
  const _FullVideoViewNetwork({required this.videoUrl, Key? key})
    : super(key: key);

  @override
  State<_FullVideoViewNetwork> createState() => _FullVideoViewNetworkState();
}

class _FullVideoViewNetworkState extends State<_FullVideoViewNetwork> {
  late VideoPlayerController _videoPlayerController;
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _hideTimer;
  double? _aspectRatio;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    _videoPlayerController
        .initialize()
        .then((_) {
          setState(() {
            _isInitialized = true;
            _aspectRatio =
                _videoPlayerController.value.aspectRatio > 0
                    ? _videoPlayerController.value.aspectRatio
                    : (9 / 16);
            _videoPlayerController.play();
          });
          if (_videoPlayerController.value.isPlaying) {
            _hideControlsAfterDelay();
          }
        })
        .catchError((error) {
          setState(() {
            _videoError = error.toString();
          });
        });

    _videoPlayerController.addListener(() {
      if (mounted) setState(() {});
      if (_videoPlayerController.value.hasError) {
        setState(() {
          _videoError =
              _videoPlayerController.value.errorDescription ??
              "Video playback error";
        });
      }
      if (_videoPlayerController.value.isPlaying && _showControls) {
        _hideControlsAfterDelay();
      }
    });
  }

  void _hideControlsAfterDelay() {
    _hideTimer?.cancel();
    if (_videoPlayerController.value.isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  Future<void> _downloadVideo(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(widget.videoUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/downloaded_video.mp4');
        await file.writeAsBytes(bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video downloaded to ${file.path}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to download video')));
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child:
                _videoError != null
                    ? Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48.sp,
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'Failed to play video.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            _videoError!,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13.sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                    : _isInitialized
                    ? AspectRatio(
                      aspectRatio: _aspectRatio ?? (9 / 16),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              setState(() {
                                _showControls = !_showControls;
                                if (_showControls &&
                                    _videoPlayerController.value.isPlaying) {
                                  _hideControlsAfterDelay();
                                } else if (!_showControls) {
                                  _hideTimer?.cancel();
                                }
                              });
                            },
                            child: VideoPlayer(_videoPlayerController),
                          ),
                          if (_showControls)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: null,
                              bottom: null,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.replay_10,
                                      color: Colors.white,
                                      size: 38.sp,
                                    ),
                                    onPressed: () {
                                      final current =
                                          _videoPlayerController.value.position;
                                      final newPosition =
                                          current - Duration(seconds: 10);
                                      _videoPlayerController.seekTo(
                                        newPosition > Duration.zero
                                            ? newPosition
                                            : Duration.zero,
                                      );
                                    },
                                  ),
                                  SizedBox(width: 16.w),
                                  IconButton(
                                    icon: Icon(
                                      _videoPlayerController.value.isPlaying
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_filled,
                                      color: Colors.white,
                                      size: 48.sp,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        if (_videoPlayerController
                                            .value
                                            .isPlaying) {
                                          _videoPlayerController.pause();
                                          _showControls = true;
                                          _hideTimer?.cancel();
                                        } else {
                                          _videoPlayerController.play();
                                          _hideControlsAfterDelay();
                                        }
                                      });
                                    },
                                  ),
                                  SizedBox(width: 16.w),
                                  IconButton(
                                    icon: Icon(
                                      Icons.forward_10,
                                      color: Colors.white,
                                      size: 38.sp,
                                    ),
                                    onPressed: () {
                                      final current =
                                          _videoPlayerController.value.position;
                                      final duration =
                                          _videoPlayerController.value.duration;
                                      final newPosition =
                                          current + Duration(seconds: 10);
                                      _videoPlayerController.seekTo(
                                        newPosition < duration
                                            ? newPosition
                                            : duration,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          // Progress bar and timer at the very bottom
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: double.infinity,
                              color: Colors.black.withOpacity(0.7),
                              padding: EdgeInsets.only(
                                left: 0,
                                right: 0,
                                top: MediaQuery.of(context).padding.bottom,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: 8.w,
                                      right: 8.w,
                                      top: 8.h,
                                      bottom: 0,
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            _videoPlayerController
                                                    .value
                                                    .isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            color: Colors.white,
                                            size: 24.sp,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              if (_videoPlayerController
                                                  .value
                                                  .isPlaying) {
                                                _videoPlayerController.pause();
                                                _showControls = true;
                                                _hideTimer?.cancel();
                                              } else {
                                                _videoPlayerController.play();
                                                _hideControlsAfterDelay();
                                              }
                                            });
                                          },
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          "${_formatDuration(_videoPlayerController.value.position)} / ${_formatDuration(_videoPlayerController.value.duration)}",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.sp,
                                            fontFeatures: [
                                              FontFeature.tabularFigures(),
                                            ],
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(12.r),
                                        topRight: Radius.circular(12.r),
                                      ),
                                      child: VideoProgressIndicator(
                                        _videoPlayerController,
                                        allowScrubbing: true,
                                        colors: VideoProgressColors(
                                          playedColor: Colors.white,
                                          backgroundColor: Colors.white24,
                                          bufferedColor: Colors.white54,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : const CircularProgressIndicator(),
          ),
          Positioned(
            top: 50.h,
            left: 10.w,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white, size: 28.sp),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: 50.h,
            right: 10.w,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.download, color: Colors.white, size: 28.sp),
                  onPressed: () => _downloadVideo(context),
                  tooltip: 'Download',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "${d.inHours > 0 ? '${twoDigits(d.inHours)}:' : ''}$minutes:$seconds";
  }
}
