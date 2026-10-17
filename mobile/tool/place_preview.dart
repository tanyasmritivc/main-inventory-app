// Network-free simulator fixture. Never used by lib/main.dart.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/place_session.dart';
import 'package:mobile/core/last_place.dart';
import 'package:mobile/features/workspaces/workspace_home.dart';
import '../test/support/hierarchy_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  await fixture.initialize(mockPreferences: false);
  var workspacePresent = true, emptyOrganizationPresent = true;
  final names = <String, String>{
    'hardware': 'Hardware Team',
    'mentors': 'Mentors',
    'outreach': 'Outreach',
    'parents': 'Parents',
    'software': 'Software Team',
  };
  fixture.respond = (request) {
    fixture.status = 200;
    final id = request.path.split('/').length > 2
        ? request.path.split('/')[2]
        : '';
    if (request.path == '/notifications') {
      return {'notifications': [], 'unread_count': 0};
    }
    if (request.path == '/organizations') {
      return {
        'organizations': [
          {'organization_id': 'org', 'name': 'FindEZ Studio', 'role': 'owner'},
          if (emptyOrganizationPresent)
            {
              'organization_id': 'empty',
              'name': 'Demo organization',
              'role': 'owner',
            },
        ],
      };
    }
    if (request.path == '/inventory-workspaces') {
      return {
        'workspaces': [
          if (workspacePresent)
            {'workspace_id': 'ftc', 'name': 'FTC Season 2026-2027'},
        ],
      };
    }
    if (request.path.startsWith('/organizations/') &&
        request.method == 'DELETE') {
      if (id == 'org' && workspacePresent) {
        fixture.status = 409;
        return {
          'detail': 'Only organizations with no workspaces can be deleted.',
        };
      }
      emptyOrganizationPresent = false;
      return {'deleted': true, 'organization_id': id};
    }
    if (request.path == '/organizations/org' ||
        request.path == '/organizations/empty') {
      return {
        'organization': {
          'organization_id': id,
          'name': id == 'org' ? 'FindEZ Studio' : 'Demo organization',
          'role': 'owner',
          'owner_user_id': 'actor-a',
        },
        'workspaces': [
          if (id == 'org' && workspacePresent)
            {'team_id': 'ftc', 'name': 'FTC Season 2026-2027'},
        ],
        'members': [
          {'user_id': 'actor-a', 'display_name': 'Demo user', 'role': 'owner'},
        ],
        'attachable': [],
      };
    }
    if (request.path == '/teams/ftc' && request.method == 'DELETE') {
      workspacePresent = false;
      return {'deleted': true};
    }
    if (request.path.startsWith('/inventories/') &&
        request.method == 'DELETE') {
      if (id == 'hardware' &&
          (request.data as Map)['delete_contents'] != true) {
        fixture.status = 409;
        return {
          'detail':
              'This inventory contains saved records. Select the contents option to remove them.',
        };
      }
      names.remove(id);
      return {'deleted': true, 'inventory_id': id};
    }
    if (request.path.endsWith('/overview')) {
      return {
        'workspace': {
          'workspace_id': id,
          'name': 'FTC Season 2026-2027',
          'organization_id': 'org',
          'organization_name': 'FindEZ Studio',
          'role': 'owner',
          'owner_user_id': 'actor-a',
        },
        'members': [],
      };
    }
    if (request.path.endsWith('/directory')) {
      return {
        'inventories': [
          if (id == 'ftc' || !workspacePresent)
            for (final entry in names.entries)
              {
                'workspace_id': id,
                'inventory_id': entry.key,
                'name': entry.value,
                'can_open': true,
                'can_edit': true,
                'can_rename': true,
                'can_manage': true,
                'role': 'owner',
                'item_count': entry.key == 'hardware' ? 12 : 0,
              },
          if (id == 'personal' && workspacePresent)
            {
              'workspace_id': id,
              'inventory_id': 'private',
              'name': 'My inventory',
              'can_open': true,
              'can_edit': true,
              'can_rename': true,
              'can_manage': true,
              'role': 'owner',
              'item_count': 0,
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
  unawaited(session.restore(override: const LastPlace.workspace('ftc')));
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
