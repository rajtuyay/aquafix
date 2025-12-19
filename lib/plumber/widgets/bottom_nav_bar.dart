import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color.fromRGBO(45, 159, 208, 1),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: SizedBox(
              height: 28,
              width: 28,
              child: Icon(Icons.assignment_outlined, size: 28),
            ),
            activeIcon: SizedBox(
              height: 28,
              width: 28,
              child: Icon(Icons.assignment, size: 28),
            ),
            label: 'Task',
          ),
          BottomNavigationBarItem(
            icon: SizedBox(
              height: 28,
              width: 28,
              child: Icon(Icons.location_on_outlined, size: 28),
            ),
            activeIcon: SizedBox(
              height: 28,
              width: 28,
              child: Icon(Icons.location_on, size: 28),
            ),
            label: 'Map',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: SizedBox(
              height: 28,
              width: 28,
              child: Icon(Icons.person_outline, size: 28),
            ),
            activeIcon: SizedBox(
              height: 28,
              width: 28,
              child: Icon(Icons.person, size: 28),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
