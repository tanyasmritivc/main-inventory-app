import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/place_session.dart';
import 'package:mobile/core/last_place.dart';
import 'package:mobile/features/workspaces/workspace_home.dart';
import 'package:mobile/features/workspaces/hierarchy_page.dart';
import 'package:mobile/features/workspaces/place_ui.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  late PlaceSession session;
  var hasWorkspace = true, role = 'owner', failOrganization = false;
  final opens = <String>[];
  Map<String, dynamic> workspace() => {
    'workspace_id': 'ws',
    'team_id': 'ws',
    'name': 'Client project',
    'organization_id': 'org',
    'organization_name': 'Acme',
    'role': role,
    'owner_user_id': role == 'owner' ? 'actor-a' : 'other',
  };
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fixture.requests.clear();
    fixture.status = 200;
    hasWorkspace = true;
    role = 'owner';
    failOrganization = false;
    opens.clear();
    fixture.respond = (r) {
      fixture.status = 200;
      if (r.path == '/organizations') {
        return {
          'organizations': [
            {'organization_id': 'org', 'name': 'Acme', 'role': role},
          ],
        };
      }
      if (r.path == '/organizations/org/workspaces' && r.method == 'POST') {
        expect(r.data, {'name': 'Client project'});
        hasWorkspace = true;
        return {'workspace': workspace()};
      }
      if (r.path == '/organizations/org') {
        if (failOrganization) {
          fixture.status = 503;
          return {'detail': 'Please try again.'};
        }
        return {
          'organization': {
            'organization_id': 'org',
            'name': 'Acme',
            'role': role,
            'owner_user_id': role == 'owner' ? 'actor-a' : 'other',
          },
          'workspaces': [if (hasWorkspace) workspace()],
          'members': [
            {'user_id': 'actor-a', 'display_name': 'Tanya', 'role': role},
          ],
          'attachable': [],
        };
      }
      if (r.path == '/inventory-workspaces') {
        return {
          'workspaces': [if (hasWorkspace) workspace()],
        };
      }
      if (r.path.endsWith('/overview')) {
        return {
          'workspace': workspace(),
          'members': [
            {'user_id': 'actor-a', 'display_name': 'Tanya', 'role': role},
          ],
        };
      }
      if (r.path.endsWith('/directory')) {
        final id = r.path.split('/')[2];
        return {
          'inventories': [
            {
              'inventory_id': 'inv-$id',
              'workspace_id': id,
              'name': '$id inventory',
              'can_open': true,
              'can_edit': role != 'viewer',
              'item_count': 0,
              'role': role,
            },
          ],
          'next_offset': null,
        };
      }
      if (r.path == '/teams') {
        return {
          'teams': [workspace()],
        };
      }
      if (r.path == '/teams/ws/board') return {'tasks': [], 'role': role};
      if (r.path == '/teams/ws/members') return {'members': []};
      if (r.path == '/teams/ws/documents') {
        return {'documents': [], 'role': role};
      }
      if (r.path.endsWith('/audit')) return {'activity': []};
      if (r.path.endsWith('/access-requests')) return {'requests': []};
      if (r.path == '/access-invitations') return {'invitations': []};
      throw StateError('Unexpected route: ${r.method} ${r.path}');
    };
    session = PlaceSession(fixture.api, 'actor-a');
  });
  tearDown(() => session.dispose());
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 18; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 3)),
      );
    }
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.runAsync(session.restore);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(Brightness.light),
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => WorkspaceHome(
              session: session,
              onOpenInventory: (id, ws, org) async => opens.add('$org/$ws/$id'),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> organization(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Switch place. Current: Personal'));
    await settle(tester);
    await tester.tap(find.text('ACME'));
    await settle(tester);
    expect(find.byType(PlaceSwitcher), findsNothing);
    if (!failOrganization) {
      expect(find.text('WORKSPACES'), findsOneWidget);
      expect(find.byType(PlaceCardList), findsNWidgets(2));
    }
  }

  testWidgets(
    'organization selection returns to the same workspace home, then all tools and inventory use that context',
    (tester) async {
      await mount(tester);
      await organization(tester);
      await tester.tap(find.text('Client project'));
      await settle(tester);
      expect(find.byType(HierarchyPage), findsNothing);
      expect(session.current, const LastPlace.workspace('ws'));
      expect(await session.store.read(), const LastPlace.workspace('ws'));
      for (final tool in ['Tasks', 'Files', 'People', 'Activity']) {
        await tester.tap(find.text(tool));
        await settle(tester);
        expect(find.text('Retry'), findsNothing);
        if (tool == 'Tasks') expect(find.text('No open tasks'), findsOneWidget);
        if (tool == 'Files') expect(find.text('No files yet'), findsOneWidget);
        await tester.pageBack();
        await settle(tester);
        expect(session.current.id, 'ws');
      }
      await tester.tap(find.byTooltip('Search'));
      await settle(tester);
      expect(find.text('INVENTORIES'), findsOneWidget);
      expect(find.text('Tasks'), findsNothing);
      expect(find.text('Tanya'), findsNothing);
      await tester.enterText(find.byType(TextField), 'missing inventory');
      await settle(tester);
      expect(find.text('No matching inventories'), findsOneWidget);
      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(opens, ['org/ws/inv-ws']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'empty organization can create and open its workspace without returning to an old dashboard',
    (tester) async {
      hasWorkspace = false;
      await mount(tester);
      await organization(tester);
      expect(find.text('No assigned workspaces yet'), findsOneWidget);
      await tester.tap(find.text('New workspace'));
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Client project',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Continue'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Client project'), findsOneWidget);
      await tester.tap(find.text('Client project'));
      await settle(tester);
      expect(find.byType(HierarchyPage), findsNothing);
      expect(session.current.id, 'ws');
      expect(
        fixture.requests.where((r) => r.method == 'POST').single.path,
        '/organizations/org/workspaces',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'organization failure and Retry do not switch the current place',
    (tester) async {
      await mount(tester);
      failOrganization = true;
      await organization(tester);
      expect(find.text('Retry'), findsOneWidget);
      expect(session.current.isPersonal, true);
      failOrganization = false;
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text('Client project'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      await tester.pageBack();
      await settle(tester);
      expect(session.current.isPersonal, true);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'organization viewer has no management writes and large text stays usable',
    (tester) async {
      role = 'viewer';
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(3.2)),
            child: child!,
          ),
          home: HierarchyPage(
            api: fixture.api,
            onOpenInventory: (_, _, _) async {},
            level: HierarchyLevel.organization,
            id: 'org',
          ),
        ),
      );
      await settle(tester);
      expect(find.text('New workspace'), findsNothing);
      expect(find.text('Invite organization member'), findsNothing);
      expect(find.byTooltip('Actions'), findsNothing);
      expect(find.text('Viewer'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(fixture.requests.where((r) => r.method != 'GET'), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
