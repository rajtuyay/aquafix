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

class ChatDetailPage extends StatefulWidget {
  final String userName;
  final int? chatId;
  final int? customerId;
  final int? plumberId;

  const ChatDetailPage({
    super.key,
    required this.userName,
    required this.chatId,
    required this.customerId,
    required this.plumberId,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  Uint8List? _thumbnail;
  String? _videoPath;
  int? _customerId;
  int? _plumberId;
  String? _customerProfileImage;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<_ChatMessage> _messages = [];

  Future<Uint8List?> _generateThumbnail(String videoPath) async {
    try {
      final thumbnail = await VideoCompress.getByteThumbnail(
        videoPath,
        quality: 75,
        position: -1,
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

  bool _isImageFile(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif');
  }

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

  // Send image message (with sent_at)
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
          'sender': 'plumber',
          'message': '',
          'media_path': mediaPath,
          'thumbnail_path': '',
          'sent_at': DateTime.now().toIso8601String(),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send image message: ${msgResp.body}'),
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

  // Send video message (with sent_at)
  void _handleMediaSend(File mediaFile) async {
    if (widget.chatId == null || _customerId == null || _plumberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing chat or user info.')),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (BuildContext context) => Center(child: CircularProgressIndicator()),
    );
    try {
      final uri = Uri.parse(
        'https://aquafixsansimon.com/api/upload_chat_media.php',
      );
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('media', mediaFile.path),
      );
      if (_thumbnail != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'thumbnail',
            _thumbnail!,
            filename: 'thumb.jpg',
          ),
        );
      }
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      Navigator.pop(context);
      if (response.statusCode == 200) {
        final respJson = json.decode(response.body);
        final String? mediaPath = respJson['media_path'];
        final String? thumbnailPath = respJson['thumbnail_path'];
        if (mediaPath != null && mediaPath.isNotEmpty) {
          final dataToSend = {
            'chat_id': widget.chatId.toString(),
            'customer_id': _customerId.toString(),
            'plumber_id': _plumberId.toString(),
            'sender': 'plumber',
            'message': '',
            'media_path': mediaPath,
            'thumbnail_path': thumbnailPath ?? '',
            'sent_at': DateTime.now().toIso8601String(),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send media message: ${msgResp.body}'),
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
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload error: $e')));
    }
  }

  // Send text message (with sent_at)
  void _handleSendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty ||
        widget.chatId == null ||
        widget.customerId == null ||
        widget.plumberId == null)
      return;
    _textController.clear();
    final dataToSend = {
      'chat_id': widget.chatId.toString(),
      'customer_id': widget.customerId.toString(),
      'plumber_id': widget.plumberId.toString(),
      'sender': 'plumber',
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
    if (response.statusCode == 200) {
      final respJson = json.decode(response.body);
      final messageId = respJson['message_id']?.toString();
      if (messageId != null) {
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

  StreamSubscription<DatabaseEvent>? _firebaseSub;

  @override
  void initState() {
    super.initState();
    _initFirebase();
    _initIdsAndFetch();
    _fetchCustomerProfileImage();
    _textController.addListener(_scrollToBottom);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _scrollToBottom();
      }
    });
  }

  Future<void> _initFirebase() async {
    print("Initializing Firebase connection");
    try {
      await FirebaseService.initialize();
      print("Firebase initialized successfully");

      if (widget.chatId != null) {
        print("Chat ID found: ${widget.chatId}");
        _subscribeToFirebase(widget.chatId!);
      } else {
        print("ERROR: No chat ID provided");
      }
    } catch (e) {
      print("Failed to initialize Firebase: $e");
    }
  }

  // Only subscribe to Firebase for messages
  void _subscribeToFirebase(int chatId) {
    _firebaseSub?.cancel();
    _firebaseSub = FirebaseService.messageStream(chatId.toString()).listen((
      event,
    ) {
      final data = event.snapshot.value;
      List messages = [];
      if (data is Map) {
        messages = data.values.where((v) => v != null).toList();
      } else if (data is List) {
        messages = data.where((item) => item != null).toList();
      }
      // Sort by message_id as integer
      messages.sort((a, b) {
        final aid = int.tryParse(a['message_id']?.toString() ?? '') ?? 0;
        final bid = int.tryParse(b['message_id']?.toString() ?? '') ?? 0;
        return aid.compareTo(bid);
      });
      setState(() {
        _messages =
            messages.map<_ChatMessage>((msg) {
              // Parse customer_id and plumber_id to int (like customer side)
              int? customerId;
              int? plumberId;
              if (msg['customer_id'] != null) {
                customerId = int.tryParse(msg['customer_id'].toString());
              }
              if (msg['plumber_id'] != null) {
                plumberId = int.tryParse(msg['plumber_id'].toString());
              }
              return _ChatMessage(
                message: msg['message']?.toString() ?? '',
                isSentByMe: msg['sender']?.toString() == 'plumber',
                mediaPath: msg['media_path'],
                sentAt: msg['sent_at'],
                customerId: customerId,
                plumberId: plumberId,
                thumbnailPath: msg['thumbnail_path'],
              );
            }).toList();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });
  }

  Future<void> _initIdsAndFetch() async {
    int? plumberId = widget.plumberId;
    int? customerId = widget.customerId;
    if (plumberId == null) {
      final prefs = await SharedPreferences.getInstance();
      final pid = prefs.getString('plumber_id');
      plumberId = pid != null ? int.tryParse(pid) : null;
    }
    if (customerId == null) {
      final prefs = await SharedPreferences.getInstance();
      final cid = prefs.getString('customer_id');
      customerId = cid != null ? int.tryParse(cid) : null;
    }
    setState(() {
      _plumberId = plumberId;
      _customerId = customerId;
    });
    // Do not call _fetchMessages here
  }

  @override
  void dispose() {
    print("Disposing chat page - cleaning up resources");
    _textController.removeListener(_scrollToBottom); // Add this line
    _scrollController.dispose(); // Add this line
    _textController.dispose(); // Add this line
    _focusNode.dispose(); // Add this line
    _firebaseSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchCustomerProfileImage() async {
    if (widget.customerId == null) return;
    final response = await http.get(
      Uri.parse('https://aquafixsansimon.com/api/customers.php'),
    );
    if (response.statusCode == 200) {
      final List users = json.decode(response.body);
      final user = users.firstWhere(
        (u) => u['customer_id'].toString() == widget.customerId.toString(),
        orElse: () => null,
      );
      if (user != null &&
          user['profile_image'] != null &&
          user['profile_image'].toString().isNotEmpty) {
        setState(() {
          _customerProfileImage = user['profile_image'];
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
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
                                index > 0 ? _messages[index - 1] : null;
                            final next =
                                index < _messages.length - 1
                                    ? _messages[index + 1]
                                    : null;

                            final bool isPrevSame =
                                prev != null &&
                                prev.isSentByMe == current.isSentByMe;
                            final bool isNextSame =
                                next != null &&
                                next.isSentByMe == current.isSentByMe;

                            final bool isOnly = !isPrevSame && !isNextSame;
                            final bool isStart = !isPrevSame && isNextSame;
                            final bool isMiddle = isPrevSame && isNextSame;
                            final bool isEnd = isPrevSame && !isNextSame;

                            if (current.mediaPath != null &&
                                current.mediaPath!.isNotEmpty) {
                              final mediaUrl =
                                  'https://aquafixsansimon.com/uploads/chats_media/${current.mediaPath}';
                              final thumbnailUrl =
                                  current.thumbnailPath != null &&
                                          current.thumbnailPath!.isNotEmpty
                                      ? 'https://aquafixsansimon.com/uploads/chats_media/${current.thumbnailPath}'
                                      : null;
                              if (_isImageFile(current.mediaPath!)) {
                                return _ImageMessage(
                                  imageUrl: mediaUrl,
                                  isSentByMe: current.isSentByMe,
                                  isOnly: isOnly,
                                  isStart: isStart,
                                  isMiddle: isMiddle,
                                  isEnd: isEnd,
                                  sentAt: current.sentAt,
                                  customerProfileImage:
                                      current.isSentByMe
                                          ? null
                                          : _customerProfileImage,
                                );
                              } else if (_isVideoFile(current.mediaPath!)) {
                                return _VideoMessage(
                                  videoUrl: mediaUrl,
                                  thumbnailUrl: thumbnailUrl,
                                  isSentByMe: current.isSentByMe,
                                  isOnly: isOnly,
                                  isStart: isStart,
                                  isMiddle: isMiddle,
                                  isEnd: isEnd,
                                  sentAt: current.sentAt,
                                  customerProfileImage:
                                      current.isSentByMe
                                          ? null
                                          : _customerProfileImage,
                                );
                              }
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isStart || isOnly) SizedBox(height: 14.sp),
                                ChatBubble(
                                  message: current.message,
                                  isSentByMe: current.isSentByMe,
                                  sentAt: current.sentAt,

                                  isOnly: isOnly,
                                  isStart: isStart,
                                  isMiddle: isMiddle,
                                  isEnd: isEnd,

                                  customerProfileImage:
                                      current.isSentByMe
                                          ? null
                                          : _customerProfileImage,
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
                onCameraPick: _pickImageFromCamera,
                onGalleryPick: _pickImageFromGallery,
              ),
            ],
          ),
        ),
      ),
    );
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
                      _customerProfileImage != null &&
                              _customerProfileImage!.isNotEmpty
                          ? CircleAvatar(
                            backgroundColor: Colors.white,
                            backgroundImage: NetworkImage(
                              'https://aquafixsansimon.com/uploads/profiles/customers/$_customerProfileImage',
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
                    // Info action
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

class FullscreenImagePageNetwork extends StatelessWidget {
  final String imageUrl;
  const FullscreenImagePageNetwork({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final appBar = AppBar(
      backgroundColor: Colors.transparent,
      iconTheme: const IconThemeData(color: Colors.white),
      elevation: 0,
    );
    final appBarHeight = appBar.preferredSize.height;
    final totalTopPadding = appBarHeight;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: appBar,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight - totalTopPadding;
          return InteractiveViewer(
            child: SizedBox(
              width: constraints.maxWidth,
              height: availableHeight,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChatMessage {
  final String? message;
  final bool isSentByMe;
  final String? mediaPath;
  final String? sentAt;
  final int? customerId;
  final int? plumberId;
  final String? thumbnailPath;

  _ChatMessage({
    this.message,
    required this.isSentByMe,
    this.mediaPath,
    this.sentAt,
    this.customerId,
    this.plumberId,
    this.thumbnailPath,
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
  final String? customerProfileImage;

  const _ImageMessage({
    required this.imageUrl,
    required this.isSentByMe,
    required this.isOnly,
    required this.isStart,
    required this.isMiddle,
    required this.isEnd,
    this.sentAt,
    this.customerProfileImage,
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
              decoration: BoxDecoration(shape: BoxShape.circle),
              child:
                  customerProfileImage != null &&
                          customerProfileImage!.isNotEmpty
                      ? CircleAvatar(
                        backgroundColor: Colors.white,
                        backgroundImage: NetworkImage(
                          'https://aquafixsansimon.com/uploads/profiles/customers/$customerProfileImage',
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
  final String? customerProfileImage;

  const _VideoMessage({
    required this.videoUrl,
    this.thumbnailUrl,
    required this.isSentByMe,
    required this.isOnly,
    required this.isStart,
    required this.isMiddle,
    required this.isEnd,
    this.sentAt,
    this.customerProfileImage,
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
              decoration: BoxDecoration(shape: BoxShape.circle),
              child:
                  customerProfileImage != null &&
                          customerProfileImage!.isNotEmpty
                      ? CircleAvatar(
                        backgroundColor: Colors.white,
                        backgroundImage: NetworkImage(
                          'https://aquafixsansimon.com/uploads/profiles/customers/$customerProfileImage',
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
                          child: NetworkVideoPlayerPreview(url: videoUrl),
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
                        thumbnailUrl != null && thumbnailUrl!.isNotEmpty
                            ? Image.network(
                              thumbnailUrl!,
                              width: width,
                              height: height,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildFallbackThumbnail();
                              },
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                  ),
                                );
                              },
                            )
                            : _buildFallbackThumbnail(),
                  ),
                  Icon(
                    Icons.play_circle_fill,
                    size: 48.sp,
                    color: Colors.white.withAlpha(204), // was .withOpacity(0.8)
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

// --- Add this widget to match customer side video preview ---

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
          child: Text(
            "Failed to play video.\n\n$_error",
            style: TextStyle(color: Colors.red, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return _isInitialized
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
                  color: Colors.black.withAlpha(179), // was .withOpacity(0.7)
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
                        padding: EdgeInsets.only(left: 0, right: 0, bottom: 0),
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
        )
        : const Center(child: CircularProgressIndicator());
  }
}

class ChatBubble extends StatelessWidget {
  final String? message;
  final File? imageFile;
  final bool isSentByMe;
  final bool isOnly;
  final bool isStart;
  final bool isMiddle;
  final bool isEnd;
  final String? sentAt;
  final String? customerProfileImage;

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
    this.customerProfileImage,
  });

  Future<bool> _fetchIsConfirmed(String joNumber) async {
    try {
      final url = Uri.parse(
        'https://aquafixsansimon.com/api/job_order_lookup.php?jo_number=$joNumber',
      );
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['job_order_id'] != null) {
          print(
            'Fetched job_order_id: ${data['job_order_id']} for jo_number: $joNumber',
          );
        } else {
          print('No job_order_id found for jo_number: $joNumber');
        }
        final isConfirmedValue =
            data.containsKey('isConfirmed') ? data['isConfirmed'] : null;
        print('isConfirmed value for jo_number $joNumber: $isConfirmedValue');
        // Defensive: treat null/empty/false as not confirmed
        return isConfirmedValue == 1 || isConfirmedValue == '1';
      }
    } catch (e) {
      print('Error fetching job_order_id for jo_number $joNumber: $e');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    BorderRadius getBubbleRadius() {
      final r = Radius.circular(20.sp);
      final tight = Radius.circular(4.sp);

      if (isSentByMe) {
        if (isOnly) {
          return BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: r,
            bottomRight: r,
          );
        } else if (isStart) {
          return BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: r,
            bottomRight: tight,
          );
        } else if (isMiddle) {
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
        if (isOnly) {
          return BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: r,
            bottomRight: r,
          );
        } else if (isStart) {
          return BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: tight,
            bottomRight: r,
          );
        } else if (isMiddle) {
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

    // Detect accomplishment message and show confirmation UI (sent by plumber)
    final bool isAccomplishment =
        message != null &&
        message!.toLowerCase().contains('your request was accomplished');

    // Extract jo_number from accomplishment message
    String? joNumber;
    if (isAccomplishment) {
      final lines = message!.split('\n');
      for (final line in lines) {
        final match = RegExp(
          r'Job Order #[:\s]*([A-Za-z0-9\-]+)',
          caseSensitive: false,
        ).firstMatch(line);
        if (match != null) {
          joNumber = match.group(1);
          break;
        }
      }
    }

    if (isAccomplishment && isSentByMe && joNumber != null) {
      final lines = message!.split('\n');
      final details = lines.skip(1).join('\n').trim();

      return FutureBuilder<bool>(
        future: _fetchIsConfirmed(joNumber),
        builder: (context, snapshot) {
          final isConfirmed = snapshot.data == true;
          return Padding(
            padding: EdgeInsets.only(top: isStart ? 12.sp : 4.sp),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.end,
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
                    decoration: BoxDecoration(shape: BoxShape.circle),
                    child:
                        customerProfileImage != null &&
                                customerProfileImage!.isNotEmpty
                            ? CircleAvatar(
                              backgroundColor: Colors.white,
                              backgroundImage: NetworkImage(
                                'https://aquafixsansimon.com/uploads/profiles/customers/$customerProfileImage',
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
                      color: const Color(0xFF2D9FD0),
                      borderRadius: getBubbleRadius(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Your request was accomplished!",
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8.sp),
                        Text(
                          "Report Details: ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8.sp),
                        Text(
                          details,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 10.sp),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withAlpha(179),
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.sp,
                                vertical: 0,
                              ),
                              minimumSize: Size(0, 30.sp),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.sp),
                              ),
                            ),
                            onPressed: null,
                            child: Text(
                              isConfirmed ? "Confirmed" : "Confirm",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.sp,
                                color: const Color.fromARGB(255, 230, 230, 230),
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
    print('Customer profile image: $customerProfileImage');

    return Padding(
      padding: EdgeInsets.only(top: isStart ? 12.sp : 4.sp),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
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
              decoration: BoxDecoration(shape: BoxShape.circle),
              child:
                  customerProfileImage != null &&
                          customerProfileImage!.isNotEmpty
                      ? CircleAvatar(
                        backgroundColor: Colors.white,
                        backgroundImage: NetworkImage(
                          'https://aquafixsansimon.com/uploads/profiles/customers/$customerProfileImage',
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
                    isSentByMe ? const Color(0xFF2D9FD0) : Colors.grey.shade200,
                borderRadius: getBubbleRadius(),
              ),
              child:
                  message != null
                      ? Text(
                        message!,
                        style: TextStyle(
                          color: isSentByMe ? Colors.white : Colors.black87,
                          fontSize: 15.sp,
                        ),
                      )
                      : ClipRRect(
                        borderRadius: BorderRadius.circular(12.sp),
                        child: Image.file(
                          imageFile!,
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
        padding: EdgeInsets.symmetric(
          horizontal: 12.sp,
          vertical: 8.sp,
        ), // applied sp
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.camera_alt,
                color: Color(0xFF2D9FD0),
                size: 24.sp,
              ), // applied sp
              onPressed: onCameraPick, // Use the callback
            ),
            IconButton(
              icon: Icon(
                Icons.photo,
                color: Color(0xFF2D9FD0),
                size: 24.sp,
              ), // applied sp
              onPressed: onGalleryPick, // Use the callback
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.sp), // applied sp
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20.sp), // applied sp
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode, // Add this line
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            SizedBox(width: 8.sp), // applied sp
            IconButton(
              icon: Icon(
                Icons.send,
                color: Color(0xFF2D9FD0),
                size: 24.sp,
              ), // applied sp
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
          child: Text(
            "Failed to play video.\n\n$_error",
            style: TextStyle(color: Colors.red, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return _isInitialized
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
                  color: Colors.black.withAlpha(179), // was .withOpacity(0.7)
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
                        padding: EdgeInsets.only(left: 0, right: 0, bottom: 0),
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
        )
        : const Center(child: CircularProgressIndicator());
  }
}
