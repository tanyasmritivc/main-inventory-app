// Isolated simulator fixture. Never imported by the production entry point.
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/place_session.dart';
import 'package:mobile/features/workspaces/workspace_home.dart';
import '../test/support/hierarchy_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  await fixture.initialize(mockPreferences: false);
  fixture.respond = (request) {
    final parts = request.path.split('/');
    final id = parts.length > 2 ? parts[2] : '';
    const names = {
      'ftc': 'FTC ROBOTS',
      'my-team': 'My Team',
      'team': 'Team',
      'personal': 'Personal',
    };
    if (request.path == '/organizations') {
      return {
        'organizations': [
          {
            'organization_id': 'org',
            'name': 'FTC ROBOTICS 2026',
            'role': 'member',
          },
        ],
      };
    }
    if (request.path == '/inventory-workspaces') {
      return {
        'workspaces': [
          for (final id in names.keys) {'workspace_id': id, 'name': names[id]},
        ],
      };
    }
    if (request.path.endsWith('/overview')) {
      return {
        'workspace': {
          'workspace_id': id,
          'name': names[id],
          'organization_id': id == 'ftc' ? 'org' : null,
          'organization_name': id == 'ftc' ? 'FTC ROBOTICS 2026' : null,
          'role': id == 'ftc' ? 'member' : 'owner',
          'owner_user_id': id == 'ftc' ? 'other' : 'actor-a',
        },
        'members': [
          {'user_id': 'other', 'display_name': 'tantanalt', 'role': 'owner'},
          {
            'user_id': 'actor-a',
            'display_name': 'Tanya',
            'role': id == 'ftc' ? 'member' : 'owner',
          },
        ],
      };
    }
    if (request.path.endsWith('/directory')) {
      return {
        'inventories': [
          {
            'workspace_id': id,
            'inventory_id': 'inventory-$id',
            'name': id == 'ftc'
                ? 'FTC INVENTORY'
                : id == 'personal'
                ? 'Personal inventory'
                : '${names[id]} inventory',
            'can_open': true,
            'can_edit': true,
            'role': 'editor',
            'item_count': id == 'ftc' ? 60 : 0,
          },
        ],
        'next_offset': null,
      };
    }
    if (request.path.endsWith('/audit')) return {'activity': []};
    if (request.path.endsWith('/access-requests')) return {'requests': []};
    if (request.path == '/access-invitations') return {'invitations': []};
    throw StateError('Unsupported isolated preview route');
  };
  final session = PlaceSession(fixture.api, 'actor-a');
  unawaited(session.restore());
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.create(Brightness.light),
      home: WorkspaceHome(
        session: session,
        onOpenInventory: (_, _, _) async {},
      ),
    ),
  );
}
