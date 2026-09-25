import 'package:flutter/material.dart';

import '../../core/ui/app_tokens.dart';
import 'app_destination.dart';

class PrimaryNavigationBar extends StatelessWidget {
  const PrimaryNavigationBar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.iconKeys = const {},
  });

  final AppDestination selected;
  final ValueChanged<AppDestination> onSelected;
  final Map<AppDestination, Key> iconKeys;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Primary navigation',
      child: NavigationBar(
        key: const ValueKey('primary-navigation'),
        height: AppTokens.primaryNavigationHeight,
        backgroundColor: Colors.transparent,
        selectedIndex: selected.index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          onSelected(AppDestination.values[index]);
        },
        destinations: [
          for (final destination in AppDestination.values)
            NavigationDestination(
              tooltip: destination.semanticLabel,
              icon: Icon(
                destination.icon,
                key: iconKeys[destination],
                semanticLabel: destination.semanticLabel,
              ),
              selectedIcon: Icon(
                destination.selectedIcon,
                key: iconKeys[destination],
                semanticLabel: destination.semanticLabel,
              ),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
