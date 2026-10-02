import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/ui/app_colors.dart';

class HomeNavigation extends StatelessWidget {
  const HomeNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.destinationKeys = const {},
    this.profileAvatar,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Map<int, Key> destinationKeys;
  final Widget? profileAvatar;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xF2131418),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: NavigationBar(
          height: 70,
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0x18FFFFFF),
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
              icon: Icon(
                CupertinoIcons.barcode_viewfinder,
                key: destinationKeys[1],
              ),
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
            NavigationDestination(
              icon:
                  profileAvatar ??
                  Icon(
                    CupertinoIcons.person_crop_circle,
                    key: destinationKeys[4],
                  ),
              selectedIcon:
                  profileAvatar ??
                  const Icon(CupertinoIcons.person_crop_circle_fill),
              label: 'Profile',
            ),
          ],
        ),
      ),
    ),
  );
}
