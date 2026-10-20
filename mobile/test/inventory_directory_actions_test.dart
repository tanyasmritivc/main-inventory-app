import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/workspaces/inventory_actions.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  var refreshed = 0;
  setUp(() {
    fixture.requests.clear();
    fixture.status = 200;
    refreshed = 0;
    fixture.respond = (r) => {'deleted': true, 'inventory_id': 'hardware'};
  });
  Future<void> mount(WidgetTester tester, {bool manager = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => manageDirectoryInventory(
                context,
                fixture.api,
                {
                  'inventory_id': 'hardware',
                  'name': 'Hardware',
                  'can_manage': manager,
                  'can_rename': true,
                },
                () async {
                  refreshed++;
                },
              ),
              child: const Text('Manage'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
  }

  testWidgets('rename permission alone has no deletion option', (tester) async {
    await mount(tester, manager: false);
    expect(find.text('Rename inventory'), findsOneWidget);
    expect(find.text('Delete inventory'), findsNothing);
    expect(fixture.requests, isEmpty);
  });
  testWidgets('directory delete opens explicit move-or-delete choices', (
    tester,
  ) async {
    fixture.respond = (_) => {
      'kind': 'inventory',
      'id': 'hardware',
      'name': 'Hardware',
      'items': 9,
      'spaces': 2,
      'inventories': 1,
      'workspaces': 0,
      'can_move': true,
      'destinations': [],
    };
    await mount(tester);
    await tester.tap(find.text('Delete inventory'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Move this inventory'), findsOneWidget);
    expect(find.text('Delete inventory and all its contents'), findsOneWidget);
    expect(fixture.requests.single.method, 'GET');
    expect(refreshed, 0);
  });
}
