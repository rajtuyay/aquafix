import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../firebase_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'chat_info_page.dart';
import 'landscape_video_player.dart'; // ensure import for landscape player

class ChatDetailPage extends StatefulWidget {
  final String userName;
  final int? chatId;
  final int? customerId;
  final int? plumberId;

  const ChatDetailPage({
    super.key,
    required this.userName,
    this.chatId,
    this.customerId,
    this.plumberId,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  Uint8List? _thumbnail;
  String? _videoPath;
  int? _jobOrderId; // <-- already present
  bool _loadingMessages = true;
  bool _showFullPageLoading = false;

  Future<Uint8List?> _generateThumbnail(String videoPath) async {
    try {
      final thumbnail = await VideoCompress.getByteThumbnail(
        videoPath,
        quality: 75, // 0-100
        position: -1, // -1 means automatic
      );
      return thumbnail;
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  Future<bool> requestCameraPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        final status = await Permission.camera.request();
        return status.isGranted;
      } else {
        final status = await [Permission.camera, Permission.storage].request();
        return status[Permission.camera]!.isGranted;
      }
    } else {
      final status = await Permission.camera.request();
      return status.isGranted;
    }
  }

  Future<bool> requestGalleryPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        final status =
            await [
              Permission.photos, // READ_MEDIA_IMAGES
              Permission.videos,
            ].request();
        return status[Permission.photos]!.isGranted;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else {
      final status = await Permission.photos.request();
      return status.isGranted;
    }
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImageFromCamera() async {
    final granted = await requestCameraPermission();
    if (granted) {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        _showMediaPreview(File(image.path));
      }
    } else {
      print('Camera permission denied');
    }
  }

  Future<void> _pickImageFromGallery() async {
    final granted = await requestGalleryPermission();
    if (granted) {
      final XFile? media = await _picker.pickMedia();
      if (media != null) {
        _showMediaPreview(File(media.path));
      }
    } else {
      print('Gallery permission denied');
    }
  }

  // Show preview dialog for image/video before sending
  Future<void> _showMediaPreview(File mediaFile) async {
    final isImage = _isImageFile(mediaFile.path);
    final isVideo = _isVideoFile(mediaFile.path);

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.sp),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: EdgeInsets.all(0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Media preview area
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24.sp),
                    topRight: Radius.circular(24.sp),
                  ),
                  child: Container(
                    color: Colors.grey[100],
                    child: AspectRatio(
                      aspectRatio: isImage ? 1 : 9 / 16,
                      child:
                          isImage
                              ? Image.file(
                                mediaFile,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              )
                              : isVideo
                              ? Stack(
                                children: [
                                  VideoPlayerPreview(file: mediaFile),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: Icon(
                                        Icons.videocam,
                                        color: Colors.white,
                                        size: 20.sp,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                              : Center(
                                child: Text(
                                  "Unsupported file type",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.sp,
                                  ),
                                ),
                              ),
                    ),
                  ),
                ),
                // Action buttons
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 18.h,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: Colors.grey[700]),
                        label: Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          padding: EdgeInsets.symmetric(
                            horizontal: 18.w,
                            vertical: 10.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.sp),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          if (_isImageFile(mediaFile.path)) {
                            _handleImageMessage(mediaFile);
                          } else if (_isVideoFile(mediaFile.path)) {
                            if (!await _validateVideo(mediaFile)) return;
                            _videoPath = mediaFile.path;
                            final thumb = await _generateThumbnail(_videoPath!);
                            if (mounted) {
                              setState(() {
                                _thumbnail = thumb;
                              });
                            }
                            _handleMediaSend(mediaFile);
                          }
                        },
                        icon: Icon(Icons.send, color: Colors.white),
                        label: Text(
                          "Send",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2D9FD0),
                          padding: EdgeInsets.symmetric(
                            horizontal: 22.w,
                            vertical: 10.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.sp),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper to check file type
  bool _isImageFile(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif');
  }

  // Improve video file type detection
  bool _isVideoFile(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.mp4') ||
        ext.endsWith('.mov') ||
        ext.endsWith('.avi') ||
        ext.endsWith('.webm') ||
        ext.endsWith('.mkv') ||
        ext.contains('.mp4') ||
        ext.contains('.mov') ||
        ext.contains('.avi') ||
        ext.contains('.webm') ||
        ext.contains('.mkv');
  }

  // Update _validateVideo to only check file extension, since MediaInfo does not provide mimeType or codec info.
  Future<bool> _validateVideo(File file) async {
    // Check file size (100MB = 104857600 bytes)
    final fileSize = await file.length();
    if (fileSize > 26214400) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video file must be less than 25MB.')),
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

  // Handles sending image messages (calls upload_chat_media.php and chat_messages.php)
  void _handleImageMessage(File imageFile) async {
    if (widget.chatId == null || _customerId == null || _plumberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing chat or user info.')),
      );
      return;
    }

    final uri = Uri.parse(
      'https://aquafixsansimon.com/api/upload_chat_media.php?type=image',
    );
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath('media', imageFile.path),
    );

    final response = await request.send();

    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final respJson = json.decode(respStr);
      final String? mediaPath = respJson['media_path'];

      if (mediaPath != null && mediaPath.isNotEmpty) {
        final dataToSend = {
          'chat_id': widget.chatId.toString(),
          'customer_id': _customerId.toString(),
          'plumber_id': _plumberId.toString(),
          'sender': 'customer',
          'message': '', // Explicitly set message to null
          'media_path': mediaPath,
          'thumbnail_path': '',
          'sent_at': DateTime.now().toIso8601String(), // <-- add this line
        };

        final url = Uri.parse(
          'https://aquafixsansimon.com/api/chat_messages.php',
        );
        final msgResp = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(dataToSend),
        );

        if (msgResp.statusCode == 200) {
          final respJson = json.decode(msgResp.body);
          final messageId = respJson['message_id']?.toString();
          if (messageId != null) {
            await FirebaseDatabase.instance
                .ref('chats/${widget.chatId}/messages/$messageId')
                .set({...dataToSend, 'message_id': messageId});
          }
        } else {
          print('Failed to send image message: ${msgResp.body}');
          print('Payload sent: $dataToSend');
          print(
            'chat_id: ${widget.chatId}, customer_id: ${_customerId}, plumber_id: ${_plumberId}, media_path: $mediaPath',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to send image message: ${msgResp.body}',
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image upload failed.')));
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image upload failed.')));
    }
  }

  // Handles sending video messages (calls upload_chat_media.php and chat_messages.php)
  void _handleMediaSend(File mediaFile) async {
    if (widget.chatId == null || _customerId == null || _plumberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing chat or user info.')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final uri = Uri.parse(
        'https://aquafixsansimon.com/api/upload_chat_media.php',
      );
      final request = http.MultipartRequest('POST', uri);

      // Add file to request
      final fileStream = http.ByteStream(mediaFile.openRead());
      final fileLength = await mediaFile.length();

      final multipartFile = http.MultipartFile(
        'media',
        fileStream,
        fileLength,
        filename: mediaFile.path.split('/').last,
      );

      request.files.add(multipartFile);
      if (_thumbnail != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'thumbnail',
            _thumbnail!,
            filename: 'thumb.jpg',
          ),
        );
      }

      // Send request and get response
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      // Close loading dialog
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final respJson = json.decode(response.body);
        print('Media upload response: $respJson'); // Debug print

        if (respJson.containsKey('error')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload error: ${respJson['error']}')),
          );
          return;
        }

        final String? mediaPath = respJson['media_path'];
        final String? thumbnailPath = respJson['thumbnail_path'];

        print('Received mediaPath: $mediaPath'); // Debug print
        print('Received thumbnailPath: $thumbnailPath'); // Debug print

        if (mediaPath != null && mediaPath.isNotEmpty) {
          final dataToSend = {
            'chat_id': widget.chatId.toString(),
            'customer_id': _customerId.toString(),
            'plumber_id': _plumberId.toString(),
            'sender': 'customer',
            'message': '',
            'media_path': mediaPath,
            'thumbnail_path': thumbnailPath ?? '',
            'sent_at':
                DateTime.now()
                    .toIso8601String(), // <-- add timestamp for Firebase sorting
          };

          print('Sending chat message with data: $dataToSend');

          final url = Uri.parse(
            'https://aquafixsansimon.com/api/chat_messages.php',
          );
          final msgResp = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(dataToSend),
          );

          print('Message response status: ${msgResp.statusCode}');
          print('Message response body: ${msgResp.body}');

          if (msgResp.statusCode == 200) {
            final respJson = json.decode(msgResp.body);
            final messageId = respJson['message_id']?.toString();
            if (messageId != null) {
              await FirebaseDatabase.instance
                  .ref('chats/${widget.chatId}/messages/$messageId')
                  .set({...dataToSend, 'message_id': messageId});
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to send media message: ${msgResp.body}',
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Media upload failed: No media path returned'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Media upload failed with status ${response.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print('Exception during media upload: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload error: $e')));
    }
  }

  final FocusNode _focusNode = FocusNode();

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  List<_ChatMessage> _messages = [];
  int? _customerId;
  int? _plumberId;
  String? _plumberProfileImage;
  StreamSubscription<DatabaseEvent>? _firebaseSub;

  @override
  void initState() {
    super.initState();
    _initFirebase();
    _initIdsAndFetch();
    _fetchPlumberProfileImage();
    _textController.addListener(_scrollToBottom);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _scrollToBottom();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _initFirebase() async {
    await FirebaseService.initialize();
    if (widget.chatId != null) {
      _subscribeToFirebase(widget.chatId!);
    }
  }

  void _subscribeToFirebase(int chatId) {
    _firebaseSub?.cancel();
    setState(() {
      _loadingMessages = true;
    });
    _firebaseSub = FirebaseService.messageStream(chatId.toString()).listen((
      event,
    ) {
      final data = event.snapshot.value;
      if (data is Map) {
        final messages = data.values.where((v) => v != null).toList();
        // Sort by message_id as integer
        messages.sort((a, b) {
          final aid = int.tryParse(a['message_id']?.toString() ?? '') ?? 0;
          final bid = int.tryParse(b['message_id']?.toString() ?? '') ?? 0;
          return aid.compareTo(bid);
        });
        // Debug: print all messages to verify accomplishment message is present
        // for (var msg in messages) {
        //   print('Chat message: ${msg['message']}');
        // }
        setState(() {
          _messages =
              messages.map<_ChatMessage>((msg) {
                // Fix: Parse chatId and messageId as int if possible, else keep as String
                int? customerId;
                int? plumberId;
                int? chatId;
                int? messageId;
                if (msg['customer_id'] != null) {
                  customerId = int.tryParse(msg['customer_id'].toString());
                }
                if (msg['plumber_id'] != null) {
                  plumberId = int.tryParse(msg['plumber_id'].toString());
                }
                // Defensive: handle both int and String types for chatId/messageId
                if (msg['chat_id'] != null) {
                  final val = msg['chat_id'];
                  chatId = val is int ? val : int.tryParse(val.toString());
                }
                if (msg['message_id'] != null) {
                  final val = msg['message_id'];
                  messageId = val is int ? val : int.tryParse(val.toString());
                }
                return _ChatMessage(
                  message: msg['message']?.toString() ?? '',
                  isSentByMe: msg['sender']?.toString() == 'customer',
                  mediaPath: msg['media_path'],
                  thumbnailPath: msg['thumbnail_path'],
                  sentAt: msg['sent_at'],
                  customerId: customerId,
                  plumberId: plumberId,
                  chatId: chatId,
                  messageId: messageId,
                );
              }).toList();
          _loadingMessages = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } else {
        setState(() {
          _loadingMessages = false;
        });
      }
    });
  }

  Future<void> _initIdsAndFetch() async {
    int? customerId = widget.customerId;
    int? plumberId = widget.plumberId;
    // Fetch job_order_id based on chatId if not set
    if (_jobOrderId == null && widget.chatId != null) {
      try {
        final url = Uri.parse(
          'https://aquafixsansimon.com/api/chats_util.php?chat_id=${widget.chatId}',
        );
        final resp = await http.get(url);
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          if (data['job_order_id'] != null) {
            setState(() {
              _jobOrderId = int.tryParse(data['job_order_id'].toString());
            });
          }
        }
      } catch (e) {
        // Optionally handle error
      }
    }
    if (customerId == null) {
      final prefs = await SharedPreferences.getInstance();
      final cid = prefs.getString('customer_id');
      customerId = cid != null ? int.tryParse(cid) : null;
    }
    if (plumberId == null) {
      final prefs = await SharedPreferences.getInstance();
      final pid = prefs.getString('plumber_id');
      plumberId = pid != null ? int.tryParse(pid) : null;
    }
    setState(() {
      _customerId = customerId;
      _plumberId = plumberId;
      // _jobOrderId is set above if found
    });
    // _fetchMessages(); <-- REMOVE THIS LINE
  }

  Future<void> _fetchPlumberProfileImage() async {
    if (widget.plumberId == null) return;
    final response = await http.get(
      Uri.parse('https://aquafixsansimon.com/api/plumbers.php'),
    );
    if (response.statusCode == 200) {
      final List users = json.decode(response.body);
      final user = users.firstWhere(
        (u) => u['plumber_id'].toString() == widget.plumberId.toString(),
        orElse: () => null,
      );
      if (user != null &&
          user['profile_image'] != null &&
          user['profile_image'].toString().isNotEmpty) {
        setState(() {
          _plumberProfileImage = user['profile_image'];
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty ||
        widget.chatId == null ||
        _customerId == null ||
        _plumberId == null) {
      return;
    }
    _textController.clear();

    final dataToSend = {
      'chat_id': widget.chatId.toString(),
      'customer_id': _customerId.toString(),
      'plumber_id': _plumberId.toString(),
      'sender': 'customer',
      'message': text,
      'media_path': '',
      'thumbnail_path': '',
      'sent_at': DateTime.now().toIso8601String(),
    };

    final url = Uri.parse('https://aquafixsansimon.com/api/chat_messages.php');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(dataToSend),
    );

    print('Response: ${response.body}');

    if (response.statusCode == 200) {
      final jsonString = response.body.trim();
      final jsonEnd = jsonString.lastIndexOf('}');
      final safeJson =
          jsonEnd != -1 ? jsonString.substring(0, jsonEnd + 1) : jsonString;
      final respJson = json.decode(safeJson);
      final messageId = respJson['message_id']?.toString();
      if (messageId != null) {
        // Save to Firebase using message_id as key
        await FirebaseDatabase.instance
            .ref('chats/${widget.chatId}/messages/$messageId')
            .set({...dataToSend, 'message_id': messageId});
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send message.')));
    }
  }

  // Method to fetch job_order_id from jo_number
  Future<int?> fetchJobOrderId(String joNumber) async {
    try {
      final url = Uri.parse(
        'https://aquafixsansimon.com/api/job_order_lookup.php?jo_number=$joNumber',
      );
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['job_order_id'] != null) {
          return int.tryParse(data['job_order_id'].toString());
        }
      }
    } catch (e) {
      print('Failed to fetch job_order_id: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _textController.removeListener(_scrollToBottom);
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _firebaseSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child:
                  _loadingMessages
                      ? Center(child: CircularProgressIndicator())
                      : Column(
                        children: [
                          _buildAppBar(context),
                          Expanded(
                            child:
                                _messages.isEmpty
                                    ? Center(
                                      child: Padding(
                                        padding: EdgeInsets.only(bottom: 32.h),
                                        child: Text(
                                          "Start Conversation",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    )
                                    : ListView.builder(
                                      controller: _scrollController,
                                      padding: EdgeInsets.all(12.sp),
                                      itemCount: _messages.length,
                                      itemBuilder: (context, index) {
                                        final current = _messages[index];
                                        final prev =
                                            index > 0
                                                ? _messages[index - 1]
                                                : null;
                                        final next =
                                            index < _messages.length - 1
                                                ? _messages[index + 1]
                                                : null;

                                        final bool isPrevSame =
                                            prev != null &&
                                            prev.isSentByMe ==
                                                current.isSentByMe;
                                        final bool isNextSame =
                                            next != null &&
                                            next.isSentByMe ==
                                                current.isSentByMe;

                                        final bool isOnly =
                                            !isPrevSame && !isNextSame;
                                        final bool isStart =
                                            !isPrevSame && isNextSame;
                                        final bool isMiddle =
                                            isPrevSame && isNextSame;
                                        final bool isEnd =
                                            isPrevSame && !isNextSame;

                                        if (current.mediaPath != null &&
                                            current.mediaPath!.isNotEmpty) {
                                          final mediaUrl =
                                              'https://aquafixsansimon.com/uploads/chats_media/${current.mediaPath}';
                                          final thumbnailUrl =
                                              current.thumbnailPath != null &&
                                                      current
                                                          .thumbnailPath!
                                                          .isNotEmpty
                                                  ? 'https://aquafixsansimon.com/uploads/chats_media/${current.thumbnailPath}'
                                                  : null;
                                          print(
                                            'Thumbnail URL for video: $thumbnailUrl',
                                          );
                                          if (_isImageFile(
                                            current.mediaPath!,
                                          )) {
                                            return _ImageMessage(
                                              imageUrl: mediaUrl,
                                              isSentByMe: current.isSentByMe,
                                              isOnly: isOnly,
                                              isStart: isStart,
                                              isMiddle: isMiddle,
                                              isEnd: isEnd,
                                              sentAt: current.sentAt,
                                              plumberProfileImage:
                                                  current.isSentByMe
                                                      ? null
                                                      : _plumberProfileImage,
                                            );
                                          } else if (_isVideoFile(
                                            current.mediaPath!,
                                          )) {
                                            return _VideoMessage(
                                              videoUrl: mediaUrl,
                                              thumbnailUrl:
                                                  thumbnailUrl, // <-- Pass thumbnailUrl here
                                              isSentByMe: current.isSentByMe,
                                              isOnly: isOnly,
                                              isStart: isStart,
                                              isMiddle: isMiddle,
                                              isEnd: isEnd,
                                              sentAt: current.sentAt,
                                              plumberProfileImage:
                                                  current.isSentByMe
                                                      ? null
                                                      : _plumberProfileImage,
                                            );
                                          }
                                        }

                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (isStart || isOnly)
                                              SizedBox(height: 14.sp),
                                            ChatBubble(
                                              message: current.message,
                                              isSentByMe: current.isSentByMe,
                                              isOnly: isOnly,
                                              isStart: isStart,
                                              isMiddle: isMiddle,
                                              isEnd: isEnd,
                                              sentAt: current.sentAt,
                                              plumberProfileImage:
                                                  current.isSentByMe
                                                      ? null
                                                      : _plumberProfileImage,
                                              current:
                                                  current, // <-- pass current message object
                                              onConfirmLoading:
                                                  _setFullPageLoading, // <-- pass callback
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                          ),
                          _MessageInputField(
                            controller: _textController,
                            onSend: _handleSendMessage,
                            focusNode: _focusNode,
                            // Camera icon opens camera, gallery icon opens gallery picker for image/video
                            onCameraPick: _pickImageFromCamera,
                            onGalleryPick: _pickImageFromGallery,
                          ),
                        ],
                      ),
            ),
          ),
          if (_showFullPageLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.25),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _setFullPageLoading(bool value) async {
    setState(() {
      _showFullPageLoading = value;
    });
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12.sp,
            offset: Offset(0, 8.sp),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(shape: BoxShape.circle),
                  child:
                      _plumberProfileImage != null &&
                              _plumberProfileImage!.isNotEmpty
                          ? CircleAvatar(
                            backgroundColor: Colors.white,
                            backgroundImage: NetworkImage(
                              'https://aquafixsansimon.com/uploads/profiles/plumbers/$_plumberProfileImage',
                            ),
                          )
                          : ClipOval(
                            child: Image.asset(
                              'assets/profiles/default.jpg',
                              fit: BoxFit.cover,
                              width: 40.w,
                              height: 40.h,
                            ),
                          ),
                ),
                SizedBox(width: 12.w),
                Text(
                  widget.userName,
                  style: TextStyle(color: Colors.black, fontSize: 18.sp),
                ),
              ],
            ),
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF2D9FD0)),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 4.w),
                child: IconButton(
                  icon: Icon(Icons.info, color: Color(0xFF2D9FD0), size: 28.sp),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ChatInfoPage(
                              userName: widget.userName,
                              chatId: widget.chatId,
                              plumberId: widget.plumberId,
                              plumberProfileImage: _plumberProfileImage,
                            ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String? message;
  final bool isSentByMe;
  final String? mediaPath;
  final String? thumbnailPath;
  final String? sentAt;
  final int? customerId;
  final int? plumberId;
  final int? chatId; // <-- add chatId
  final int? messageId; // <-- add messageId

  _ChatMessage({
    this.message,
    required this.isSentByMe,
    this.mediaPath,
    this.thumbnailPath,
    this.sentAt,
    this.customerId,
    this.plumberId,
    this.chatId, // <-- add chatId
    this.messageId, // <-- add messageId
  });
}

class _ImageMessage extends StatelessWidget {
  final String imageUrl;
  final bool isSentByMe;
  final bool isOnly;
  final bool isStart;
  final bool isMiddle;
  final bool isEnd;
  final String? sentAt;
  final String? plumberProfileImage;

  const _ImageMessage({
    required this.imageUrl,
    required this.isSentByMe,
    required this.isOnly,
    required this.isStart,
    required this.isMiddle,
    required this.isEnd,
    this.sentAt,
    this.plumberProfileImage,
  });

  Future<Size> _getImageSize(BuildContext context, String url) async {
    final completer = Completer<Size>();
    final image = Image.network(url);
    image.image
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener((ImageInfo info, bool _) {
            final mySize = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            );
            completer.complete(mySize);
          }),
        );
    return completer.future;
  }

  Widget _buildImageCard(BuildContext context, double width, double height) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.sp),
      child: Row(
        mainAxisAlignment:
            isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Visibility(
            visible: !isSentByMe && (isEnd || isOnly),
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Container(
              width: 36.sp,
              height: 36.sp,
              margin: EdgeInsets.only(right: 8.sp),
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child:
                  plumberProfileImage != null && plumberProfileImage!.isNotEmpty
                      ? CircleAvatar(
                        backgroundColor: Colors.white,
                        backgroundImage: NetworkImage(
                          'https://aquafixsansimon.com/uploads/profiles/plumbers/$plumberProfileImage',
                        ),
                      )
                      : CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          color: Color(0xFF2D9FD0),
                          size: 20.sp,
                        ),
                      ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16.sp),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => FullscreenImagePageNetwork(imageUrl: imageUrl),
                  ),
                );
              },
              child: Image.network(
                imageUrl,
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: width,
                    height: height,
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.red,
                      size: 32.sp,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Set max dimensions similar to video
    final double maxPortraitHeight = 180.sp;
    final double maxPortraitWidth = 120.sp;
    final double maxLandscapeWidth = 180.sp;
    final double maxLandscapeHeight = 120.sp;

    return FutureBuilder<Size>(
      future: _getImageSize(context, imageUrl),
      builder: (context, snapshot) {
        double width = maxLandscapeWidth;
        double height = maxLandscapeHeight;
        if (snapshot.hasData) {
          final size = snapshot.data!;
          final aspectRatio = size.width / size.height;
          if (aspectRatio < 1) {
            // Portrait
            height = maxPortraitHeight;
            width = maxPortraitWidth;
          } else {
            // Landscape or square
            width = maxLandscapeWidth;
            height = maxLandscapeHeight;
          }
        }
        return _buildImageCard(context, width, height);
      },
    );
  }
}

class _VideoMessage extends StatelessWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool isSentByMe;
  final bool isOnly;
  final bool isStart;
  final bool isMiddle;
  final bool isEnd;
  final String? sentAt;
  final String? plumberProfileImage;

  const _VideoMessage({
    required this.videoUrl,
    this.thumbnailUrl,
    required this.isSentByMe,
    required this.isOnly,
    required this.isStart,
    required this.isMiddle,
    required this.isEnd,
    this.sentAt,
    this.plumberProfileImage,
  });

  Future<Size> _getImageSize(BuildContext context, String url) async {
    final completer = Completer<Size>();
    final image = Image.network(url);
    image.image
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener((ImageInfo info, bool _) {
            final mySize = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            );
            completer.complete(mySize);
          }),
        );
    return completer.future;
  }

  Widget _buildThumbnailCard(
    BuildContext context,
    double width,
    double height,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.sp),
      child: Row(
        mainAxisAlignment:
            isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Visibility(
            visible: !isSentByMe && (isEnd || isOnly),
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Container(
              width: 36.sp,
              height: 36.sp,
              margin: EdgeInsets.only(right: 8.sp),
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child:
                  plumberProfileImage != null && plumberProfileImage!.isNotEmpty
                      ? CircleAvatar(
                        backgroundColor: Colors.white,
                        backgroundImage: NetworkImage(
                          'https://aquafixsansimon.com/uploads/profiles/plumbers/$plumberProfileImage',
                        ),
                      )
                      : CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          color: const Color(0xFF2D9FD0),
                          size: 20.sp,
                        ),
                      ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => Scaffold(
                        backgroundColor: Colors.black,
                        appBar: AppBar(
                          backgroundColor: Colors.transparent,
                          iconTheme: const IconThemeData(color: Colors.white),
                          elevation: 0,
                        ),
                        body: Center(
                          // CHANGED: use selector (detect landscape vs portrait)
                          child: _VideoPlayerSelector(url: videoUrl),
                        ),
                      ),
                ),
              );
            },
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16.sp),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16.sp),
                    child:
                        (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
                            ? Image.network(
                              thumbnailUrl!,
                              width: width,
                              height: height,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildFallbackThumbnail();
                              },
                            )
                            : _buildFallbackThumbnail(),
                  ),
                  Icon(
                    Icons.play_circle_fill,
                    size: 48.sp,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackThumbnail() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam, color: Colors.white70, size: 32.sp),
            SizedBox(height: 8.h),
            Text(
              'VIDEO',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Default fallback size
    final double defaultWidth = 180.sp;
    final double defaultHeight = 120.sp;

    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return FutureBuilder<Size>(
        future: _getImageSize(context, thumbnailUrl!),
        builder: (context, snapshot) {
          double width = defaultWidth;
          double height = defaultHeight;
          if (snapshot.hasData) {
            final size = snapshot.data!;
            final ratio = size.width / size.height;
            if (ratio < 1) {
              // Portrait
              height = 180.sp;
              width = 120.sp;
            } else {
              // Landscape or square
              width = 180.sp;
              height = 120.sp;
            }
          }
          return _buildThumbnailCard(context, width, height);
        },
      );
    } else {
      // Fallback if no thumbnail
      return _buildThumbnailCard(context, defaultWidth, defaultHeight);
    }
  }
}

class FullscreenImagePageNetwork extends StatelessWidget {
  final String imageUrl;

  const FullscreenImagePageNetwork({super.key, required this.imageUrl});

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

class ChatBubble extends StatefulWidget {
  final String? message;
  final File? imageFile;
  final bool isSentByMe;
  final bool isOnly;
  final bool isStart;
  final bool isMiddle;
  final bool isEnd;
  final String? sentAt;
  final String? plumberProfileImage;
  final _ChatMessage? current;
  final void Function(bool)? onConfirmLoading;

  const ChatBubble({
    super.key,
    this.message,
    this.imageFile,
    required this.isSentByMe,
    required this.isOnly,
    required this.isStart,
    required this.isMiddle,
    required this.isEnd,
    this.sentAt,
    this.plumberProfileImage,
    this.current,
    this.onConfirmLoading,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool isConfirmed = false;
  bool isConfirming = false;

  Future<int?> fetchJobOrderId(String joNumber) async {
    try {
      final url = Uri.parse(
        'https://aquafixsansimon.com/api/job_order_lookup.php?jo_number=$joNumber',
      );
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['job_order_id'] != null) {
          print('Fetched jo_id: ${data['job_order_id']}');
          return int.tryParse(data['job_order_id'].toString());
        }
      }
    } catch (e) {
      print('Failed to fetch job_order_id: $e');
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset isConfirmed if message changes
    if (oldWidget.message != widget.message) {
      if (mounted) isConfirmed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    BorderRadius getBubbleRadius() {
      final r = Radius.circular(20.sp);
      final tight = Radius.circular(4.sp);
      if (widget.isSentByMe) {
        if (widget.isOnly) {
          return BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: r,
            bottomRight: r,
          );
        } else if (widget.isStart) {
          return BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: r,
            bottomRight: tight,
          );
        } else if (widget.isMiddle) {
          return BorderRadius.only(
            topLeft: r,
            topRight: tight,
            bottomLeft: r,
            bottomRight: tight,
          );
        } else {
          // isEnd
          return BorderRadius.only(
            topLeft: r,
            topRight: tight,
            bottomLeft: r,
            bottomRight: r,
          );
        }
      } else {
        if (widget.isOnly) {
          return BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: r,
            bottomRight: r,
          );
        } else if (widget.isStart) {
          return BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: tight,
            bottomRight: r,
          );
        } else if (widget.isMiddle) {
          return BorderRadius.only(
            topLeft: tight,
            topRight: r,
            bottomLeft: tight,
            bottomRight: r,
          );
        } else {
          // isEnd
          return BorderRadius.only(
            topLeft: tight,
            topRight: r,
            bottomLeft: r,
            bottomRight: r,
          );
        }
      }
    }

    // Detect accomplishment message and show confirmation UI
    final bool isAccomplishment =
        widget.message != null &&
        widget.message!.toLowerCase().contains('your request was accomplished');

    if (isAccomplishment) {
      // Extract request details
      final lines = widget.message!.split('\n');
      final details = lines.skip(1).join('\n').trim();

      // Extract jo_number from the accomplishment message if present
      String? extractedJoNumber;
      for (final line in lines) {
        // Match "Job Order #:" followed by any non-whitespace characters
        final match = RegExp(
          r'Job Order #[:\s]*([A-Za-z0-9\-]+)',
          caseSensitive: false,
        ).firstMatch(line);
        if (match != null) {
          extractedJoNumber = match.group(1);
          break;
        }
      }

      final chatState = context.findAncestorStateOfType<_ChatDetailPageState>();
      int? jobOrderId = chatState?._jobOrderId;

      Future<Map<String, dynamic>> fetchJobOrderStatus(
        int? jobOrderId,
        String? joNumber,
      ) async {
        if (jobOrderId != null) {
          final url = Uri.parse(
            'https://aquafixsansimon.com/api/job_order_status.php?job_order_id=$jobOrderId',
          );
          final resp = await http.get(url);
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body);
            return {
              'isConfirmed': data['isConfirmed'] == 1,
              'isAccomplished':
                  (data['status'] ?? '').toString().toLowerCase() ==
                  'accomplished',
            };
          }
        } else if (joNumber != null) {
          final id = await fetchJobOrderId(joNumber);
          if (id != null) {
            final url = Uri.parse(
              'https://aquafixsansimon.com/api/job_order_status.php?job_order_id=$id',
            );
            final resp = await http.get(url);
            if (resp.statusCode == 200) {
              final data = json.decode(resp.body);
              return {
                'isConfirmed': data['isConfirmed'] == 1,
                'isAccomplished':
                    (data['status'] ?? '').toString().toLowerCase() ==
                    'accomplished',
              };
            }
          }
        }
        return {'isConfirmed': false, 'isAccomplished': false};
      }

      return FutureBuilder<Map<String, dynamic>>(
        future: fetchJobOrderStatus(jobOrderId, extractedJoNumber),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: EdgeInsets.only(top: widget.isStart ? 12.sp : 4.sp),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Visibility(
                    visible:
                        !widget.isSentByMe && (widget.isEnd || widget.isOnly),
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Container(
                      width: 36.sp,
                      height: 36.sp,
                      margin: EdgeInsets.only(right: 8.sp),
                      decoration: BoxDecoration(shape: BoxShape.circle),
                      child:
                          widget.plumberProfileImage != null &&
                                  widget.plumberProfileImage!.isNotEmpty
                              ? CircleAvatar(
                                backgroundColor: Colors.white,
                                backgroundImage: NetworkImage(
                                  'https://aquafixsansimon.com/uploads/profiles/plumbers/${widget.plumberProfileImage}',
                                ),
                              )
                              : CircleAvatar(
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.person,
                                  color: Color(0xFF2D9FD0),
                                  size: 20.sp,
                                ),
                              ),
                    ),
                  ),
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.fromLTRB(14.sp, 14.sp, 14.sp, 8.sp),
                      constraints: BoxConstraints(maxWidth: screenWidth * 0.7),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(18.sp),
                      ),
                      // Removed loading indicator here
                    ),
                  ),
                ],
              ),
            );
          }
          final isConfirmedDb = snapshot.data?['isConfirmed'] ?? false;
          final isAccomplishedDb = snapshot.data?['isAccomplished'] ?? false;
          final bool showConfirmed =
              isConfirmed || isConfirmedDb || isAccomplishedDb;
          return Padding(
            padding: EdgeInsets.only(top: widget.isStart ? 12.sp : 4.sp),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Visibility(
                  visible:
                      !widget.isSentByMe && (widget.isEnd || widget.isOnly),
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Container(
                    width: 36.sp,
                    height: 36.sp,
                    margin: EdgeInsets.only(right: 8.sp),
                    decoration: BoxDecoration(shape: BoxShape.circle),
                    child:
                        widget.plumberProfileImage != null &&
                                widget.plumberProfileImage!.isNotEmpty
                            ? CircleAvatar(
                              backgroundColor: Colors.white,
                              backgroundImage: NetworkImage(
                                'https://aquafixsansimon.com/uploads/profiles/plumbers/${widget.plumberProfileImage}',
                              ),
                            )
                            : CircleAvatar(
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.person,
                                color: Color(0xFF2D9FD0),
                                size: 20.sp,
                              ),
                            ),
                  ),
                ),
                Flexible(
                  child: Container(
                    padding: EdgeInsets.fromLTRB(14.sp, 14.sp, 14.sp, 8.sp),
                    constraints: BoxConstraints(maxWidth: screenWidth * 0.7),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(18.sp),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Your request was accomplished!",
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8.sp),
                        Text(
                          "Report Details: ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8.sp),
                        Text(
                          details,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 10.sp),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  showConfirmed
                                      ? Colors.grey[700]
                                      : const Color.fromARGB(
                                        255,
                                        252,
                                        252,
                                        252,
                                      ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.sp,
                                vertical: 0,
                              ),
                              minimumSize: Size(0, 30.sp),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.sp),
                              ),
                            ),
                            onPressed:
                                showConfirmed || isConfirming
                                    ? null
                                    : () async {
                                      if (mounted)
                                        setState(() {
                                          isConfirming = true;
                                          isConfirmed = true;
                                        });
                                      if (widget.onConfirmLoading != null) {
                                        widget.onConfirmLoading!(true);
                                      }
                                      // Call confirmation API
                                      if (widget.current != null) {
                                        final chatId = widget.current!.chatId;
                                        final messageId =
                                            widget.current!.messageId;
                                        if (jobOrderId == null &&
                                            extractedJoNumber != null) {
                                          jobOrderId = await fetchJobOrderId(
                                            extractedJoNumber,
                                          );
                                        }
                                        if (chatId != null &&
                                            messageId != null &&
                                            jobOrderId != null) {
                                          final url = Uri.parse(
                                            'https://aquafixsansimon.com/api/confirm_accomplishment.php',
                                          );
                                          final resp = await http.post(
                                            url,
                                            headers: {
                                              'Content-Type':
                                                  'application/json',
                                            },
                                            body: json.encode({
                                              'chat_id': chatId,
                                              'message_id': messageId,
                                              'job_order_id': jobOrderId,
                                              'role': 'customer',
                                              'action': 'confirm',
                                            }),
                                          );
                                          if (resp.statusCode == 200) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Job order confirmed successfully.',
                                                ),
                                              ),
                                            );

                                            // Send notification to Firebase immediately after confirmation
                                            String joNumber = '';
                                            try {
                                              final joResp = await http.get(
                                                Uri.parse(
                                                  'https://aquafixsansimon.com/api/jo_number_lookup.php?job_order_id=$jobOrderId',
                                                ),
                                              );
                                              if (joResp.statusCode == 200) {
                                                final joData = json.decode(
                                                  joResp.body,
                                                );
                                                if (joData
                                                        is Map<
                                                          String,
                                                          dynamic
                                                        > &&
                                                    joData['jo_number'] !=
                                                        null) {
                                                  joNumber =
                                                      joData['jo_number']
                                                          .toString();
                                                }
                                              }
                                            } catch (_) {
                                              joNumber = '';
                                            }

                                            final bodyText =
                                                'The Job Order $joNumber has been confirmed by the customer.';

                                            // Get customerId from SharedPreferences
                                            String? customerId;
                                            try {
                                              final prefs =
                                                  await SharedPreferences.getInstance();
                                              customerId = prefs.getString(
                                                'customer_id',
                                              );
                                              print(
                                                '[Notification] customerId: $customerId',
                                              );
                                            } catch (_) {
                                              customerId = null;
                                            }

                                            if (customerId != null &&
                                                customerId.isNotEmpty) {
                                              try {
                                                tz.initializeTimeZones();
                                                final phLocation = tz
                                                    .getLocation('Asia/Manila');
                                                final nowPH = tz.TZDateTime.now(
                                                  phLocation,
                                                );

                                                final timestamp =
                                                    "${nowPH.year.toString().padLeft(4, '0')}-"
                                                    "${nowPH.month.toString().padLeft(2, '0')}-"
                                                    "${nowPH.day.toString().padLeft(2, '0')} "
                                                    "${nowPH.hour.toString().padLeft(2, '0')}:"
                                                    "${nowPH.minute.toString().padLeft(2, '0')}:"
                                                    "${nowPH.second.toString().padLeft(2, '0')}";

                                                final notifRef =
                                                    FirebaseDatabase.instance
                                                        .ref(
                                                          'notifications/$customerId',
                                                        )
                                                        .push();

                                                await notifRef.set({
                                                  'body': bodyText,
                                                  'jo_number': joNumber,
                                                  'timestamp': timestamp,
                                                  'title':
                                                      'Job Order Confirmed',
                                                  'adminViewed': false,
                                                });

                                                print(
                                                  '[Notification] Saved for customerId: $customerId at $timestamp',
                                                );
                                              } catch (e) {
                                                print(
                                                  '[Notification] Error saving notification: $e',
                                                );
                                              }

                                              // Fetch plumber's fcm_token from tbl_plumbers API
                                              String? plumberFcmToken;
                                              try {
                                                final plumberResp = await http.get(
                                                  Uri.parse(
                                                    'https://aquafixsansimon.com/api/plumbers.php',
                                                  ),
                                                );
                                                if (plumberResp.statusCode ==
                                                    200) {
                                                  final plumbers = json.decode(
                                                    plumberResp.body,
                                                  );
                                                  final plumber = (plumbers
                                                          as List)
                                                      .firstWhere(
                                                        (u) =>
                                                            u['plumber_id']
                                                                .toString() ==
                                                            widget
                                                                .current!
                                                                .plumberId
                                                                .toString(),
                                                        orElse: () => null,
                                                      );
                                                  if (plumber != null &&
                                                      plumber['fcm_token'] !=
                                                          null) {
                                                    plumberFcmToken =
                                                        plumber['fcm_token']
                                                            .toString();
                                                  }
                                                }
                                              } catch (_) {
                                                plumberFcmToken = null;
                                              }

                                              // Send notification to plumber in Firebase
                                              if (widget.current != null &&
                                                  widget.current!.plumberId !=
                                                      null) {
                                                final plumberId =
                                                    widget.current!.plumberId
                                                        .toString();
                                                final notifRef =
                                                    FirebaseDatabase.instance
                                                        .ref(
                                                          'notification_plumber/$plumberId',
                                                        )
                                                        .push();

                                                tz.initializeTimeZones();
                                                final phLocation = tz
                                                    .getLocation('Asia/Manila');
                                                final nowPH = tz.TZDateTime.now(
                                                  phLocation,
                                                );

                                                final timestamp =
                                                    "${nowPH.year.toString().padLeft(4, '0')}-"
                                                    "${nowPH.month.toString().padLeft(2, '0')}-"
                                                    "${nowPH.day.toString().padLeft(2, '0')} "
                                                    "${nowPH.hour.toString().padLeft(2, '0')}:"
                                                    "${nowPH.minute.toString().padLeft(2, '0')}:"
                                                    "${nowPH.second.toString().padLeft(2, '0')}";

                                                await notifRef.set({
                                                  'body':
                                                      'The Job Order $joNumber has been confirmed by the customer.',
                                                  'fcm_token':
                                                      plumberFcmToken ?? '',
                                                  'jo_number': joNumber,
                                                  'timestamp': timestamp,
                                                  'title':
                                                      'Job Order Confirmed',
                                                  'viewed': false,
                                                });
                                              }
                                            }
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to confirm.',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                      if (widget.onConfirmLoading != null) {
                                        widget.onConfirmLoading!(false);
                                      }
                                      if (mounted)
                                        setState(() {
                                          isConfirming = false;
                                        });
                                    },
                            child:
                                isConfirming || showConfirmed
                                    ? Text(
                                      "Confirmed",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.sp,
                                        color: const Color.fromARGB(
                                          255,
                                          62,
                                          62,
                                          62,
                                        ),
                                      ),
                                    )
                                    : Text(
                                      "Confirm",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.sp,
                                        color: const Color.fromARGB(
                                          255,
                                          62,
                                          62,
                                          62,
                                        ),
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
          );
        },
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: widget.isStart ? 12.sp : 4.sp),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            widget.isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Visibility(
            visible: !widget.isSentByMe && (widget.isEnd || widget.isOnly),
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Container(
              width: 36.sp,
              height: 36.sp,
              margin: EdgeInsets.only(right: 8.sp),
              decoration: BoxDecoration(shape: BoxShape.circle),
              child:
                  widget.plumberProfileImage != null &&
                          widget.plumberProfileImage!.isNotEmpty
                      ? CircleAvatar(
                        backgroundColor: Colors.white,
                        backgroundImage: NetworkImage(
                          'https://aquafixsansimon.com/uploads/profiles/plumbers/${widget.plumberProfileImage}',
                        ),
                      )
                      : CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          color: Color(0xFF2D9FD0),
                          size: 20.sp,
                        ),
                      ),
            ),
          ),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.sp, vertical: 10.sp),
              constraints: BoxConstraints(maxWidth: screenWidth * 0.7),
              decoration: BoxDecoration(
                color:
                    widget.isSentByMe
                        ? const Color(0xFF2D9FD0)
                        : Colors.grey.shade200,
                borderRadius: getBubbleRadius(),
              ),
              child:
                  widget.message != null
                      ? Text(
                        widget.message!,
                        style: TextStyle(
                          color:
                              widget.isSentByMe ? Colors.white : Colors.black87,
                          fontSize: 15.sp,
                        ),
                      )
                      : ClipRRect(
                        borderRadius: BorderRadius.circular(12.sp),
                        child: Image.file(
                          widget.imageFile!,
                          width: screenWidth * 0.7,
                          height: null,
                          fit: BoxFit.cover,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final Future<void> Function() onCameraPick;
  final Future<void> Function() onGalleryPick;

  const _MessageInputField({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onCameraPick,
    required this.onGalleryPick,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.sp, vertical: 8.sp),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.camera_alt,
                color: Color(0xFF2D9FD0),
                size: 24.sp,
              ),
              onPressed: onCameraPick,
            ),
            IconButton(
              icon: Icon(Icons.photo, color: Color(0xFF2D9FD0), size: 24.sp),
              onPressed: onGalleryPick,
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.sp),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20.sp),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            SizedBox(width: 8.sp),
            IconButton(
              icon: Icon(Icons.send, color: Color(0xFF2D9FD0), size: 24.sp),
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerPreview extends StatefulWidget {
  final File file;
  const VideoPlayerPreview({super.key, required this.file});

  @override
  State<VideoPlayerPreview> createState() => _VideoPlayerPreviewState();
}

class _VideoPlayerPreviewState extends State<VideoPlayerPreview> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _hideTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file);
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {
            _isInitialized = true;
            _controller.play();
          });
          if (_controller.value.isPlaying) {
            _hideControlsAfterDelay();
          }
        })
        .catchError((e) {
          setState(() {
            _error = e.toString();
          });
        });
    _controller.addListener(() {
      if (mounted) setState(() {});
      if (_controller.value.hasError) {
        setState(() {
          _error = _controller.value.errorDescription ?? "Unknown video error";
        });
      }
      if (_controller.value.isPlaying && _showControls) {
        _hideControlsAfterDelay();
      }
    });
  }

  void _hideControlsAfterDelay() {
    _hideTimer?.cancel();
    if (_controller.value.isPlaying) {
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
    _controller.dispose();
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
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(
              "Failed to play video.\n\n$_error\n\n"
              "Possible causes:\n"
              "- The video format/codec is not supported on your device.\n"
              "- The video file is corrupted or incomplete.\n"
              "- The file is not accessible or readable.\n"
              "- The video is not encoded as H.264/AAC (required for most Android devices).\n\n"
              "Try:\n"
              "- Playing the video in your phone's gallery or file manager.\n"
              "- Re-encoding the video to standard MP4 (H.264/AAC).",
              style: TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return _isInitialized
        ? Center(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    setState(() {
                      _showControls = !_showControls;
                      if (_showControls && _controller.value.isPlaying) {
                        _hideControlsAfterDelay();
                      } else if (!_showControls) {
                        _hideTimer?.cancel();
                      }
                    });
                  },
                  child: VideoPlayer(_controller),
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
                            final current = _controller.value.position;
                            final newPosition = current - Duration(seconds: 10);
                            _controller.seekTo(
                              newPosition > Duration.zero
                                  ? newPosition
                                  : Duration.zero,
                            );
                          },
                        ),
                        SizedBox(width: 16.w),
                        IconButton(
                          icon: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: Colors.white,
                            size: 48.sp,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_controller.value.isPlaying) {
                                _controller.pause();
                                _showControls = true;
                                _hideTimer?.cancel();
                              } else {
                                _controller.play();
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
                            final current = _controller.value.position;
                            final duration = _controller.value.duration;
                            final newPosition = current + Duration(seconds: 10);
                            _controller.seekTo(
                              newPosition < duration ? newPosition : duration,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
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
                      bottom: MediaQuery.of(context).padding.bottom,
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
                                  _controller.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 24.sp,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (_controller.value.isPlaying) {
                                      _controller.pause();
                                      _showControls = true;
                                      _hideTimer?.cancel();
                                    } else {
                                      _controller.play();
                                      _hideControlsAfterDelay();
                                    }
                                  });
                                },
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                "${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.sp,
                                  fontFeatures: [FontFeature.tabularFigures()],
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
                              _controller,
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
          ),
        )
        : const Center(child: CircularProgressIndicator());
  }
}

class NetworkVideoPlayerPreview extends StatefulWidget {
  final String url;
  const NetworkVideoPlayerPreview({super.key, required this.url});

  @override
  State<NetworkVideoPlayerPreview> createState() =>
      _NetworkVideoPlayerPreviewState();
}

class _NetworkVideoPlayerPreviewState extends State<NetworkVideoPlayerPreview> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _hideTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller
          .initialize()
          .then((_) {
            if (!mounted) return;
            setState(() {
              _isInitialized = true;
              _controller.play();
            });
            if (_controller.value.isPlaying) {
              _hideControlsAfterDelay();
            }
          })
          .catchError((e) {
            setState(() {
              _error = e.toString();
            });
          });
      _controller.addListener(() {
        if (mounted) setState(() {});
        if (_controller.value.hasError) {
          setState(() {
            _error =
                _controller.value.errorDescription ?? "Unknown video error";
          });
        }
        if (_controller.value.isPlaying && _showControls) {
          _hideControlsAfterDelay();
        }
      });
    } catch (e) {
      setState(() {
        _error = "Failed to initialize video: $e";
      });
    }
  }

  void _hideControlsAfterDelay() {
    _hideTimer?.cancel();
    if (_controller.value.isPlaying) {
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
    _controller.dispose();
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
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(
              "Failed to play video.\n\n$_error\n\n"
              "Possible causes:\n"
              "- The video format/codec is not supported on your device.\n"
              "- The video file is corrupted or incomplete.\n"
              "- The server does not support HTTP range requests (needed for streaming large files).\n"
              "- The server is not using HTTPS (required on some devices).\n"
              "- The video is not encoded as H.264/AAC (required for most Android devices).\n\n"
              "Try:\n"
              "- Playing the video in your phone's browser.\n"
              "- Re-encoding the video to standard MP4 (H.264/AAC).\n"
              "- Checking server permissions and CORS.",
              style: TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return _isInitialized
        ? Center(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    setState(() {
                      _showControls = !_showControls;
                      if (_showControls && _controller.value.isPlaying) {
                        _hideControlsAfterDelay();
                      } else if (!_showControls) {
                        _hideTimer?.cancel();
                      }
                    });
                  },
                  child: VideoPlayer(_controller),
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
                            final current = _controller.value.position;
                            final newPosition = current - Duration(seconds: 10);
                            _controller.seekTo(
                              newPosition > Duration.zero
                                  ? newPosition
                                  : Duration.zero,
                            );
                          },
                        ),
                        SizedBox(width: 16.w),
                        IconButton(
                          icon: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: Colors.white,
                            size: 48.sp,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_controller.value.isPlaying) {
                                _controller.pause();
                                _showControls = true;
                                _hideTimer?.cancel();
                              } else {
                                _controller.play();
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
                            final current = _controller.value.position;
                            final duration = _controller.value.duration;
                            final newPosition = current + Duration(seconds: 10);
                            _controller.seekTo(
                              newPosition < duration ? newPosition : duration,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
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
                      bottom: MediaQuery.of(context).padding.top,
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
                                  _controller.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 24.sp,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (_controller.value.isPlaying) {
                                      _controller.pause();
                                      _showControls = true;
                                      _hideTimer?.cancel();
                                    } else {
                                      _controller.play();
                                      _hideControlsAfterDelay();
                                    }
                                  });
                                },
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                "${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.sp,
                                  fontFeatures: [FontFeature.tabularFigures()],
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
                              _controller,
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
          ),
        )
        : const Center(child: CircularProgressIndicator());
  }
}

// ADDED: selector widget (same logic style as chat_info_page)
class _VideoPlayerSelector extends StatefulWidget {
  final String url;
  const _VideoPlayerSelector({required this.url});
  @override
  State<_VideoPlayerSelector> createState() => _VideoPlayerSelectorState();
}

class _VideoPlayerSelectorState extends State<_VideoPlayerSelector> {
  late VideoPlayerController _controller;
  bool _ready = false;
  bool _isLandscape = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          final ratio = _controller.value.aspectRatio;
          setState(() {
            _isLandscape = ratio > 1.2;
            _ready = true;
          });
        })
        .catchError((e) {
          setState(() => _err = e.toString());
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_err != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Video error: $_err',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (!_ready) return const CircularProgressIndicator();
    return _isLandscape
        ? LandscapeVideoPlayerPreview(url: widget.url)
        : NetworkVideoPlayerPreview(url: widget.url);
  }
}
