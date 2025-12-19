import 'package:flutter/material.dart';
import 'bottom_nav_bar.dart';
import '../task_page.dart';
import '../map_page.dart';
import '../chats_page.dart';
import '../profile_page.dart';

class MainScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;

  const MainScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
  });

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget destination;
    switch (index) {
      case 0:
        destination = const TaskPage(currentIndex: 0);
        break;
      case 1:
        destination = const MapPage(currentIndex: 1);
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
    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavBar(
        currentIndex: currentIndex,
        onTap: (index) => _onItemTapped(context, index),
      ),
    );
  }
}
