import 'package:flutter/material.dart';
import 'bottom_nav_bar.dart';
import '../home_page.dart';
import '../plumber_page.dart';
import '../chats_page.dart';
import '../profile_page.dart';

class MainScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final Widget? overlay;

  const MainScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    this.overlay,
  });

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget destination;
    switch (index) {
      case 0:
        destination = const HomePage(currentIndex: 0);
        break;
      case 1:
        destination = const PlumberPage(currentIndex: 1);
        break;
      case 2:
        destination = const ChatsPage(currentIndex: 2);
        break;
      case 3:
        destination = const ProfilePage(currentIndex: 3);
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionDuration: const Duration(milliseconds: 0), // No animation
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: body,
          bottomNavigationBar: BottomNavBar(
            currentIndex: currentIndex,
            onTap: (index) => _onItemTapped(context, index),
          ),
        ),
        if (overlay != null) overlay!, // Overlay on top of everything
      ],
    );
  }
}
