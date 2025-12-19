import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
import 'plumber_ratings_page.dart';
import 'landscape_video_player.dart';

class ChatInfoPage extends StatefulWidget {
  final String userName;
  final int? chatId;
  final int? plumberId;
  final String? plumberProfileImage;

  const ChatInfoPage({
    super.key,
    required this.userName,
    this.chatId,
    this.plumberId,
    this.plumberProfileImage,
  });

  @override
  State<ChatInfoPage> createState() => _ChatInfoPageState();
}

class _ChatInfoPageState extends State<ChatInfoPage> {
  List<Map<String, dynamic>> _mediaItems = [];
  bool _loadingMedia = true;

  @override
  void initState() {
    super.initState();
    _fetchChatMedia();
  }

  Future<void> _fetchChatMedia() async {
    if (widget.chatId == null) return;
    try {
      final url = Uri.parse(
        'https://aquafixsansimon.com/api/chat_messages.php?chat_id=${widget.chatId}',
      );
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final List messages = json.decode(resp.body);
        final media =
            messages
                .where(
                  (msg) =>
                      msg['media_path'] != null &&
                      msg['media_path'].toString().isNotEmpty,
                )
                .toList();
        setState(() {
          _mediaItems = List<Map<String, dynamic>>.from(media);
          _loadingMedia = false;
        });
      } else {
        setState(() {
          _loadingMedia = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadingMedia = false;
      });
    }
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
        ext.endsWith('.mkv');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          'Chat Info',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D9FD0)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header with profile - Centered
            Container(
              padding: EdgeInsets.all(20.sp),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 80.w,
                    height: 80.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
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
                              backgroundColor: Color(0xFF2D9FD0),
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 40.sp,
                              ),
                            ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    widget.userName,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Professional Plumber',
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey[200]),
            // Options section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _showRatingModal(context),
                    child: _buildOptionItem(
                      icon: Icons.star,
                      label: 'Ratings & Reviews',
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 16.sp,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _contactPlumber(),
                    child: _buildOptionItem(
                      icon: Icons.phone,
                      label: 'Contact Plumber',
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 16.sp,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey[200]),
            // Media section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Media',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _loadingMedia
                      ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.sp),
                          child: CircularProgressIndicator(),
                        ),
                      )
                      : _mediaItems.isEmpty
                      ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.sp),
                          child: Text(
                            'No media shared',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      )
                      : GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8.w,
                          mainAxisSpacing: 8.h,
                        ),
                        itemCount: _mediaItems.length,
                        itemBuilder: (context, index) {
                          final media = _mediaItems[index];
                          final mediaPath = media['media_path'];
                          final thumbnailPath = media['thumbnail_path'];
                          final mediaUrl =
                              'https://aquafixsansimon.com/uploads/chats_media/$mediaPath';
                          final thumbnailUrl =
                              thumbnailPath != null &&
                                      thumbnailPath.toString().isNotEmpty
                                  ? 'https://aquafixsansimon.com/uploads/chats_media/$thumbnailPath'
                                  : null;

                          return GestureDetector(
                            onTap: () {
                              if (_isImageFile(mediaPath)) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => _FullscreenMediaViewer(
                                          url: mediaUrl,
                                          isVideo: false,
                                        ),
                                  ),
                                );
                              } else if (_isVideoFile(mediaPath)) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => _FullscreenMediaViewer(
                                          url: mediaUrl,
                                          isVideo: true,
                                        ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.sp),
                                color: Colors.grey[200],
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _isImageFile(mediaPath)
                                      ? Image.network(
                                        mediaUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return Container(
                                            color: Colors.grey[300],
                                            child: Icon(Icons.broken_image),
                                          );
                                        },
                                      )
                                      : _isVideoFile(mediaPath)
                                      ? (thumbnailUrl != null
                                          ? Image.network(
                                            thumbnailUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (
                                              context,
                                              error,
                                              stackTrace,
                                            ) {
                                              return Container(
                                                color: Colors.grey[300],
                                                child: Icon(Icons.videocam),
                                              );
                                            },
                                          )
                                          : Container(
                                            color: Colors.grey[300],
                                            child: Icon(Icons.videocam),
                                          ))
                                      : Container(
                                        color: Colors.grey[300],
                                        child: Icon(Icons.insert_drive_file),
                                      ),
                                  if (_isVideoFile(mediaPath))
                                    Center(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        padding: EdgeInsets.all(6.sp),
                                        child: Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                          size: 16.sp,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    required Widget trailing,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF2D9FD0), size: 24.sp),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15.sp, color: Colors.black87),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Future<void> _contactPlumber() async {
    if (widget.plumberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plumber contact not available.')),
      );
      return;
    }

    // Fetch plumber contact from API
    try {
      final response = await http.get(
        Uri.parse('https://aquafixsansimon.com/api/plumbers.php'),
      );
      if (response.statusCode == 200) {
        final List users = json.decode(response.body);
        final plumber = users.firstWhere(
          (u) => u['plumber_id'].toString() == widget.plumberId.toString(),
          orElse: () => null,
        );
        if (plumber != null && plumber['contact_no'] != null) {
          final phone = plumber['contact_no'].toString();
          final uri = Uri(scheme: 'tel', path: phone);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cannot make a call.')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plumber contact not available.')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showRatingModal(BuildContext context) async {
    if (widget.plumberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plumber ID not available.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => PlumberRatingsPage(
              plumberId: widget.plumberId!,
              plumberName: widget.userName,
            ),
      ),
    );
  }
}

class _FullscreenMediaViewer extends StatelessWidget {
  final String url;
  final bool isVideo;

  const _FullscreenMediaViewer({required this.url, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        titleSpacing: 0,
      ),
      body: Center(
        child:
            isVideo
                ? _VideoPlayerSelector(url: url)
                : InteractiveViewer(
                  panEnabled: true,
                  scaleEnabled: true,
                  child: Image.network(url, fit: BoxFit.contain),
                ),
      ),
    );
  }
}

class _VideoPlayerSelector extends StatefulWidget {
  final String url;
  const _VideoPlayerSelector({required this.url});

  @override
  State<_VideoPlayerSelector> createState() => _VideoPlayerSelectorState();
}

class _VideoPlayerSelectorState extends State<_VideoPlayerSelector> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isLandscape = false;

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
            _isInitialized = true;
            _isLandscape = ratio > 1.2; // Landscape if aspect ratio > 1.2
          });
        })
        .catchError((e) {
          debugPrint('Video initialization error: $e');
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return _isLandscape
        ? LandscapeVideoPlayerPreview(url: widget.url)
        : NetworkVideoPlayerPreview(url: widget.url);
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
              "- The server does not support HTTP range requests.\n"
              "- The server is not using HTTPS.\n"
              "- The video is not encoded as H.264/AAC.\n\n"
              "Try:\n"
              "- Playing the video in your phone's browser.\n"
              "- Re-encoding the video to standard MP4 (H.264/AAC).",
              style: TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
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
