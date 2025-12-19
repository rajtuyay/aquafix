// Required imports
import 'dart:io';
import 'dart:typed_data';
import 'dart:async'; // Add this import for StreamController
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart'; // For download
import 'package:timezone/data/latest.dart' as tz;
import 'package:image_picker/image_picker.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_database/firebase_database.dart';

class JOReportForm extends StatefulWidget {
  final int plumberId;
  final int jobOrderId;

  const JOReportForm({
    Key? key,
    required this.plumberId,
    required this.jobOrderId,
  }) : super(key: key);

  @override
  _JOReportFormState createState() => _JOReportFormState();
}

class _JOReportFormState extends State<JOReportForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  AutovalidateMode autovalidateMode = AutovalidateMode.disabled;

  final TextEditingController _rootCauseController = TextEditingController();
  final TextEditingController _actionTakenController =
      TextEditingController(); // New field
  final TextEditingController _dateTimeStartedController =
      TextEditingController();
  final TextEditingController _dateTimeFinishedController =
      TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _bookSeqController =
      TextEditingController(); // Add this controller

  String? _selectedJOCategory; // New field
  String? _selectedStatus;

  String? _dateStartError;
  String? _dateFinishError;

  List<File> _selectedImages = [];
  List<File> _selectedVideos = [];
  Map<int, VideoPlayerController> _videoControllers = {};

  List<Map<String, String>> _materials = [];

  List<Map<String, dynamic>> _dbMaterials = [];
  bool _loadingMaterials = true;
  bool _isSubmitting = false;
  bool _isSaving = false; // <-- add this
  StreamController<double>? _progressController;
  String? _plumberFullName;

  bool _isDraftMode = false;

  int? _existingReportId; // Track if a report already exists for update

  @override
  void initState() {
    super.initState();
    _fetchMaterialsFromDb();
    _fetchPlumberFullName();
    _loadSavedReport(); // Load saved report if exists
  }

  // Fetch saved report from database and populate fields
  Future<void> _loadSavedReport() async {
    try {
      final uri = Uri.parse(
        'https://aquafixsansimon.com/api/report_draft_details.php?job_order_id=${widget.jobOrderId}&plumber_id=${widget.plumberId}',
      );
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        print('[JOReportForm] Fetched report_details data: $data');
        if (data is Map<String, dynamic> && data['report_id'] != null) {
          // --- Fix dropdown value assertion error ---
          // Allowed values for category and status
          final allowedCategories = [
            'Busted Pipe',
            'Busted Mainline',
            'Busted Meter Stand',
            'Change Ball Valve',
            'Change Meter',
            'Relocate Meter Stand',
            'Elevate Meter Stand',
            'Drain Mainline',
            'Drain Meter Stand',
          ];
          final allowedStatus = ['Accomplished', 'Cancelled'];

          String? fetchedCategory = data['category']?.toString();
          String? fetchedStatus = data['status']?.toString();

          // If fetched value is not in allowed list, set to null
          if (!allowedCategories.contains(fetchedCategory)) {
            fetchedCategory = null;
          }
          if (!allowedStatus.contains(fetchedStatus)) {
            fetchedStatus = null;
          }

          setState(() {
            _existingReportId = int.tryParse(data['report_id'].toString());
            _selectedJOCategory = fetchedCategory;
            _selectedStatus = fetchedStatus;
            _actionTakenController.text =
                data['action_taken']?.toString() ?? '';
            _rootCauseController.text = data['root_cause']?.toString() ?? '';
            _dateTimeStartedController.text =
                data['date_time_started']?.toString() ?? '';
            _dateTimeFinishedController.text =
                data['date_time_finished']?.toString() ?? '';
            _priceController.text = data['remarks']?.toString() ?? '';
            // Materials
            if (data['materials'] != null && data['materials'] is List) {
              _materials = List<Map<String, String>>.from(
                (data['materials'] as List).map((mat) {
                  // Find material_name using material_id from _dbMaterials
                  String materialName = '';
                  if (mat['material_id'] != null) {
                    final found = _dbMaterials.firstWhere(
                      (m) =>
                          m['material_id'].toString() ==
                          mat['material_id'].toString(),
                      orElse: () => {},
                    );
                    materialName =
                        found['material_name']?.toString() ??
                        (mat['material_name']?.toString() ??
                            mat['material']?.toString() ??
                            '');
                  } else {
                    materialName =
                        (mat['material'] ?? mat['material_name'] ?? '')
                            .toString();
                  }
                  final size = (mat['size'] ?? mat['s'] ?? '').toString();
                  final qty = (mat['qty'] ?? mat['quantity'] ?? '0').toString();
                  final unitPrice =
                      (mat['unit_price'] ??
                              mat['price'] ??
                              mat['unitPrice'] ??
                              '0')
                          .toString();

                  // compute total if backend didn't provide it
                  String totalPrice =
                      (mat['total_price'] ?? mat['totalPrice'] ?? null)
                          ?.toString() ??
                      (() {
                        final up = double.tryParse(unitPrice) ?? 0;
                        final q = double.tryParse(qty) ?? 0;
                        return (up * q).toStringAsFixed(0);
                      })();

                  return {
                    "material_id": mat['material_id']?.toString() ?? '',
                    "material_name": materialName,
                    "size": size,
                    "qty": qty,
                    "unit_price": unitPrice,
                    "total_price": totalPrice,
                  };
                }).toList(),
              );
              print(
                '[JOReportForm] _materials after report fetch: $_materials',
              );

              print(
                '[JOReportForm] data["attachments"]: ${data['attachments']}',
              );
              print(
                '[JOReportForm] data["attachments"] type: ${data['attachments']?.runtimeType}',
              );
              // Load server attachments if present
              if (data['attachments'] != null && data['attachments'] is List) {
                _serverAttachments = List<Map<String, dynamic>>.from(
                  (data['attachments'] as List).map((att) {
                    return {
                      'report_media_id': att['report_media_id'],
                      'file_path':
                          att['file_path'].toString().startsWith('/')
                              ? att['file_path']
                              : 'https://aquafixsansimon.com/uploads/report_media/' +
                                  att['file_path'],
                      'media_type': att['media_type'],
                      'thumbnail_path':
                          att['thumbnail_path'] != null
                              ? 'https://aquafixsansimon.com/uploads/report_media/' +
                                  att['thumbnail_path']
                              : null,
                    };
                  }),
                );
              } else {
                _serverAttachments = [];
              }
            }
          });
        }
      }
    } catch (e) {
      print('[JOReportForm] Error loading saved report: $e');
    }
  }

  Future<void> _fetchPlumberFullName() async {
    try {
      final response = await http.get(
        Uri.parse('https://aquafixsansimon.com/api/plumbers.php'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> plumbers = json.decode(response.body);
        final plumber = plumbers.firstWhere(
          (p) => p['plumber_id'].toString() == widget.plumberId.toString(),
          orElse: () => null,
        );
        if (plumber != null) {
          final firstName = plumber['first_name'] ?? '';
          final lastName = plumber['last_name'] ?? '';
          setState(() {
            _plumberFullName = (firstName + ' ' + lastName).trim();
          });
        }
      }
    } catch (e) {
      // Optionally handle error
      _plumberFullName = '';
    }
  }

  Future<void> _fetchMaterialsFromDb() async {
    setState(() {
      _loadingMaterials = true;
    });
    try {
      final response = await http.get(
        Uri.parse('https://aquafixsansimon.com/api/materials.php'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> mats = json.decode(response.body);
        setState(() {
          _dbMaterials = mats.cast<Map<String, dynamic>>();
          _loadingMaterials = false;
        });
      } else {
        setState(() {
          _dbMaterials = [];
          _loadingMaterials = false;
        });
      }
    } catch (e) {
      setState(() {
        _dbMaterials = [];
        _loadingMaterials = false;
      });
    }
  }

  @override
  void dispose() {
    _videoControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<bool> _validateVideo(File file) async {
    try {
      // Check file size (50MB = 52428800 bytes)
      final fileSize = await file.length();
      const maxBytes = 52428800;
      if (fileSize > maxBytes) {
        final name = file.path.split(Platform.pathSeparator).last;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name exceeds the 50MB limit.')),
        );
        return false;
      }

      // Allow common mobile video extensions
      final path = file.path.toLowerCase();
      final allowed = ['.mp4', '.mov'];
      final isAllowed = allowed.any((e) => path.endsWith(e));
      if (!isAllowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unsupported video type. Allowed: mp4, mov (max 50MB).',
            ),
          ),
        );
        return false;
      }

      return true;
    } catch (e) {
      print('[JOReportForm] Error validating video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to validate selected video.')),
      );
      return false;
    }
  }

  Future<bool> _validateMediaFile(File file) async {
    try {
      final path = file.path.toLowerCase();
      final fileSize = await file.length();
      const maxBytes = 52428800; // 50 MB

      if (fileSize > maxBytes) {
        final name = file.path.split(Platform.pathSeparator).last;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name exceeds the 50MB limit.')),
        );
        return false;
      }

      final allowedImageExt = ['.jpg', '.jpeg', '.png'];
      final allowedVideoExt = ['.mp4', '.mov'];

      final isImage = allowedImageExt.any((e) => path.endsWith(e));
      final isVideo = allowedVideoExt.any((e) => path.endsWith(e));

      if (!isImage && !isVideo) {
        final ext = path.contains('.') ? path.split('.').last : 'unknown';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unsupported file type "$ext". Allowed: jpg, jpeg, png, mp4, mov.',
            ),
          ),
        );
        return false;
      }

      return true;
    } catch (e) {
      print('[JOReportForm] Error validating media file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to validate selected file.')),
      );
      return false;
    }
  }

  Future<void> pickMultiMedia() async {
    final ImagePicker picker = ImagePicker();
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
                  final pickedFile = await picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (pickedFile != null) {
                    final file = File(pickedFile.path);
                    if (await _validateMediaFile(file)) {
                      setState(() {
                        _selectedImages.add(file);
                      });
                    }
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.videocam),
                title: Text('Take Video'),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile = await picker.pickVideo(
                    source: ImageSource.camera,
                  );
                  if (pickedFile != null) {
                    final file = File(pickedFile.path);
                    // Keep existing video-specific checks and also general validation
                    if (await _validateVideo(file) &&
                        await _validateMediaFile(file)) {
                      setState(() {
                        _selectedVideos.add(file);
                      });
                    }
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Select from Album'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles(
                    allowMultiple: true,
                    type: FileType.custom,
                    allowedExtensions: ['jpg', 'png', 'jpeg', 'mp4', 'mov'],
                  );
                  if (result != null && result.files.isNotEmpty) {
                    for (final file in result.files) {
                      if (file.path == null) continue;
                      final fileObj = File(file.path!);
                      final valid = await _validateMediaFile(fileObj);
                      if (!valid) continue;
                      final lower = file.extension?.toLowerCase() ?? '';
                      if (lower == 'mp4' || lower == 'mov') {
                        // additional video codec/size messages are handled by validator
                        _selectedVideos.add(fileObj);
                      } else {
                        _selectedImages.add(fileObj);
                      }
                    }
                    setState(() {});
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

  Widget _buildMediaButton(IconData icon, VoidCallback onTap) {
    return Container(
      width: 70.w,
      height: 70.w,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: IconButton(
        icon: Icon(icon, size: 32.sp, color: Colors.grey),
        onPressed: onTap, // On tap, it will pick image/video
      ),
    );
  }

  List<Map<String, dynamic>> _serverAttachments = [];

  Widget _buildMediaCard(
    File file,
    int index, {
    bool isServerAttachment = false,
    int? serverAttachmentId,
  }) {
    int imageCount = _selectedImages.length;
    final isVideo =
        isServerAttachment
            ? (_serverAttachments[index]['media_type'] == 'video')
            : file.path.endsWith('.mp4') || file.path.endsWith('.mov');
    String? serverThumbnail;
    String? serverFilePath;
    if (isServerAttachment && index < _serverAttachments.length) {
      serverThumbnail = _serverAttachments[index]['thumbnail_path'];
      serverFilePath = _serverAttachments[index]['file_path'];
    }
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            if (isServerAttachment) {
              if (isVideo && serverFilePath != null) {
                // Open network video preview
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => FullVideoView(
                          videoFile: null,
                          videoUrl: serverFilePath,
                        ),
                  ),
                );
              } else if (serverFilePath != null) {
                // Open network image preview
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => FullImageView(
                          imageFile: null,
                          imageUrl: serverFilePath,
                        ),
                  ),
                );
              }
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) =>
                          isVideo
                              ? FullVideoView(videoFile: file)
                              : FullImageView(imageFile: file),
                ),
              );
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: Container(
              width: 70.w,
              height: 70.w,
              color: Colors.black12,
              child:
                  isServerAttachment
                      ? (isVideo
                          // Show server thumbnail if available, else fallback icon
                          ? (serverThumbnail != null
                              ? Image.network(
                                serverThumbnail,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        Center(child: Icon(Icons.videocam)),
                              )
                              : Center(
                                child: Icon(
                                  Icons.videocam,
                                  size: 32.sp,
                                  color: Colors.grey,
                                ),
                              ))
                          : (serverFilePath != null
                              ? Image.network(
                                serverFilePath,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        Center(child: Icon(Icons.broken_image)),
                              )
                              : Center(child: Icon(Icons.broken_image))))
                      : (isVideo
                          ? FutureBuilder<Uint8List>(
                            future: _generateThumbnail(file.path),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                      ConnectionState.done &&
                                  snapshot.hasData &&
                                  snapshot.data!.isNotEmpty) {
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                );
                              } else {
                                return Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              }
                            },
                          )
                          : Image.file(file, fit: BoxFit.cover)),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: () async {
              if (isServerAttachment && serverAttachmentId != null) {
                await _deleteAttachmentFromServer(serverAttachmentId);
                setState(() {
                  if (index >= 0 && index < _serverAttachments.length) {
                    _serverAttachments.removeAt(index);
                  }
                });
              } else {
                setState(() {
                  if (isVideo) {
                    final videoIndex = index - imageCount;
                    if (videoIndex >= 0 &&
                        videoIndex < _selectedVideos.length) {
                      _selectedVideos.removeAt(videoIndex);
                    }
                  } else {
                    if (index >= 0 && index < _selectedImages.length) {
                      _selectedImages.removeAt(index);
                    }
                  }
                });
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 16.sp, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitJobOrder() async {
    if (_isSubmitting) return; // Prevent double submit
    if (!_formKey.currentState!.validate()) {
      setState(() {
        autovalidateMode = AutovalidateMode.always;
      });
      return;
    }

    _validateDateFields(); // <-- Add this

    if (_dateStartError != null || _dateFinishError != null) {
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    // Validate required fields manually
    bool invalidDateStarted =
        _dateTimeStartedController.text.trim().isEmpty ||
        _dateTimeStartedController.text.trim() == '0000-00-00 00:00:00';
    bool invalidDateFinished =
        _dateTimeFinishedController.text.trim().isEmpty ||
        _dateTimeFinishedController.text.trim() == '0000-00-00 00:00:00';

    if ((_selectedJOCategory == null || _selectedJOCategory!.isEmpty) ||
        _actionTakenController.text.trim().isEmpty ||
        _rootCauseController.text.trim().isEmpty ||
        invalidDateStarted ||
        invalidDateFinished ||
        (_selectedStatus == null || _selectedStatus!.isEmpty) ||
        (_selectedImages.isEmpty &&
            _selectedVideos.isEmpty &&
            _serverAttachments.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill all required fields and add at least one attachment.',
          ),
        ),
      );
      return;
    }

    // Validate selected local files before sending
    final allLocalMedia = [..._selectedImages, ..._selectedVideos];
    for (final file in allLocalMedia) {
      final ok = await _validateMediaFile(file);
      if (!ok) {
        // validation shows snack message already; abort submission
        return;
      }
    }

    final startText = _dateTimeStartedController.text.trim();
    final finishText = _dateTimeFinishedController.text.trim();
    if (startText.isNotEmpty &&
        finishText.isNotEmpty &&
        startText != '0000-00-00 00:00:00' &&
        finishText != '0000-00-00 00:00:00') {
      try {
        final start = DateTime.parse(startText);
        final finish = DateTime.parse(finishText);
        if (!finish.isAfter(start)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Finish time must be after start time.')),
          );
          setState(() {
            _isSubmitting = false;
          });
          return;
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invalid date format.')));

        setState(() {
          _isSubmitting = false;
        });
        return;
      }
    }

    final jobOrderId = widget.jobOrderId;
    final plumberId = widget.plumberId;
    if (jobOrderId == 0 || plumberId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Missing job order or plumber ID.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isDraftMode = false;
    });
    if (!_formKey.currentState!.validate()) return;

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
      // Prepare materials with price/total
      final List<Map<String, dynamic>> materials =
          _materials.map((e) {
            return {
              "material_id": int.tryParse(e['material_id'] ?? '0') ?? 0,
              "qty": int.tryParse(e['qty'] ?? '0') ?? 0,
              "total_price":
                  double.tryParse(e['total_price'].toString()) ?? 0.0,
            };
          }).toList();

      final dio = Dio();
      final formData = FormData();

      final uri = Uri.parse(
        'https://aquafixsansimon.com/api/report_submit.php',
      );
      var request = http.MultipartRequest('POST', uri);

      // Insert or update depending on _existingReportId
      if (_existingReportId != null) {
        formData.fields.add(
          MapEntry('report_id', _existingReportId.toString()),
        );
        formData.fields.add(MapEntry('update', '1'));
      }

      formData.fields.addAll([
        MapEntry('job_order_id', widget.jobOrderId.toString()),
        MapEntry('plumber_id', widget.plumberId.toString()),
        MapEntry('category', _selectedJOCategory ?? ''),
        MapEntry('action_taken', _actionTakenController.text.trim()),
        MapEntry('root_cause', _rootCauseController.text.trim()),
        MapEntry('date_time_started', _dateTimeStartedController.text.trim()),
        MapEntry('date_time_finished', _dateTimeFinishedController.text.trim()),
        MapEntry('status', _selectedStatus ?? ''),
        MapEntry('remarks', _priceController.text.trim()),
        MapEntry('materials', json.encode(materials)),
        MapEntry('accomplished_by', _plumberFullName ?? ''),
        MapEntry('is_draft', '0'), // Not a draft
      ]);

      // Attach images and videos
      int mediaIndex = 0;
      final allMedia = [..._selectedImages, ..._selectedVideos];
      for (final file in allMedia) {
        final fileName = file.path.split(Platform.pathSeparator).last;
        formData.files.add(
          MapEntry(
            'media[$mediaIndex]',
            await MultipartFile.fromFile(file.path, filename: fileName),
          ),
        );
        mediaIndex++;
      }

      final response = await dio.post(
        'https://aquafixsansimon.com/api/report_submit.php',
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) {
            updateProgress(sent / total);
          }
        },
      );

      updateProgress(1.0);

      await Future.delayed(const Duration(milliseconds: 500));
      Navigator.of(context, rootNavigator: true).pop();

      final resp =
          response.data is String ? json.decode(response.data) : response.data;

      if (resp['success'] == true) {
        setState(() {
          _existingReportId =
              int.tryParse(resp['report_id'].toString()) ?? _existingReportId;
        });
        // --- Call accomplishment chat API after successful report submission ---
        final status = _selectedStatus ?? '';
        final accomplishmentApiUrl =
            'https://aquafixsansimon.com/api/report_details.php';
        final accomplishmentPayload = {
          'job_order_id': jobOrderId,
          'status': status,
        };
        print(
          '[JOReportForm] Sending accomplishment chat API: $accomplishmentApiUrl',
        );
        print('[JOReportForm] Payload: ${json.encode(accomplishmentPayload)}');
        final accomplishmentResp = await http.post(
          Uri.parse(accomplishmentApiUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(accomplishmentPayload),
        );
        print(
          '[JOReportForm] Accomplishment chat response status: ${accomplishmentResp.statusCode}',
        );
        print(
          '[JOReportForm] Accomplishment chat response body: ${accomplishmentResp.body}',
        );
        // Optionally handle response, show error if failed
        if (accomplishmentResp.statusCode == 200) {
          print('[JOReportForm] Accomplishment chat sent successfully.');
        }

        if (_existingReportId != null) {
          await _sendReportToFirebase(_existingReportId!);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report submitted successfully!')),
        );
        Navigator.of(context).pop(true); // Go back or to another page
      } else {
        print('[JOReportForm] Report submission failed: $resp');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report. Please try again.')),
        );
      }
    } catch (e, st) {
      print('[JOReportForm] Error during report submission: $e\n$st');
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'An error occurred while submitting the report. Please check your connection and try again.',
          ),
        ),
      );
    } finally {
      _progressController?.close();
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Helper function to fetch jo_number from backend
  Future<String?> _fetchJONumber(int jobOrderId) async {
    try {
      final resp = await http.get(
        Uri.parse(
          'https://aquafixsansimon.com/api/jo_number_lookup.php?job_order_id=$jobOrderId',
        ),
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        // PHP returns an object: { "jo_number": ... }
        if (data is Map<String, dynamic> && data['jo_number'] != null) {
          return data['jo_number'].toString();
        }
      }
    } catch (e) {
      print('[JOReportForm] Error fetching jo_number: $e');
    }
    return null;
  }

  // Update this function to send notification to Firebase with the correct structure
  Future<void> _sendReportToFirebase(int reportId) async {
    try {
      // Fetch the actual jo_number from backend
      final joNumber =
          await _fetchJONumber(widget.jobOrderId) ?? 'JO-${widget.jobOrderId}';

      final bodyText = 'A report has been submitted for job order #$joNumber.';
      print("[JOReportForm] Job Order Number: $joNumber");
      print("[JOReportForm] Job Order ID: ${widget.jobOrderId}");

      // Get Philippine time zone location
      final phLocation = tz.getLocation('Asia/Manila');
      final nowPH = tz.TZDateTime.now(phLocation);
      final timestamp =
          "${nowPH.year.toString().padLeft(4, '0')}-"
          "${nowPH.month.toString().padLeft(2, '0')}-"
          "${nowPH.day.toString().padLeft(2, '0')} "
          "${nowPH.hour.toString().padLeft(2, '0')}:"
          "${nowPH.minute.toString().padLeft(2, '0')}:"
          "${nowPH.second.toString().padLeft(2, '0')}";

      // Push notification to Firebase using plumberId
      final DatabaseReference notifRef =
          FirebaseDatabase.instance.ref('reports/${widget.plumberId}').push();

      await notifRef.set({
        'adminViewed': false,
        'body': bodyText,
        'timestamp': timestamp,
        'title': 'Job Order Report Submitted',
      });

      print('[JOReportForm] Notification sent to Firebase: $bodyText');
    } catch (e) {
      print('[JOReportForm] Error sending notification to Firebase: $e');
    }
  }

  // Save as draft (do not require fields)
  Future<void> _saveJobOrder() async {
    setState(() {
      _isSaving = true;
      _isDraftMode = true;
    });

    _validateDateFields(); // <-- Add this

    if (_dateStartError != null || _dateFinishError != null) {
      setState(() {
        _isSaving = false;
      });
      return;
    }

    final startText = _dateTimeStartedController.text.trim();
    final finishText = _dateTimeFinishedController.text.trim();
    if (startText.isNotEmpty &&
        finishText.isNotEmpty &&
        startText != '0000-00-00 00:00:00' &&
        finishText != '0000-00-00 00:00:00') {
      try {
        final start = DateTime.parse(startText);
        final finish = DateTime.parse(finishText);
        if (!finish.isAfter(start)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Finish time must be after start time.')),
          );
          setState(() {
            _isSaving = false;
          });
          return;
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invalid date format.')));
        setState(() {
          _isSaving = false;
        });
        return;
      }
    }

    try {
      final materials =
          _materials.map((e) {
            return {
              "material_id": int.tryParse(e['material_id'] ?? '0') ?? 0,
              "qty": int.tryParse(e['qty'] ?? '0') ?? 0,
              "total_price": double.tryParse(e['total_price'] ?? '0') ?? 0.0,
            };
          }).toList();

      final Map<String, dynamic> payload = {
        "job_order_id": widget.jobOrderId,
        "plumber_id": widget.plumberId,
        "category": _selectedJOCategory ?? '',
        "action_taken": _actionTakenController.text.trim(),
        "root_cause": _rootCauseController.text.trim(),
        "date_time_started": _dateTimeStartedController.text.trim(),
        "date_time_finished": _dateTimeFinishedController.text.trim(),
        "status": _selectedStatus ?? '',
        "remarks": _priceController.text.trim(),
        "materials": materials, // <-- now correct
        "accomplished_by": _plumberFullName ?? '',
        "is_draft": true,
      };
      if (_existingReportId != null) {
        payload["report_id"] = _existingReportId;
      }

      print(
        '[JOReportForm] SAVE DRAFT PAYLOAD: ${json.encode(payload)}',
      ); // <-- added print

      final uri = Uri.parse('https://aquafixsansimon.com/api/report_save.php');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      final respData = json.decode(resp.body);
      if (resp.statusCode == 200 && respData['success'] == true) {
        setState(() {
          _existingReportId = respData['report_id'] ?? _existingReportId;
        });

        // Save Attachments if any
        if ((_selectedImages.isNotEmpty || _selectedVideos.isNotEmpty) &&
            _existingReportId != null) {
          await _saveAttachmentsToServer(_existingReportId!);
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Report saved as draft.')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save draft.')));
      }
    } catch (e) {
      // Show friendly message to user; log details for debugging
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save draft. Please check your connection and try again.',
          ),
        ),
      );
      print('[JOReportForm] Error saving draft: $e');
    } finally {
      setState(() {
        _isSaving = false;
        _isDraftMode = false;
      });
    }
  }

  Future<void> _saveAttachmentsToServer(int reportId) async {
    final dio = Dio();
    final formData = FormData();

    // Validate selected local files before uploading
    final allLocalMedia = [..._selectedImages, ..._selectedVideos];
    for (final file in allLocalMedia) {
      final ok = await _validateMediaFile(file);
      if (!ok) {
        // validation already notifies user
        return;
      }
    }

    int mediaIndex = 0;
    final allMedia = [..._selectedImages, ..._selectedVideos];
    for (final file in allMedia) {
      final fileName = file.path.split(Platform.pathSeparator).last;
      formData.files.add(
        MapEntry(
          'media[$mediaIndex]',
          await MultipartFile.fromFile(file.path, filename: fileName),
        ),
      );

      // --- Add this block for video thumbnails ---
      if (file.path.toLowerCase().endsWith('.mp4') ||
          file.path.toLowerCase().endsWith('.mov')) {
        final thumb = await VideoCompress.getByteThumbnail(
          file.path,
          quality: 75,
          position: -1,
        );
        if (thumb != null) {
          formData.files.add(
            MapEntry(
              'thumbnail[$mediaIndex]',
              MultipartFile.fromBytes(thumb, filename: 'thumb.jpg'),
            ),
          );
        }
      }

      mediaIndex++;
    }
    formData.fields.add(MapEntry('report_id', reportId.toString()));

    try {
      final response = await dio.post(
        'https://aquafixsansimon.com/api/report_media_save.php',
        data: formData,
      );
      print('[JOReportForm] Attachments save response: ${response.data}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attachments uploaded successfully.')),
      );
    } catch (e) {
      // User-friendly message; log details for debugging
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to upload attachments. Please check your connection and try again.',
          ),
        ),
      );
      print('[JOReportForm] Error saving attachments: $e');
      if (e is DioException) {
        print('[JOReportForm] DioException: ${e.toString()}');
        print('[JOReportForm] Request URI: ${e.requestOptions.uri}');
        if (e.response != null) {
          print('[JOReportForm] Response status: ${e.response?.statusCode}');
          print('[JOReportForm] Response data: ${e.response?.data}');
        }
      }
    }
  }

  Future<void> _deleteAttachmentFromServer(int reportMediaId) async {
    // Show confirmation dialog before deleting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_forever, size: 48, color: Colors.redAccent),
                SizedBox(height: 16),
                Text(
                  'Delete Attachment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Are you sure you want to delete this attachment? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true) return;

    try {
      final resp = await http.post(
        Uri.parse('https://aquafixsansimon.com/api/report_media_delete.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'report_media_id': reportMediaId}),
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Attachment deleted successfully.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete attachment.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error deleting attachment.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete attachment. Please check your connection and try again.',
          ),
        ),
      );
      print('[JOReportForm] Error deleting attachment: $e');
    }
  }

  void _addMaterial() {
    String? selectedMaterial;
    String? selectedSize;
    int? selectedPrice;
    final qtyController = TextEditingController();
    final materialFormKey = GlobalKey<FormState>(); // Add form key

    // Get unique material names from db
    final List<String> materialNames =
        _dbMaterials.map((e) => e['material_name'].toString()).toSet().toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            // Sizes for selected material
            final List<Map<String, dynamic>> sizes =
                selectedMaterial == null
                    ? []
                    : _dbMaterials
                        .where((e) => e['material_name'] == selectedMaterial)
                        .toList();
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 16.h,
                left: 16.w,
                right: 16.w,
              ),
              child: Form(
                key: materialFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Add Material", style: TextStyle(fontSize: 16.sp)),
                    SizedBox(height: 14.h),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Material',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      value: selectedMaterial,
                      items:
                          materialNames
                              .map(
                                (mat) => DropdownMenuItem(
                                  value: mat,
                                  child: Text(mat),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        modalSetState(() {
                          selectedMaterial = value;
                          selectedSize = null;
                          selectedPrice = null;
                        });
                      },
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Required'
                                  : null,
                    ),
                    SizedBox(height: 10.h),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Size',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      value: selectedSize,
                      items:
                          sizes
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e['size'].toString(),
                                  child: Text(e['size'].toString()),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        modalSetState(() {
                          selectedSize = value;
                          final found = sizes.firstWhere(
                            (e) => e['size'].toString() == value,
                            orElse: () => {},
                          );
                          selectedPrice =
                              int.tryParse(found['price'].toString()) ?? 0;
                        });
                      },
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Required'
                                  : null,
                    ),
                    SizedBox(height: 10.h),
                    TextFormField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(2),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Qty',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      validator:
                          (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                    ),
                    SizedBox(height: 10.h),
                    if (selectedPrice != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Unit Price: ₱$selectedPrice",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    SizedBox(height: 20.h),
                    ElevatedButton(
                      onPressed: () {
                        if (materialFormKey.currentState?.validate() ?? false) {
                          final selectedDbMaterial = sizes.firstWhere(
                            (e) => e['size'].toString() == selectedSize,
                            orElse: () => <String, dynamic>{},
                          );

                          if (selectedDbMaterial.isNotEmpty) {
                            setState(() {
                              _materials.add({
                                "material_id":
                                    selectedDbMaterial['material_id']
                                        .toString(),
                                "material_name": selectedMaterial!,
                                "size": selectedSize!,
                                "qty": qtyController.text,
                                "unit_price": double.parse(
                                  selectedDbMaterial['price'].toString(),
                                ).toStringAsFixed(2),
                                "total_price":
                                    ((int.tryParse(qtyController.text) ?? 0) *
                                            (double.tryParse(
                                                  selectedDbMaterial['price']
                                                      .toString(),
                                                ) ??
                                                0.0))
                                        .toStringAsFixed(2),
                              });
                            });
                          }
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D9FD0),
                        minimumSize: Size(double.infinity, 44.h),
                        foregroundColor: Colors.white,
                        textStyle: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 30.h),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Save current _materials to server (only updates materials, not report fields)
  Future<void> _saveMaterialsToServer({bool showSnack = true}) async {
    try {
      final materialsPayload =
          _materials.map((e) {
            return {
              'material_id': int.tryParse(e['material_id'] ?? '0') ?? 0,
              'qty': int.tryParse(e['qty'] ?? '0') ?? 0,
              'total_price': double.tryParse(e['total_price'] ?? '0') ?? 0.0,
            };
          }).toList();

      final existingId = _existingReportId;
      if (existingId == null) {
        // Don't save if report_id is not available
        if (showSnack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot update materials: report not saved yet.'),
            ),
          );
        }
        return;
      }

      final Map<String, dynamic> payload = {
        'report_id': existingId,
        'materials': materialsPayload,
      };

      final uri = Uri.parse(
        'https://aquafixsansimon.com/api/report_materials_update.php',
      );
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      print('[JOReportForm] Raw response from materials update:');
      print(resp.body);
      if (resp.statusCode == 200) {
        final respData = json.decode(resp.body);
        if (respData['success'] == true || respData['success'] == 1) {
          if (showSnack) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Materials updated.')));
          }
        } else {
          if (showSnack) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update materials (server error).'),
              ),
            );
          }
        }
      } else {
        if (showSnack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update materials (server error).'),
            ),
          );
        }
      }
    } catch (e) {
      if (showSnack) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating materials: $e')));
      }
    }
  }

  Widget _buildMaterialTable() {
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
              SizedBox(width: 40), // space for delete icon column
            ],
          ),
          Divider(),
          if (_materials.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("No material added yet."),
            )
          else
            // Use asMap so we have the index for deletion/undo logic
            ..._materials.asMap().entries.map((entry) {
              final int idx = entry.key;
              final e = entry.value;
              // Parse as double for price/total
              final unitPrice = double.tryParse(e['unit_price'] ?? '0') ?? 0.0;
              final qty = double.tryParse(e['qty'] ?? '0') ?? 0.0;
              final total =
                  double.tryParse(e['total_price'] ?? '') ?? (unitPrice * qty);

              // Keep a stable key based on content/index
              final dismissKey = ValueKey(
                'material_${idx}_${e['material_name']}_${e['size']}',
              );

              return Dismissible(
                key: dismissKey,
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.only(right: 20.w),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  // Show confirmation dialog (modern look)
                  final shouldDelete = await showDialog<bool>(
                    context: context,
                    builder: (ctx) {
                      return Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.delete_forever,
                                size: 40.sp,
                                color: Colors.redAccent,
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                'Remove Material',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Are you sure you want to remove "${e['material_name'] ?? ''} (${e['size'] ?? ''})"?',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(height: 16.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed:
                                          () => Navigator.of(ctx).pop(false),
                                      child: Text('CANCEL'),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                      ),
                                      onPressed:
                                          () => Navigator.of(ctx).pop(true),
                                      child: Text('DELETE'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                  return shouldDelete ?? false;
                },
                onDismissed: (direction) async {
                  // Remove and offer undo, then persist change to DB
                  final removed = Map<String, String>.from(_materials[idx]);
                  setState(() {
                    if (idx < _materials.length) {
                      _materials.removeAt(idx);
                    } else if (_materials.isNotEmpty) {
                      _materials.removeLast();
                    }
                  });

                  // Save updated materials to server (do not show immediate snack here)
                  _saveMaterialsToServer(showSnack: false);

                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Material removed'),
                      action: SnackBarAction(
                        label: 'UNDO',
                        onPressed: () {
                          setState(() {
                            final insertIndex =
                                idx <= _materials.length
                                    ? idx
                                    : _materials.length;
                            _materials.insert(insertIndex, removed);
                          });
                          // restore on server (fire-and-forget)
                          _saveMaterialsToServer(showSnack: false);
                        },
                      ),
                      duration: Duration(seconds: 4),
                    ),
                  );
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 3.h),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          e['material_name'] ?? '',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          e['size'] ?? '',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          e['qty'] ?? '',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          "₱${unitPrice.toStringAsFixed(0)}",
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          "₱${total.toStringAsFixed(0)}",
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      // Delete icon (tap to delete with confirmation)
                      SizedBox(
                        width: 40.w,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                            size: 20.sp,
                          ),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) {
                                return Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(16.w),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.delete_forever,
                                          size: 40.sp,
                                          color: Colors.redAccent,
                                        ),
                                        SizedBox(height: 12.h),
                                        Text(
                                          'Remove Material',
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 8.h),
                                        Text(
                                          'Are you sure you want to remove "${e['material_name'] ?? ''} (${e['size'] ?? ''})"?',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        SizedBox(height: 16.h),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed:
                                                    () => Navigator.of(
                                                      ctx,
                                                    ).pop(false),
                                                child: Text('CANCEL'),
                                              ),
                                            ),
                                            SizedBox(width: 8.w),
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.redAccent,
                                                ),
                                                onPressed:
                                                    () => Navigator.of(
                                                      ctx,
                                                    ).pop(true),
                                                child: Text('DELETE'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                            if (confirmed == true) {
                              final removed = Map<String, String>.from(
                                _materials[idx],
                              );
                              setState(() {
                                if (idx < _materials.length) {
                                  _materials.removeAt(idx);
                                } else if (_materials.isNotEmpty) {
                                  _materials.removeLast();
                                }
                              });

                              // Persist deletion to server
                              _saveMaterialsToServer(showSnack: false);

                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Material removed'),
                                  action: SnackBarAction(
                                    label: 'UNDO',
                                    onPressed: () {
                                      setState(() {
                                        final insertIndex =
                                            idx <= _materials.length
                                                ? idx
                                                : _materials.length;
                                        _materials.insert(insertIndex, removed);
                                      });
                                      _saveMaterialsToServer(showSnack: false);
                                    },
                                  ),
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13.sp),
      contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
    );
  }

  Future<void> _pickDateTime(
    BuildContext context,
    TextEditingController controller, {
    GlobalKey<FormState>? formKey,
  }) async {
    // Get Philippine time zone location
    final phLocation = tz.getLocation('Asia/Manila');
    final nowPH = tz.TZDateTime.now(phLocation);

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: nowPH,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;

    // Use Philippine current time for the time picker
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: nowPH.hour, minute: nowPH.minute),
    );
    if (pickedTime == null) return;

    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    controller.text =
        "${dt.year.toString().padLeft(4, '0')}-"
        "${dt.month.toString().padLeft(2, '0')}-"
        "${dt.day.toString().padLeft(2, '0')} "
        "${dt.hour.toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')}";

    WidgetsBinding.instance.addPostFrameCallback((_) {
      formKey?.currentState?.validate();
      _validateDateFields(); // <-- Add this
    });
  }

  void _validateDateFields() {
    final startText = _dateTimeStartedController.text.trim();
    final finishText = _dateTimeFinishedController.text.trim();
    String? startError;
    String? finishError;

    // Validate start date
    if (startText.isNotEmpty && startText != '0000-00-00 00:00:00') {
      try {
        final parsed = DateTime.parse(startText);
        final phLocation = tz.getLocation('Asia/Manila');
        final nowPH = tz.TZDateTime.now(phLocation);
        if (parsed.isAfter(nowPH)) {
          startError = 'Start time cannot be in the future.';
        }
      } catch (e) {
        startError = 'Invalid date format.';
      }
    }

    // Validate finish date
    if (finishText.isNotEmpty && finishText != '0000-00-00 00:00:00') {
      final startText = _dateTimeStartedController.text.trim();
      if (startText.isNotEmpty && startText != '0000-00-00 00:00:00') {
        try {
          final start = DateTime.parse(startText);
          final finish = DateTime.parse(finishText);
          if (!finish.isAfter(start)) {
            finishError = 'Finish time must be after start time.';
          }
        } catch (e) {
          finishError = 'Invalid date format.';
        }
      }
    }

    setState(() {
      _dateStartError = startError;
      _dateFinishError = finishError;
    });
  }

  Future<Uint8List> _generateThumbnail(String videoPath) async {
    try {
      await VideoCompress.deleteAllCache();
      final uint8list = await VideoCompress.getByteThumbnail(
        videoPath,
        quality: 50,
        position: -1,
      );
      return uint8list ?? Uint8List(0);
    } catch (e) {
      print("Error generating thumbnail: $e");
      return Uint8List(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C9CD9),
        title: Text(
          'Job Order Report Form',
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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          autovalidateMode: autovalidateMode,
          child: Column(
            children: [
              // Category/Reason and Status in the same row, manual width
              LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final categoryWidth = totalWidth * 0.55;
                  final statusWidth = totalWidth * 0.45;
                  return Row(
                    children: [
                      SizedBox(
                        width: categoryWidth,
                        child: DropdownButtonFormField<String>(
                          value: _selectedJOCategory,
                          decoration: _inputDecoration('Category'),
                          items:
                              [
                                    'Busted Pipe',
                                    'Busted Mainline',
                                    'Busted Meter Stand',
                                    'Change Ball Valve',
                                    'Change Meter',
                                    'Relocate Meter Stand',
                                    'Elevate Meter Stand',
                                    'Drain Mainline',
                                    'Drain Meter Stand',
                                  ]
                                  .map(
                                    (cat) => DropdownMenuItem(
                                      value: cat,
                                      child: Text(
                                        cat,
                                        style: TextStyle(fontSize: 13.sp),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedJOCategory = value;
                            });
                          },
                          validator:
                              (value) =>
                                  (value == null || value.isEmpty)
                                      ? 'Required'
                                      : null,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      SizedBox(
                        width: statusWidth - 10.w, // subtract spacing
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: _inputDecoration('Status'),
                          items:
                              ['Accomplished', 'Cancelled']
                                  .map(
                                    (status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(
                                        status,
                                        style: TextStyle(fontSize: 13.sp),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value;
                            });
                          },
                          validator:
                              (value) =>
                                  (value == null || value.isEmpty)
                                      ? 'Required'
                                      : null,
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 12.h),

              // Meter Findings (Root Cause) TextField (required)
              TextFormField(
                controller: _rootCauseController,
                decoration: _inputDecoration('Root Cause/Meter Findings'),
                style: TextStyle(fontSize: 13.sp),
                validator:
                    (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _actionTakenController,
                decoration: _inputDecoration('Action Taken'),
                style: TextStyle(fontSize: 13.sp),
                validator:
                    (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
              ),
              SizedBox(height: 12.h),
              // REMOVE Book Sequence field
              // Row(
              //   children: [
              //     Expanded(
              //       child: TextFormField(
              //         controller: _bookSeqController, // Use new controller
              //         decoration: _inputDecoration('Book Sequence'),
              //         style: TextStyle(fontSize: 13.sp),
              //         validator:
              //             (value) =>
              //                 (value == null || value.trim().isEmpty)
              //                     ? 'Required'
              //                     : null,
              //       ),
              //     ),
              //     // JO Category Dropdown (required)
              //     SizedBox(width: 10.w),
              //     Expanded(
              //       child: DropdownButtonFormField<String>(
              //         value: _selectedStatus,
              //         decoration: _inputDecoration('Status'),
              //         items:
              //             ['Accomplished', 'Cancelled']
              //                 .map(
              //                   (status) => DropdownMenuItem(
              //                     value: status,
              //                     child: Text(
              //                       status,
              //                       style: TextStyle(fontSize: 13.sp),
              //                     ),
              //                   ),
              //                 )
              //                 .toList(),
              //         onChanged: (value) {
              //           setState(() {
              //             _selectedStatus = value;
              //           });
              //         },
              //         validator:
              //             (value) =>
              //                 (value == null || value.isEmpty)
              //                     ? 'Required'
              //                     : null,
              //       ),
              //     ),
              //   ],
              // ),
              // SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap:
                          () => _pickDateTime(
                            context,
                            _dateTimeStartedController,
                          ),
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _dateTimeStartedController,
                          autovalidateMode: AutovalidateMode.disabled,
                          decoration: _inputDecoration('Date Time Started'),
                          style: TextStyle(fontSize: 13.sp),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty ||
                                value.trim() == '0000-00-00 00:00:00') {
                              return 'Required';
                            }
                            try {
                              final parsed = DateTime.parse(value.trim());
                              final phLocation = tz.getLocation('Asia/Manila');
                              final nowPH = tz.TZDateTime.now(phLocation);
                              if (parsed.isAfter(nowPH)) {
                                return null; // Show custom label instead
                              }
                            } catch (e) {
                              return null;
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: GestureDetector(
                      onTap:
                          () => _pickDateTime(
                            context,
                            _dateTimeFinishedController,
                          ),
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _dateTimeFinishedController,
                          autovalidateMode: AutovalidateMode.disabled,
                          decoration: _inputDecoration('Date Time Finished'),
                          style: TextStyle(fontSize: 13.sp),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty ||
                                value.trim() == '0000-00-00 00:00:00') {
                              return 'Required';
                            }
                            final startText =
                                _dateTimeStartedController.text.trim();
                            if (startText.isNotEmpty &&
                                startText != '0000-00-00 00:00:00') {
                              try {
                                final start = DateTime.parse(startText);
                                final finish = DateTime.parse(value.trim());
                                if (!finish.isAfter(start)) {
                                  return null; // Show custom label instead
                                }
                              } catch (e) {
                                return null;
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_dateStartError != null && _dateStartError!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4, left: 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _dateStartError!,
                      style: TextStyle(color: Colors.red, fontSize: 12.sp),
                    ),
                  ),
                ),
              if (_dateFinishError != null && _dateFinishError!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4, left: 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _dateFinishError!,
                      style: TextStyle(color: Colors.red, fontSize: 12.sp),
                    ),
                  ),
                ),
              SizedBox(height: 12.h),

              TextFormField(
                controller: _priceController,
                maxLines: 3,
                decoration: _inputDecoration('Remarks'),
                style: TextStyle(fontSize: 13.sp),
                // Remarks is optional, no validator
              ),
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Materials',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                  IconButton(icon: Icon(Icons.add), onPressed: _addMaterial),
                ],
              ),
              _buildMaterialTable(),
              SizedBox(height: 16.h),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Attachments',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
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
                      _buildMediaButton(Icons.add, pickMultiMedia),
                      SizedBox(width: 10.w),
                      // Server attachments first
                      ...List.generate(
                        _serverAttachments.length,
                        (i) => Padding(
                          padding: EdgeInsets.only(right: 10.w),
                          child: _buildMediaCard(
                            File(
                              '',
                            ), // Pass an empty File, not used for server attachments
                            i,
                            isServerAttachment: true,
                            serverAttachmentId:
                                _serverAttachments[i]['report_media_id'],
                          ),
                        ),
                      ),
                      ...List.generate(
                        _selectedImages.length + _selectedVideos.length,
                        (i) => Padding(
                          padding: EdgeInsets.only(right: 10.w),
                          child: _buildMediaCard(
                            i < _selectedImages.length
                                ? _selectedImages[i]
                                : _selectedVideos[i - _selectedImages.length],
                            i,
                            isServerAttachment: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Attachments are required, show error if none selected
              // Only show when submitting and no attachments
              if (_isSubmitting &&
                  _selectedImages.isEmpty &&
                  _selectedVideos.isEmpty &&
                  _serverAttachments.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'At least one attachment is required.',
                      style: TextStyle(color: Colors.red, fontSize: 12.sp),
                    ),
                  ),
                ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          20.w,
          0,
          20.w,
          20.h + MediaQuery.of(context).padding.bottom,
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Color(0xFF2C9CD9), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                onPressed: _isSaving ? null : _saveJobOrder,
                child:
                    _isSaving
                        ? SizedBox(
                          width: 22.sp,
                          height: 22.sp,
                          child: CircularProgressIndicator(
                            color: Color(0xFF2C9CD9),
                            strokeWidth: 2.5,
                          ),
                        )
                        : Text(
                          'SAVE',
                          style: TextStyle(
                            letterSpacing: 1.5,
                            fontSize: 16.sp,
                            color: Color(0xFF2C9CD9),
                          ),
                        ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  backgroundColor: Color(0xFF2C9CD9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitJobOrder,
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
          ],
        ),
      ),
    );
  }
}

class FullImageView extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;
  const FullImageView({required this.imageFile, this.imageUrl, Key? key})
    : super(key: key);

  Future<void> _downloadImage(BuildContext context) async {
    try {
      if (imageUrl != null) {
        final response = await http.get(Uri.parse(imageUrl!));
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/downloaded_image.jpg');
          await file.writeAsBytes(bytes);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image downloaded to ${file.path}')),
          );
        }
      } else if (imageFile != null) {
        final bytes = await imageFile!.readAsBytes();
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
            child:
                imageUrl != null
                    ? Image.network(
                      imageUrl!,
                      fit: BoxFit.contain,
                      width: 1.sw,
                      height: 0.8.sh,
                    )
                    : Image.file(
                      imageFile!,
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

class FullVideoView extends StatefulWidget {
  final File? videoFile;
  final String? videoUrl;
  const FullVideoView({required this.videoFile, this.videoUrl, Key? key})
    : super(key: key);

  @override
  State<FullVideoView> createState() => _FullVideoViewState();
}

class _FullVideoViewState extends State<FullVideoView> {
  late VideoPlayerController _videoPlayerController;
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      _videoPlayerController = VideoPlayerController.network(widget.videoUrl!);
    } else {
      _videoPlayerController = VideoPlayerController.file(widget.videoFile!);
    }
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
      if (widget.videoUrl != null) {
        final response = await http.get(Uri.parse(widget.videoUrl!));
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/downloaded_video.mp4');
          await file.writeAsBytes(bytes);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Video downloaded to ${file.path}')),
          );
        }
      } else if (widget.videoFile != null) {
        final bytes = await widget.videoFile!.readAsBytes();
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

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "${d.inHours > 0 ? '${twoDigits(d.inHours)}:' : ''}$minutes:$seconds";
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
                      aspectRatio: _videoPlayerController.value.aspectRatio,
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
}

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
                  'Submitting Report',
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
                      ? 'Please wait while we process your report...'
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
