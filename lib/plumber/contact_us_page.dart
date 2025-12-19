import 'package:flutter/material.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Contact Us")),
      body: const Center(
        child: Text("Stats content goes here!", style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
