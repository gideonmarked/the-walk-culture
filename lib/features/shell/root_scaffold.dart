import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_providers.dart';
import '../../state/premium_providers.dart';
import '../home/home_screen.dart';
import '../pass/travel_pass_screen.dart';
import '../profile/profile_screen.dart';
import '../quests/quests_screen.dart';
import '../shop/shop_screen.dart';

class RootScaffold extends ConsumerStatefulWidget {
  const RootScaffold({super.key});

  @override
  ConsumerState<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends ConsumerState<RootScaffold> {
  int _index = 0;
  static const _pages = [
    HomeScreen(),
    QuestsScreen(),
    TravelPassScreen(),
    ShopScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Both feed the badge: the count moves with XP/claims, and going VIP makes
    // the whole earned VIP column claimable at once.
    ref.watch(playerControllerProvider);
    ref.watch(premiumControllerProvider);
    final claimable = ref.read(playerControllerProvider.notifier).passClaimableCount;

    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          const NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag),
              label: 'Quests'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: claimable > 0,
              label: Text('$claimable'),
              child: const Icon(Icons.card_travel_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: claimable > 0,
              label: Text('$claimable'),
              child: const Icon(Icons.card_travel),
            ),
            label: 'Pass',
          ),
          const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Shop'),
          const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}
