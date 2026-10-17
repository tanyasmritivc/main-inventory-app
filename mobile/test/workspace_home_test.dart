import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/last_place.dart';
import 'package:mobile/core/place_session.dart';
import 'package:mobile/features/workspaces/workspace_home.dart';
import 'package:mobile/features/workspaces/hierarchy_page.dart';
import 'package:mobile/features/workspaces/place_ui.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  late PlaceSession session;
  var count = 1, canOpen = true;
  final opened = <String>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fixture.status = 200;
    count = 1;
    canOpen = true;
    opened.clear();
    fixture.respond = (r) {
      final id = r.path.split('/').length > 2 ? r.path.split('/')[2] : '';
      if (r.path == '/organizations') {
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
      if (r.path == '/inventory-workspaces') {
        return {
          'workspaces': [
            {'workspace_id': 'ftc'},
            {'workspace_id': 'standalone'},
          ],
        };
      }
      if (r.path.endsWith('/overview')) {
        return {
          'workspace': {
            'workspace_id': id,
            'name': id == 'ftc' ? 'FTC ROBOTS' : 'My Team',
            'organization_id': id == 'ftc' ? 'org' : null,
            'organization_name': id == 'ftc' ? 'FTC ROBOTICS 2026' : null,
            'role': 'member',
            'owner_user_id': 'owner',
          },
          'members': [
            {'user_id': 'owner', 'display_name': 'Owner', 'role': 'owner'},
            {'user_id': 'actor-a', 'display_name': 'Tanya', 'role': 'member'},
          ],
        };
      }
      if (r.path.endsWith('/inventories') && r.method == 'POST') {
        count++;
        return {
          'inventory': {'inventory_id': 'inv-${count - 1}'},
        };
      }
      if (r.path.endsWith('/directory')) {
        return {
          'inventories': [
            for (var i = 0; i < count; i++)
              {
                'inventory_id': 'inv-$i',
                'workspace_id': id,
                'name': 'Inventory $i',
                'can_open': canOpen,
                'can_edit': false,
                'role': 'viewer',
                'item_count': canOpen ? 60 : null,
              },
          ],
          'next_offset': null,
        };
      }
      if (r.path.endsWith('/audit')) return {'activity': []};
      if (r.path.endsWith('/access-requests')) return {'requests': []};
      throw StateError(r.path);
    };
    session = PlaceSession(fixture.api, 'actor-a');
  });
  tearDown(() => session.dispose());
  Future<void> open(String id, String workspace, String? org) async {
    opened.add('$org/$workspace/$id');
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
  }

  Future<void> pump(WidgetTester tester, {double scale = 1}) async {
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
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: WorkspaceHome(session: session, onOpenInventory: open),
      ),
    );
    await settle(tester);
  }

  testWidgets(
    'workspace home has correct role, count and inventory destination',
    (tester) async {
      await tester.runAsync(
        () => session.select(const LastPlace.workspace('ftc')),
      );
      await pump(tester);
      expect(find.text('FTC ROBOTICS 2026'), findsOneWidget);
      expect(find.text('60 items · Viewer'), findsOneWidget);
      expect(find.text('New inventory'), findsNothing);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('People'), findsOneWidget);
      expect(find.byTooltip('Refresh'), findsNothing);
      await tester.tap(find.text('Inventory 0'));
      expect(opened, ['org/ftc/inv-0']);
    },
  );
  testWidgets(
    'create remains visible after the first inventory and refreshes the selected workspace',
    (tester) async {
      await tester.runAsync(session.restore);
      await pump(tester);
      expect(find.text('Inventory 0'), findsOneWidget);
      await tester.tap(find.text('New inventory'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Materials');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Create'));
      await settle(tester);
      expect(
        fixture.requests.where((r) => r.method == 'POST').last.path,
        '/inventory-workspaces/personal/inventories',
      );
      expect(find.text('Inventory 1'), findsOneWidget);
      expect(find.text('New inventory'), findsOneWidget);
      expect(opened, isEmpty);
    },
  );
  testWidgets('Personal contains inventories and no workspace tools', (
    tester,
  ) async {
    await tester.runAsync(session.restore);
    await pump(tester);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Tasks'), findsNothing);
    expect(find.text('People'), findsNothing);
  });
  testWidgets(
    'switcher groups real parents once and a tap persists the place',
    (tester) async {
      await tester.runAsync(
        () => session.select(const LastPlace.workspace('ftc')),
      );
      await pump(tester);
      await tester.tap(
        find.bySemanticsLabel(
          'Switch place. Current: FTC ROBOTS in FTC ROBOTICS 2026',
        ),
      );
      await settle(tester);
      expect(find.text('FTC ROBOTS'), findsNWidgets(2));
      expect(find.text('My Team'), findsOneWidget);
      expect(find.text('Editor · 1 inventory'), findsOneWidget);
      await tester.tap(find.text('Personal'));
      await settle(tester);
      expect(session.current.isPersonal, true);
      expect(
        await tester.runAsync(session.store.read),
        const LastPlace.personal(),
      );
    },
  );
  testWidgets('multiple inventories show list; missing counts stay hidden', (
    tester,
  ) async {
    count = 2;
    canOpen = false;
    await tester.runAsync(session.restore);
    await pump(tester);
    expect(find.text('Inventories'), findsOneWidget);
    expect(find.text('Access restricted'), findsNWidgets(2));
    expect(find.text('items'), findsNothing);
    expect(find.text('0'), findsNothing);
  });
  testWidgets('home and switcher grow at largest text scale without overflow', (
    tester,
  ) async {
    await tester.runAsync(
      () => session.select(const LastPlace.workspace('ftc')),
    );
    await pump(tester, scale: 3.2);
    expect(tester.takeException(), null);
    await tester.tap(
      find.bySemanticsLabel(
        'Switch place. Current: FTC ROBOTS in FTC ROBOTICS 2026',
      ),
    );
    await settle(tester);
    expect(tester.takeException(), null);
  });
  testWidgets(
    'Leave is on People, uses existing confirmation and does not write on cancel',
    (tester) async {
      await tester.runAsync(
        () => session.select(const LastPlace.workspace('ftc')),
      );
      await pump(tester);
      await tester.tap(find.text('People'));
      await settle(tester);
      expect(find.byType(PlaceAvatar), findsNWidgets(2));
      expect(find.text('Leave workspace'), findsOneWidget);
      await tester.tap(find.text('Leave workspace'));
      await settle(tester);
      expect(find.text('Leave workspace?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(fixture.requests.any((r) => r.path.endsWith('/leave')), false);
      expect(find.byType(HierarchyPage), findsOneWidget);
    },
  );
  testWidgets(
    'owner deletes from workspace menu and returns to Personal with no stale context',
    (tester) async {
      final original = fixture.respond;
      fixture.respond = (r) async {
        if (r.path == '/teams/ftc' && r.method == 'DELETE') {
          return {'deleted': true};
        }
        final result = await original(r) as Map<String, dynamic>;
        if (r.path == '/inventory-workspaces/ftc/overview') {
          result['workspace'] = Map<String,dynamic>.from(result['workspace'] as Map)..addAll({'role':'owner','owner_user_id':'actor-a'});
        }
        return result;
      };
      await tester.runAsync(
        () => session.select(const LastPlace.workspace('ftc')),
      );
      await pump(tester);
      expect(session.error, isNull);
      expect(session.data?.resource['owner_user_id'], 'actor-a');
      await tester.scrollUntilVisible(find.byTooltip('Manage workspace'), 120, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byTooltip('Manage workspace'));
      await settle(tester);
      await tester.tap(find.text('Delete workspace'));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField), 'FTC ROBOTS');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete workspace'));
      await settle(tester);
      expect(
        fixture.requests.where((r) => r.method == 'DELETE').single.path,
        '/teams/ftc',
      );
      expect(session.current.isPersonal, true);
      expect((await session.store.read()).isPersonal, true);
      expect(opened, isEmpty);
    },
  );

  testWidgets('workspace member has no deletion menu', (tester) async {
    await tester.runAsync(
      () => session.select(const LastPlace.workspace('ftc')),
    );
    await pump(tester);
    expect(find.byTooltip('Manage workspace'), findsNothing);
    expect(find.text('Delete workspace'), findsNothing);
  });
}
