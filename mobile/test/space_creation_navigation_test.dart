import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/inventory_cache.dart';
import 'package:mobile/core/inventory_context.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  var created = false;
  setUp(() {
    InventoryCache.clear();
    fixture.requests.clear();
    fixture.status = 200;
    created = false;
    fixture.respond = (r) {
      if (r.path.endsWith('/spaces')) {
        if (r.method == 'POST') {
          expect(r.data, {'name': 'Workshop'});
          created = true;
          return {
            'space': {'id': 'new-room', 'name': 'Workshop'},
          };
        }
        return {
          'spaces': [
            if (created)
              {'id': 'new-room', 'name': 'Workshop', 'item_count': 0},
          ],
        };
      }
      if (r.path.endsWith('/search_items')) return {'items': [], 'parsed': {}};
      if (r.path.endsWith('/sharing/my-shares') ||
          r.path.endsWith('/sharing/joined')) {
        return <Object>[];
      }
      return <String, dynamic>{};
    };
  });
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 3)),
      );
    }
  }

  Future<void> mount(
    WidgetTester tester, {
    String workspace = 'personal',
    bool edit = true,
  }) async {
    final api = ApiClient.forInventory(
      fixture.api,
      InventoryContext.fromJson(
        inventory(
          'inventory-a',
          workspace: workspace,
          role: edit ? 'editor' : 'viewer',
        ),
        accountId: 'actor-a',
        expectedInventory: 'inventory-a',
      ),
      isCurrent: () => true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(Brightness.light),
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => InventoryPage(api: api, refreshToken: 0),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> dialog(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('New Space'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('New Space'));
    await settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Workshop',
    );
  }

  for (final workspace in ['personal', 'workspace-a']) {
    testWidgets(
      '$workspace creates a Space without popping the inventory navigator',
      (tester) async {
        await mount(tester, workspace: workspace);
        await dialog(tester);
        await tester.tap(find.widgetWithText(TextButton, 'Create'));
        await settle(tester);
        expect(created, isTrue);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(LocationItemsPage), findsOneWidget);
        expect(
          tester
              .widget<LocationItemsPage>(find.byType(LocationItemsPage))
              .spaceId,
          'new-room',
        );
        expect(
          fixture.requests
              .where((r) => r.method == 'POST' && r.path.endsWith('/spaces'))
              .single
              .path,
          '/inventories/inventory-a/spaces',
        );
        await tester.pageBack();
        await settle(tester);
        expect(find.byType(InventoryPage), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('Cancel leaves the inventory mounted and makes no write', (
    tester,
  ) async {
    await mount(tester);
    await dialog(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(InventoryPage), findsOneWidget);
    expect(created, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('viewer cannot create a Space', (tester) async {
    await mount(tester, edit: false);
    expect(find.text('New Space'), findsNothing);
    expect(created, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
