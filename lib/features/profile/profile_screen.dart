import 'package:flutter/material.dart';

import '../character/character_screen.dart';
import '../house/house_screen.dart';

/// Profile hub with two tabs: Avatar (character customiser) and Home (the room).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.face), text: 'Avatar'),
              Tab(icon: Icon(Icons.cottage), text: 'Home'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [AvatarTab(), HomeTab()],
        ),
      ),
    );
  }
}
