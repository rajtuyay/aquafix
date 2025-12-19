import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_compress/video_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'add_account_page.dart';
import 'my_job_orders_page.dart';
import 'package:dio/dio.dart';
import 'package:firebase_database/firebase_database.dart';

class JORequestForm extends StatefulWidget {
  @override
  _JORequestFormState createState() => _JORequestFormState();
}

class _JORequestFormState extends State<JORequestForm> {
  final _formKey = GlobalKey<FormState>();

  // List to hold selected images and videos
  List<File> _selectedImages = [];
  List<File> _selectedVideos = [];

  final ImagePicker _picker = ImagePicker();
  Map<int, VideoPlayerController> _videoControllers = {};

  // Address dropdown logic
  List<dynamic> _addresses = [];
  dynamic _selectedAddress;
  bool _loadingAddresses = true;

  // Controllers for form fields
  final _notesController = TextEditingController();
  String? _selectedCategory;
  String? _otherIssue; // Add this field

  bool _isSubmitting = false;
  StreamController<double>? _progressController;

  OverlayEntry? _tutorialOverlayEntry;

  // Tutorial keys and state (NEW)
  final GlobalKey _accountKey = GlobalKey();
  final GlobalKey _addAccountKey = GlobalKey();
  final GlobalKey _reasonKey = GlobalKey();
  final GlobalKey _notesKey = GlobalKey();
  final GlobalKey _attachmentsKey = GlobalKey();

  final GlobalKey _attachImageBtnKey = GlobalKey();
  final GlobalKey _attachVideoBtnKey = GlobalKey();

  bool _tutorialVisible = false;
  int _tutorialStep = 0;

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
    // Show tutorial if needed after first frame (NEW)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeShowTutorial();
    });
  }

  Future<void> _fetchAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id') ?? '';
    debugPrint('Fetched customer_id from SharedPreferences: $customerId');
    if (customerId.isEmpty) {
      if (mounted) {
        setState(() {
          _addresses = [];
          _selectedAddress = null;
          _loadingAddresses = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _loadingAddresses = true);
    final response = await http.get(
      Uri.parse(
        'https://aquafixsansimon.com/api/jo_request.php?customer_id=$customerId',
      ),
    );
    if (response.statusCode == 200) {
      final addresses = json.decode(response.body);
      debugPrint('Addresses response: $addresses');
      if (mounted) {
        setState(() {
          _addresses = addresses;
          _selectedAddress = addresses.isNotEmpty ? addresses[0] : null;
          _loadingAddresses = false;
        });
      }
    } else {
      if (mounted) setState(() => _loadingAddresses = false);
    }
  }

  // Submit a Job Order
  Future<void> _submitJobOrder() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate() || _selectedAddress == null) return;
    if (_selectedImages.isEmpty || _selectedVideos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please attach at least one image and one video.'),
        ),
      );
      return;
    }
    if (_selectedCategory == 'Others' &&
        (_otherIssue == null || _otherIssue!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify the issue for "Others".')),
      );
      return;
    }
    if (mounted) {
      setState(() {
        _isSubmitting = true;
      });
    }

    _progressController = StreamController<double>();
    void updateProgress(double value) {
      _progressController?.add(value);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _ProgressModal(progressStream: _progressController!.stream),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getString('customer_id') ?? '';
      final data = {
        "customer_id": customerId,
        "clw_account_id": _selectedAddress['clw_account_id'],
        "category": _selectedCategory ?? '',
        "notes": _notesController.text.trim(),
        if (_selectedCategory == 'Others' &&
            _otherIssue != null &&
            _otherIssue!.trim().isNotEmpty)
          "other_issue": _otherIssue!.trim(),
        "isPredictive": 0,
      };

      updateProgress(0.05);

      final dio = Dio();
      final response = await dio.post(
        'https://aquafixsansimon.com/api/jo_request.php',
        data: data,
        options: Options(contentType: Headers.jsonContentType),
      );

      updateProgress(0.10);

      if (response.statusCode == 200) {
        try {
          final resp = response.data;
          final jobOrderId = int.tryParse(
            resp['job_order_id']?.toString() ?? '',
          );
          if (jobOrderId == null) {
            throw Exception(
              'Invalid job_order_id in response: ${response.data}',
            );
          }

          // --- Calculate total bytes ---
          final allFiles = [..._selectedImages, ..._selectedVideos];
          int totalBytes = 0;
          for (final file in allFiles) {
            totalBytes += await file.length();
          }

          int uploadedBytes = 0;

          // --- Upload images ---
          for (final image in _selectedImages) {
            int previousSent = 0;
            await _uploadMediaDio(jobOrderId, 'image', image, (sent, total) {
              // sent is for this file only
              uploadedBytes += (sent - previousSent);
              previousSent = sent;
              double progress = 0.10 + (uploadedBytes / totalBytes) * 0.85;
              updateProgress(progress.clamp(0, 0.95));
            });
          }
          // --- Upload videos ---
          for (final video in _selectedVideos) {
            int previousSent = 0;
            await _uploadMediaDio(jobOrderId, 'video', video, (sent, total) {
              uploadedBytes += (sent - previousSent);
              previousSent = sent;
              double progress = 0.10 + (uploadedBytes / totalBytes) * 0.85;
              updateProgress(progress.clamp(0, 0.95));
            });
          }

          updateProgress(0.98);
          await Future.delayed(const Duration(milliseconds: 500));
          updateProgress(1.0);

          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.of(context, rootNavigator: true).pop();

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Job order submitted!')));
          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.of(context, rootNavigator: true).pop();

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Job order submitted!')));

          // Replace the navigation stack so back goes to HomePage
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => MyJobOrdersPage()),
            (route) => route.isFirst,
          );
        } catch (e, stack) {
          Navigator.of(context, rootNavigator: true).pop();
          print('Error parsing job order response: $e\n$stack');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit job order: $e')),
          );
        }
      } else {
        Navigator.of(context, rootNavigator: true).pop();
        print(
          'Job order submission failed: ${response.statusCode} ${response.data}',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit job order.')),
        );
      }
    } finally {
      _progressController?.close();
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // --- Update _uploadMediaDio to accept sent/total bytes ---
  Future<void> _uploadMediaDio(
    int jobOrderId,
    String mediaType,
    File file,
    Function(int sent, int total) onProgress,
  ) async {
    final dio = Dio();
    final formData = FormData.fromMap({
      'job_order_id': jobOrderId.toString(),
      'media_type': mediaType,
      'file': await MultipartFile.fromFile(file.path),
    });

    try {
      await dio.post(
        'https://aquafixsansimon.com/api/jo_media_upload.php',
        data: formData,
        onSendProgress: onProgress,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload $mediaType: ${file.path}')),
      );
      print('Upload error: $e');
      rethrow;
    }
  }

  Future<bool> _validateVideo(File file) async {
    // Check file size (50MB = 52428800 bytes)
    final fileSize = await file.length();
    if (fileSize > 52428800) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video file must be less than 50MB.')),
      );
      return false;
    }

    // Only check file extension for .mp4 (cannot check codec in Flutter)
    final ext = file.path.toLowerCase();
    if (!ext.endsWith('.mp4')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video must be an MP4 file (H.264/AAC recommended).'),
        ),
      );
      return false;
    }

    // Optionally, warn user that codec cannot be fully validated in Flutter.
    // For full validation, server-side ffprobe/ffmpeg is required.

    return true;
  }

  final List<String> _allowedImageExtensions = ['jpg', 'jpeg', 'png'];

  // Function to pick an image
  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile = await _picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (pickedFile != null) {
                    final ext = pickedFile.path.split('.').last.toLowerCase();
                    if (_allowedImageExtensions.contains(ext)) {
                      if (mounted) {
                        setState(() {
                          _selectedImages.add(File(pickedFile.path));
                        });
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Only JPG, JPEG, or PNG images are allowed.',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (pickedFile != null) {
                    final ext = pickedFile.path.split('.').last.toLowerCase();
                    if (_allowedImageExtensions.contains(ext)) {
                      if (mounted) {
                        setState(() {
                          _selectedImages.add(File(pickedFile.path));
                        });
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Only JPG, JPEG, or PNG images are allowed.',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.cancel),
                title: Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  // Function to pick multiple media files
  Future<void> pickMultiMedia() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov'],
    );

    if (result != null && result.files.isNotEmpty) {
      for (final file in result.files) {
        final fileObj = File(file.path!);
        final ext = file.extension?.toLowerCase() ?? '';
        if (ext == 'mp4' || ext == 'mov') {
          if (await _validateVideo(fileObj)) {
            _selectedVideos.add(fileObj);
          }
        } else if (_allowedImageExtensions.contains(ext)) {
          _selectedImages.add(fileObj);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only JPG, JPEG, or PNG images are allowed.'),
            ),
          );
        }
      }

      if (mounted) setState(() {});
    }
  }

  Future<void> pickVideoOnly() async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.videocam),
                title: Text('Record Video'),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile = await _picker.pickVideo(
                    source: ImageSource.camera,
                  );
                  if (pickedFile != null) {
                    final fileObj = File(pickedFile.path);
                    if (await _validateVideo(fileObj)) {
                      final index = _selectedVideos.length;
                      _selectedVideos.add(fileObj);
                      final controller = VideoPlayerController.file(fileObj);
                      await controller.initialize();
                      controller.setLooping(true);
                      _videoControllers[index] = controller;
                      if (mounted) setState(() {});
                    }
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.video_library),
                title: Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile = await _picker.pickVideo(
                    source: ImageSource.gallery,
                  );
                  if (pickedFile != null) {
                    final fileObj = File(pickedFile.path);
                    if (await _validateVideo(fileObj)) {
                      final index = _selectedVideos.length;
                      _selectedVideos.add(fileObj);
                      final controller = VideoPlayerController.file(fileObj);
                      await controller.initialize();
                      controller.setLooping(true);
                      _videoControllers[index] = controller;
                      if (mounted) setState(() {});
                    }
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.cancel),
                title: Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> compressVideo(String videoPath) async {
    try {
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        videoPath,
        quality: VideoQuality.DefaultQuality,
        deleteOrigin: false,
      );

      if (mediaInfo != null && mediaInfo.path != null) {
        final file = File(mediaInfo.path!);
        final fileSizeInBytes = await file.length();
        final fileSizeInMB = fileSizeInBytes / (1024 * 1024);

        print('Compressed video path: ${mediaInfo.path}');
        print('Compressed video size: ${fileSizeInMB.toStringAsFixed(2)} MB');
      } else {
        print('Compression failed');
      }
    } catch (e) {
      print('Error during video compression: $e');
    }
  }

  @override
  void dispose() {
    _videoControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  // Remove selected image
  void _removeImage(int index) {
    if (mounted) {
      setState(() {
        _selectedImages.removeAt(index); // Remove the image from the list
      });
    }
  }

  void _removeVideo(int index) {
    final file = _selectedVideos[index];
    _videoControllers[index]?.dispose();
    file.deleteSync(); // Safe disposal
    if (mounted) {
      setState(() {
        _selectedVideos.removeAt(index);
        _videoControllers.remove(index);
      });
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      floatingLabelAlignment: FloatingLabelAlignment.start,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
    );
  }

  // --- Tutorial overlay methods ---
  Future<void> _maybeShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    if (customerId == null || customerId.isEmpty) return;
    final dbRef = FirebaseDatabase.instance.ref(
      'tutorials/$customerId/jo_request',
    );
    final snapshot = await dbRef.get();
    final show = snapshot.value == true;
    if (!show) return;
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() {
      _tutorialVisible = true;
      _tutorialStep = 0;
    });
    _showTutorialOverlay();
  }

  void _showTutorialOverlay() async {
    // remove any existing overlay first
    _removeTutorialOverlay();

    // Wait up to ~600ms for the target widget to be laid out so rect isn't null
    // This reduces cases where the first tutorial step doesn't show.
    final keys = [
      _accountKey,
      _addAccountKey,
      _reasonKey,
      _notesKey,
      _attachmentsKey,
    ];
    int tries = 0;
    Rect? rect;
    while (tries < 6) {
      final stepKey =
          (_tutorialStep < keys.length) ? keys[_tutorialStep] : null;
      rect = stepKey != null ? _getWidgetRect(stepKey) : null;
      if (rect != null) break;
      tries += 1;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Insert overlay. Wrap with Material + DefaultTextStyle so RichText/TextSpan
    // in the overlay will inherit the app font (fixes monospace fallback).
    _tutorialOverlayEntry = OverlayEntry(
      builder:
          (context) => DefaultTextStyle(
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
          ),
    );

    Overlay.of(context, rootOverlay: true)?.insert(_tutorialOverlayEntry!);
  }

  void _removeTutorialOverlay() {
    _tutorialOverlayEntry?.remove();
    _tutorialOverlayEntry = null;
  }

  void _advanceTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customer_id');
    const steps = 5;
    if (_tutorialStep >= steps - 1) {
      if (customerId != null && customerId.isNotEmpty) {
        final dbRef = FirebaseDatabase.instance.ref(
          'tutorials/$customerId/jo_request',
        );
        await dbRef.set(false);
      }
      if (!mounted) return;
      setState(() {
        _tutorialVisible = false;
        _tutorialStep = 0;
      });
      _removeTutorialOverlay();
    } else {
      if (!mounted) return;
      setState(() {
        _tutorialStep += 1;
      });
      _showTutorialOverlay();
    }
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

  Widget _buildTutorialOverlay() {
    final keys = [
      _accountKey,
      _addAccountKey,
      _reasonKey,
      _notesKey,
      _attachmentsKey,
    ];
    final messages = [
      'Select the account you want to use for this request.',
      'Tap here to add a new account if missing.',
      'Choose the reason/issue for the job order.',
      'Add any notes or details about the problem.',
      'Attach photos and videos as proof of the problem.',
    ];
    final stepKey = (_tutorialStep < keys.length) ? keys[_tutorialStep] : null;
    final rect = stepKey != null ? _getWidgetRect(stepKey) : null;

    Rect? highlightRect = rect;
    if (_tutorialStep == 4) {
      final imgRect = _getWidgetRect(_attachImageBtnKey);
      final vidRect = _getWidgetRect(_attachVideoBtnKey);
      if (imgRect != null && vidRect != null) {
        final left = imgRect.left;
        final top = imgRect.top;
        final right = vidRect.right;
        final bottom = vidRect.bottom;
        highlightRect = Rect.fromLTRB(left, top, right, bottom);
      }
    }

    // Use highlightRect for the mask and pointer
    final r = highlightRect ?? rect;

    // Wrap Positioned widgets in a Stack (remove any direct Positioned return)
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _advanceTutorial,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenW = constraints.maxWidth;
                final screenH = constraints.maxHeight;
                const double horizPadding = 24;
                final double bubbleMaxWidth = (screenW - horizPadding * 2)
                    .clamp(0, 360);
                const double bubbleGap = 8;
                const double triangleHeight = 10;
                final double estimatedBubbleHeight = 110.0;
                final message =
                    (_tutorialStep < messages.length)
                        ? messages[_tutorialStep]
                        : '';

                double bubbleLeft = (screenW - bubbleMaxWidth) / 2;
                double bubbleTop = screenH - 120;
                double triangleLeft = screenW / 2 - 9;
                double triangleTop = bubbleTop - triangleHeight;
                bool placeAbove = false;

                if (r != null) {
                  final centerX = r.left + r.width / 2;
                  triangleLeft = centerX - 9;

                  bubbleLeft = (centerX - bubbleMaxWidth / 2).clamp(
                    horizPadding,
                    screenW - horizPadding - bubbleMaxWidth,
                  );

                  final refTop = r.top;
                  final refHeight = r.height;
                  bubbleTop = refTop + refHeight + triangleHeight + bubbleGap;
                  triangleTop = bubbleTop - triangleHeight;

                  if (bubbleTop + estimatedBubbleHeight > screenH - 28) {
                    placeAbove = true;
                    bubbleTop =
                        refTop -
                        estimatedBubbleHeight -
                        triangleHeight -
                        bubbleGap;
                    triangleTop = bubbleTop + estimatedBubbleHeight;
                  }
                }

                List<InlineSpan> _buildTutorialMessageSpans(int step) {
                  switch (step) {
                    case 0:
                      return [
                        const TextSpan(
                          text:
                              'Select the account you want to use for this request.',
                        ),
                      ];
                    case 1:
                      return [
                        const TextSpan(
                          text: 'Tap here to add a new account if missing.',
                        ),
                      ];
                    case 2:
                      return [
                        const TextSpan(
                          text: 'Choose the reason/issue for the job order.',
                        ),
                      ];
                    case 3:
                      return [
                        const TextSpan(
                          text: 'Add any notes or details about the problem.',
                        ),
                      ];
                    case 4:
                      return [
                        const TextSpan(text: 'Attach '),
                        const TextSpan(
                          text: 'photos',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' and '),
                        const TextSpan(
                          text: 'videos',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' as proof of the problem.'),
                      ];
                    default:
                      return [const TextSpan(text: '')];
                  }
                }

                return Stack(
                  children: [
                    if (r != null) ...[
                      Positioned(
                        left: 0,
                        top: 0,
                        right: 0,
                        height: r.top - 8,
                        child: Container(color: Colors.black54),
                      ),
                      Positioned(
                        left: 0,
                        top: r.top + r.height + 8,
                        right: 0,
                        bottom: 0,
                        child: Container(color: Colors.black54),
                      ),
                      Positioned(
                        left: 0,
                        top: r.top - 8,
                        width: r.left - 8,
                        height: r.height + 16,
                        child: Container(color: Colors.black54),
                      ),
                      Positioned(
                        left: r.left + r.width + 8,
                        top: r.top - 8,
                        right: 0,
                        height: r.height + 16,
                        child: Container(color: Colors.black54),
                      ),
                      Positioned(
                        left: r.left - 8,
                        top: r.top - 8,
                        width: r.width + 16,
                        height: r.height + 16,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: triangleLeft,
                        top: triangleTop,
                        child: CustomPaint(
                          size: const Size(18, 10),
                          painter: _TrianglePainter(
                            color: Colors.white,
                            pointingUp: !placeAbove,
                          ),
                        ),
                      ),
                      Positioned(
                        left: bubbleLeft,
                        top: bubbleTop,
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
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: const Color.fromARGB(221, 39, 39, 39),
                                fontSize: 15.sp,
                                fontWeight: FontWeight.normal,
                                decoration: TextDecoration.none,
                                backgroundColor: Colors.transparent,
                              ),
                              children: _buildTutorialMessageSpans(
                                _tutorialStep,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: bubbleTop + estimatedBubbleHeight - 44,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.touch_app,
                              color: Colors.white,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap to continue',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                                fontSize: 15.sp,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ] else
                      Positioned.fill(child: Container(color: Colors.black54)),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> _categories = [
      'Leakage',
      'Water Quality Issue',
      'No Water Supply',
      'Meter Issue',
      'Valve/Stand Issue',
      'Relocation Request',
      'Drainage Issue',
      'Others',
    ];
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, popResult) async {
        if (_tutorialOverlayEntry != null) {
          _removeTutorialOverlay();
          if (mounted) {
            setState(() {
              _tutorialVisible = false;
              _tutorialStep = 0;
            });
          }
          // cast to the expected callback signature then call safely
          final callback = popResult as void Function(bool)?;
          callback?.call(false);
          return;
        }
        // Allow normal back navigation
        final callback = popResult as void Function(bool)?;
        callback?.call(true);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF2C9CD9),
          title: Text(
            'Job Order Form',
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, size: 22.sp, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.help_outline, color: Colors.white, size: 24.sp),
              tooltip: 'Show Tutorial',
              onPressed: () {
                setState(() {
                  _tutorialVisible = true;
                  _tutorialStep = 0;
                });
                _showTutorialOverlay();
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            _loadingAddresses
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Account Dropdown (styled like category dropdown)
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                key: _accountKey,
                                child: DropdownButtonFormField2<dynamic>(
                                  value: _selectedAddress,
                                  isExpanded: true,
                                  decoration: _dropdownDecoration(
                                    'Select Account',
                                  ),
                                  items:
                                      _addresses.map<
                                        DropdownMenuItem<dynamic>
                                      >((address) {
                                        final label = address['label'] ?? '';
                                        final accountNumber =
                                            address['account_number'] ?? '';
                                        final accountName =
                                            address['account_name'] ?? '';
                                        final display =
                                            '$label - $accountNumber, $accountName';
                                        return DropdownMenuItem(
                                          value: address,
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12.w,
                                              vertical: 8.h,
                                            ),
                                            child: Text(
                                              display,
                                              style: TextStyle(
                                                fontSize: 15.sp,
                                                color: Colors.black,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    if (mounted) {
                                      setState(() {
                                        _selectedAddress = value;
                                      });
                                    }
                                  },
                                  selectedItemBuilder: (context) {
                                    return _addresses.map((address) {
                                      final label = address['label'] ?? '';
                                      final accountNumber =
                                          address['account_number'] ?? '';
                                      final accountName =
                                          address['account_name'] ?? '';
                                      final display =
                                          '$label - $accountNumber, $accountName';
                                      return Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: EdgeInsets.zero,
                                          child: Text(
                                            display,
                                            style: TextStyle(
                                              fontSize: 15.sp,
                                              color: Colors.black,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList();
                                  },
                                  dropdownStyleData: DropdownStyleData(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                  ),
                                  menuItemStyleData: MenuItemStyleData(
                                    height: 38.h,
                                    padding: EdgeInsets.zero,
                                  ),
                                  validator:
                                      (value) =>
                                          value == null
                                              ? 'Please select an account'
                                              : null,
                                  hint: Text(
                                    _addresses.isEmpty
                                        ? 'No account found. Please add one.'
                                        : 'Select Account',
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              key: _addAccountKey,
                              child: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                tooltip: 'Add Account',
                                onPressed: _addAccountAndSelect,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),

                        // Category Dropdown with key
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                key: _reasonKey,
                                child: DropdownButtonFormField2<String>(
                                  value: _selectedCategory,
                                  decoration: _dropdownDecoration(
                                    'Reason/Issue',
                                  ),
                                  items:
                                      _categories.map((item) {
                                        return DropdownMenuItem<String>(
                                          value: item,
                                          child: Padding(
                                            // padding for dropdown list items only (not the selected one)
                                            padding: EdgeInsets.symmetric(
                                              vertical: 6.h,
                                            ),
                                            child: Text(
                                              item,
                                              style: TextStyle(
                                                fontSize: 15.sp,
                                                color: Colors.black,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    if (mounted) {
                                      setState(() {
                                        _selectedCategory = value;
                                        if (_selectedCategory != 'Others')
                                          _otherIssue = null;
                                      });
                                    }
                                  },
                                  validator:
                                      (value) =>
                                          value == null
                                              ? 'Please select a category'
                                              : null,
                                  dropdownStyleData: DropdownStyleData(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                  ),
                                  menuItemStyleData: MenuItemStyleData(
                                    height: 40.h,
                                    padding: EdgeInsets.only(
                                      left: 10,
                                      right: 8.w,
                                    ),
                                  ),
                                  buttonStyleData: ButtonStyleData(
                                    height: 30.h,
                                    padding: EdgeInsets.only(
                                      left: 0,
                                      right: 8.w,
                                    ), // aligned to border
                                  ),
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Show "Specify Other Issue" field if "Others" is selected
                        if (_selectedCategory == 'Others')
                          Padding(
                            padding: EdgeInsets.only(top: 12.h),
                            child: TextFormField(
                              maxLines: 2,
                              decoration: _inputDecoration(
                                'Specify Other Issue',
                              ),
                              onChanged: (val) => _otherIssue = val,
                              validator: (val) {
                                if (_selectedCategory == 'Others' &&
                                    (val == null || val.trim().isEmpty)) {
                                  return 'Please specify the issue';
                                }
                                return null;
                              },
                            ),
                          ),
                        SizedBox(height: 12.h),
                        // Notes with key
                        Container(
                          key: _notesKey,
                          child: TextFormField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: _inputDecoration('Notes (Optional)'),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Info message to user
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 22.sp,
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    text: 'Please attach at least one ',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 14.sp,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'photo',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                      TextSpan(text: ' and one '),
                                      TextSpan(
                                        text: 'video',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            ' as proof before submitting the form.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 6.h),

                        // Attachments (both sections wrapped under one key)
                        Container(
                          key: _attachmentsKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Images Section
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Attach Image',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.sp,
                                    color: Colors.black,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Container(
                                alignment: Alignment.centerLeft,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildMediaButton(
                                        Icons.add,
                                        _pickImage,
                                        key: _attachImageBtnKey,
                                      ),
                                      SizedBox(width: 10.w),
                                      ..._selectedImages.asMap().entries.map((
                                        entry,
                                      ) {
                                        return Padding(
                                          padding: EdgeInsets.only(right: 10.w),
                                          child: SizedBox(
                                            width: 70.w,
                                            height: 70.w,
                                            child: _buildMediaCard(
                                              entry.value,
                                              entry.key,
                                              true,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.h),

                              // Videos Section
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Attach Video',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.sp,
                                    color: Colors.black,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Container(
                                alignment: Alignment.centerLeft,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildMediaButton(
                                        Icons.add,
                                        pickVideoOnly,
                                        key: _attachVideoBtnKey,
                                      ),
                                      SizedBox(width: 10.w),
                                      ..._selectedVideos.asMap().entries.map((
                                        entry,
                                      ) {
                                        return Padding(
                                          padding: EdgeInsets.only(right: 10.w),
                                          child: SizedBox(
                                            width: 70.w,
                                            height: 70.w,
                                            child: _buildMediaCard(
                                              entry.value,
                                              entry.key,
                                              false,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 24.h),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(
            20.w,
            0,
            20.w,
            20.h + MediaQuery.of(context).padding.bottom,
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                backgroundColor: Color(0xFF2C9CD9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              onPressed: _submitJobOrder,
              child: Text(
                'SUBMIT',
                style: TextStyle(
                  letterSpacing: 1.5,
                  fontSize: 16.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Media button for picking image or video
  Widget _buildMediaButton(IconData icon, VoidCallback onTap, {Key? key}) {
    return Container(
      key: key,
      width: 70.w,
      height: 70.w,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: IconButton(
        icon: Icon(icon, size: 32.sp, color: Colors.grey),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildMediaCard(File file, int index, bool isImage) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            color: Colors.grey[200],
          ),
          child: isImage ? _buildImage(file) : _buildVideoPlayer(file, index),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => isImage ? _removeImage(index) : _removeVideo(index),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black54,
              ),
              child: Icon(Icons.close, size: 18.sp, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // Displaying the selected image
  Widget _buildImage(File imageFile) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullImageView(imageFile: imageFile),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: Image.file(
          imageFile,
          fit: BoxFit.cover,
          width: 70.w,
          height: 70.w,
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(File videoFile, int index) {
    final controller = _videoControllers[index];

    Widget content;
    if (controller != null) {
      content = FutureBuilder(
        future:
            controller.value.isInitialized
                ? Future.value(true)
                : controller.initialize(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              controller.value.isInitialized) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: AspectRatio(
                aspectRatio:
                    controller.value.aspectRatio > 0
                        ? controller.value.aspectRatio
                        : 1.0,
                child: VideoPlayer(controller),
              ),
            );
          }
          return _buildThumbnailWithProgress(videoFile.path);
        },
      );
    } else {
      content = _buildThumbnailWithProgress(videoFile.path);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullVideoView(videoFile: videoFile),
          ),
        );
      },
      child: content,
    );
  }

  // Generate the thumbnail for video
  Widget _buildThumbnailWithProgress(String videoPath) {
    return FutureBuilder(
      future: _generateThumbnail(videoPath),
      builder: (ctx, thumbSnapshot) {
        if (thumbSnapshot.hasData && thumbSnapshot.data!.isNotEmpty) {
          return Stack(
            children: [
              Image.memory(thumbSnapshot.data!, fit: BoxFit.cover),
              Center(child: CircularProgressIndicator()),
            ],
          );
        }
        return _buildPlaceholder();
      },
    );
  }

  // Generate the thumbnail data
  Future<Uint8List> _generateThumbnail(String videoPath) async {
    try {
      final uint8list = await VideoCompress.getByteThumbnail(
        videoPath,
        quality: 50, // Lower quality for faster generation
        position: -1, // Capture thumbnail at 1 second
      );
      return uint8list ?? Uint8List(0); // Return an empty Uint8List if null
    } catch (e) {
      print("Error generating thumbnail: $e");
      return Uint8List(0); // Return empty data if an error occurs
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(child: Icon(Icons.videocam, color: Colors.grey[400])),
    );
  }

  // Add this function to handle adding a new account and selecting it
  Future<void> _addAccountAndSelect() async {
    final clwAccountId = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddAccountPage()),
    );
    if (clwAccountId != null) {
      await _fetchAccounts();
      final found = _addresses.firstWhere(
        (a) => a['clw_account_id'].toString() == clwAccountId.toString(),
        orElse: () => null,
      );
      if (mounted) {
        setState(() {
          _selectedAddress =
              found ?? (_addresses.isNotEmpty ? _addresses.last : null);
        });
      }
    }
  }
}

// Full screen image viewer
class FullImageView extends StatelessWidget {
  final File imageFile;

  const FullImageView({required this.imageFile, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: 80.h), // Pushes the image up slightly
        child: Center(
          child: InteractiveViewer(
            panEnabled: true,
            scaleEnabled: true,
            child: Image.file(
              imageFile,
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

// Full screen video viewer
class FullVideoView extends StatefulWidget {
  final File videoFile;

  const FullVideoView({required this.videoFile, Key? key}) : super(key: key);

  @override
  _FullVideoViewState createState() => _FullVideoViewState();
}

class _FullVideoViewState extends State<FullVideoView> {
  late VideoPlayerController _videoPlayerController;
  bool _isInitialized = false;

  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _videoPlayerController = VideoPlayerController.file(widget.videoFile);
    _videoPlayerController.initialize().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _videoPlayerController.play();
        });
      }
      // Hide controls after delay if playing
      if (_videoPlayerController.value.isPlaying) {
        _hideControlsAfterDelay();
      }
    });
    _videoPlayerController.addListener(() {
      if (mounted) setState(() {});
      // Hide controls when video starts playing
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
                          // GestureDetector wraps the video for showing controls
                          GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              if (mounted) {
                                setState(() {
                                  _showControls = !_showControls;
                                  if (_showControls &&
                                      _videoPlayerController.value.isPlaying) {
                                    _hideControlsAfterDelay();
                                  } else if (!_showControls) {
                                    _hideTimer?.cancel();
                                  }
                                });
                              }
                            },
                            child: VideoPlayer(_videoPlayerController),
                          ),
                          // Centered backward, play, forward controls (show only if _showControls is true)
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
                                      if (mounted) {
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
                                      }
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
                                  // Timer and play button at the top of progress bar
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: 8.w,
                                      right: 8.w,
                                      top: 8.h,
                                      bottom: 0,
                                    ),
                                    child: Row(
                                      children: [
                                        // Play/pause button at top-left of progress bar (always visible)
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
                                            if (mounted) {
                                              setState(() {
                                                if (_videoPlayerController
                                                    .value
                                                    .isPlaying) {
                                                  _videoPlayerController
                                                      .pause();
                                                  _showControls = true;
                                                  _hideTimer?.cancel();
                                                } else {
                                                  _videoPlayerController.play();
                                                  _hideControlsAfterDelay();
                                                }
                                              });
                                            }
                                          },
                                        ),
                                        SizedBox(width: 8.w),
                                        // Timer
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
                                  // Progress bar at the very bottom
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

// Add this widget at the end of the file
class _ProgressModal extends StatelessWidget {
  final Stream<double> progressStream;
  const _ProgressModal({required this.progressStream});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: StreamBuilder<double>(
          stream: progressStream,
          initialData: 0.0,
          builder: (context, snapshot) {
            final percent =
                ((snapshot.data ?? 0.0) * 100).clamp(0, 100).toInt();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 8),
                Text(
                  'Submitting Job Order',
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
                        value: (snapshot.data ?? 0.0).clamp(0, 1),
                        strokeWidth: 7,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF2C9CD9),
                        ),
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Text(
                  percent < 100
                      ? 'Please wait while we process your request...'
                      : 'Done!',
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
                SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Triangle painter used by the tutorial overlay
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
