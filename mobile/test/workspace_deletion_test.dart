import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/workspaces/workspace_actions.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  bool? deleted;
  setUp(() {
    fixture.requests.clear();
    fixture.status = 200;
    deleted = null;
    fixture.respond = (_) => {'deleted': true};
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                deleted = await confirmWorkspaceDeletion(
                  context,
                  fixture.api,
                  id: 'ftc',
                  name: 'FTC ROBOTS',
                );
              },
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
    'exact name confirms owner endpoint and physical retention warning',
    (tester) async {
      await mount(tester);
      expect(
        find.textContaining('Physical inventories are retained'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Delete workspace'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextFormField), 'FTC ROBOTS');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete workspace'));
      await tester.pumpAndSettle();
      expect(fixture.requests.single.path, '/teams/ftc');
      expect(fixture.requests.single.method, 'DELETE');
      expect(deleted, true);
    },
  );
  testWidgets(
    'cancel never deletes and false receipt remains in confirmation',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fixture.requests, isEmpty);
      expect(deleted, false);
      fixture.respond = (_) => {'deleted': false};
      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'FTC ROBOTS');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete workspace'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(deleted, false);
    },
  );
  testWidgets('revoked access error keeps dialog available for Cancel', (
    tester,
  ) async {
    fixture.status = 403;
    fixture.respond = (_) => {
      'detail': 'Only the team owner can delete this team.',
    };
    await mount(tester);
    await tester.enterText(find.byType(TextFormField), 'FTC ROBOTS');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Delete workspace'));
    await tester.pumpAndSettle();
    expect(deleted, isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deleted, false);
  });
}
