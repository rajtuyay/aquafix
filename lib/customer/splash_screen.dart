import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'welcome_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _videoController;
  bool _showLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize the video player (MP4)
    _videoController = VideoPlayerController.asset(
        'assets/animations/splashscreen.webm',
      )
      ..initialize().then((_) {
        setState(() {});
        _videoController.play();
        _videoController.setLooping(false);

        // Once the video ends, show the loading spinner
        _videoController.addListener(() {
          if (_videoController.value.position ==
              _videoController.value.duration) {
            if (mounted) {
              setState(() {
                _showLoading = true;
              });
            }
            // Wait 2 seconds, then navigate
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) _navigateToNextPage();
            });
          }
        });
      });
  }

  Future<void> _navigateToNextPage() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

    if (!mounted) return; // Prevent navigation if unmounted

    if (isFirstLaunch) {
      await prefs.setBool('isFirstLaunch', false);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomePage()),
        );
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    }
  }

  @override
  void dispose() {
    _videoController.dispose(); // Clean up the video controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: _showLoading ? -20.h : 0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_videoController.value.isInitialized)
                    SizedBox(
                      width: 200.w,
                      height: 200.w,
                      child: VideoPlayer(_videoController),
                    ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child:
                        _showLoading
                            ? Padding(
                              padding: EdgeInsets.only(top: 24.h),
                              child: const CircularProgressIndicator(
                                color: Color(0xFF2C9CD9),
                              ),
                            )
                            : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
