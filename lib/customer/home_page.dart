import 'package:flutter/material.dart';
import 'widgets/main_scaffold.dart';
import 'water_analysis.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../main.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io'; // Add this for File operations
import '../firebase_service.dart';
import 'notification_page.dart';
import 'plumber_page.dart';
import 'edit_profile_page.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class HomePage extends StatefulWidget {
  final int currentIndex;

  const HomePage({super.key, required this.currentIndex});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  List<dynamic> _jobOrders = [];
  List<dynamic> _waterBills = [];
  bool _loadingJobs = true;
  bool _loadingBills = true;

  int _unreadCount = 0;
  int _lastNotifCount = 0;
  String? _lastNotifId; // Track last notification id/hash/timestamp

  String _customerName = '';
  String? _currentAddress;
  loc.LocationData? _currentLocation;
  final loc.Location _location = loc.Location();
  static bool _sessionConfirmedResidency = false; // persists for app session
  bool _shownSanSimonModal = false;
  bool _hasConfirmedResidency = false; // Track residency confirmation
  List<Map<String, dynamic>> _notifications = [];

  StreamSubscription<DatabaseEvent>? _notifSubscription;

  // Add tutorial-related keys and state
  final GlobalKey _analysisKey = GlobalKey();
  final GlobalKey _requestKey = GlobalKey();
  final GlobalKey _chartKey = GlobalKey();

  bool _tutorialVisible = false;
  int _tutorialStep = 0;
  bool _tutorialHasChart = false;

  @override
  void initState() {
    super.initState();
    _loadNotifPrefs(); // <-- Load persisted notification state
    _reloadAll();
    _checkCustomerLocationAndPrompt();
    // Start tutorial check after first frame so widgets are laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowTutorial();
    });
    /*FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'default_channel_id',
              'Default',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true, // This enables sound
            ),
          ),
        );
      }
    });*/
  }

  Future<void> _loadNotifPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastNotifId = prefs.getString('last_notif_id');
      _unreadCount = prefs.getInt('unread_count') ?? 0;
    });
  }

  void _reloadAll() {
    _fetchCustomerName();
    _fetchJobOrders();
    _fetchWaterBills();
    _fetchCurrentLocation();
    _listenToNotifications();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use the global routeObserver, not a new one!
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void didPopNext() {
    // Called when coming back to this page
    _reloadAll();
  }

  Future<void> _fetchCustomerName() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    if (customerId.isEmpty) {
      setState(() {
        _customerName = '';
      });
      return;
    }
    final response = await http.get(
      Uri.parse('https://aquafixsansimon.com/api/customers.php'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> customers = json.decode(response.body);
      final customer = customers.firstWhere(
        (c) => c['customer_id'].toString() == customerId,
        orElse: () => null,
      );
      if (customer != null) {
        if (!mounted) return;
        setState(() {
          _customerName =
              ((customer['first_name'] ?? '') +
                      ' ' +
                      (customer['last_name'] ?? ''))
                  .trim();
        });
      }
    }
  }

  Future<void> _fetchJobOrders() async {
    setState(() => _loadingJobs = true);
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    if (customerId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _jobOrders = [];
        _loadingJobs = false;
      });
      return;
    }
    final response = await http.get(
      Uri.parse(
        'https://aquafixsansimon.com/api/job_orders.php?customer_id=$customerId',
      ),
    );
    if (response.statusCode == 200) {
      try {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          if (!mounted) return;
          // Sort by job_order_id descending (latest first)
          decoded.sort((a, b) {
            final int aId = int.tryParse(a['job_order_id'].toString()) ?? 0;
            final int bId = int.tryParse(b['job_order_id'].toString()) ?? 0;
            return bId.compareTo(aId);
          });
          setState(() {
            _jobOrders = decoded;
            _loadingJobs = false;
          });
        } else {
          if (!mounted) return;
          setState(() {
            _jobOrders = [];
            _loadingJobs = false;
          });
        }
      } catch (e) {
        // Response is not valid JSON (likely HTML error)
        if (!mounted) return;
        setState(() {
          _jobOrders = [];
          _loadingJobs = false;
        });
        debugPrint('Failed to decode job orders JSON: $e\n${response.body}');
      }
    } else {
      if (!mounted) return;
      setState(() {
        _jobOrders = [];
        _loadingJobs = false;
      });
    }
  }

  Future<void> _fetchWaterBills() async {
    setState(() => _loadingBills = true);
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    if (customerId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _waterBills = [];
        _loadingBills = false;
      });
      return;
    }
    final response = await http.get(
      Uri.parse(
        'https://aquafixsansimon.com/api/water_bills.php?customer_id=$customerId',
      ),
    );
    if (response.statusCode == 200) {
      if (!mounted) return;
      setState(() {
        _waterBills = json.decode(response.body);
        _loadingBills = false;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _waterBills = [];
        _loadingBills = false;
      });
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      // Check and request location service
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      // Check and request permissions
      loc.PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) return;
      }

      // Get location data
      final locationData = await _location.getLocation();
      if (!mounted) return;

      setState(() {
        _currentLocation = locationData;
      });

      // If we have coordinates, fetch the address
      if (locationData.latitude != null && locationData.longitude != null) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          locationData.latitude!,
          locationData.longitude!,
        );

        if (placemarks.isNotEmpty) {
          Placemark p = placemarks.first;

          String barangay = (p.subLocality ?? '').trim();
          String municipality = (p.locality ?? '').trim();

          // Prefer subAdministrativeArea as province
          String province = (p.subAdministrativeArea ?? '').trim();

          // If province is empty or same as municipality, fallback to administrativeArea
          if (province.isEmpty ||
              province.toLowerCase() == municipality.toLowerCase()) {
            province = (p.administrativeArea ?? '').trim();
          }

          // Remove region names like "Central Luzon"
          final regionNames = [
            'central luzon',
            'ilocos region',
            'cagayan valley',
            'calabarzon',
            'mimaropa',
            'bicol region',
            'western visayas',
            'central visayas',
            'eastern visayas',
            'zamboanga peninsula',
            'northern mindanao',
            'davao region',
            'soccsksargen',
            'caraga',
            'bangsamoro autonomous region',
            'cordillera administrative region',
            'national capital region',
          ];
          if (regionNames.contains(province.toLowerCase())) {
            province = '';
          }

          String address =
              [
                if (barangay.isNotEmpty) barangay,
                if (municipality.isNotEmpty) municipality,
                if (province.isNotEmpty) province,
              ].join(', ').trim();

          if (address.isEmpty) {
            address =
                "Turn on GPS and location permission to show your address";
          }

          setState(() {
            _currentAddress = address;
          });

          // Show modal if not San Simon, Pampanga
          if (!_shownSanSimonModal &&
              !_sessionConfirmedResidency &&
              !_isSanSimonPampanga(address) &&
              address !=
                  "Turn on GPS and location permission to show your address") {
            _shownSanSimonModal = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showSanSimonModal(context);
            });
          }
        } else {
          setState(() {
            _currentAddress =
                "Turn on GPS and location permission to show your address";
          });
        }
      } else {
        setState(() {
          _currentAddress = 'Open your GPS to get location';
        });
      }
    } catch (e) {
      setState(() {
        _currentAddress = 'Open your GPS to get location';
      });
    }
  }

  bool _isSanSimonPampanga(String address) {
    final addr = address.toLowerCase();
    return addr.contains('san simon') && addr.contains('pampanga');
  }

  void _showSanSimonModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Center(
          child: Material(
            borderRadius: BorderRadius.circular(16.r),
            color: Colors.white,
            elevation: 12,
            child: Container(
              width: 320.w,
              padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 18.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.red, size: 32.sp),
                      SizedBox(width: 8.w),
                      Text(
                        "Verify Your Residency",
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    "Are you a resident of San Simon, Pampanga? Our services are currently available only to residents of this area.",
                    style: TextStyle(fontSize: 15.sp, color: Colors.black87),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    "Your current detected location:",
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      _currentAddress ?? "Location not available",
                      style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                    ),
                  ),
                  SizedBox(height: 22.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2C9CD9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _sessionConfirmedResidency = true;
                            _shownSanSimonModal = true;
                          });
                          Navigator.of(ctx).pop();
                        },
                        child: Text(
                          "Yes, I am",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
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
    );
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _listenToNotifications() async {
    print('Setting up notifications listener...');
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    print('Listening to notifications/$customerId'); // Debug print
    if (customerId == null || customerId.isEmpty) {
      print('No customer_id found for notifications.');
      return;
    }
    final dbRef = FirebaseDatabase.instance.ref(
      'notification_customer/$customerId',
    );
    _notifSubscription = dbRef.onValue.listen(
      (event) async {
        print('Notifications snapshot: ${event.snapshot.value}');
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
        } else if (data is Map &&
            data.containsKey('body') &&
            data.containsKey('title')) {
          notifs = [
            {
              'title': data['title'] ?? '',
              'body': data['body'] ?? '',
              'timestamp': data['timestamp'] ?? '',
              'viewed': data['viewed'] ?? false,
            },
          ];
        }
        notifs = notifs.reversed.toList(); // Newest first

        int unreadCount = notifs.where((n) => n['viewed'] == false).length;

        // Find the latest notification id/hash/timestamp
        String? latestId;
        if (notifs.isNotEmpty) {
          // Use timestamp + title + body as a unique id
          final latest = notifs.first;
          latestId =
              '${latest['timestamp']}_${latest['title']}_${latest['body']}';
        }

        /* Show local notification and update badge if new notification arrives
        if (notifs.isNotEmpty && latestId != null && latestId != _lastNotifId) {
          final latest = notifs.first;
          flutterLocalNotificationsPlugin.show(
            latest.hashCode,
            latest['title'],
            latest['body'],
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'default_channel_id',
                'Default',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
              ),
            ),
          );
          if (!mounted) return;
          setState(() {
            _unreadCount++;
            _lastNotifId = latestId;
            _lastNotifCount = notifs.length;
          });
          // Persist lastNotifId and unreadCount
          final prefs = await SharedPreferences.getInstance();
          prefs.setString('last_notif_id', latestId);
          prefs.setInt('unread_count', _unreadCount);
        } else {
          if (!mounted) return;
          setState(() {
            _lastNotifCount = notifs.length;
          });
        }*/

        if (!mounted) return;
        setState(() {
          _notifications = notifs;
          _unreadCount = unreadCount;
        });
        // Persist unread count
        final prefs = await SharedPreferences.getInstance();
        prefs.setInt('unread_count', unreadCount);
      },
      onError: (error) {
        print('Firebase DB error: $error');
      },
    );
  }

  void _showNotificationsModal(BuildContext context) async {
    print('Showing notifications modal with: $_notifications'); // Debug print
    final screenSize = MediaQuery.of(context).size;

    // Set all notifications as viewed when modal is opened
    _setAllNotificationsViewed();

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
              height: screenSize.height * 0.7,
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
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              _getNotifIcon(notif['title']),
                                              SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  notif['title'] ?? '',
                                                  style: TextStyle(
                                                    fontSize: 16,
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
                                              fontSize: 15,
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
                                              SizedBox(width: 4),
                                              Text(
                                                notif['timestamp'] != null
                                                    ? notif['timestamp']
                                                        .toString()
                                                        .substring(0, 16)
                                                    : '',
                                                style: TextStyle(
                                                  fontSize: 13,
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
    // Persist unread count and lastNotifId as "read"
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('unread_count', 0);
    if (_notifications.isNotEmpty) {
      final latest = _notifications.first;
      final latestId =
          '${latest['timestamp']}_${latest['title']}_${latest['body']}';
      prefs.setString('last_notif_id', latestId);
      _lastNotifId = latestId;
    }
  }

  Icon _getNotifIcon(String? title) {
    if (title != null && title.toLowerCase().contains('accomplished')) {
      return Icon(Icons.verified, color: Colors.green, size: 20);
    } else if (title != null && title.toLowerCase().contains('created')) {
      return Icon(Icons.hourglass_top, color: Color(0xFF2D9FD0), size: 20);
    } else if (title != null && title.toLowerCase().contains('cancelled')) {
      return Icon(Icons.cancel, color: Colors.red, size: 20);
    }
    return Icon(Icons.notifications_active, color: Color(0xFF2D9FD0), size: 20);
  }

  void _setAllNotificationsViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    if (customerId == null || customerId.isEmpty) return;
    final dbRef = FirebaseDatabase.instance.ref(
      'notification_customer/$customerId',
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

  void _showJobOrderDetailsModal(BuildContext context, dynamic job) async {
    // Fetch attachments from backend (same as my_job_orders_page)
    List<dynamic> attachments = [];
    try {
      print(
        'Fetching attachments for job_order_id: ${job['job_order_id'] ?? job['jo_number']}',
      );
      final resp = await http.get(
        Uri.parse(
          'https://aquafixsansimon.com/api/jo_media_list.php?job_order_id=${job['job_order_id'] ?? job['jo_number']}',
        ),
      );
      print('Attachments API response status: ${resp.statusCode}');
      print('Attachments API response body: ${resp.body}');
      if (resp.statusCode == 200) {
        try {
          final decoded = json.decode(resp.body);
          print('Decoded attachments: $decoded');
          if (decoded is List && decoded.isNotEmpty) {
            attachments = decoded;
          }
        } catch (e) {
          print(
            'Error decoding attachments JSON: $e\nRAW RESPONSE:\n${resp.body}',
          );
          print(
            'First 200 chars of response: ${resp.body.substring(0, resp.body.length > 200 ? 200 : resp.body.length)}',
          );
        }
      } else {
        print('Attachment API error: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      print('Error fetching attachments: $e');
    }

    showDialog(
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
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Account Number: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(
                          text:
                              '${job['account_number'] ?? job['account_no'] ?? ''}',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Account Name: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(text: '${job['account_name'] ?? ''}'),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Meter Number: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(text: '${job['meter_no'] ?? ''}'),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Reason/Issue: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(text: '${job['category'] ?? ''}'),
                      ],
                    ),
                  ),
                  if ((job['other_issue'] ?? '').toString().isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 15.sp, color: Colors.black),
                        children: [
                          TextSpan(
                            text: 'Other Issue: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15.sp,
                            ),
                          ),
                          TextSpan(text: '${job['other_issue']}'),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Status: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(text: '${job['status'] ?? ''}'),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Date: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(
                          text: _formatDate(job['date'], job['created_at']),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Plumber: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(
                          text:
                              ((job['plumber_first_name'] ?? '')
                                          .toString()
                                          .trim()
                                          .isEmpty &&
                                      (job['plumber_last_name'] ?? '')
                                          .toString()
                                          .trim()
                                          .isEmpty)
                                  ? 'Unassigned'
                                  : '${job['plumber_first_name'] ?? ''} ${job['plumber_last_name'] ?? ''}',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 15.sp, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Address: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        TextSpan(
                          text: [
                                job['account_label'] ?? '',
                                job['street'] ?? '',
                                job['barangay'] ?? '',
                                job['municipality'] ?? '',
                                job['province'] ?? '',
                              ]
                              .where(
                                (e) =>
                                    e != null && e.toString().trim().isNotEmpty,
                              )
                              .join(', '),
                        ),
                      ],
                    ),
                  ),
                  if ((job['notes'] ?? '').toString().isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 15.sp, color: Colors.black),
                        children: [
                          TextSpan(
                            text: 'Notes: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15.sp,
                            ),
                          ),
                          TextSpan(text: '${job['notes']}'),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 18.h),
                  // Attachments section (copied from my_job_orders_page, with label logic)
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: () {
                        int imageCount = 1;
                        int videoCount = 1;
                        return attachments.map<Widget>((att) {
                          final isImage = att['media_type'] == 'image';
                          final isVideo = att['media_type'] == 'video';
                          final fileName = att['file_path'] ?? '';
                          final url =
                              'https://aquafixsansimon.com/uploads/jo_media/$fileName';
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
                          return Padding(
                            padding: EdgeInsets.only(bottom: 8.h),
                            child: GestureDetector(
                              onTap: () {
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
                        }).toList();
                      }(),
                    ),
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

  Future<void> _checkCustomerLocationAndPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    if (customerId == null) return;

    final ref = FirebaseDatabase.instance.ref(
      'locations/customers/$customerId',
    );
    final snapshot = await ref.get();

    if (snapshot.exists && snapshot.value is Map) {
      final data = snapshot.value as Map;
      final lat = data['lat'];
      final lng = data['lng'];
      if (lat != null && lng != null) {
        // Location exists, optionally show "Track Plumber" button
        setState(() {
          // You can set a flag here to show a button in the UI
        });
        return;
      }
    }

    // Location does not exist, show modal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSetLocationModal(context);
    });
  }

  void _showSetLocationModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Center(
          child: Material(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            elevation: 16,
            child: Container(
              width: 340,
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_searching,
                    color: Color(0xFF2D9FD0),
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Set Your Location",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "To use plumber tracking and other location-based features, please set your exact address.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2D9FD0),
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(Icons.pin_drop),
                    label: Text(
                      "Set Location Now",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => PlumberPage(
                                currentIndex: 1, // <-- Set to plumber tab index
                              ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                    child: Text(
                      "Maybe Later",
                      style: TextStyle(color: Colors.grey[700], fontSize: 15),
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

  Widget _buildStatusCard(BuildContext context) {
    return Container(
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Color.fromARGB(80, 45, 159, 208), // Outline color
            width: 1, // Outline thickness
          ),
        ),
        shadowColor: Colors.black.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFF2D9FD0).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF2D9FD0),
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 18),
              // Text + CTA
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finish Account Registration',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D9FD0),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Complete your profile to unlock all features and get personalized service.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 5),
                        Text(
                          'Secure & private',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2D9FD0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.sp,
                          vertical: 10.sp,
                        ),
                        textStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        minimumSize: Size(0, 0),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EditProfilePage()),
                        );
                      },
                      child: Text('Complete Now'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobOrderSection(BuildContext context) {
    // Always show Quick Request card, even if no job orders
    final quickRequestCard = Container(
      key: _requestKey,
      child: GestureDetector(
        onTap: () async {
          // Fetch customer data by ID (single customer API)
          final prefs = await SharedPreferences.getInstance();
          final customerId = prefs.getString('customer_id') ?? '';
          if (customerId.isEmpty) return;

          final response = await http.get(
            Uri.parse(
              'https://aquafixsansimon.com/api/customers.php?customer_id=$customerId',
            ),
          );
          if (response.statusCode == 200) {
            final customer = json.decode(response.body);
            final status =
                (customer['account_status'] ?? '').toString().toLowerCase();
            if (status == 'suspended') {
              // Show suspended modal
              showDialog(
                context: context,
                barrierDismissible: true,
                builder:
                    (ctx) => Center(
                      child: Material(
                        borderRadius: BorderRadius.circular(18.r),
                        color: Colors.white,
                        elevation: 16,
                        child: Container(
                          width: 340.w,
                          padding: EdgeInsets.fromLTRB(28.w, 32.h, 28.w, 24.h),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.block,
                                color: Colors.redAccent,
                                size: 48.sp,
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                "Account Suspended",
                                style: TextStyle(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                "Your account is temporarily suspended and you cannot request a job order at this time.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 18.h),
                              Container(
                                padding: EdgeInsets.all(10.w),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.redAccent,
                                      size: 22.sp,
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        "Please contact support for assistance or wait for further updates.",
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 22.h),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF2D9FD0),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 12.h,
                                    ),
                                  ),
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: Text(
                                    "OK",
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
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
              return;
            }
            // If not suspended, proceed to job request form
            Navigator.pushNamed(context, '/jobRequestForm');
          } else {
            // Fallback: show error modal
            showDialog(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: Text("Error"),
                    content: Text(
                      "Unable to verify account status. Please try again.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text("OK"),
                      ),
                    ],
                  ),
            );
          }
        },
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.add_circle,
                      color: const Color.fromARGB(255, 153, 153, 153),
                      size: 32.sp,
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'Request Job Order',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.chevron_right,
                  color: const Color.fromARGB(255, 153, 153, 153),
                  size: 25.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (_loadingJobs) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_jobOrders.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [quickRequestCard],
      );
    }
    // Show up to 2 latest job orders
    final jobs = _jobOrders.take(1).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        quickRequestCard,
        ...jobs.map((job) {
          String title =
              job['category'] == 'Others'
                  ? 'Others${(job['other_issue'] != null && job['other_issue'].toString().isNotEmpty) ? ' (${job['other_issue']})' : ''}'
                  : job['category'] ?? '';
          // Use created_at only for date display
          String date = _formatShortMonthDate(job['created_at'], null);
          return GestureDetector(
            onTap: () => _showJobOrderDetailsModal(context, job),
            child: _buildSingleJobCard(
              title: title,
              status: _getStatusText(job['status']),
              statusColor: _getStatusColor(job['status']),
              date: date,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildImportantCard(BuildContext context) {
    return Container(
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Color.fromARGB(80, 45, 159, 208), // Outline color
            width: 1, // Outline thickness
          ),
        ),
        shadowColor: Colors.black.withOpacity(0.08),
        color: Color(0xFFF7FBFF),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFF2D9FD0).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(8.sp),
                child: Icon(
                  Icons.water_drop,
                  color: Color(0xFF2D9FD0),
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 18),
              // Text + CTA
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Water Insights',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D9FD0),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'See how your water usage changes over time and discover smarter ways to save.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2D9FD0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 10.h,
                        ),
                        minimumSize: Size(0, 0),
                        textStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WaterAnalysisPage(),
                          ),
                        );
                      },
                      child: Text('Explore', style: TextStyle(fontSize: 13.sp)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(dynamic status) {
    final s = (status ?? '').toString().toLowerCase();
    if (s == 'accomplished') return 'Accomplished';
    if (s == 'dispatched' || s == 'ongoing') return 'Ongoing';
    if (s == 'pending') return 'Pending';
    if (s == 'cancelled') return 'Cancelled';
    return s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accomplished':
        return Colors.green;
      case 'ongoing':
      case 'dispatched':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.black;
    }
  }

  Widget _buildSingleJobCard({
    required String title,
    required String status,
    required Color statusColor,
    required String date,
  }) {
    // Restore the previous card design, only update the status design to match my_job_orders_page
    final displayStatus =
        (status.toLowerCase() == 'dispatched') ? 'Ongoing' : status;
    final displayStatusColor = _getStatusColor(status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description,
                  color: const Color.fromARGB(255, 153, 153, 153),
                  size: 32.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title, style: TextStyle(fontSize: 16.sp)),
                          const Spacer(),
                          Text(
                            date,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: displayStatusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              displayStatus,
                              style: TextStyle(
                                color: displayStatusColor,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterBillCard() {
    if (_loadingBills) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_waterBills.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16.w),
        child: Text(
          "No water bill data found. Please add your bill.",
          style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
        ),
      );
    }

    // Helper for month index
    int monthIdx(String month) {
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      final idx = months.indexWhere(
        (m) => m.toLowerCase().startsWith(month.toLowerCase().substring(0, 3)),
      );
      return idx >= 0 ? idx : 0;
    }

    // Sort bills by year/month descending
    final bills = List<Map<String, dynamic>>.from(_waterBills);
    bills.sort((a, b) {
      final ay = int.tryParse(a['year'].toString()) ?? 0;
      final by = int.tryParse(b['year'].toString()) ?? 0;
      final am = monthIdx(a['month'] ?? '');
      final bm = monthIdx(b['month'] ?? '');
      if (by != ay) return by.compareTo(ay);
      return bm.compareTo(am);
    });

    // Find the latest streak of consecutive months (max 5, min 1)
    List<Map<String, dynamic>> streak = [];
    if (bills.isNotEmpty) {
      streak.add(bills.first);
      int prevYear = int.tryParse(bills.first['year'].toString()) ?? 0;
      int prevMonth = monthIdx(bills.first['month'] ?? '');
      for (int i = 1; i < bills.length && streak.length < 5; i++) {
        int currYear = int.tryParse(bills[i]['year'].toString()) ?? 0;
        int currMonth = monthIdx(bills[i]['month'] ?? '');
        // Check for consecutive month
        bool isConsecutive =
            (currYear == prevYear && currMonth == prevMonth - 1) ||
            (currYear == prevYear - 1 && prevMonth == 0 && currMonth == 11);
        if (isConsecutive) {
          streak.add(bills[i]);
          prevYear = currYear;
          prevMonth = currMonth;
        } else {
          break; // Stop at first gap
        }
      }
    }
    if (streak.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16.w),
        child: Text(
          "No consecutive water bill data found.",
          style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
        ),
      );
    }
    streak = streak.reversed.toList();

    final billData =
        streak.map((e) => (e['amount'] as num?)?.toDouble() ?? 0.0).toList();
    final months =
        streak
            .map((e) => (e['month'] ?? '').toString().substring(0, 3))
            .toList();
    final currentBill = billData.isNotEmpty ? billData.last : 0.0;
    final prevBill = billData.length > 1 ? billData[billData.length - 2] : 0.0;
    final trendUp = currentBill > prevBill;
    final trendDown = currentBill < prevBill;
    double fluctuation = 0.0;
    if (prevBill > 0) {
      fluctuation = ((currentBill - prevBill) / prevBill) * 100;
    }
    String fluctuationText = '';
    if (trendUp && prevBill > 0) {
      fluctuationText =
          "Up from last month by ${fluctuation.abs().toStringAsFixed(2)}%";
    } else if (trendDown && prevBill > 0) {
      fluctuationText =
          "Down from last month by ${fluctuation.abs().toStringAsFixed(2)}%";
    } else if (prevBill > 0) {
      fluctuationText = "No change from last month";
    } else {
      fluctuationText = "";
    }
    final trendColor =
        trendUp ? Colors.red : (trendDown ? Colors.green : Colors.grey);

    // Calculate maxY and interval for 5 labels (including 0)
    double maxBill =
        billData.isNotEmpty ? billData.reduce((a, b) => a > b ? a : b) : 600;
    double interval;
    if (maxBill <= 0) {
      interval = 200;
      maxBill = interval * 4;
    } else {
      interval = (maxBill / 4).ceilToDouble();
      if (interval > 100) {
        interval = (interval / 100).ceil() * 100;
      } else if (interval > 50) {
        interval = (interval / 50).ceil() * 50;
      } else {
        interval = (interval / 10).ceil() * 10;
      }
      maxBill = interval * 4;
      if (billData.isNotEmpty &&
          billData.reduce((a, b) => a > b ? a : b) > maxBill) {
        maxBill += interval;
      }
    }

    final barCount = billData.length;

    // Adjust width based on bar count (fewer bars → wider, but not too wide if only 1)
    double barWidth;
    if (barCount == 1) {
      barWidth = 0.10; // much narrower for single bar
    } else if (barCount < 4) {
      barWidth = 0.35; // medium width for 2–3 bars
    } else {
      barWidth = 0.55; // thinner for 4–5 bars
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bar Chart Card - LEFT
        SizedBox(
          width: 200.w, // Increased from 190.w for more space
          key: _chartKey,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(0.w, 8.h, 0.w, 0.h),
              child: SizedBox(
                height: 140.h,
                child: SfCartesianChart(
                  plotAreaBorderWidth: 0,
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    format: 'point.y',
                    header: '',
                  ),
                  primaryXAxis: CategoryAxis(
                    majorGridLines: const MajorGridLines(width: 0),
                    labelStyle: TextStyle(fontSize: 11.sp),
                    interval: 1,
                    edgeLabelPlacement: EdgeLabelPlacement.shift,
                    labelRotation: 0, // Try 0, 30, or 45 for angled labels
                  ),
                  primaryYAxis: NumericAxis(
                    minimum: 0,
                    maximum: maxBill,
                    interval: interval,
                    labelStyle: TextStyle(fontSize: 12.sp),
                    axisLine: const AxisLine(width: 0),
                    majorTickLines: const MajorTickLines(size: 0),
                  ),
                  series: <CartesianSeries<_BillBarData, String>>[
                    ColumnSeries<_BillBarData, String>(
                      dataSource: List.generate(barCount, (index) {
                        return _BillBarData(months[index], billData[index]);
                      }),
                      xValueMapper: (data, _) => data.month,
                      yValueMapper: (data, _) => data.amount,
                      pointColorMapper:
                          (_, __) => const Color.fromRGBO(45, 159, 208, 1),
                      borderRadius: BorderRadius.circular(4.r),
                      width: barWidth,
                      spacing:
                          barCount == 1
                              ? 0
                              : 0.2, // no spacing needed for 1 bar
                      enableTooltip: true,
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 4.w),
        // Current Bill Card - RIGHT
        Expanded(
          flex: 1,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: SizedBox(
              height: 152.h,
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Bill', style: TextStyle(fontSize: 16.sp)),
                    SizedBox(height: 4.h),
                    Text(
                      '₱${currentBill.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      fluctuationText,
                      style: TextStyle(color: trendColor, fontSize: 13.sp),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  int _monthIndex(dynamic month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (month == null) return 0;
    final idx = months.indexWhere(
      (m) => m.toLowerCase().startsWith(
        month.toString().toLowerCase().substring(0, 3),
      ),
    );
    return idx >= 0 ? idx : 0;
  }

  String _formatDate(dynamic date, dynamic createdAt) {
    String? raw =
        (date != null &&
                date.toString().isNotEmpty &&
                date.toString().toLowerCase() != 'null')
            ? date.toString()
            : (createdAt != null ? createdAt.toString() : null);
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') return '';
    try {
      final dt = DateTime.parse(raw);
      return "${_monthName(dt.month)} ${dt.day}, ${dt.year}";
    } catch (_) {
      return raw;
    }
  }

  String _monthName(int month) {
    const monthNames = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return (month >= 1 && month <= 12) ? monthNames[month] : '';
  }

  String _formatShortMonthDate(dynamic date, dynamic createdAt) {
    String? raw =
        (date != null &&
                date.toString().isNotEmpty &&
                date.toString().toLowerCase() != 'null')
            ? date.toString()
            : (createdAt != null ? createdAt.toString() : null);
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') return '';
    try {
      final dt = DateTime.parse(raw);
      const shortMonths = [
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
      String month =
          (dt.month >= 1 && dt.month <= 12) ? shortMonths[dt.month] : '';
      return "${month} ${dt.day}, ${dt.year}";
    } catch (_) {
      return raw;
    }
  }

  Future<void> _maybeShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    if (customerId == null || customerId.isEmpty) return;
    final dbRef = FirebaseDatabase.instance.ref('tutorials/$customerId/home');
    final snapshot = await dbRef.get();
    final shown = snapshot.value == true;
    if (!shown) return;
    _tutorialHasChart = _waterBills.isNotEmpty;
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() {
      _tutorialVisible = true;
      _tutorialStep = 0;
    });
  }

  Rect? _getWidgetRect(GlobalKey key) {
    try {
      final ctx = key.currentContext;
      if (ctx == null) return null;
      final renderBox = ctx.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return null;
      final pos = renderBox.localToGlobal(Offset.zero);
      return Rect.fromLTWH(
        pos.dx,
        pos.dy,
        renderBox.size.width,
        renderBox.size.height,
      );
    } catch (_) {
      return null;
    }
  }

  void _advanceTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    final steps = _tutorialHasChart ? 3 : 2;
    if (_tutorialStep >= steps - 1) {
      // finish: set home to false in Firebase
      if (customerId != null && customerId.isNotEmpty) {
        final dbRef = FirebaseDatabase.instance.ref(
          'tutorials/$customerId/home',
        );
        await dbRef.set(false);
      }
      if (!mounted) return;
      setState(() {
        _tutorialVisible = false;
        _tutorialStep = 0;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _tutorialStep += 1;
      });
    }
  }

  Widget _buildTutorialOverlay() {
    // step -> target key and message
    final keys = [_analysisKey, _requestKey];
    if (_tutorialHasChart) keys.add(_chartKey);

    final messages = [
      'Tap here to open Analysis. View smart water insights and trends.',
      'Tap here to request a job order quickly for plumbing support.',
      'This is your water usage graph. Monitor recent bills and trends here.',
    ];

    final stepKey = (_tutorialStep < keys.length) ? keys[_tutorialStep] : null;
    final rect = stepKey != null ? _getWidgetRect(stepKey) : null;

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _advanceTutorial,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenW = constraints.maxWidth;
              final screenH = constraints.maxHeight;

              // Default bubble values
              const double horizPadding = 24;
              final double bubbleMaxWidth = (screenW - horizPadding * 2).clamp(
                0,
                360,
              );
              const double bubbleGap = 8;
              final message =
                  (_tutorialStep < messages.length)
                      ? messages[_tutorialStep]
                      : '';

              double bubbleLeft = (screenW - bubbleMaxWidth) / 2;
              double bubbleTop = screenH - 120; // fallback
              bool placeAbove = false;
              double tailCenterX = screenW / 2;
              if (rect != null) {
                final centerX = rect.left + rect.width / 2;
                tailCenterX = centerX.clamp(
                  horizPadding + 12,
                  screenW - horizPadding - 12,
                );
                bubbleLeft = (centerX - bubbleMaxWidth / 2).clamp(
                  horizPadding,
                  screenW - horizPadding - bubbleMaxWidth,
                );

                // Special case: always place bubble below analysis for step 0
                if (_tutorialStep == 0) {
                  bubbleTop = rect.top + rect.height + bubbleGap + 12;
                  placeAbove = false;
                } else {
                  // try placing below rect
                  bubbleTop = rect.top + rect.height + bubbleGap + 12;
                  // if the bubble would overflow bottom, place above
                  final estimatedBubbleHeight = 110.0;
                  if (bubbleTop + estimatedBubbleHeight > screenH - 28) {
                    placeAbove = true;
                    bubbleTop =
                        rect.top - estimatedBubbleHeight - bubbleGap - 12;
                  }
                }
              }

              return Stack(
                children: [
                  // dim background except highlight
                  if (rect != null) ...[
                    Positioned(
                      left: 0,
                      top: 0,
                      right: 0,
                      height: rect.top - 8,
                      child: Container(color: Colors.black54),
                    ),
                    Positioned(
                      left: 0,
                      top: rect.top + rect.height + 8,
                      right: 0,
                      bottom: 0,
                      child: Container(color: Colors.black54),
                    ),
                    Positioned(
                      left: 0,
                      top: rect.top - 8,
                      width: rect.left - 8,
                      height: rect.height + 16,
                      child: Container(color: Colors.black54),
                    ),
                    Positioned(
                      left: rect.left + rect.width + 8,
                      top: rect.top - 8,
                      right: 0,
                      height: rect.height + 16,
                      child: Container(color: Colors.black54),
                    ),
                    // Transparent highlight border
                    Positioned(
                      left: rect.left - 8,
                      top: rect.top - 8,
                      width: rect.width + 16,
                      height: rect.height + 16,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ] else
                    Container(color: Colors.black54),

                  // Bubble + tail positioned relative to rect (or anchored bottom center when rect null)

                  // Special-case step 0: place triangle and bubble absolutely in the Stack
                  if (_tutorialStep == 0 && rect != null) ...[
                    // Triangle tail at bottom-center of analysis button
                    Positioned(
                      left:
                          rect.left + rect.width / 2 - 9, // half triangle width
                      top: rect.top + rect.height,
                      child: CustomPaint(
                        size: const Size(18, 10),
                        painter: _TrianglePainter(
                          color: Colors.white,
                          pointingUp: true,
                        ),
                      ),
                    ),
                    // Bubble below the triangle
                    Positioned(
                      left: (rect.left + rect.width / 2 - bubbleMaxWidth / 2)
                          .clamp(
                            horizPadding,
                            screenW - horizPadding - bubbleMaxWidth,
                          ),
                      top: rect.top + rect.height + 10, // triangle height
                      child: Container(
                        width: bubbleMaxWidth,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                    // "Tap to continue" row below bubble
                    Positioned(
                      left: 0,
                      right: 0,
                      top:
                          rect.top +
                          rect.height +
                          10 +
                          82, // bubble height estimate
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.touch_app, color: Colors.white, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Tap to continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else
                    // Non-step-0 behavior: keep single Positioned with Column content
                    Positioned(
                      left: bubbleLeft,
                      top: bubbleTop.clamp(12.0, screenH - 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (placeAbove)
                            Column(
                              children: [
                                // bubble above target
                                Container(
                                  width: bubbleMaxWidth,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    message,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                                Align(
                                  alignment: Alignment(
                                    ((tailCenterX - bubbleLeft) /
                                                bubbleMaxWidth *
                                                2 -
                                            1)
                                        .clamp(-1.0, 1.0),
                                    0,
                                  ),
                                  child: CustomPaint(
                                    size: const Size(18, 10),
                                    painter: _TrianglePainter(
                                      color: Colors.white,
                                      pointingUp: false,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 18.h),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.touch_app,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Tap to continue',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                Align(
                                  alignment: Alignment(
                                    ((tailCenterX - bubbleLeft) /
                                                bubbleMaxWidth *
                                                2 -
                                            1)
                                        .clamp(-1.0, 1.0),
                                    0,
                                  ),
                                  child: CustomPaint(
                                    size: const Size(18, 10),
                                    painter: _TrianglePainter(
                                      color: Colors.white,
                                      pointingUp: true,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: bubbleMaxWidth,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    message,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                                SizedBox(height: 18),

                                Icon(
                                  Icons.touch_app,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Tap to continue',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double safeTop = MediaQuery.of(context).padding.top;
    final double headerHeight = 160.h;

    // Wrap with AnnotatedRegion for status bar style
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: MainScaffold(
        currentIndex: widget.currentIndex,
        overlay:
            _tutorialVisible
                ? DefaultTextStyle(
                  style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'PlusJakartaSans',
                        color: Colors.black87,
                      ) ??
                      const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        color: Colors.black87,
                      ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: _buildTutorialOverlay(),
                  ),
                )
                : null,
        body: Stack(
          children: [
            // Header background (at the very top)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: headerHeight + safeTop,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/homepage-header.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            // Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header content, below the status bar
                Padding(
                  padding: EdgeInsets.only(top: safeTop),
                  child: Container(
                    height: headerHeight,
                    color: Colors.transparent,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(22.w, 16.h, 22.w, 16.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Greeting and Icons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hello,',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18.sp,
                                    ),
                                  ),
                                  Text(
                                    _customerName.isNotEmpty
                                        ? _customerName
                                        : '...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: () {
                                        final nameWords = _customerName
                                            .trim()
                                            .split(RegExp(r'\s+'));
                                        final nameLength =
                                            _customerName
                                                .replaceAll(' ', '')
                                                .length;

                                        if (nameWords.length >= 3) {
                                          return 22.sp;
                                        } else if (nameWords.length == 2 &&
                                            nameLength >= 16) {
                                          return 22.sp;
                                        } else {
                                          return 28.sp;
                                        }
                                      }(),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  // mark Analysis button for tutorial
                                  Container(
                                    key: _analysisKey,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          PageRouteBuilder(
                                            pageBuilder:
                                                (_, __, ___) =>
                                                    const WaterAnalysisPage(),
                                            transitionsBuilder: (
                                              _,
                                              animation,
                                              __,
                                              child,
                                            ) {
                                              const begin = Offset(1.0, 0.0);
                                              const end = Offset.zero;
                                              final tween = Tween(
                                                begin: begin,
                                                end: end,
                                              ).chain(
                                                CurveTween(
                                                  curve: Curves.easeInOut,
                                                ),
                                              );
                                              return SlideTransition(
                                                position: animation.drive(
                                                  tween,
                                                ),
                                                child: child,
                                              );
                                            },
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(30.r),
                                      child: CircleAvatar(
                                        radius: 20.r,
                                        backgroundColor: const Color.fromARGB(
                                          255,
                                          255,
                                          255,
                                          255,
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(11.0.w),
                                          child: Image.asset(
                                            'assets/icons/Water_Analysis.png',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _unreadCount =
                                                0; // Reset when modal is opened
                                          });
                                          _showNotificationsModal(context);
                                        },
                                        borderRadius: BorderRadius.circular(
                                          30.r,
                                        ),
                                        child: CircleAvatar(
                                          radius: 20.r,
                                          backgroundColor: Colors.white,
                                          child: Icon(
                                            Icons.notifications_outlined,
                                            color: const Color.fromRGBO(
                                              45,
                                              159,
                                              208,
                                              1,
                                            ),
                                            size: 22.sp,
                                          ),
                                        ),
                                      ),
                                      if (_unreadCount > 0)
                                        Positioned(
                                          top:
                                              -7, // slightly outside for better visual alignment
                                          right: -4,
                                          child: Container(
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            constraints: BoxConstraints(
                                              minWidth: 19,
                                              minHeight: 19,
                                            ),
                                            child: Text(
                                              '$_unreadCount',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
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
                            ],
                          ),
                          SizedBox(height: 16.h),
                          // Location
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30.r),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 18.sp,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  _currentAddress ??
                                      'Open your GPS to get location',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 6.h),
                    child: Column(
                      children: [
                        _buildImportantCard(context),
                        Row(
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 0),
                              child: Text(
                                'Job Order History',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Spacer(),
                            Padding(
                              padding: EdgeInsets.only(right: 12.w, top: 4.h),
                              child: TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/all_job_requests',
                                  );
                                },
                                style: TextButton.styleFrom(
                                  minimumSize: Size(0, 0),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 0,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'See All',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: const Color.fromRGBO(
                                      45,
                                      159,
                                      208,
                                      1,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        _buildJobOrderSection(context),
                        Row(
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                12.w,
                                4.h,
                                12.w,
                                4.h,
                              ),
                              child: Text(
                                'Water Bill Overview',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Spacer(),
                            Padding(
                              padding: EdgeInsets.only(right: 12.w, top: 4.h),
                              child: TextButton(
                                onPressed: () {
                                  WaterAnalysisPage.navigateAndShowAddModal(
                                    context,
                                  );
                                },
                                style: TextButton.styleFrom(
                                  minimumSize: Size(0, 0),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 0,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Add Bill',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: const Color.fromRGBO(
                                      45,
                                      159,
                                      208,
                                      1,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        _buildWaterBillCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    _videoPlayerController.initialize().then((_) {
      setState(() {
        _isInitialized = true;
        _videoPlayerController.play();
      });
      if (_videoPlayerController.value.isPlaying) {
        _hideControlsAfterDelay();
      }
    });
    _videoPlayerController.addListener(() {
      if (mounted) setState(() {});
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
                _isInitialized
                    ? AspectRatio(
                      aspectRatio: 9 / 16,
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
                // Remove or comment out the share button if _shareVideo is not defined
                // IconButton(
                //   icon: Icon(Icons.share, color: Colors.white, size: 28.sp),
                //   onPressed: () => _shareVideo(context),
                //   tooltip: 'Share',
                // ),
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

class _BillBarData {
  final String month;
  final double amount;
  _BillBarData(this.month, this.amount);
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  final bool pointingUp;
  _TrianglePainter({required this.color, required this.pointingUp});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (pointingUp) {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
