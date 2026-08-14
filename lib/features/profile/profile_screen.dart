import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_providers.dart';
import '../character/character_screen.dart';
import '../house/house_screen.dart';
import '../social/account_code_card.dart';
import '../social/social_screen.dart';

/// Profile hub with three tabs: Avatar (character), Home (the room), and Social
/// (your shareable code + friends & groups).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.face), text: 'Avatar'),
              Tab(icon: Icon(Icons.cottage), text: 'Home'),
              Tab(icon: Icon(Icons.people_outline), text: 'Social'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [AvatarTab(), HomeTab(), SocialTab()],
        ),
      ),
    );
  }
}

/// The Social tab: your username + shareable account code (works offline), and
/// shortcuts into the full Friends & Groups screen.
class SocialTab extends ConsumerWidget {
  const SocialTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);

    void open(int tab) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SocialScreen(initialIndex: tab)),
        );

    return ListView(
      children: [
        const SizedBox(height: 4),
        AccountCodeCard(
          username: player.username,
          accountCode: player.accountCode,
          onCopy: () {
            Clipboard.setData(ClipboardData(text: player.accountCode));
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(
                  content: Text('Code copied — share it to get added')));
          },
          onEditName: () => showUsernameEditor(context, ref),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => open(0),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Add friend'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => open(1),
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Groups'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
