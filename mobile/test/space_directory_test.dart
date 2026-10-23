import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/inventory_context.dart';
import 'package:mobile/core/place_session.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import 'package:mobile/features/inventory/space_directory.dart';
import 'package:mobile/features/shell/main_shell.dart';
import 'package:mobile/features/world/world_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/hierarchy_fixture.dart';

Future<void> Function(String)? spaceAuditCapture;

void main() {
  final f = HierarchyFixture();
  setUpAll(f.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  late List<Map<String, dynamic>> spaces;
  late String role;
  bool reject = false;
  bool current = true;
  Completer<void>? delayed;
  Map<String, dynamic> detail() =>
      inventory('inv-a', workspace: 'personal', role: role, name: 'Tools');
  Map<String, dynamic> group() => {
    'inventory_id': 'inv-a',
    'workspace_id': 'personal',
    'workspace_name': 'Personal',
    'name': 'Tools',
    'can_edit': role != 'viewer',
    'spaces': spaces,
  };
  setUp(() {
    f.status = 200;
    f.requests.clear();
    role = 'owner';
    reject = false;
    current = true;
    delayed = null;
    spaces = [
      {'id': 'bench', 'name': 'Workbench', 'item_count': 2},
      {'id': 'drawers', 'name': 'Drawers', 'item_count': 1},
    ];
    f.respond = (r) async {
      if (r.path == '/profile/me') {
        return {'user_id': 'actor-a', 'display_name': 'Alex'};
      }
      if (r.path == '/worlds/personal/directory') {
        return {
          'inventories': [group()],
        };
      }
      if (r.path == '/worlds/personal/spaces') {
        return {
          'inventories': [group()],
        };
      }
      if (r.path == '/inventories/inv-a') {
        await delayed?.future;
        return {'inventory': detail()};
      }
      if (r.path == '/inventories/inv-a/spaces') {
        if (r.method == 'POST') {
          spaces.add({'id': 'new', 'name': r.data['name'], 'item_count': 0});
        }
        return {'spaces': spaces, 'space': spaces.last};
      }
      if (r.path == '/inventories/inv-a/spaces/bench') {
        if (reject) {
          f.status = 403;
          return {'detail': 'Access to this Space changed.'};
        }
        spaces.first['name'] = r.data['name'];
        return {'space': spaces.first};
      }
      if (r.path == '/resource-removal/space/bench') {
        if (r.method == 'POST') {
          if (reject) return {'deleted': false};
          spaces.removeAt(0);
          return {
            'id': 'bench',
            'kind': 'space',
            'action': r.data['action'],
            'deleted': true,
          };
        }
        return {
          'id': 'bench',
          'kind': 'space',
          'name': 'Workbench',
          'items': 2,
          'spaces': 0,
          'inventories': 0,
          'workspaces': 0,
          'can_move': true,
          'destinations': [
            {'id': 'drawers', 'name': 'Drawers'},
          ],
        };
      }
      if (r.path.endsWith('/search_items')) return {'items': [], 'parsed': {}};
      return <String, dynamic>{};
    };
  });
  Future<void> mount(
    WidgetTester tester, {
    bool world = true,
    Brightness brightness = Brightness.dark,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = PlaceSession(f.api, 'actor-a')
      ..loading = false
      ..navigationReady = true;
    addTearDown(session.dispose);
    final api = ApiClient.forInventory(
      f.api,
      InventoryContext.fromJson(
        detail(),
        accountId: 'actor-a',
        expectedInventory: 'inv-a',
      ),
      isCurrent: () => current,
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('spaces-audit-frame'),
        child: MaterialApp(
          theme: AppTheme.create(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 44, bottom: 34),
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: world
              ? WorldShell(session: session)
              : InventorySpacesPage(api: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (world) {
      await tester.tap(find.byTooltip('Spaces'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> menu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Options for Workbench'));
    await tester.pumpAndSettle();
  }

  Future<void> delete(WidgetTester tester, {bool move = false}) async {
    await menu(tester);
    await tester.tap(find.text('Delete Space'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(
        move
            ? 'Move items to another Space'
            : 'Delete space and all its contents',
      ),
    );
    await tester.pumpAndSettle();
    if (move) {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drawers').last);
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextFormField), 'Workbench');
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(
      TextButton,
      move ? 'Move and continue' : 'Delete space',
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'Spaces menu is anchored and updates after rename $brightness',
      (tester) async {
        await mount(tester, brightness: brightness);
        await menu(tester);
        expect(find.text('Open Space'), findsOneWidget);
        expect(find.text('Delete Space'), findsOneWidget);
        await spaceAuditCapture?.call('menu-${brightness.name}');
        await tester.tap(find.text('Rename'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Workbench'),
          'Electronics',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('Electronics'), findsOneWidget);
        expect(find.text('Workbench'), findsNothing);
        expect(
          f.requests.where((r) => r.method == 'PATCH').single.path,
          '/inventories/inv-a/spaces/bench',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets('Inventory opens only Spaces and exact item page $brightness', (
      tester,
    ) async {
      await mount(tester, world: false, brightness: brightness);
      expect(find.byType(MainShell), findsNothing);
      expect(find.text('personal / Tools'), findsOneWidget);
      expect(f.requests.any((r) => r.path.endsWith('/search_items')), false);
      await spaceAuditCapture?.call('directory-${brightness.name}');
      await tester.tap(find.text('Workbench'));
      await tester.pumpAndSettle();
      final page = tester.widget<LocationItemsPage>(
        find.byType(LocationItemsPage),
      );
      expect(page.spaceId, 'bench');
      expect(page.api.inventoryContext!.inventoryId, 'inv-a');
      expect(
        f.requests.any((r) => r.path == '/inventories/inv-a/search_items'),
        true,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(InventorySpacesPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final move in [false, true]) {
    testWidgets('Space deletion refreshes directory, move=$move', (
      tester,
    ) async {
      await mount(tester);
      await delete(tester, move: move);
      final request = f.requests
          .where(
            (r) =>
                r.path == '/resource-removal/space/bench' && r.method == 'POST',
          )
          .single;
      expect(request.data, {
        'name': 'Workbench',
        'action': move ? 'move' : 'delete',
        if (move) 'destination_id': 'drawers',
      });
      expect(find.text('Workbench'), findsNothing);
      expect(find.text('Drawers'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Cancelled removal sends no write', (tester) async {
    await mount(tester);
    await menu(tester);
    await tester.tap(find.text('Delete Space'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(f.requests.where((r) => r.method == 'POST'), isEmpty);
    expect(find.text('Workbench'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Unconfirmed deletion keeps Space and explicit retry error', (
    tester,
  ) async {
    reject = true;
    await mount(tester);
    await delete(tester);
    expect(
      find.text('The change could not be confirmed. Refresh before retrying.'),
      findsOneWidget,
    );
    expect(spaces.length, 2);
    await tester.pumpWidget(const SizedBox());
  });
  for (final value in ['editor', 'viewer']) {
    testWidgets('$value menu follows current inventory permissions', (
      tester,
    ) async {
      role = value;
      await mount(tester);
      await menu(tester);
      expect(find.text('Open Space'), findsOneWidget);
      expect(
        find.text('Rename'),
        value == 'editor' ? findsOneWidget : findsNothing,
      );
      expect(find.text('Delete Space'), findsNothing);
      expect(f.requests.where((r) => r.method != 'GET'), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Revoked context after menu opens sends no write', (
    tester,
  ) async {
    await mount(tester, world: false);
    await menu(tester);
    current = false;
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(find.text('Rename Space'), findsNothing);
    expect(f.requests.where((r) => r.method != 'GET'), isEmpty);
    expect(
      find.text(
        'The account or inventory changed. Reopen this page and try again.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Rename rejection preserves Space and shows server error', (
    tester,
  ) async {
    await mount(tester);
    await menu(tester);
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Workbench'),
      'Electronics',
    );
    reject = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Access to this Space changed.'), findsOneWidget);
    expect(find.text('Workbench'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('New Space stays in the selected inventory', (tester) async {
    await mount(tester, world: false);
    await tester.tap(find.text('New Space'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Space name'),
      'Parts bins',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Parts bins'), findsOneWidget);
    final request = f.requests.where((r) => r.method == 'POST').single;
    expect(request.path, '/inventories/inv-a/spaces');
    expect(request.data, {'name': 'Parts bins'});
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('World New space creates in chosen inventory and refreshes', (
    tester,
  ) async {
    await mount(tester);
    expect(find.byTooltip('Account'), findsNothing);
    expect(find.text('Search Spaces'), findsNothing);
    final button = find.text('New space');
    expect(button.hitTestable(), findsOneWidget);
    expect(
      tester.getBottomLeft(button).dy,
      lessThan(tester.getTopLeft(find.byTooltip('Spaces')).dy),
    );
    await spaceAuditCapture?.call('world-new-space');
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tools').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Garage');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Garage'), findsOneWidget);
    expect(
      f.requests
          .where(
            (r) => r.method == 'POST' && r.path == '/inventories/inv-a/spaces',
          )
          .length,
      1,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('World viewer does not see creation action', (tester) async {
    role = 'viewer';
    await mount(tester);
    expect(find.text('New space'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Large type menu and directory remain usable', (tester) async {
    await mount(tester, world: false, scale: 2);
    await menu(tester);
    expect(find.text('Delete Space').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await spaceAuditCapture?.call('large-type');
    await tester.pumpWidget(const SizedBox());
  });
}
