import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math'; // Add this for min/max and distance calculation
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart'; // <-- This is important for RenderRepaintBoundary
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:firebase_database/firebase_database.dart'; // Add this for real-time location
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/main_scaffold.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../plumber/location_service.dart'; // Import the location service

// Add at top-level (near other top-level code) a RouteObserver instance that matches usage elsewhere
final RouteObserver<PageRoute> routeObserverForPages =
    RouteObserver<PageRoute>();

class PlumberPage extends StatefulWidget {
  final int currentIndex;
  final double? customerLat;
  final double? customerLng;
  final double? plumberLat;
  final double? plumberLng;
  final String? plumberName;
  final String? plumberAvatar;
  final Uint8List? plumberProfileImageBytes;

  const PlumberPage({
    super.key,
    required this.currentIndex,
    this.customerLat,
    this.customerLng,
    this.plumberLat,
    this.plumberLng,
    this.plumberName,
    this.plumberAvatar,
    this.plumberProfileImageBytes,
  });

  @override
  State<PlumberPage> createState() => _PlumberPageState();
}

class _PlumberPageState extends State<PlumberPage>
    with WidgetsBindingObserver, RouteAware {
  GoogleMapController? mapController;
  final Location location = Location();

  LatLng? customerLatLng;
  LatLng? plumberLatLng;
  String? _plumberName;
  String? _plumberPhone;
  String? _plumberAvatar;
  Uint8List? _plumberProfileImageBytes;
  BitmapDescriptor? _plumberProfileIcon;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  StreamSubscription<LocationData>? _locationSubscription;
  StreamSubscription<DatabaseEvent>? _customerLocationSub;
  StreamSubscription? _plumberLocationSub;
  BitmapDescriptor? _profileIcon;

  bool _isLoadingLocation = true;
  Uint8List? _profileImageBytes;

  MapType _selectedMapType = MapType.hybrid;

  // For ETA and distance
  double? _distanceMeters;
  int? _etaMinutes;

  int? _jobOrderIdFromNav; // <-- Add this to store job_order_id from navigation

  // Add a field to track job status
  String? _jobOrderStatus;

  bool _plumberIconCreating = false;
  bool _customerIconCreating = false;

  // Add missing fields
  bool _showPlumberLocation = false;
  BitmapDescriptor? _customerProfileIcon;
  Uint8List? _customerProfileImageBytes;

  // Add missing field to fix the error
  String? _customerName;

  // Add missing field to fix the error
  int? _dispatchedPlumberId;

  bool _isPinningLocation = false;
  LatLng? _pinnedLocation;
  Marker? _pinMarker;

  LatLng? _plumberMarkerPos; // <-- new: actual marker position (snapped)
  Timer? _plumberUpdateDebounce;

  bool _modalOpen = false;

  // Tutorial keys and state
  final GlobalKey _pinKey = GlobalKey();
  final GlobalKey _mapTypeKey = GlobalKey();
  final GlobalKey _currentLocKey = GlobalKey();
  final GlobalKey _zoomKey = GlobalKey();

  bool _tutorialVisible = false;
  int _tutorialStep = 0;

  bool _skipFirebaseUpdates = false;
  DateTime? _lastPinnedAt;
  final Duration _pinCooldown = const Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchCustomerProfileImage();
    _initializeLocation();
    _checkNavigationFlag();
    // --- ADD THIS: ---
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final showFlag = prefs.getBool('show_plumber_location') ?? false;
      if (!showFlag) {
        _clearPlumberViewLocal();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeShowTutorial();
    });
  }

  @override
  void dispose() {
    routeObserverForPages.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _plumberLocationSub?.cancel();
    _customerLocationSub?.cancel();

    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('show_plumber_location', false);
      prefs.remove('navigate_job_order_id');
    });
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Subscribe to route changes so we get didPushNext / didPopNext callbacks
    try {
      routeObserverForPages.subscribe(
        this,
        ModalRoute.of(context)! as PageRoute,
      );
    } catch (_) {}

    // Prefer route arguments: if this page was pushed with args, honor them.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final route = ModalRoute.of(context);
      final args = route?.settings.arguments;
      if (args is Map) {
        // Get all needed data from navigation arguments (same as map_page)
        final jobOrderIdArg = args['jobOrderId'];
        final custLatArg = args['customerLat'];
        final custLngArg = args['customerLng'];
        final plumberLatArg = args['plumberLat'];
        final plumberLngArg = args['plumberLng'];
        final plumberNameArg = args['plumberName'];
        final plumberAvatarArg = args['plumberAvatar'];
        final plumberProfileImageBytesArg = args['plumberProfileImageBytes'];
        final plumberIdArg = args['plumber_id']; // <-- new: explicit plumber id

        if (custLatArg != null && custLngArg != null) {
          customerLatLng = LatLng(
            (custLatArg as num).toDouble(),
            (custLngArg as num).toDouble(),
          );
        }
        if (plumberLatArg != null && plumberLngArg != null) {
          plumberLatLng = LatLng(
            (plumberLatArg as num).toDouble(),
            (plumberLngArg as num).toDouble(),
          );
        }
        if (plumberNameArg != null) {
          _plumberName = plumberNameArg.toString();
        }
        if (plumberAvatarArg != null) {
          _plumberAvatar = plumberAvatarArg.toString();
        }
        if (plumberProfileImageBytesArg != null) {
          _plumberProfileImageBytes = plumberProfileImageBytesArg as Uint8List;
          await _createPlumberProfileMarkerIcon();
        }

        // If a plumber_id was passed, prefer it and initialize plumber data immediately.
        if (plumberIdArg != null) {
          final pid = plumberIdArg.toString();
          _dispatchedPlumberId = int.tryParse(pid);
          // Fetch profile image, average rating and subscribe to real-time location
          await _fetchPlumberProfileImage(plumberId: pid);
          _subscribeToPlumberLocation(pid);
          setState(() {
            _showPlumberLocation = true;
          });
          return;
        }

        // If no plumber_id was passed but jobOrderId was passed, keep existing behavior:
        if (jobOrderIdArg != null) {
          _jobOrderIdFromNav = int.tryParse(jobOrderIdArg.toString());
          if (_jobOrderIdFromNav != null) {
            await _fetchDispatchedPlumberIdAndSubscribe(
              jobOrderId: _jobOrderIdFromNav,
            );
          }
          setState(() {
            _showPlumberLocation = true;
          });
          return;
        }

        setState(() {
          _showPlumberLocation = true;
        });
        return;
      }

      // Otherwise re-check persisted flag and clear plumber view if flag is false.
      final prefs = await SharedPreferences.getInstance();
      final showFlag = prefs.getBool('show_plumber_location') ?? false;
      if (!showFlag && _showPlumberLocation) {
        // Clear plumber view when returning and flag is off
        if (!mounted) return;
        _clearPlumberViewLocal(); // <-- use helper to clear plumber marker/polylines
      } else if (showFlag && !_showPlumberLocation) {
        // If persisted flag is true (e.g. from previous navigation), fetch
        setState(() {
          _showPlumberLocation = true;
        });
        // REMOVE: No more _fetchDispatchedPlumberIdAndSubscribe
        // REMOVE: No more _fetchPlumberProfileImage() here
      }
    });
  }

  // Called when a new route has been pushed, and this route is no longer visible.
  @override
  void didPushNext() {
    // Clear plumber view immediately when another page is pushed on top
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_plumber_location', false);
      // Clear local plumber UI/state and cancel subscriptions
      await _clearPlumberViewLocal();
    });
  }

  // Called when the top route has been popped and this route shows again.
  @override
  void didPopNext() {
    // Re-check persisted flag and clear plumber view if needed
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final showFlag = prefs.getBool('show_plumber_location') ?? false;
      if (!showFlag) {
        _clearPlumberViewLocal();
      } else {
        if (!_showPlumberLocation) {
          setState(() {
            _showPlumberLocation = true;
          });
          // REMOVE: No more _fetchDispatchedPlumberIdAndSubscribe
          // REMOVE: No more _fetchPlumberProfileImage() here
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant PlumberPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final showFlag = prefs.getBool('show_plumber_location') ?? false;
      if (!showFlag) {
        _clearPlumberViewLocal();
      }
    });
  }

  // Local helper used by RouteAware callbacks to clear plumber view state (no prefs touch)
  Future<void> _clearPlumberViewLocal() async {
    // cancel firebase subscription and any plumber-related streams
    try {
      await _plumberLocationSub?.cancel();
    } catch (_) {}
    _plumberLocationSub = null;

    if (!mounted) return;
    setState(() {
      _showPlumberLocation = false;
      _jobOrderIdFromNav = null;
      plumberLatLng = null;
      _plumberProfileIcon = null;
      _polylines.clear();
      _markers.removeWhere((m) => m.markerId.value == 'plumber');
    });
  }

  Future<void> _prepareForPush() async {
    // Clear persisted navigation flag so when user returns only customer is shown
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_plumber_location', false);
    await prefs.remove('navigate_job_order_id');
    if (!mounted) return;
    setState(() {
      _showPlumberLocation = false;
      _jobOrderIdFromNav = null;
      plumberLatLng = null;
      _plumberProfileIcon = null;
      _polylines.clear();
      _markers.removeWhere((m) => m.markerId.value == 'plumber');
    });
  }

  Future<void> _checkNavigationFlag() async {
    // Use SharedPreferences to check if navigation was triggered
    final prefs = await SharedPreferences.getInstance();
    final showPlumberLocation = prefs.getBool('show_plumber_location') ?? false;
    final jobOrderId = prefs.getInt('navigate_job_order_id');
    setState(() {
      _showPlumberLocation = showPlumberLocation;
      _jobOrderIdFromNav = jobOrderId;
    });
    // If persisted flag indicates plumber should be shown, try to fetch plumber for that job
    if (_showPlumberLocation &&
        _jobOrderIdFromNav != null &&
        _jobOrderIdFromNav! > 0) {
      await _fetchDispatchedPlumberIdAndSubscribe(
        jobOrderId: _jobOrderIdFromNav,
      );

      // consume the navigation intent so it does not persist across other navigations
      await prefs.setBool('show_plumber_location', false);
      await prefs.remove('navigate_job_order_id');
      return;
    }

    if (!(_showPlumberLocation &&
        _jobOrderIdFromNav != null &&
        _jobOrderIdFromNav! > 0)) {
      setState(() {
        plumberLatLng = null;
        _plumberProfileIcon = null;
        _polylines.clear();
        _markers.removeWhere((m) => m.markerId.value == 'plumber');
      });
    }
  }

  Future<void> _fetchCustomerProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    if (customerId == null) return;
    final response = await http.get(
      Uri.parse('https://aquafixsansimon.com/api/customers.php'),
    );
    if (response.statusCode == 200) {
      final List users = json.decode(response.body);
      final user = users.firstWhere(
        (u) => u['customer_id'].toString() == customerId,
        orElse: () => null,
      );
      if (user != null &&
          user['profile_image'] != null &&
          user['profile_image'].toString().isNotEmpty) {
        final url =
            'https://aquafixsansimon.com/uploads/profiles/customers/${user['profile_image']}';
        final imgResp = await http.get(Uri.parse(url));
        if (imgResp.statusCode == 200) {
          _customerProfileImageBytes = imgResp.bodyBytes;
          await _createCustomerProfileMarkerIcon();
        }
      } else {
        await _loadDefaultCustomerProfileImage();
      }
    } else {
      await _loadDefaultCustomerProfileImage();
    }
  }

  Future<void> _loadDefaultCustomerProfileImage() async {
    final ByteData imageData = await rootBundle.load(
      'assets/profiles/default.jpg',
    );
    final Uint8List bytes = imageData.buffer.asUint8List();
    _customerProfileImageBytes = bytes;
    await _createCustomerProfileMarkerIcon();
  }

  Future<void> _createCustomerProfileMarkerIcon() async {
    if (_customerProfileImageBytes == null || _customerIconCreating) return;

    _customerIconCreating = true; // Set flag

    final boundaryKey = GlobalKey();
    if (!mounted) return;
    final overlay = Overlay.of(context);
    if (overlay == null) {
      _customerIconCreating = false;
      return;
    }

    OverlayEntry? entry;
    bool markerSet = false;
    bool inserted = false;

    entry = OverlayEntry(
      builder:
          (_) => Center(
            child: Material(
              type: MaterialType.transparency,
              child: RepaintBoundary(
                key: boundaryKey,
                child: ProfilePinWidget(
                  imageBytes: _customerProfileImageBytes!,
                  backgroundColor: const Color(0xFF4ADE80),
                  size: 38,
                ),
              ),
            ),
          ),
    );

    try {
      overlay.insert(entry);
      inserted = true;
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;
      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject != null && renderObject is RenderRepaintBoundary) {
        final image = await renderObject.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null && mounted && _customerProfileIcon == null) {
          // Only set if icon not already set
          final Uint8List pngBytes = byteData.buffer.asUint8List();
          setState(() {
            _customerProfileIcon = BitmapDescriptor.fromBytes(pngBytes);
          });
          markerSet = true;
          _updateMarkers();
        }
      }
    } catch (e) {
      debugPrint('Error creating customer profile icon: $e');
    } finally {
      _customerIconCreating = false; // Clear flag
      if (inserted) {
        try {
          entry.remove();
        } catch (_) {}
      }
      Future.delayed(const Duration(seconds: 2), () {
        if (!markerSet && mounted && _customerProfileIcon == null) {
          setState(() {
            _customerProfileIcon = BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            );
          });
          _updateMarkers();
        }
      });
    }
  }

  // Update this method to ONLY fetch plumber for a specific jobOrderId.
  Future<void> _fetchDispatchedPlumberIdAndSubscribe({int? jobOrderId}) async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    if (customerId == null) return;

    final response = await http.get(
      Uri.parse(
        'https://aquafixsansimon.com/api/job_orders.php?customer_id=$customerId',
      ),
    );
    if (response.statusCode == 200) {
      final List<dynamic> orders = json.decode(response.body);
      dynamic job;
      if (jobOrderId != null) {
        job = orders.firstWhere(
          (j) => int.tryParse(j['job_order_id'].toString()) == jobOrderId,
          orElse: () => null,
        );
      } else {
        // REMOVE fallback: do not fetch latest ongoing/dispatched job
        job = null;
      }
      if (job != null && job['plumber_id'] != null) {
        final plumberId = job['plumber_id'].toString();
        final status = (job['status'] ?? '').toString().toLowerCase();
        setState(() {
          _dispatchedPlumberId = int.tryParse(plumberId);
          _jobOrderStatus = status;
        });
        if (status == 'accomplished') {
          // Clear plumber marker and route if job is accomplished
          setState(() {
            plumberLatLng = null;
            _plumberProfileIcon = null;
            _polylines.clear();
            _markers.removeWhere((m) => m.markerId.value == 'plumber');
          });
          return;
        }
        _fetchPlumberProfileImage(plumberId: plumberId);
        _subscribeToPlumberLocation(plumberId);
      }
    }
  }

  Future<void> _fetchPlumberProfileImage({String? plumberId}) async {
    final prefs = await SharedPreferences.getInstance();
    final id = plumberId ?? prefs.getString('plumber_id');
    if (id == null) return;
    final response = await http.get(
      Uri.parse('https://aquafixsansimon.com/api/plumbers.php'),
    );
    if (response.statusCode == 200) {
      final List users = json.decode(response.body);
      final user = users.firstWhere(
        (u) => u['plumber_id'].toString() == id,
        orElse: () => null,
      );
      if (user != null) {
        // Set plumber name (first_name + last_name)
        setState(() {
          _plumberName =
              ((user['first_name'] ?? '') + ' ' + (user['last_name'] ?? ''))
                  .trim();
          _plumberPhone = user['contact_no']?.toString();
        });
        // Fetch average rating for this plumber
        _fetchPlumberAverageRating(id);

        if (user['profile_image'] != null &&
            user['profile_image'].toString().isNotEmpty) {
          final url =
              'https://aquafixsansimon.com/uploads/profiles/plumbers/${user['profile_image']}';
          final imgResp = await http.get(Uri.parse(url));
          if (imgResp.statusCode == 200) {
            _plumberProfileImageBytes = imgResp.bodyBytes;
            await _createPlumberProfileMarkerIcon();
          }
        } else {
          await _loadDefaultPlumberProfileImage();
        }
      } else {
        await _loadDefaultPlumberProfileImage();
      }
    } else {
      await _loadDefaultPlumberProfileImage();
    }
  }

  // Add this method to create the plumber's marker icon
  Future<void> _createPlumberProfileMarkerIcon() async {
    if (_plumberProfileImageBytes == null || _plumberIconCreating) return;

    _plumberIconCreating = true; // Set flag to prevent concurrent calls

    final boundaryKey = GlobalKey();
    if (!mounted) return;
    final overlay = Overlay.of(context);
    if (overlay == null) {
      _plumberIconCreating = false;
      return;
    }

    OverlayEntry? entry;
    bool markerSet = false;
    bool inserted = false;

    entry = OverlayEntry(
      builder:
          (_) => Center(
            child: Material(
              type: MaterialType.transparency,
              child: RepaintBoundary(
                key: boundaryKey,
                child: ProfilePinWidget(
                  imageBytes: _plumberProfileImageBytes!,
                  backgroundColor: const Color(0xFFFF6B6B),
                  size: 38,
                ),
              ),
            ),
          ),
    );

    try {
      overlay.insert(entry);
      inserted = true;
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;
      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject != null && renderObject is RenderRepaintBoundary) {
        final image = await renderObject.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null && mounted && _plumberProfileIcon == null) {
          // Only set if icon is not already set
          final Uint8List pngBytes = byteData.buffer.asUint8List();
          setState(() {
            _plumberProfileIcon = BitmapDescriptor.fromBytes(pngBytes);
          });
          markerSet = true;
          _updateMarkers();
        }
      }
    } catch (e) {
      debugPrint('Error creating plumber profile icon: $e');
    } finally {
      _plumberIconCreating = false; // Clear flag
      if (inserted) {
        try {
          entry.remove();
        } catch (_) {}
      }
      Future.delayed(const Duration(seconds: 2), () {
        if (!markerSet && mounted && _plumberProfileIcon == null) {
          setState(() {
            _plumberProfileIcon = BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            );
          });
          _updateMarkers();
        }
      });
    }
  }

  // Add this method to load the default plumber profile image
  Future<void> _loadDefaultPlumberProfileImage() async {
    final ByteData imageData = await rootBundle.load(
      'assets/profiles/default.jpg',
    );
    final Uint8List bytes = imageData.buffer.asUint8List();
    _plumberProfileImageBytes = bytes;
    await _createPlumberProfileMarkerIcon();
  }

  // Fetch average rating for the plumber from tbl_ratings (via plumber_ratings.php)
  Future<void> _fetchPlumberAverageRating(String plumberId) async {
    final url =
        'https://aquafixsansimon.com/api/plumber_ratings.php?plumber_id=$plumberId';
    debugPrint('Fetching plumber ratings from: $url');
    final response = await http.get(Uri.parse(url));
    debugPrint(
      'Plumber ratings response: ${response.statusCode} ${response.body}',
    );
    if (response.statusCode == 200) {
      final List ratings = json.decode(response.body);
      debugPrint('Decoded plumber ratings: $ratings');
      if (ratings.isNotEmpty) {
        double sum = 0;
        int count = 0;
        for (final r in ratings) {
          final rating = double.tryParse(r['ratings'].toString());
          if (rating != null) {
            sum += rating;
            count++;
          }
        }
        if (count > 0) {
          setState(() {
            _plumberAvatar = (sum / count).toStringAsFixed(2);
          });
          debugPrint('Plumber average rating: $_plumberAvatar');
        } else {
          setState(() {
            _plumberAvatar = null;
          });
          debugPrint('No ratings found for plumber.');
        }
      } else {
        setState(() {
          _plumberAvatar = null;
        });
        debugPrint('Ratings list empty for plumber.');
      }
    } else {
      debugPrint(
        'Failed to fetch plumber ratings: ${response.statusCode} ${response.body}',
      );
      setState(() {
        _plumberAvatar = null;
      });
    }
  }

  void _subscribeToPlumberLocation(String plumberId) {
    _plumberLocationSub?.cancel();
    final ref = FirebaseDatabase.instance.ref('locations/plumbers/$plumberId');
    _plumberLocationSub = ref.onValue.listen((event) async {
      // Skip updates if we temporarily ignore Firebase (pinning)
      if (_skipFirebaseUpdates) {
        debugPrint('⏭️ Skipping Firebase plumber update (pinning in progress)');
        return;
      }

      final data = event.snapshot.value;
      if (data is Map) {
        final lat = data['lat'];
        final lng = data['lng'];
        if (lat != null && lng != null) {
          // update raw device location
          plumberLatLng = LatLng(lat as double, lng as double);

          // Debounce frequent updates to avoid flicker
          _plumberUpdateDebounce?.cancel();
          _plumberUpdateDebounce = Timer(
            const Duration(milliseconds: 250),
            () async {
              // Ensure map is ready before attempting polyline/snapping
              if (mapController == null) return;

              // Rebuild polyline and compute snapped marker position
              await _updatePolyline();

              // Recompute ETA/distance
              _updateDistanceAndEta();

              // Update markers after polyline/snapping done
              if (mounted) {
                _updateMarkers();
              }
            },
          );
        }
      }
    });
  }

  void _updateDistanceAndEta() {
    final currentCustomerPos = _getCustomerMarkerPosition();
    if (currentCustomerPos != null && plumberLatLng != null) {
      final distance = _calculateDistanceMeters(
        plumberLatLng!.latitude,
        plumberLatLng!.longitude,
        currentCustomerPos.latitude,
        currentCustomerPos.longitude,
      );
      final etaMinutes = (distance / 500.0).ceil(); // adjust as needed
      setState(() {
        _distanceMeters = distance;
        _etaMinutes = etaMinutes;
      });
    }
  }

  double _calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000; // Earth radius in meters
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  Future<void> _loadProfileImage() async {
    final ByteData imageData = await rootBundle.load('assets/profile.jpg');
    final Uint8List bytes = imageData.buffer.asUint8List();
    if (!mounted) return;
    setState(() {
      _profileImageBytes = bytes;
    });
    // Wait for the widget to build, then create the marker icon
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _createProfileMarkerIcon();
      }
    });
  }

  Future<void> _createProfileMarkerIcon() async {
    if (_profileImageBytes == null) return;
    final boundaryKey = GlobalKey();
    if (!mounted) return;
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    OverlayEntry? entry;
    bool inserted = false;

    entry = OverlayEntry(
      builder:
          (_) => Center(
            child: Material(
              type: MaterialType.transparency,
              child: RepaintBoundary(
                key: boundaryKey,
                child: ProfilePinWidget(
                  imageBytes: _profileImageBytes!,
                  backgroundColor: const Color(0xFF4ADE80),
                  size: 38,
                ),
              ),
            ),
          ),
    );

    try {
      overlay.insert(entry);
      inserted = true;
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;
      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject != null && renderObject is RenderRepaintBoundary) {
        final image = await renderObject.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null && mounted) {
          final Uint8List pngBytes = byteData.buffer.asUint8List();
          setState(() {
            _profileIcon = BitmapDescriptor.fromBytes(pngBytes);
          });
          _updateMarkers();
        }
      }
    } catch (e) {
      debugPrint('Error creating profile icon: $e');
    } finally {
      if (inserted) {
        try {
          entry.remove();
        } catch (_) {}
      }
    }
  }

  Future<void> _initializeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    if (customerId == null) return;

    final ref = FirebaseDatabase.instance.ref(
      'locations/customers/$customerId',
    );
    final snapshot = await ref.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map?;
      final lat = data?['lat'];
      final lng = data?['lng'];
      if (lat != null && lng != null) {
        setState(() {
          customerLatLng = LatLng(lat as double, lng as double);
          _isLoadingLocation = false;
        });
        _updateMarkers();
        _listenToCustomerLocationOnFirebase(customerId);
        return;
      }
    }

    // If no location in Firebase, use GPS and save to Firebase
    _listenToCustomerLocationOnFirebase(customerId); // Listen for future pins
    _startGpsLocationTracking();
  }

  void _startGpsLocationTracking() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    await location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000,
      distanceFilter: 5,
    );

    LocationData initialData = await location.getLocation();
    if (_isValidLocation(initialData)) {
      _setLocation(initialData);
    }

    _locationSubscription?.cancel();
    _locationSubscription = location.onLocationChanged.listen((locationData) {
      if (_isValidLocation(locationData)) {
        _setLocation(locationData);
      }
    });
  }

  void _listenToCustomerLocationOnFirebase(String customerId) {
    _customerLocationSub?.cancel();
    final ref = FirebaseDatabase.instance.ref(
      'locations/customers/$customerId',
    );
    _customerLocationSub = ref.onValue.listen((event) {
      // SKIP updates if we temporarily ignore Firebase (pinning)
      if (_skipFirebaseUpdates) {
        debugPrint(
          '⏭️ Skipping Firebase customer update (pinning in progress)',
        );
        return;
      }

      final data = event.snapshot.value;
      if (data is Map) {
        final lat = data['lat'];
        final lng = data['lng'];
        if (lat != null && lng != null) {
          setState(() {
            customerLatLng = LatLng(lat as double, lng as double);
            _isLoadingLocation = false;
          });
          _updateMarkers();
        }
      }
    });
  }

  bool _isValidLocation(LocationData data) {
    return data.latitude != null &&
        data.longitude != null &&
        data.latitude != 0.0 &&
        data.longitude != 0.0;
  }

  void _updateCustomerLocationToFirebase(LatLng position) async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    if (customerId != null &&
        position.latitude != 0.0 &&
        position.longitude != 0.0) {
      updateCustomerLocation(customerId, position.latitude, position.longitude);
    }
  }

  void _setLocation(LocationData locationData) {
    final newPosition = LatLng(locationData.latitude!, locationData.longitude!);
    debugPrint('📍 New Location (local only): $newPosition');

    // If we are within pin cooldown or skipping updates, ignore GPS updates so
    // pinned location is not immediately overwritten.
    if (_skipFirebaseUpdates ||
        (_lastPinnedAt != null &&
            DateTime.now().difference(_lastPinnedAt!) < _pinCooldown)) {
      debugPrint('⏭️ Skipping local GPS update due to pin cooldown');
      return;
    }

    if (!mounted) return;
    setState(() {
      // Update only local state — DO NOT write to Firebase here.
      customerLatLng = newPosition;
      _isLoadingLocation = false;
    });

    // Update UI only (no Firebase write)
    _updateMarkers();
    _updateDistanceAndEta();
    // Do NOT call _updateCustomerLocationToFirebase here.
  }

  void _moveCameraToPosition(LatLng position) {
    if (mapController == null) return;
    mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 20), // was 16, now nearer
      ),
    );
  }

  void _updateMarkers() {
    // SKIP if modal is open
    if (_modalOpen) return;

    final newMarkers = <Marker>{};

    final BitmapDescriptor customerIconFallback =
        _customerProfileIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

    // Show customer marker ONLY when NOT pinning
    if (customerLatLng != null && !_isPinningLocation) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: customerLatLng!,
          infoWindow: InfoWindow(title: _customerName ?? "You"),
          icon: customerIconFallback,
          zIndexInt: 2,
        ),
      );
    }

    if (_showPlumberLocation &&
        plumberLatLng != null &&
        mapController != null &&
        !_isPinningLocation &&
        _plumberProfileIcon != null) {
      LatLng markerPosition = _plumberMarkerPos ?? plumberLatLng!;

      if (_polylines.isNotEmpty && _polylines.first.points.isNotEmpty) {
        if (_plumberMarkerPos == null) {
          final polylinePoints = _polylines.first.points;
          markerPosition = _getSnappedPlumberPosition(
            plumberLatLng!,
            polylinePoints,
          );
          _plumberMarkerPos = markerPosition;
        } else {
          markerPosition = _plumberMarkerPos!;
        }
      }

      newMarkers.add(
        Marker(
          markerId: const MarkerId('plumber'),
          position: markerPosition,
          infoWindow: InfoWindow(title: _plumberName ?? "Plumber"),
          icon: _plumberProfileIcon!,
          onTap: () {
            _showPlumberInfoModal();
          },
          zIndexInt: 3,
        ),
      );
    }

    if (!mounted) return;

    // Only call setState if markers actually changed
    if (_markersChanged(newMarkers)) {
      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
      });
    }
  }

  // Add this helper to detect actual marker changes
  bool _markersChanged(Set<Marker> newMarkers) {
    if (_markers.length != newMarkers.length) return true;

    for (final newMarker in newMarkers) {
      final existing = _markers.firstWhere(
        (m) => m.markerId == newMarker.markerId,
        orElse: () => null as dynamic,
      );
      if (existing == null ||
          existing.position != newMarker.position ||
          existing.icon != newMarker.icon) {
        return true;
      }
    }
    return false;
  }

  // --- Directions API for route polyline ---
  double _getPolylineWidth(double zoom) {
    // Make width thinner for large distances (zoom out)
    // At zoom 18, width ~8, at zoom 12, width ~2, at zoom 8, width ~1
    return (zoom - 10).clamp(1, 8).toDouble();
  }

  Color getRouteColor() {
    // Use blue for path lines
    return const Color(0xFF2D9FD0); // Blue
  }

  LatLng? _getCustomerMarkerPosition() {
    // ALWAYS return current state first, ignore cached markers
    if (customerLatLng != null) {
      return customerLatLng;
    }
    // Only fallback to marker cache if state is null
    for (final m in _markers) {
      if (m.markerId.value == 'customer') return m.position;
    }
    return null;
  }

  // --- Directions API for route polyline ---
  Future<void> _updatePolyline({double? zoomOverride}) async {
    // Only clear and reset if we have valid data
    final currentCustomerPos = customerLatLng;
    if (plumberLatLng == null || currentCustomerPos == null) {
      _polylines.clear();
      _plumberMarkerPos = null;
      return;
    }

    LatLng snappedPlumberPos = plumberLatLng!;
    List<LatLng> polylinePoints = [];

    final apiKey = 'AIzaSyCTQce3K5wSStYAuyQQdjsg8S_2cyTVsd0';
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${plumberLatLng!.latitude},${plumberLatLng!.longitude}&destination=${currentCustomerPos.latitude},${currentCustomerPos.longitude}&mode=driving&key=$apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'];
        if (routes != null && routes.isNotEmpty) {
          final polylinePointsEncoded =
              routes[0]['overview_polyline']['points'];
          polylinePoints = _decodePolyline(polylinePointsEncoded);

          if (polylinePoints.isNotEmpty) {
            snappedPlumberPos = _getSnappedPlumberPosition(
              plumberLatLng!,
              polylinePoints,
            );
          }

          // Build polyline and cache snapped position ONCE
          setState(() {
            _polylines.clear();
            _plinesUpdateSet(snappedPlumberPos, polylinePoints, zoomOverride);
            _plumberMarkerPos = snappedPlumberPos; // Cache it
          });

          return;
        }
      }
    } catch (e) {
      debugPrint('Directions API exception: $e');
    }

    // Fallback: straight line from snapped position to customer
    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [snappedPlumberPos, currentCustomerPos],
          color: getRouteColor(),
          width: 8,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
          jointType: JointType.round,
          zIndex: 1,
        ),
      );
      _plumberMarkerPos = snappedPlumberPos;
    });
  }

  // helper to set polyline with width logic (keeps _updatePolyline smaller)
  void _plinesUpdateSet(
    LatLng snappedPlumberPos,
    List<LatLng> polylinePoints,
    double? zoomOverride,
  ) {
    double zoom = zoomOverride ?? 18;
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: [snappedPlumberPos, ...polylinePoints],
        color: getRouteColor(),
        width: _getPolylineWidth(zoom).toInt(),
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 1,
      ),
    );
  }

  // Polyline decoder for Google Directions API
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    // If this returns only 2 points, the polyline is a straight line.
    return poly;
  }

  void _centerCameraOnBoth() {
    final currentCustomerPos = _getCustomerMarkerPosition();
    if (mapController == null ||
        currentCustomerPos == null ||
        plumberLatLng == null)
      return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        min(currentCustomerPos.latitude, plumberLatLng!.latitude),
        min(currentCustomerPos.longitude, plumberLatLng!.longitude),
      ),
      northeast: LatLng(
        max(currentCustomerPos.latitude, plumberLatLng!.latitude),
        max(currentCustomerPos.longitude, plumberLatLng!.longitude),
      ),
    );
    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _showPlumberInfoModal() {
    setState(() {
      _modalOpen = true;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      barrierColor: Colors.black87,
      builder: (context) {
        final eta = _etaMinutes != null ? "${_etaMinutes!} min" : "--";
        final distance =
            _distanceMeters != null
                ? "${(_distanceMeters! / 1000).toStringAsFixed(1)} km"
                : "--";
        final plumberName = _plumberName ?? "Plumber";
        final plumberPhone = _plumberPhone ?? "";
        // --- FIX: Use plumberAvatar as double if possible, fallback to 0.0 ---
        double plumberRating = 0.0;
        String plumberIdForDebug =
            _dispatchedPlumberId?.toString() ?? "unknown";
        if (_plumberAvatar != null && _plumberAvatar!.isNotEmpty) {
          plumberRating = double.tryParse(_plumberAvatar!) ?? 0.0;
          if (plumberRating == 0.0) {
            plumberRating = int.tryParse(_plumberAvatar!)?.toDouble() ?? 0.0;
          }
        }
        debugPrint(
          'Modal plumberId: $plumberIdForDebug, plumberAvatar: $_plumberAvatar',
        );
        // Timeline mock data
        final timeline = [
          {"label": "On the way", "distance": "", "eta": ""},
          {
            "label": "Customer's Location",
            "distance": "0 km",
            "eta": "Arriving",
          },
        ];
        return Padding(
          padding: EdgeInsets.only(
            left: 0,
            right: 0,
            top: 12.h,
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 12.h),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Plumber profile image
                    _plumberProfileImageBytes != null
                        ? CircleAvatar(
                          radius: 36.sp,
                          backgroundColor: Colors.white,
                          backgroundImage: MemoryImage(
                            _plumberProfileImageBytes!,
                          ),
                        )
                        : CircleAvatar(
                          radius: 36.sp,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            color: Color(0xFF2D9FD0),
                            size: 32.sp,
                          ),
                        ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  plumberName,
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.call,
                                  color: Colors.red,
                                  size: 26.sp,
                                ),
                                onPressed: () async {
                                  // Use plumberPhone or fallback to contact_no if available
                                  final phone = _plumberPhone ?? '';
                                  if (phone.isNotEmpty) {
                                    final uri = Uri(scheme: 'tel', path: phone);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Cannot make a call.'),
                                        ),
                                      );
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Plumber contact not available.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.message,
                                  color: Colors.blue,
                                  size: 26.sp,
                                ),
                                onPressed: () async {
                                  // Start or open chat with plumber (similar to my_job_orders_page)
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  final customerId =
                                      prefs.getString('customer_id') ?? '';
                                  final plumberId =
                                      _dispatchedPlumberId?.toString() ?? '';
                                  if (customerId.isEmpty || plumberId.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Missing customer or plumber ID.',
                                        ),
                                      ),
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
                                      chatId = int.tryParse(
                                        chatData['chat_id'].toString(),
                                      );
                                    }
                                  }
                                  // 2. If not, create chat
                                  if (chatId == null) {
                                    final createRes = await http.post(
                                      Uri.parse(
                                        'https://aquafixsansimon.com/api/chats_util.php',
                                      ),
                                      headers: {
                                        'Content-Type': 'application/json',
                                      },
                                      body: json.encode({
                                        'customer_id': customerId,
                                        'plumber_id': plumberId,
                                      }),
                                    );
                                    if (createRes.statusCode == 200) {
                                      final chatData = json.decode(
                                        createRes.body,
                                      );
                                      chatId = int.tryParse(
                                        chatData['chat_id'].toString(),
                                      );
                                    }
                                  }
                                  if (chatId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Failed to start chat.'),
                                      ),
                                    );
                                    return;
                                  }
                                  final plumberName = _plumberName ?? 'Plumber';
                                  Navigator.pushNamed(
                                    context,
                                    '/customer_chat_detail',
                                    arguments: {
                                      'userName': plumberName,
                                      'chatId': chatId,
                                      'customerId': int.tryParse(customerId),
                                      'plumberId': int.tryParse(plumberId),
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                          // Five-star rating bar
                          Row(
                            children: [
                              ...List.generate(5, (index) {
                                final plumberRatingValue =
                                    plumberRating > 0 ? plumberRating : 0.0;
                                final filled = plumberRatingValue >= index + 1;
                                final halfFilled =
                                    !filled &&
                                    plumberRatingValue > index &&
                                    plumberRatingValue < index + 1;
                                return Icon(
                                  halfFilled ? Icons.star_half : Icons.star,
                                  color:
                                      filled || halfFilled
                                          ? Colors.amber
                                          : Colors.grey[400],
                                  size: 24.sp,
                                );
                              }),
                              SizedBox(width: 6.w),
                              Text(
                                plumberRating > 0
                                    ? plumberRating.toStringAsFixed(2)
                                    : (() {
                                      debugPrint(
                                        'No rating for plumber: $_plumberAvatar | plumberId: $plumberIdForDebug | _plumberName: $_plumberName',
                                      );
                                      return "No rating";
                                    })(),
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: Colors.grey[200]),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
                child: Row(
                  children: [
                    Icon(Icons.timer, color: Colors.red, size: 18.sp),
                    SizedBox(width: 6.w),
                    Text(
                      "ETA: $eta",
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 18.w),
                    Icon(Icons.location_on, color: Colors.blue, size: 18.sp),
                    SizedBox(width: 6.w),
                    Text(
                      "Distance: $distance",
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: Colors.grey[200]),
              // Timeline
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
                child: _PlumberTimeline(timeline: timeline),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    ).then((_) {
      // Refresh markers after modal closes
      if (mounted) {
        setState(() {
          _modalOpen = false;
        });
        _updateMarkers();
      }
    });
  }

  LatLng _getSnappedPlumberPosition(
    LatLng plumber,
    List<LatLng> polyline, {
    double endpointThresholdMeters = 30,
    double snapThresholdMeters = 100,
  }) {
    if (polyline.isEmpty) return plumber;

    double pointDist(LatLng a, LatLng b) => _calculateDistanceMeters(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );

    double clampDouble(double v, double a, double b) =>
        v < a ? a : (v > b ? b : v);

    // Closest point on segment AB to point P
    LatLng _closestPointOnSegment(LatLng a, LatLng b, LatLng p) {
      final double ax = a.latitude;
      final double ay = a.longitude;
      final double bx = b.latitude;
      final double by = b.longitude;
      final double px = p.latitude;
      final double py = p.longitude;

      final double vx = bx - ax;
      final double vy = by - ay;
      final double wx = px - ax;
      final double wy = py - ay;

      final double len2 = vx * vx + vy * vy;
      double t = 0.0;
      if (len2 > 0) {
        t = clampDouble((vx * wx + vy * wy) / len2, 0.0, 1.0);
      }

      final double projLat = ax + vx * t;
      final double projLng = ay + vy * t;
      return LatLng(projLat, projLng);
    }

    // Find closest point on any polyline segment
    double minDist = double.infinity;
    LatLng bestPoint = plumber;

    for (int i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final candidate = _closestPointOnSegment(a, b, plumber);
      final dist = pointDist(candidate, plumber);
      if (dist < minDist) {
        minDist = dist;
        bestPoint = candidate;
      }
    }

    // Single-vertex fallback
    if (polyline.length == 1) {
      final only = polyline.first;
      final d = pointDist(plumber, only);
      if (d < minDist) {
        minDist = d;
        bestPoint = only;
      }
    }

    // Endpoints
    final LatLng startPoint = polyline.first;
    final LatLng endPoint = polyline.last;
    final double distToStart = pointDist(plumber, startPoint);
    final double distToEnd = pointDist(plumber, endPoint);

    // If plumber is very close to an endpoint prefer that endpoint (plumber-side)
    if (distToStart <= endpointThresholdMeters &&
        distToStart <= distToEnd &&
        distToStart > 20.0) {
      // <-- ADD THIS CONDITION
      return startPoint;
    }
    if (distToEnd <= endpointThresholdMeters && distToEnd < distToStart) {
      return endPoint;
    }

    // SPECIAL FIX: If the best point is the start and plumber is close to it (e.g., inside house),
    // avoid snapping to start and find the next closest point on the polyline (on the road).
    if ((bestPoint.latitude - startPoint.latitude).abs() < 0.00001 &&
        (bestPoint.longitude - startPoint.longitude).abs() < 0.00001 &&
        distToStart < 20.0) {
      // 20m threshold for "inside house"
      double minDist2 = double.infinity;
      LatLng bestPoint2 = plumber;
      for (int i = 0; i < polyline.length - 1; i++) {
        final a = polyline[i];
        final b = polyline[i + 1];
        if (a == startPoint) continue; // Skip segments starting at the house
        final candidate = _closestPointOnSegment(a, b, plumber);
        final dist = pointDist(candidate, plumber);
        if (dist < minDist2) {
          minDist2 = dist;
          bestPoint2 = candidate;
        }
      }
      if (minDist2 <= snapThresholdMeters) {
        bestPoint = bestPoint2;
      }
    }

    // Only snap if projection is reasonably close to the route
    if (minDist <= snapThresholdMeters) {
      return bestPoint;
    }

    return plumber;
  }

  // Helper used before pushing another page from this screen.
  // It clears the persisted navigation flag and local plumber view state so that
  // when the user comes back only the customer location is shown.
  Future<void> _clearPlumberViewBeforeNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_plumber_location', false);
    await prefs.remove('navigate_job_order_id');
    _clearPlumberViewLocal();
  }

  void _showPinLocationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pin_drop_rounded, color: Colors.blueAccent, size: 48),
              SizedBox(height: 12),
              Text(
                "Pin Your Exact Location",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Move the map so the pin points to your house or exact location. Tap Confirm to save.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.close, color: Colors.red),
                      label: Text("Cancel"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _isPinningLocation = true;
                        });

                        // IMPORTANT: Navigate camera to current customer location first
                        if (mapController != null && customerLatLng != null) {
                          mapController!.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(target: customerLatLng!, zoom: 20),
                            ),
                          );
                        }

                        // Then initialize pinned location from map center
                        Future.delayed(const Duration(milliseconds: 600), () {
                          if (mapController != null) {
                            mapController!
                                .getVisibleRegion()
                                .then((bounds) {
                                  final centerLat =
                                      (bounds.northeast.latitude +
                                          bounds.southwest.latitude) /
                                      2;
                                  final centerLng =
                                      (bounds.northeast.longitude +
                                          bounds.southwest.longitude) /
                                      2;
                                  setState(() {
                                    _pinnedLocation = LatLng(
                                      centerLat,
                                      centerLng,
                                    );
                                  });
                                })
                                .catchError((e) {
                                  // fallback to current customer location
                                  setState(() {
                                    _pinnedLocation = customerLatLng;
                                  });
                                });
                          } else {
                            setState(() {
                              _pinnedLocation = customerLatLng;
                            });
                          }
                        });

                        _locationSubscription?.cancel();
                      },
                      icon: Icon(Icons.check_circle, color: Colors.white),
                      label: Text("Pin Now"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _maybeShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    if (customerId == null || customerId.isEmpty) return;
    final dbRef = FirebaseDatabase.instance.ref(
      'tutorials/$customerId/plumber',
    );
    final snapshot = await dbRef.get();
    final shown = snapshot.value == true;
    if (!shown) return;
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
    const steps = 4;
    if (_tutorialStep >= steps - 1) {
      // finish: set plumber to false in Firebase
      if (customerId != null && customerId.isNotEmpty) {
        final dbRef = FirebaseDatabase.instance.ref(
          'tutorials/$customerId/plumber',
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
    final keys = [_pinKey, _mapTypeKey, _currentLocKey, _zoomKey];
    final messages = [
      'Tap here to pin your exact location on the map.',
      'Tap here to change the map type (Normal/Satellite).',
      'Tap here to center the map on your current location.',
      'Use these buttons to zoom in and out on the map.',
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
              double bubbleTop = screenH - 120;
              bool placeAbove = false;
              double tailCenterX = screenW / 2;

              if (rect != null) {
                final centerX = rect.left + rect.width / 2;
                tailCenterX = centerX.clamp(
                  horizPadding + 12,
                  screenW - horizPadding - 12,
                );

                // --- NEW LOGIC: align bubble to button side ---
                if (_tutorialStep == 0) {
                  bubbleLeft = screenW - bubbleMaxWidth - 12.w;
                } else if (_tutorialStep == 1) {
                  bubbleLeft = rect.left;
                } else if (_tutorialStep == 2) {
                  bubbleLeft = screenW - bubbleMaxWidth - 6.w;
                } else {
                  bubbleLeft = (centerX - bubbleMaxWidth / 2).clamp(
                    horizPadding,
                    screenW - horizPadding - bubbleMaxWidth,
                  );
                }

                // Vertical positioning logic unchanged
                bubbleTop = rect.top + rect.height + bubbleGap + 12;
                final estimatedBubbleHeight = 110.0;
                if (bubbleTop + estimatedBubbleHeight > screenH - 28) {
                  placeAbove = true;
                  bubbleTop = rect.top - estimatedBubbleHeight - bubbleGap - 12;
                }
              }

              return Stack(
                children: [
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

                  // Triangle and bubble positioning
                  if ((rect != null)) ...[
                    if (!placeAbove)
                      Positioned(
                        left: tailCenterX - 9,
                        top: rect.top + rect.height,
                        child: CustomPaint(
                          size: const Size(18, 10),
                          painter: _TrianglePainter(
                            color: Colors.white,
                            pointingUp: true,
                          ),
                        ),
                      ),
                    if (!placeAbove)
                      Positioned(
                        left: bubbleLeft,
                        top: rect.top + rect.height + 10, // was +10, now closer
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
                    if (placeAbove)
                      Positioned(
                        left: tailCenterX - 9,
                        top: bubbleTop + 110.h, // bubble height estimate
                        child: CustomPaint(
                          size: const Size(18, 10),
                          painter: _TrianglePainter(
                            color: Colors.white,
                            pointingUp: false,
                          ),
                        ),
                      ),
                    if (placeAbove)
                      Positioned(
                        left: bubbleLeft + 10.w,
                        top:
                            bubbleTop +
                            46.h, // bubbleTop is already calculated to be close
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
                          (!placeAbove)
                              ? rect.top + rect.height + 10.h + 82.h
                              : bubbleTop + 82.h + 50.h,
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
                    // Default positioning for other steps
                    Positioned(
                      left: bubbleLeft,
                      top: bubbleTop.clamp(12.0, screenH - 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (placeAbove)
                            Column(
                              children: [
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
                                SizedBox(height: 18),
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
    final double headerHeight = 64.h;

    // --- ADD THIS GUARD: ---
    if (!_showPlumberLocation) {
      // Always clear plumber marker and polylines if flag is false
      if (_markers.any((m) => m.markerId.value == 'plumber') ||
          _polylines.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _markers.removeWhere((m) => m.markerId.value == 'plumber');
              _polylines.clear();
              plumberLatLng = null;
              _plumberProfileIcon = null;
            });
          }
        });
      }
    }

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
            // Header background
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
            // Ensure map is at the back, markers and overlays are on top
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: safeTop),
                  child: Container(
                    height: headerHeight,
                    color: Colors.transparent,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 0, 10.w, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Plumber Tracking',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              // Pin button with tutorial key
                              Container(
                                key: _pinKey,
                                child: IconButton(
                                  onPressed: () {
                                    _showPinLocationModal();
                                  },
                                  icon: const FaIcon(
                                    FontAwesomeIcons.mapPin,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                  iconSize: 26.sp,
                                  tooltip: 'Pin',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child:
                      _isLoadingLocation || customerLatLng == null
                          ? const Center(child: CircularProgressIndicator())
                          : Stack(
                            children: [
                              Positioned.fill(
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: customerLatLng!,
                                    zoom: 18,
                                  ),
                                  markers:
                                      _showPlumberLocation &&
                                              !_isPinningLocation
                                          ? _markers // Use cached _markers set directly
                                          : {
                                            if (!_isPinningLocation &&
                                                customerLatLng != null &&
                                                _customerProfileIcon != null)
                                              Marker(
                                                markerId: const MarkerId(
                                                  'customer',
                                                ),
                                                position: customerLatLng!,
                                                infoWindow: InfoWindow(
                                                  title: _customerName ?? "You",
                                                ),
                                                icon: _customerProfileIcon!,
                                                zIndexInt: 2,
                                              ),
                                          },
                                  polylines:
                                      _showPlumberLocation &&
                                              !_isPinningLocation
                                          ? _polylines
                                          : {},
                                  onMapCreated: (
                                    GoogleMapController controller,
                                  ) {
                                    mapController = controller;

                                    if (_showPlumberLocation &&
                                        !_isPinningLocation) {
                                      _updatePolyline();
                                      // Center camera ONCE on map creation
                                      Future.delayed(
                                        const Duration(milliseconds: 500),
                                        () {
                                          if (mounted) {
                                            _centerCameraOnBoth();
                                          }
                                        },
                                      );
                                    }
                                  },
                                  myLocationEnabled: false,
                                  mapType: _selectedMapType,
                                  zoomControlsEnabled: false,
                                  onCameraMove:
                                      _isPinningLocation
                                          ? (CameraPosition pos) {
                                            // Only update state without rebuilding markers
                                            if (mounted) {
                                              setState(() {
                                                _pinnedLocation = pos.target;
                                              });
                                            }
                                          }
                                          : null,
                                ),
                              ),
                              // Current location button with tutorial key
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    key: _currentLocKey,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(32),
                                      onTap: () {
                                        if (customerLatLng != null &&
                                            mapController != null) {
                                          mapController!.animateCamera(
                                            CameraUpdate.newCameraPosition(
                                              CameraPosition(
                                                target: customerLatLng!,
                                                zoom: 18,
                                              ),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Customer location not available',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.85),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 6,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        padding: EdgeInsets.all(10),
                                        child: Icon(
                                          Icons.my_location,
                                          color: Colors.grey[800],
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Map type button with tutorial key
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    key: _mapTypeKey,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(32),
                                      onTap: () async {
                                        final selected =
                                            await showMenu<MapType>(
                                              context: context,
                                              position: RelativeRect.fromLTRB(
                                                0,
                                                180,
                                                0,
                                                0,
                                              ),
                                              items: [
                                                PopupMenuItem(
                                                  value: MapType.normal,
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.map,
                                                        color: Colors.grey[600],
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text('Normal'),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: MapType.hybrid,
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.satellite_alt,
                                                        color: Colors.grey[600],
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text('Satellite'),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                        if (selected != null) {
                                          setState(() {
                                            _selectedMapType = selected;
                                          });
                                        }
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.85),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 6,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        padding: EdgeInsets.all(10),
                                        child: Icon(
                                          _selectedMapType == MapType.hybrid
                                              ? Icons.satellite_alt
                                              : Icons.map,
                                          color: Colors.grey[800],
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Zoom buttons with tutorial key and new design
                              Positioned(
                                bottom: 15,
                                right: 10,
                                child: Container(
                                  key: _zoomKey,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(32),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _ZoomButton(
                                        icon: Icons.zoom_in,
                                        onTap: () {
                                          if (mapController != null) {
                                            mapController!.animateCamera(
                                              CameraUpdate.zoomIn(),
                                            );
                                          }
                                        },
                                        isFirst: true,
                                        isLast: false,
                                      ),
                                      Container(
                                        width: 40.w,
                                        height: 1,
                                        color: Colors.grey[600],
                                      ),
                                      _ZoomButton(
                                        icon: Icons.zoom_out,
                                        onTap: () {
                                          if (mapController != null) {
                                            mapController!.animateCamera(
                                              CameraUpdate.zoomOut(),
                                            );
                                          }
                                        },
                                        isFirst: false,
                                        isLast: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Center pin overlay
                              if (_isPinningLocation)
                                IgnorePointer(
                                  ignoring: true,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            FaIcon(
                                              FontAwesomeIcons.mapPin,
                                              size: 46, // Larger for outline
                                              color:
                                                  Colors.white, // Outline color
                                            ),
                                            FaIcon(
                                              FontAwesomeIcons.mapPin,
                                              size: 44, // Smaller for fill
                                              color:
                                                  Colors
                                                      .redAccent, // Fill color
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          "Drag the map to position the pin",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 15,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black,
                                                blurRadius: 12,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // Confirm/Cancel buttons
                              if (_isPinningLocation)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 40,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                    ),
                                    child: Row(
                                      children: [
                                        // Cancel button
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                _isPinningLocation = false;
                                                _pinnedLocation = null;
                                              });
                                              _initializeLocation();
                                            },
                                            icon: Icon(
                                              Icons.close,
                                              color: Colors.redAccent,
                                            ),
                                            label: Text("Cancel"),
                                            style: OutlinedButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 16,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                              side: BorderSide(
                                                color: Colors.redAccent,
                                                width: 1.5,
                                              ),
                                              backgroundColor:
                                                  const ui.Color.fromARGB(
                                                    255,
                                                    255,
                                                    240,
                                                    240,
                                                  ),
                                              foregroundColor: Colors.redAccent,
                                              textStyle: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 16),

                                        // Confirm button
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              // ALWAYS sample the actual map center here
                                              if (mapController != null) {
                                                try {
                                                  final bounds =
                                                      await mapController!
                                                          .getVisibleRegion();
                                                  final centerLat =
                                                      (bounds
                                                              .northeast
                                                              .latitude +
                                                          bounds
                                                              .southwest
                                                              .latitude) /
                                                      2;
                                                  final centerLng =
                                                      (bounds
                                                              .northeast
                                                              .longitude +
                                                          bounds
                                                              .southwest
                                                              .longitude) /
                                                      2;
                                                  _pinnedLocation = LatLng(
                                                    centerLat,
                                                    centerLng,
                                                  );
                                                } catch (e) {
                                                  // fallback
                                                  _pinnedLocation =
                                                      customerLatLng;
                                                }
                                              } else {
                                                _pinnedLocation =
                                                    customerLatLng;
                                              }

                                              if (_pinnedLocation != null) {
                                                debugPrint(
                                                  'Saving pinned location: $_pinnedLocation',
                                                );
                                                await _savePinnedLocation(
                                                  _pinnedLocation!,
                                                );
                                                setState(() {
                                                  _isPinningLocation = false;
                                                  customerLatLng =
                                                      _pinnedLocation;
                                                });
                                              } else {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Unable to determine pinned location. Try again.',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            icon: Icon(
                                              Icons.check,
                                              color: Colors.white,
                                            ),
                                            label: Text(
                                              "Confirm",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 16,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                              backgroundColor:
                                                  Colors.blueAccent,
                                              elevation: 8,
                                              shadowColor: Colors.blueAccent
                                                  .withOpacity(0.4),
                                              textStyle: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePinnedLocation(LatLng location) async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    if (customerId != null) {
      // Pause Firebase listener to avoid immediate overwrite
      await _customerLocationSub?.cancel();
      _customerLocationSub = null;

      final ref = FirebaseDatabase.instance.ref(
        'locations/customers/$customerId',
      );
      final snapshot = await ref.get();

      bool locationChanged = true;
      if (snapshot.exists) {
        final data = snapshot.value as Map?;
        final lat = data?['lat'];
        final lng = data?['lng'];
        if (lat != null && lng != null) {
          final latDouble =
              (lat is num)
                  ? lat.toDouble()
                  : double.tryParse(lat.toString()) ?? 0.0;
          final lngDouble =
              (lng is num)
                  ? lng.toDouble()
                  : double.tryParse(lng.toString()) ?? 0.0;
          const tolerance = 0.00001;
          locationChanged =
              (latDouble - location.latitude).abs() > tolerance ||
              (lngDouble - location.longitude).abs() > tolerance;
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      if (locationChanged) {
        await ref.set({
          'lat': location.latitude,
          'lng': location.longitude,
          'timestamp': timestamp,
        });
      } else {
        await ref.update({'timestamp': timestamp});
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Location pinned successfully!")));

      // UPDATE STATE IMMEDIATELY before any async operations
      if (mounted) {
        setState(() {
          customerLatLng = location; // Set to pinned location
          _lastPinnedAt = DateTime.now();
          _skipFirebaseUpdates = true;
          _isPinningLocation = false;
          // CLEAR old markers to force fresh render with new position
          _markers.removeWhere((m) => m.markerId.value == 'customer');
        });
        // Force immediate UI update with new position
        _updateMarkers();
      }

      // Recalculate polyline using pinned location
      if (mounted && locationChanged && plumberLatLng != null) {
        await Future.delayed(const Duration(milliseconds: 300));
        await _updatePolyline();
        _updateMarkers(); // Update again after polyline
      }

      // Re-subscribe to Firebase but continue to skip applying updates for a short cooldown
      if (mounted) {
        _listenToCustomerLocationOnFirebase(customerId);
      }

      // After cooldown, allow GPS/Firebase updates again
      Future.delayed(_pinCooldown, () {
        if (!mounted) return;
        setState(() {
          _skipFirebaseUpdates = false;
          _lastPinnedAt = null;
        });
        _startGpsLocationTracking();
      });
    }
  }

  Future<void> updateCustomerLocation(
    String customerId,
    double lat,
    double lng,
  ) async {
    final ref = FirebaseDatabase.instance.ref(
      'locations/customers/$customerId',
    );
    await ref.set({
      'lat': lat,
      'lng': lng,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
}

// Remove the accidentally nested/duplicated class definitions that were inside
// the state class and replace them with these top-level widgets:

class ProfilePinWidget extends StatelessWidget {
  final Uint8List imageBytes;
  final Color backgroundColor;
  final double size;
  const ProfilePinWidget({
    super.key,
    required this.imageBytes,
    required this.backgroundColor,
    this.size = 48,
  });

  Future<ui.Image> _loadUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size + 12,
      child: FutureBuilder<ui.Image>(
        future: _loadUiImage(imageBytes),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }
          return CustomPaint(
            painter: _PinPainter(snapshot.data!, backgroundColor),
          );
        },
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  final ui.Image profileImage;
  final Color backgroundColor;
  _PinPainter(this.profileImage, this.backgroundColor);

  @override
  void paint(Canvas canvas, Size size) {
    final double pinWidth = size.width;
    final double pinHeight = size.height;

    final double outerRadius = pinWidth / 2.2;
    final double imageRadius = outerRadius - 3;
    final Offset circleCenter = Offset(pinWidth / 2, outerRadius + 2);

    final Paint bgPaint = Paint()..color = backgroundColor;
    canvas.drawCircle(circleCenter, outerRadius, bgPaint);

    final Path pinPath =
        Path()
          ..moveTo(pinWidth / 2, pinHeight)
          ..quadraticBezierTo(
            pinWidth,
            pinHeight * 0.6,
            pinWidth / 2,
            circleCenter.dy + (outerRadius - (outerRadius * 0.5)),
          )
          ..quadraticBezierTo(0, pinHeight * 0.6, pinWidth / 2, pinHeight);

    canvas.drawPath(pinPath, bgPaint);

    final Rect imageRect = Rect.fromCircle(
      center: circleCenter,
      radius: imageRadius,
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(imageRect));
    paintImage(
      canvas: canvas,
      rect: imageRect,
      image: profileImage,
      fit: BoxFit.cover,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlumberTimeline extends StatelessWidget {
  final List<Map<String, String>> timeline;
  const _PlumberTimeline({required this.timeline});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(timeline.length, (i) {
        final item = timeline[i];
        final isFirst = i == 0;
        final isLast = i == timeline.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isFirst ? Colors.blue : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Container(width: 2, height: 32, color: Colors.grey[300]),
              ],
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item["eta"] != null && item["eta"]!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      item["eta"]!,
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Text(
                  item["label"] ?? "",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                if (item["distance"] != null && item["distance"]!.isNotEmpty)
                  Text(
                    item["distance"]!,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  final bool pointingUp;
  _TrianglePainter({required this.color, this.pointingUp = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (pointingUp) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Zoom button widget for combined border radius
class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;
  const _ZoomButton({
    required this.icon,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? Radius.circular(32) : Radius.zero,
          bottom: isLast ? Radius.circular(32) : Radius.zero,
        ),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 9),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.vertical(
              top: isFirst ? Radius.circular(32) : Radius.zero,
              bottom: isLast ? Radius.circular(32) : Radius.zero,
            ),
          ),
          child: Icon(icon, color: Colors.grey[800], size: 28.sp),
        ),
      ),
    );
  }
}
