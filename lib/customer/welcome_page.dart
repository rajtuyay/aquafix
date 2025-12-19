import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'login_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 9,
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: const [
                  WelcomeSection1(),
                  WelcomeSection2(),
                  WelcomeSection3(),
                  WelcomeSection4(),
                ],
              ),
            ),
            // Dots Indicator
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: 4,
                effect: const WormEffect(
                  dotHeight: 10,
                  dotWidth: 10,
                  spacing: 8,
                  dotColor: Color(0xFFB0BEC5),
                  activeDotColor: Color(0xFF2C9CD9),
                ),
              ),
            ),
            // Skip or Get Started Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage == 3) {
                      // Navigate to LoginPage
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    } else {
                      // Jump directly to last page
                      _pageController.animateToPage(
                        3,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C9CD9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    _currentPage == 3 ? 'Get Started' : 'Skip',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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

// Section 1
class WelcomeSection1 extends StatelessWidget {
  const WelcomeSection1({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/logo.png', width: 200),
          const SizedBox(height: 16),
          const Text(
            'Welcome to AquaFix',
            style: TextStyle(
              fontFamily: 'Cambria',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(2, 73, 154, 1),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Where smart living starts with smart water habits.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color.fromRGBO(0, 0, 0, 1)),
            ),
          ),
        ],
      ),
    );
  }
}

// Section 2
class WelcomeSection2 extends StatelessWidget {
  const WelcomeSection2({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          Image.asset('assets/Hassle.png', width: 160),
          const SizedBox(height: 32),
          const Text(
            'Hassle-Free Plumbing Service',
            style: TextStyle(
              fontFamily: 'Cambria',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(2, 73, 154, 1),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Easily request plumbing help and let us match you with a certified professional.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color.fromRGBO(0, 0, 0, 1)),
            ),
          ),
        ],
      ),
    );
  }
}

// Section 3
class WelcomeSection3 extends StatelessWidget {
  const WelcomeSection3({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/track.png', width: 180),
          const SizedBox(height: 40),
          const Text(
            'Track Your Plumber Live',
            style: TextStyle(
              fontFamily: 'Cambria',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(2, 73, 154, 1),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 50),
            child: Text(
              'See your plumber’s real-time location and arrival—no guessing, no stress.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color.fromRGBO(0, 0, 0, 1)),
            ),
          ),
        ],
      ),
    );
  }
}

// Section 4
class WelcomeSection4 extends StatelessWidget {
  const WelcomeSection4({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 30),
          Image.asset('assets/alert.png', width: 170),
          const SizedBox(height: 24),
          const Text(
            'Smart Alerts & Updates',
            style: TextStyle(
              fontFamily: 'Cambria',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(2, 73, 154, 1),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Get notified about billing spikes, appointment reminders, and job progress instantly.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color.fromRGBO(0, 0, 0, 1)),
            ),
          ),
        ],
      ),
    );
  }
}
