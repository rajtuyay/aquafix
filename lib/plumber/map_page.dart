// ignore_for_file: prefer_final_fields, unused_field, cancel_subscriptions

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart'; // <-- This is important for RenderRepaintBoundary
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'widgets/main_scaffold.dart';

import 'jo_report_form.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math'; // For LatLngBounds
import 'location_service.dart'; // Add this import for Firebase location updates
import 'package:firebase_database/firebase_database.dart'; // Add this import
import 'package:geocoding/geocoding.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class MapPage extends StatefulWidget {
  final int currentIndex;
  final double? customerLat;
  final double? customerLng;
  final double? plumberLat;
  final double? plumberLng;
  final String? customerProfileImage; // <-- Add this
  final String? customerId;

  const MapPage({
    super.key,
    required this.currentIndex,
    this.customerLat,
    this.customerLng,
    this.plumberLat,
    this.plumberLng,
    this.customerProfileImage, // <-- Add this
    this.customerId,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;
  final loc.Location location = loc.Location();
  StreamSubscription<loc.LocationData>? _locationSubscription;
  LatLng? customerLatLng;
  LatLng? plumberLatLng;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {}; // Add this for path lines
  BitmapDescriptor? _profileIcon;

  bool _isLoadingLocation = true;
  bool _isAvatarReady = false; // Track if avatar marker is ready
  Uint8List? _profileImageBytes;
  String? _plumberProfileImageUrl; // Add this to hold the profile image URL
  StreamSubscription? _customerLocationSub;

  // Customer profile variables
  Uint8List? _customerProfileImageBytes;
  BitmapDescriptor? _customerProfileIcon;
  String? _customerProfileImageUrl;

  String? _streetViewImageUrl;
  bool _showStreetViewPreview = false;
  LatLng? _streetViewLatLng;

  bool _showBothMarkers = false;
  bool _mapInitialized = false;

  OverlayEntry? _plumberOverlayEntry;
  OverlayEntry? _customerOverlayEntry;

  // Add these fields to fix undefined name errors
  bool _shownSanSimonModal = false;
  String _currentAddress = '';
  bool _sessionConfirmedSanSimon = false;

  // Add this field to persist modal state until app restart
  bool _sanSimonModalDismissed = false;

  MapType _selectedMapType = MapType.hybrid;

  // Helper to check if both locations and icons are ready
  bool _isReadyToShowBothMarkers() {
    return plumberLatLng != null &&
        customerLatLng != null &&
        _profileIcon != null &&
        _customerProfileIcon != null;
  }

  String getStreetViewImageUrl(
    LatLng location, {
    int width = 200,
    int height = 100,
  }) {
    const apiKey =
        'AIzaSyBzbVKBsJMwEudSfBzHe-EffVbTHuHnChg'; // <-- Replace with your API key
    return 'https://maps.googleapis.com/maps/api/streetview'
        '?size=${width}x$height'
        '&location=${location.latitude},${location.longitude}'
        '&fov=90&heading=235&pitch=10'
        '&key=$apiKey';
  }

  Future<void> _openStreetViewWeb(LatLng location) async {
    final url =
        'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=${location.latitude},${location.longitude}';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  // Helper to check if map can be shown
  bool _isReadyToShowMap() {
    if (_showBothMarkers) {
      // Navigated from task_page: need both locations and icons
      return plumberLatLng != null &&
          customerLatLng != null &&
          _profileIcon != null &&
          _customerProfileIcon != null;
    } else {
      // Normal map view: only plumber location and icon required
      return plumberLatLng != null && _profileIcon != null;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchPlumberProfileImage();
    _fetchCustomerProfileImage();
    _initializeLocation();
    // Set customerLatLng from widget if available
    if (widget.customerLat != null && widget.customerLng != null) {
      customerLatLng = LatLng(widget.customerLat!, widget.customerLng!);
      // Generate plumber location 10m west (left) of customer
      if (plumberLatLng == null) {
        plumberLatLng = LatLng(
          widget.customerLat!,
          widget.customerLng! - 0.00009,
        );
        _isLoadingLocation = false;
      }
      // Ensure marker is updated if profile icon is already loaded
      if (_customerProfileIcon != null) {
        _updateMarkers();
      }
    }
    // Set plumberLatLng from widget if available
    if (widget.plumberLat != null && widget.plumberLng != null) {
      plumberLatLng = LatLng(widget.plumberLat!, widget.plumberLng!);
      _isLoadingLocation =
          false; // If plumber location is provided, don't wait for device location
    }

    // Set flag if both customerLat and customerLng are provided
    _showBothMarkers = widget.customerLat != null && widget.customerLng != null;

    // Start listening to customer location updates if customer ID is available
    _startListeningToCustomerLocation();

    // START LISTENING TO PLUMBER'S OWN LOCATION FROM FIREBASE
    _startListeningToPlumberLocationFromFirebase();

    _loadSanSimonModalDismissedFlag();
  }

  Future<void> _loadSanSimonModalDismissedFlag() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sanSimonModalDismissed =
          prefs.getBool('sanSimonModalDismissed') ?? false;
    });
  }

  Future<void> _fetchPlumberProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final plumberId = prefs.getString('plumber_id') ?? '';
    if (plumberId.isEmpty) return;
    final response = await http.get(
      Uri.parse('https://aquafixsansimon.com/api/plumbers.php'),
    );
    if (response.statusCode == 200) {
      final List users = json.decode(response.body);
      final user = users.firstWhere(
        (u) => u['plumber_id'].toString() == plumberId,
        orElse: () => null,
      );
      if (user != null &&
          user['profile_image'] != null &&
          user['profile_image'].toString().isNotEmpty) {
        if (!mounted)
          return; // <-- Add this line to prevent setState after dispose
        setState(() {
          _plumberProfileImageUrl =
              'https://aquafixsansimon.com/uploads/profiles/plumbers/${user['profile_image']}';
        });
        await _loadProfileImageFromNetwork(_plumberProfileImageUrl!);
      } else {
        // fallback to default asset if no profile image
        await _loadProfileImage();
      }
    } else {
      await _loadProfileImage();
    }
  }

  Future<void> _loadProfileImageFromNetwork(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        if (!mounted) return;
        setState(() {
          _profileImageBytes = bytes;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _createProfileMarkerIcon();
          }
        });
      } else {
        await _loadProfileImage(); // fallback to asset
      }
    } catch (_) {
      await _loadProfileImage(); // fallback to asset
    }
  }

  Future<void> _loadProfileImage() async {
    final ByteData imageData = await rootBundle.load(
      'assets/profiles/default.jpg',
    );
    final Uint8List bytes = imageData.buffer.asUint8List();
    if (!mounted) return;
    setState(() {
      _profileImageBytes = bytes;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _createProfileMarkerIcon();
      }
    });
  }

  Future<void> _createProfileMarkerIcon() async {
    if (_profileImageBytes == null) return;
    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context);

    // If there's no Overlay (rare), fallback to using the raw image bytes as marker
    if (overlay == null) {
      try {
        setState(() {
          _profileIcon = BitmapDescriptor.fromBytes(_profileImageBytes!);
          _isAvatarReady = true;
        });
        _updateMarkers();
      } catch (e) {
        debugPrint('Fallback profile icon creation failed: $e');
      }
      return;
    }

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
      _plumberOverlayEntry = entry;
      await Future.delayed(const Duration(milliseconds: 200));

      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject != null && renderObject is RenderRepaintBoundary) {
        final image = await renderObject.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final Uint8List pngBytes = byteData.buffer.asUint8List();
          if (!mounted) return;
          setState(() {
            _profileIcon = BitmapDescriptor.fromBytes(pngBytes);
            _isAvatarReady = true;
          });
          _updateMarkers();
        }
      } else {
        // fallback if renderObject couldn't be obtained
        setState(() {
          _profileIcon = BitmapDescriptor.fromBytes(_profileImageBytes!);
          _isAvatarReady = true;
        });
        _updateMarkers();
      }
    } catch (e) {
      debugPrint('Error creating profile icon: $e');
      // final fallback
      if (mounted) {
        setState(() {
          _profileIcon = BitmapDescriptor.fromBytes(_profileImageBytes!);
          _isAvatarReady = true;
        });
        _updateMarkers();
      }
    } finally {
      if (inserted) {
        entry.remove();
      }
      _plumberOverlayEntry = null;
    }
  }

  Future<void> _fetchCustomerProfileImage() async {
    String? profileImageFile = widget.customerProfileImage;
    debugPrint('Customer profile image from widget: $profileImageFile');
    if (profileImageFile != null && profileImageFile.isNotEmpty) {
      _customerProfileImageUrl =
          'https://aquafixsansimon.com/uploads/profiles/customers/$profileImageFile';
      await _loadCustomerProfileImageFromNetwork(_customerProfileImageUrl!);
      // Ensure marker is updated if location is already set
      if (_customerProfileIcon != null) {
        _updateMarkers();
      }
      return;
    }
    // fallback: fetch from backend if not passed
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    debugPrint('Customer ID from prefs: $customerId');
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
      if (user != null &&
          user['profile_image'] != null &&
          user['profile_image'].toString().isNotEmpty) {
        setState(() {
          _customerProfileImageUrl =
              'https://aquafixsansimon.com/uploads/profiles/customers/${user['profile_image']}';
        });
        await _loadCustomerProfileImageFromNetwork(_customerProfileImageUrl!);
      } else {
        await _loadCustomerProfileImage();
      }
    } else {
      await _loadCustomerProfileImage();
    }
  }

  Future<void> _loadCustomerProfileImageFromNetwork(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        if (!mounted) return;
        setState(() {
          _customerProfileImageBytes = bytes;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _createCustomerProfileMarkerIcon();
          }
        });
      } else {
        await _loadCustomerProfileImage();
      }
    } catch (_) {
      await _loadCustomerProfileImage();
    }
  }

  Future<void> _loadCustomerProfileImage() async {
    final ByteData imageData = await rootBundle.load(
      'assets/profiles/default.jpg',
    );
    final Uint8List bytes = imageData.buffer.asUint8List();
    if (!mounted) return;
    setState(() {
      _customerProfileImageBytes = bytes;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _createCustomerProfileMarkerIcon();
      }
    });
  }

  Future<void> _createCustomerProfileMarkerIcon() async {
    if (_customerProfileImageBytes == null) return;
    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context);

    // Fallback when overlay is not available
    if (overlay == null) {
      try {
        setState(() {
          _customerProfileIcon = BitmapDescriptor.fromBytes(
            _customerProfileImageBytes!,
          );
        });
        _updateMarkers();
      } catch (e) {
        debugPrint('Fallback customer icon creation failed: $e');
      }
      return;
    }

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
                  imageBytes: _customerProfileImageBytes!,
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
      _customerOverlayEntry = entry;
      await Future.delayed(const Duration(milliseconds: 200));

      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject != null && renderObject is RenderRepaintBoundary) {
        final image = await renderObject.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final Uint8List pngBytes = byteData.buffer.asUint8List();
          if (!mounted) return;
          setState(() {
            _customerProfileIcon = BitmapDescriptor.fromBytes(pngBytes);
          });
          _updateMarkers();
        }
      } else {
        // fallback if renderObject couldn't be obtained
        setState(() {
          _customerProfileIcon = BitmapDescriptor.fromBytes(
            _customerProfileImageBytes!,
          );
        });
        _updateMarkers();
      }
    } catch (e) {
      debugPrint('Error creating customer profile icon: $e');
      if (mounted) {
        setState(() {
          _customerProfileIcon = BitmapDescriptor.fromBytes(
            _customerProfileImageBytes!,
          );
        });
        _updateMarkers();
      }
    } finally {
      if (inserted) {
        entry.remove();
      }
      _customerOverlayEntry = null;
    }
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    loc.PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) return;
    }

    await location.changeSettings(
      accuracy: loc.LocationAccuracy.high,
      interval: 1000,
      distanceFilter: 5,
    );

    loc.LocationData initialData = await location.getLocation();
    if (_isValidLocation(initialData)) {
      _setLocation(initialData);
    }

    _locationSubscription = location.onLocationChanged.listen((locationData) {
      if (_isValidLocation(locationData)) {
        _setLocation(locationData);
      } else {
        debugPrint(
          '❗ Invalid location data: ${locationData.latitude}, ${locationData.longitude}',
        );
      }
    });
  }

  bool _isValidLocation(loc.LocationData data) {
    return data.latitude != null &&
        data.longitude != null &&
        data.latitude != 0.0 &&
        data.longitude != 0.0;
  }

  void _setLocation(loc.LocationData locationData) async {
    final newPosition = LatLng(locationData.latitude!, locationData.longitude!);
    debugPrint('📍 Plumber Location: $newPosition');

    if (!mounted) return;
    setState(() {
      plumberLatLng = newPosition;
      _isLoadingLocation = false;
    });
    _updateMarkers();

    // Reverse geocode plumber location to get address
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        locationData.latitude!,
        locationData.longitude!,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        String barangay = (p.subLocality ?? '').trim();
        String municipality =
            (p.locality ?? p.subAdministrativeArea ?? '').trim();
        String province = (p.administrativeArea ?? '').trim();

        String address = [
          if (barangay.isNotEmpty) barangay,
          if (municipality.isNotEmpty) municipality,
          if (province.isNotEmpty) province,
        ].join(', ');

        setState(() {
          _currentAddress =
              address.isNotEmpty ? address : 'Location not available';
        });

        // Show modal if not San Simon, Pampanga and not already shown and not dismissed
        if (!_shownSanSimonModal &&
            !_sessionConfirmedSanSimon &&
            !_sanSimonModalDismissed &&
            !_isSanSimonPampanga(address) &&
            address.isNotEmpty) {
          _shownSanSimonModal = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showSanSimonModal(context, address);
          });
        }
      } else {
        setState(() {
          _currentAddress = 'Location not available';
        });
      }
    } catch (e) {
      setState(() {
        _currentAddress = 'Location not available';
      });
    }

    // Update plumber location in Firebase for real-time tracking
    _updatePlumberLocationToFirebase(newPosition);

    // Also update customer location in Firebase if available
    _updateCustomerLocationToFirebase();

    _updateMarkers();

    // If both markers are ready and map initialized, update polyline and center camera
    if (_showBothMarkers && _isReadyToShowMap() && _mapInitialized) {
      _updatePolyline();
      _centerCameraOnBoth();
    } else if (!_showBothMarkers) {
      _moveCameraToPosition(newPosition);
    }
  }

  bool _isSanSimonPampanga(String address) {
    final addr = address.toLowerCase();
    return addr.contains('san simon') && addr.contains('pampanga');
  }

  void _showSanSimonModal(BuildContext context, String address) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final double maxWidth = 320.w;
        final double screenWidth = MediaQuery.of(ctx).size.width;
        final double dialogWidth =
            screenWidth * 0.95 < maxWidth ? screenWidth * 0.95 : maxWidth;
        return Center(
          child: Material(
            borderRadius: BorderRadius.circular(16.r),
            color: Colors.white,
            elevation: 12,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: dialogWidth, minWidth: 0),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 22.w,
                    vertical: 18.h,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_off,
                            color: Colors.red,
                            size: 32.w,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              "You're currently outside San Simon",
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      // Remove IntrinsicWidth and use only Container for width constraint
                      Container(
                        width: double.infinity,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              WidgetSpan(child: SizedBox(width: 18.w)),
                              TextSpan(
                                text:
                                    "Our services are intended for San Simon, Pampanga. You are currently detected outside this area.",
                              ),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.justify,
                        ),
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
                          address.isNotEmpty
                              ? address
                              : "Location not available",
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      SizedBox(height: 22.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2C9CD9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            onPressed: () async {
                              setState(() {
                                _sessionConfirmedSanSimon = true;
                                _shownSanSimonModal = true;
                                _sanSimonModalDismissed = true;
                              });
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool(
                                'sanSimonModalDismissed',
                                true,
                              ); // <-- Save flag
                              Navigator.of(ctx).pop();
                            },
                            child: Text(
                              "Proceed",
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
            ),
          ),
        );
      },
    );
  }

  void _updatePlumberLocationToFirebase(LatLng position) async {
    final prefs = await SharedPreferences.getInstance();
    final plumberId = prefs.getString('plumber_id');
    if (plumberId != null &&
        position.latitude != 0.0 &&
        position.longitude != 0.0) {
      updatePlumberLocation(plumberId, position.latitude, position.longitude);
    }
  }

  void _updateCustomerLocationToFirebase() async {
    if (customerLatLng == null) return;
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    if (customerId != null &&
        customerLatLng!.latitude != 0.0 &&
        customerLatLng!.longitude != 0.0) {
      updateCustomerLocation(
        customerId,
        customerLatLng!.latitude,
        customerLatLng!.longitude,
      );
    }
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
    final markers = <Marker>{};

    // Fallback icons
    final BitmapDescriptor customerIconFallback =
        _customerProfileIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    final BitmapDescriptor plumberIconFallback =
        _profileIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

    // Always add customer marker at the exact customer location
    if (customerLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: customerLatLng!,
          infoWindow: const InfoWindow(title: 'Customer'),
          icon: customerIconFallback,
          onTap: () {
            setState(() {
              _streetViewLatLng = customerLatLng;
              _streetViewImageUrl = getStreetViewImageUrl(customerLatLng!);
              _showStreetViewPreview = true;
            });
          },
        ),
      );
    }

    // Add plumber marker (snapped to route start/end, whichever is closest)
    if (plumberLatLng != null) {
      // Get the route polyline
      List<LatLng> polylinePoints = [];
      final routePolyline = _polylines.firstWhere(
        (p) => p.polylineId.value == 'route',
        orElse:
            () => Polyline(polylineId: const PolylineId('__none'), points: []),
      );

      if (routePolyline.points.isNotEmpty) {
        polylinePoints = routePolyline.points;
      }

      LatLng markerPosition = plumberLatLng!;

      // If we have polyline points, snap plumber marker to the nearest endpoint (start or end)
      if (polylinePoints.isNotEmpty) {
        markerPosition = _getSnappedPlumberPosition(
          plumberLatLng!,
          polylinePoints,
        );
      }

      markers.add(
        Marker(
          markerId: const MarkerId('plumber'),
          position: markerPosition,
          infoWindow: const InfoWindow(title: 'Plumber'),
          icon: plumberIconFallback,
        ),
      );
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(markers);
    });
  }

  LatLng? _getCustomerMarkerPosition() {
    for (final m in _markers) {
      if (m.markerId.value == 'customer') return m.position;
    }
    return customerLatLng;
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

  LatLng _getSnappedPlumberPosition(LatLng plumber, List<LatLng> polyline) {
    if (polyline.isEmpty) return plumber;

    // Helper: distance (meters) between two LatLng using Haversine
    double pointDist(LatLng a, LatLng b) => _calculateDistanceMeters(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );

    double clampDouble(double v, double a, double b) =>
        v < a ? a : (v > b ? b : v);

    // Project plumber onto the nearest point on any polyline segment
    double minDist = double.infinity;
    LatLng bestPoint = plumber;

    final double meanLat =
        (plumber.latitude +
            polyline.fold<double>(0, (s, p) => s + p.latitude)) /
        (polyline.length + 1);
    final double meanLatRad = meanLat * (pi / 180);
    final double metersPerDegLat = 111320.0;
    final double metersPerDegLon = 111320.0 * cos(meanLatRad);

    final double px = plumber.longitude * metersPerDegLon;
    final double py = plumber.latitude * metersPerDegLat;

    // Find closest point on any polyline segment
    for (int i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];

      final double ax = a.longitude * metersPerDegLon;
      final double ay = a.latitude * metersPerDegLat;
      final double bx = b.longitude * metersPerDegLon;
      final double by = b.latitude * metersPerDegLat;

      final double vx = bx - ax;
      final double vy = by - ay;
      final double wx = px - ax;
      final double wy = py - ay;

      final double len2 = vx * vx + vy * vy;
      double t = 0.0;
      if (len2 > 0) {
        t = clampDouble((vx * wx + vy * wy) / len2, 0.0, 1.0);
      }

      final double projX = ax + vx * t;
      final double projY = ay + vy * t;

      final double projLat = projY / metersPerDegLat;
      final double projLng = projX / metersPerDegLon;
      final LatLng proj = LatLng(projLat, projLng);

      final double distMeters = pointDist(proj, plumber);
      if (distMeters < minDist) {
        minDist = distMeters;
        bestPoint = proj;
      }
    }

    // Only snap if projection is reasonably close to the route (within ~100m)
    const double snapThresholdMeters = 100.0;
    if (minDist <= snapThresholdMeters) {
      return bestPoint; // Snap to nearest point on route
    }

    return plumber; // If too far from route, show actual location
  }

  // Helper to create dashed polyline (simulate by splitting into segments)
  void _updatePolylines() {
    if (customerLatLng != null && plumberLatLng != null) {
      _polylines.clear();
      final points = [plumberLatLng!, customerLatLng!];
      // Simulate dashed line: break into segments
      final dashLength = 0.00005; // ~5m
      final gapLength = 0.00003; // ~3m
      final lat1 = plumberLatLng!.latitude;
      final lng1 = plumberLatLng!.longitude;
      final lat2 = customerLatLng!.latitude;
      final lng2 = customerLatLng!.longitude;
      final totalDist = sqrt(pow(lat2 - lat1, 2) + pow(lng2 - lng1, 2));
      final numDashes = (totalDist / (dashLength + gapLength)).ceil();
      List<LatLng> dashPoints = [];
      for (int i = 0; i < numDashes; i++) {
        final startFrac = (i * (dashLength + gapLength)) / totalDist;
        final endFrac =
            ((i * (dashLength + gapLength) + dashLength)) / totalDist;
        if (endFrac > 1.0) break;
        final startLat = lat1 + (lat2 - lat1) * startFrac;
        final startLng = lng1 + (lng2 - lng1) * startFrac;
        final endLat = lat1 + (lat2 - lat1) * endFrac;
        final endLng = lng1 + (lng2 - lng1) * endFrac;
        _polylines.add(
          Polyline(
            polylineId: PolylineId('route_dash_$i'),
            points: [LatLng(startLat, startLng), LatLng(endLat, endLng)],
            color: Colors.red.shade900, // dark red for route
            width: 5,
            patterns: [], // Not supported, so simulate with segments
          ),
        );
      }
      setState(() {});
    }
  }

  // --- Directions API for route polyline ---
  double _getPolylineWidth(double zoom) {
    // At zoom 18, width ~8, at zoom 12, width ~2
    return (zoom - 10).clamp(2, 12).toDouble();
  }

  Color getRouteColor() {
    // Use blue for path lines
    return const Color(0xFF2D9FD0); // Blue
  }

  Future<void> _updatePolyline({double? zoomOverride}) async {
    _polylines.clear();
    if (plumberLatLng != null && customerLatLng != null) {
      // Get the snapped plumber position (where marker actually appears on road)
      LatLng snappedPlumberPos = plumberLatLng!;
      List<LatLng> polylinePoints = [];

      // Use Google Directions API to get route polyline
      final apiKey =
          'AIzaSyCTQce3K5wSStYAuyQQdjsg8S_2cyTVsd0'; // <-- Replace with your API key
      final url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=${plumberLatLng!.latitude},${plumberLatLng!.longitude}&destination=${customerLatLng!.latitude},${customerLatLng!.longitude}&mode=driving&key=$apiKey';
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final routes = data['routes'];
          if (routes != null && routes.isNotEmpty) {
            final polylinePointsEncoded =
                routes[0]['overview_polyline']['points'];
            polylinePoints = _decodePolyline(polylinePointsEncoded);
            debugPrint(
              'Directions API polyline points count: ${polylinePoints.length}',
            );

            // Get the snapped plumber position from the polyline
            if (polylinePoints.isNotEmpty) {
              snappedPlumberPos = _getSnappedPlumberPosition(
                plumberLatLng!,
                polylinePoints,
              );
            }

            double zoom = zoomOverride ?? 18;
            setState(() {
              // Now build polyline starting from snapped plumber position
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: [snappedPlumberPos, ...polylinePoints],
                  color: getRouteColor(),
                  width: _getPolylineWidth(zoom).toInt(),
                  endCap: Cap.roundCap,
                  startCap: Cap.roundCap,
                  jointType: JointType.round,
                ),
              );
            });

            // UPDATE MARKERS AFTER POLYLINE IS SET
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateMarkers();
              _centerCameraOnBoth();
            });
            return;
          } else {
            debugPrint('Directions API: No routes found');
          }
        } else {
          debugPrint('Directions API error: ${response.body}');
        }
      } catch (e) {
        debugPrint('Directions API exception: $e');
      }

      // Fallback: straight line from snapped position to customer
      double zoom = zoomOverride ?? 18;
      setState(() {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: [snappedPlumberPos, customerLatLng!],
            color: getRouteColor(),
            width: _getPolylineWidth(zoom).toInt(),
            endCap: Cap.roundCap,
            startCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );
      });

      // UPDATE MARKERS AFTER FALLBACK POLYLINE IS SET
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateMarkers();
        _centerCameraOnBoth();
      });
    }
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
    return poly;
  }

  void _centerCameraOnBoth() {
    if (mapController == null ||
        customerLatLng == null ||
        plumberLatLng == null)
      return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        min(customerLatLng!.latitude, plumberLatLng!.latitude),
        min(customerLatLng!.longitude, plumberLatLng!.longitude),
      ),
      northeast: LatLng(
        max(customerLatLng!.latitude, plumberLatLng!.latitude),
        max(customerLatLng!.longitude, plumberLatLng!.longitude),
      ),
    );
    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  StreamSubscription? _plumberLocationSub;

  // Add this listener for plumber's own location from Firebase
  void _startListeningToPlumberLocationFromFirebase() async {
    final prefs = await SharedPreferences.getInstance();
    final plumberId = prefs.getString('plumber_id');
    if (plumberId != null && plumberId.isNotEmpty) {
      final ref = FirebaseDatabase.instance.ref(
        'locations/plumbers/$plumberId',
      );
      _plumberLocationSub = ref.onValue.listen((event) {
        final data = event.snapshot.value;
        if (data is Map) {
          final lat = data['lat'];
          final lng = data['lng'];
          if (lat != null && lng != null) {
            setState(() {
              plumberLatLng = LatLng(lat as double, lng as double);
            });

            _updateMarkers();
            if (_showBothMarkers && _isReadyToShowMap() && _mapInitialized) {
              _updatePolyline();
              _centerCameraOnBoth();
            }
          }
        }
      });
    }
  }

  // Example usage to listen for customer location updates:
  // Listen for customer location updates using FirebaseDatabase directly
  void _startListeningToCustomerLocation() async {
    // Use customerId from widget (passed from tbl_customers)
    final String? customerId = widget.customerId;

    if (customerId == null || customerId.isEmpty) {
      debugPrint(
        '⚠️ No customer_id provided. Cannot listen to customer location updates.',
      );
      return;
    }

    final ref = FirebaseDatabase.instance.ref(
      'locations/customers/$customerId',
    );
    _customerLocationSub = ref.onValue.listen(
      (event) {
        final data = event.snapshot.value;
        if (data is Map) {
          final lat = data['lat'];
          final lng = data['lng'];
          if (lat != null && lng != null) {
            debugPrint(
              '🎯 Customer location updated from Firebase: ($lat, $lng)',
            );
            setState(() {
              customerLatLng = LatLng(lat as double, lng as double);
            });

            _updateMarkers();

            // IMPORTANT: Recalculate polyline when customer location changes
            if (_showBothMarkers && _isReadyToShowMap() && _mapInitialized) {
              _updatePolyline();
              _centerCameraOnBoth();
            }
          }
        }
      },
      onError: (error) {
        debugPrint('❌ Error listening to customer location: $error');
      },
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _customerLocationSub?.cancel();
    _plumberLocationSub?.cancel();
    _plumberOverlayEntry?.remove();
    _plumberOverlayEntry = null;
    _customerOverlayEntry?.remove();
    _customerOverlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double safeTop = MediaQuery.of(context).padding.top;
    final double headerHeight = 64.h;

    // Only show map when both locations and icons are ready
    final bool showMap = _isReadyToShowMap();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: MainScaffold(
        currentIndex: widget.currentIndex,
        body: Column(
          children: [
            // Header
            Container(
              height: headerHeight + safeTop,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/homepage-header.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, safeTop, 10.w, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left Title with no extra padding needed because of outer padding
                    Text(
                      'Service Map',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Map or Loader inside content only
            Expanded(
              child:
                  showMap
                      ? Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target:
                                  plumberLatLng ??
                                  customerLatLng ??
                                  LatLng(0, 0),
                              zoom: 18,
                            ),
                            markers: _markers,
                            polylines: _polylines,
                            onMapCreated: (GoogleMapController controller) {
                              mapController = controller;
                              _mapInitialized = true;
                              _updateMarkers();
                              if (_showBothMarkers &&
                                  plumberLatLng != null &&
                                  customerLatLng != null) {
                                _updatePolyline(zoomOverride: 18);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _centerCameraOnBoth();
                                });
                              } else if (!_showBothMarkers &&
                                  plumberLatLng != null) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _moveCameraToPosition(plumberLatLng!);
                                });
                              }
                            },
                            myLocationEnabled: false,
                            mapType: _selectedMapType,
                            zoomControlsEnabled: false,
                            onCameraMove: (CameraPosition position) {
                              // Update polyline width on camera move
                              if (_polylines.isNotEmpty) {
                                final newPolylines =
                                    _polylines.map((polyline) {
                                      if (polyline.polylineId.value ==
                                          'route') {
                                        return polyline.copyWith(
                                          widthParam:
                                              _getPolylineWidth(
                                                position.zoom,
                                              ).toInt(),
                                        );
                                      }
                                      return polyline;
                                    }).toSet();
                                setState(() {
                                  _polylines.clear();
                                  _polylines.addAll(newPolylines);
                                });
                              }
                            },
                          ),

                          if (_showStreetViewPreview &&
                              _streetViewImageUrl != null)
                            Positioned(
                              bottom: 10,
                              left: 10,
                              child: GestureDetector(
                                onTap: () {
                                  if (_streetViewLatLng != null) {
                                    _openStreetViewWeb(_streetViewLatLng!);
                                  }
                                },
                                child: Material(
                                  elevation: 6,
                                  borderRadius: BorderRadius.circular(12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        Image.network(
                                          _streetViewImageUrl!,
                                          width: 180,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    width: 180,
                                                    height: 100,
                                                    color: Colors.grey[300],
                                                    child: Center(
                                                      child: Icon(Icons.error),
                                                    ),
                                                  ),
                                        ),
                                        Positioned(
                                          right: 8,
                                          bottom: 8,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.threesixty,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Street View',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _showStreetViewPreview = false;
                                              });
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black38,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(32),
                                onTap: () {
                                  if (plumberLatLng != null &&
                                      mapController != null) {
                                    mapController!.animateCamera(
                                      CameraUpdate.newCameraPosition(
                                        CameraPosition(
                                          target: plumberLatLng!,
                                          zoom: 20,
                                        ),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Plumber location not available',
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

                          // Top left: Map type selector
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(32),
                                onTap: () async {
                                  final selected = await showMenu<MapType>(
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

                          // Zoom buttons (same UI as plumber_page)
                          Positioned(
                            bottom: 15,
                            right: 10,
                            child: Container(
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
                        ],
                      )
                      : const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}

// Add this widget at the end of the file or in a separate file
class ProfilePinWidget extends StatelessWidget {
  final Uint8List imageBytes;
  final Color backgroundColor;
  final double size;
  const ProfilePinWidget({
    super.key,
    required this.imageBytes,
    required this.backgroundColor,
    this.size = 48, // default for backward compatibility
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
      height: size + 12, // keep pin shape aspect
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

    final double outerRadius = pinWidth / 2.2; // Blue circle radius
    final double imageRadius = outerRadius - 3; // Slightly smaller for image
    final Offset circleCenter = Offset(pinWidth / 2, outerRadius + 2);

    // Draw blue circle background
    final Paint bgPaint = Paint()..color = backgroundColor;
    canvas.drawCircle(circleCenter, outerRadius, bgPaint);

    // Draw the teardrop pin shape (excluding circle)
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

    // Clip and draw the image inside the circle (perfectly centered)
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

// Add Zoom button widget (same as plumber_page)
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
