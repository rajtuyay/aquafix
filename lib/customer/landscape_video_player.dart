import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:ui';

class LandscapeVideoPlayerPreview extends StatefulWidget {
  final String url;
  const LandscapeVideoPlayerPreview({super.key, required this.url});

  @override
  State<LandscapeVideoPlayerPreview> createState() =>
      _LandscapeVideoPlayerPreviewState();
}

class _LandscapeVideoPlayerPreviewState
    extends State<LandscapeVideoPlayerPreview> {
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
        ? Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
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
