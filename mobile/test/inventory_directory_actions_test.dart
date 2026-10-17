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

  testWidgets(
    'empty inventory deletion needs name confirmation and refreshes after receipt',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Delete inventory'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Delete inventory'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextFormField), 'Hardware');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete inventory'));
      await tester.pumpAndSettle();
      expect(fixture.requests.single.method, 'DELETE');
      expect(fixture.requests.single.path, '/inventories/hardware');
      expect(fixture.requests.single.data, {'name': 'Hardware'});
      expect(refreshed, 1);
    },
  );
  testWidgets('nonempty error never refreshes as a success', (tester) async {
    fixture.status = 409;
    fixture.respond = (_) => {
      'detail': 'This inventory contains saved records.',
    };
    await mount(tester);
    await tester.tap(find.text('Delete inventory'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Hardware');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Delete inventory'));
    await tester.pumpAndSettle();
    expect(find.textContaining('contains saved records'), findsOneWidget);
    expect(refreshed, 0);
  });
  testWidgets('rename permission alone has no deletion option', (tester) async {
    await mount(tester, manager: false);
    expect(find.text('Rename inventory'), findsOneWidget);
    expect(find.text('Delete inventory'), findsNothing);
    expect(fixture.requests, isEmpty);
  });
  testWidgets(
    'content blocker keeps the name and permits explicit purge without restarting',
    (tester) async {
      fixture.status = 409;
      fixture.respond = (_) => {
        'detail': 'This inventory contains saved records.',
      };
      await mount(tester);
      await tester.tap(find.text('Delete inventory'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Hardware');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete inventory'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Hardware',
      );
      expect(refreshed, 0);
      fixture.status = 200;
      fixture.respond = (_) => {'deleted': true, 'inventory_id': 'hardware'};
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete inventory'));
      await tester.pumpAndSettle();
      expect(fixture.requests.last.data, {
        'name': 'Hardware',
        'delete_contents': true,
      });
      expect(refreshed, 1);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  for (final status in [501, 502]) {
    testWidgets(
      '$status keeps deletion choices and never reports success or retries',
      (tester) async {
        fixture.status = status;
        fixture.respond = (_) => {
          'detail': 'Could not confirm deletion. Refresh before retrying.',
        };
        await mount(tester);
        await tester.tap(find.text('Delete inventory'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), 'Hardware');
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        await tester.tap(find.widgetWithText(TextButton, 'Delete inventory'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Hardware',
        );
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          true,
        );
        expect(fixture.requests, hasLength(1));
        expect(refreshed, 0);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  }
  testWidgets(
    'content deletion is explicitly selected and sent with confirmation',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Delete inventory'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), 'Hardware');
      await tester.pump();
      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Delete inventory'),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Delete inventory'));
      await tester.pumpAndSettle();
      expect(fixture.requests.single.data, {
        'name': 'Hardware',
        'delete_contents': true,
      });
      expect(refreshed, 1);
    },
  );
}
