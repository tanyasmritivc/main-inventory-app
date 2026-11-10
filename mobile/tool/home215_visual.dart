// Synthetic visual check only. Release builds always use lib/main.dart.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/place_session.dart';
import 'package:mobile/features/world/world_shell.dart';
import '../test/support/hierarchy_fixture.dart';
import '../test/support/announcement_fixture.dart';
import 'package:mobile/features/announcements/announcement_controller.dart';
import 'package:mobile/features/announcements/announcement_host.dart';

Future<void> main() async {
  if (kReleaseMode) throw UnsupportedError('Debug audit only');
  WidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  await fixture.initialize();
  var unread = true;
  var accepted = false;
  fixture.respond = (r) {
    if (r.path.startsWith('/announcements/')) return announcementAccess;
    if (r.path == '/organizations') {
      return {
        'organizations': [
          {'organization_id': 'studio', 'name': 'Design Studio'},
          {'organization_id': 'workshop', 'name': 'Workshop'},
        ],
      };
    }
    if (r.path.startsWith('/access-invitations/')) {
      if (r.path.endsWith('/decision')) accepted = true;
      return {
        'invitation': {
          'invitation_id': 'demo-invite',
          'scope': 'organization',
          'resource_id': 'studio',
          'organization_id': 'studio',
          'name': 'Design Studio',
          'role': 'admin',
          'status': accepted ? 'accepted' : 'pending',
          'invited_by_name': 'Alex Example',
          'expires_at': '2099-01-01T00:00:00Z',
        },
      };
    }

    if (r.path.endsWith('/profile/me')) return {'display_name': 'Alex Example'};
    if (r.path.endsWith('/directory')) {
      return {'has_items': true, 'inventories': []};
    }
    if (r.path.endsWith('/spaces')) return {'inventories': []};
    if (r.path.endsWith('/notifications/read')) {
      unread = false;
      return {'ok': true};
    }
    if (r.path.endsWith('/notifications')) {
      return {
        'unread_count': unread ? 1 : 0,
        'notifications': [
          {
            'id': '10000000-0000-0000-0000-000000000001',
            'action': 'access_invitation',
            'invitation': {'invitation_id': 'demo-invite', 'status': 'pending'},
            'display_text': 'Alex invited you to Design Studio.',
            'created_at': '2026-11-09T20:00:00Z',
            'is_read': !unread,
          },
        ],
      };
    }
    if (r.path.endsWith('/conversations')) {
      return [
        {'id': 'sample', 'title': 'Workshop tools'},
      ];
    }
    if (r.path.endsWith('/conversations/sample')) {
      return {
        'conversation': {'id': 'sample', 'title': 'Workshop tools'},
        'messages': [
          {'id': 'q1', 'role': 'user', 'content': 'Where is my drill?'},
          {
            'id': 'a1',
            'role': 'assistant',
            'content': 'On the workshop shelf.',
          },
        ],
      };
    }
    return <String, dynamic>{};
  };
  final session = PlaceSession(fixture.api, 'actor-a')
    ..loading = false
    ..navigationReady = true;
  runApp(
    MaterialApp(
      theme: AppTheme.create(Brightness.light),
      darkTheme: AppTheme.create(Brightness.dark),
      themeMode: ThemeMode.system,
      navigatorObservers: [announcementRoutes],
      home: AnnouncementScope(
        controller: AnnouncementController(
          api: fixture.api,
          accountId: 'actor-a',
          isCurrent: () => true,
          platform: 'ios',
          welcomeAfterSignIn: true,
        ),
        child: WorldShell(session: session),
      ),
    ),
  );
}
