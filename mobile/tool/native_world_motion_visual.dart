// Synthetic native audit only; never a production build target.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/appearance_controller.dart';
import 'package:mobile/core/place_session.dart';
import 'package:mobile/features/world/world_shell.dart';
import '../test/support/hierarchy_fixture.dart';

Future<void> main() async {
  if (kReleaseMode) throw UnsupportedError('Debug audit only');
  WidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  await fixture.initialize();
  fixture.respond = (request) {
    if (request.path.endsWith('/profile/me')) {
      return {'user_id': 'actor-a', 'display_name': 'Alex Example'};
    }
    if (request.path.endsWith('/notifications')) {
      return {'notifications': [], 'unread_count': 0};
    }
    if (request.path.endsWith('/conversations')) return [];
    if (request.path.endsWith('/directory')) {
      return {
        'has_items': true,
        'inventories': [
          {'inventory_id': 'inventory-a', 'name': 'Workshop', 'can_edit': true},
        ],
      };
    }
    if (request.path.endsWith('/spaces')) {
      return {
        'inventories': [
          {
            'inventory_id': 'inventory-a',
            'name': 'Workshop',
            'workspace_name': 'Personal',
            'can_edit': true,
            'spaces': [
              {'name': 'Workbench', 'space_id': 'space-a'},
              {'name': 'Parts drawers', 'space_id': 'space-b'},
            ],
          },
        ],
      };
    }
    return <String, dynamic>{};
  };
  final session = PlaceSession(fixture.api, 'actor-a')
    ..loading = false
    ..navigationReady = true;
  final appearance = AppearanceController();
  await appearance.load();
  await appearance.setThemeMode(ThemeMode.dark);
  runApp(
    AnimatedBuilder(
      animation: appearance,
      builder: (context, _) => AppearanceScope(
        controller: appearance,
        child: MaterialApp(
          theme: AppTheme.create(Brightness.light),
          darkTheme: AppTheme.create(Brightness.dark),
          themeMode: appearance.themeMode,
          home: WorldShell(session: session),
        ),
      ),
    ),
  );
}
