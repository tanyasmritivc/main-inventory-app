import 'package:flutter/cupertino.dart';

/// Stable top-level product destinations.
///
/// The enum order is the PageView and primary navigation order. Secondary
/// capabilities remain routes within Memory or Profile rather than new tabs.
enum AppDestination { ask, capture, find, memory, profile }

const initialAppDestination = AppDestination.ask;

extension AppDestinationPresentation on AppDestination {
  String get label => switch (this) {
    AppDestination.ask => 'Ask',
    AppDestination.capture => 'Capture',
    AppDestination.find => 'Find',
    AppDestination.memory => 'Memory',
    AppDestination.profile => 'Profile',
  };

  String get appBarTitle => switch (this) {
    AppDestination.ask => 'Ask FindEZ',
    AppDestination.capture => 'Capture',
    AppDestination.find => 'Find',
    AppDestination.memory => 'Memory',
    AppDestination.profile => 'Profile',
  };

  String get semanticLabel => switch (this) {
    AppDestination.ask => 'Ask FindEZ about your physical world',
    AppDestination.capture => 'Capture objects and add them to memory',
    AppDestination.find => 'Find items across your spaces',
    AppDestination.memory => 'Browse and organize FindEZ memory',
    AppDestination.profile => 'Profile and account controls',
  };

  IconData get icon => switch (this) {
    AppDestination.ask => CupertinoIcons.chat_bubble,
    AppDestination.capture => CupertinoIcons.camera,
    AppDestination.find => CupertinoIcons.search,
    AppDestination.memory => CupertinoIcons.archivebox,
    AppDestination.profile => CupertinoIcons.person_crop_circle,
  };

  IconData get selectedIcon => switch (this) {
    AppDestination.ask => CupertinoIcons.chat_bubble_fill,
    AppDestination.capture => CupertinoIcons.camera_fill,
    AppDestination.find => CupertinoIcons.search,
    AppDestination.memory => CupertinoIcons.archivebox_fill,
    AppDestination.profile => CupertinoIcons.person_crop_circle_fill,
  };
}

/// Existing product capabilities and the destination that owns their entry.
/// This is deliberately current-state metadata, not a future route registry.
const preservedMobileRoutes = <String, AppDestination>{
  'Ask and conversation history': AppDestination.ask,
  'Attachments and voice': AppDestination.ask,
  'Photo capture': AppDestination.capture,
  'Barcode and FindEZ QR': AppDestination.capture,
  'Inventory search': AppDestination.find,
  'Spaces and items': AppDestination.memory,
  'Teams and sharing': AppDestination.memory,
  'Documents': AppDestination.memory,
  'Check-outs': AppDestination.memory,
  'Low stock': AppDestination.memory,
  'Project kits and BOM': AppDestination.memory,
  'Labels and activity': AppDestination.memory,
  'Notifications': AppDestination.profile,
  'Account, support, and legal': AppDestination.profile,
};
