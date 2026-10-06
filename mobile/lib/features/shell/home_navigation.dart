import '../../core/app_theme.dart';
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
    this.monochrome = false,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Map<int, Key> destinationKeys;
  final Widget? profileAvatar;
  final bool monochrome;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.adaptive(context, const Color(0xF2131418)),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: AppTheme.adaptive(context, AppColors.border),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.isDark(context)
                  ? const Color(0x66000000)
                  : const Color(0x14000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: NavigationBar(
            height: 56,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            backgroundColor: Colors.transparent,
            indicatorColor: monochrome
                ? AppTheme.adaptive(context, const Color(0x18FFFFFF))
                : AppTheme.accentTint(context),
            indicatorShape: const CircleBorder(),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            destinations: [
              NavigationDestination(
                icon: Icon(CupertinoIcons.house, key: destinationKeys[0]),
                selectedIcon: Icon(
                  CupertinoIcons.house_fill,
                  color: monochrome ? AppTheme.textPrimary(context) : null,
                ),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(
                  CupertinoIcons.barcode_viewfinder,
                  key: destinationKeys[1],
                ),
                selectedIcon: Icon(
                  CupertinoIcons.barcode_viewfinder,
                  color: monochrome ? AppTheme.textPrimary(context) : null,
                ),
                label: 'Capture',
              ),
              NavigationDestination(
                icon: Icon(CupertinoIcons.chat_bubble, key: destinationKeys[2]),
                selectedIcon: Icon(
                  CupertinoIcons.chat_bubble_fill,
                  color: monochrome ? AppTheme.textPrimary(context) : null,
                ),
                label: 'Ask',
              ),
              NavigationDestination(
                icon: const Icon(CupertinoIcons.search),
                selectedIcon: Icon(
                  CupertinoIcons.search_circle_fill,
                  color: monochrome ? AppTheme.textPrimary(context) : null,
                ),
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
                    Icon(
                      CupertinoIcons.person_crop_circle_fill,
                      color: monochrome ? AppTheme.textPrimary(context) : null,
                    ),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
