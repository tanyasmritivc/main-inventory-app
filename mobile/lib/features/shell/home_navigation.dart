import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HomeNavigation extends StatelessWidget {
  const HomeNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.destinationKeys = const {},
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Map<int, Key> destinationKeys;
  @override
  Widget build(BuildContext context) => NavigationBar(
    height: 80,
    backgroundColor: const Color(0xFF111113),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    destinations: [
      NavigationDestination(
        icon: Icon(CupertinoIcons.house, key: destinationKeys[0]),
        selectedIcon: const Icon(CupertinoIcons.house_fill),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(CupertinoIcons.barcode_viewfinder, key: destinationKeys[1]),
        selectedIcon: const Icon(CupertinoIcons.barcode_viewfinder),
        label: 'Capture',
      ),
      NavigationDestination(
        icon: Icon(CupertinoIcons.chat_bubble, key: destinationKeys[2]),
        selectedIcon: const Icon(CupertinoIcons.chat_bubble_fill),
        label: 'Ask',
      ),
      const NavigationDestination(
        icon: Icon(CupertinoIcons.search),
        selectedIcon: Icon(CupertinoIcons.search_circle_fill),
        label: 'Find',
      ),
    ],
  );
}
