import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/workspaces/organization_leave.dart';
import 'package:mobile/features/workspaces/hierarchy_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    fixture.requests.clear();
    fixture.status = 200;
    fixture.respond = (_) => {'left': true, 'organization_id': 'org-a'};
  });
  Future<void> open(
    WidgetTester tester, {
    bool owner = false,
    Brightness brightness = Brightness.light,
    ValueChanged<bool>? result,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final left = await confirmOrganizationLeave(
                  context,
                  fixture.api,
                  id: 'org-a',
                  name: 'Acme',
                  isOwner: owner,
                );
                result?.call(left);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('$brightness leave needs confirmation and keeps team content', (
      tester,
    ) async {
      bool? result;
      await open(tester, brightness: brightness, result: (v) => result = v);
      expect(find.textContaining("team's items, photos"), findsOneWidget);
      expect(fixture.requests, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, false);
      expect(fixture.requests, isEmpty);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave organization'));
      await tester.pumpAndSettle();
      expect(result, true);
      expect(fixture.requests.single.method, 'DELETE');
      expect(fixture.requests.single.path, '/organizations/org-a/leave');
      expect(fixture.requests.single.data, {'name': 'Acme'});
    });
  }
  testWidgets('owner must transfer before leaving', (tester) async {
    await open(tester, owner: true);
    expect(
      find.textContaining('Transfer organization ownership'),
      findsOneWidget,
    );
    expect(find.text('Leave organization'), findsNothing);
    expect(fixture.requests, isEmpty);
  });
  testWidgets('wrong receipt stays open and retry can succeed', (tester) async {
    fixture.respond = (_) => {'left': true, 'organization_id': 'wrong'};
    bool? result;
    await open(tester, result: (v) => result = v);
    await tester.tap(find.text('Leave organization'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.textContaining('could not be confirmed'), findsOneWidget);
    fixture.respond = (_) => {'left': true, 'organization_id': 'org-a'};
    await tester.tap(find.text('Leave organization'));
    await tester.pumpAndSettle();
    expect(result, true);
  });
  testWidgets('workspace ownership error is visible without leaving', (
    tester,
  ) async {
    fixture.status = 409;
    fixture.respond = (_) => {
      'detail':
          'Transfer ownership of your workspaces in this organization before leaving.',
    };
    bool? result;
    await open(tester, result: (v) => result = v);
    await tester.tap(find.text('Leave organization'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Transfer ownership of your workspaces'),
      findsOneWidget,
    );
    expect(result, isNull);
  });
  testWidgets('pending leave disables repeat taps and cancellation', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    fixture.respond = (_) => pending.future;
    await open(tester);
    await tester.tap(find.text('Leave organization'));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(fixture.requests.length, 1);
    pending.complete({'left': true, 'organization_id': 'org-a'});
    await tester.pumpAndSettle();
    expect(find.text('Leave Acme?'), findsNothing);
  });
  testWidgets('ordinary member can find Leave in organization menu', (
    tester,
  ) async {
    fixture.respond = (request) => request.path == '/organizations/org-a'
        ? {
            'organization': {
              'organization_id': 'org-a',
              'name': 'Acme',
              'role': 'member',
              'owner_user_id': 'other',
            },
            'workspaces': [],
            'members': [],
          }
        : {};
    await tester.pumpWidget(
      MaterialApp(
        home: HierarchyPage(
          api: fixture.api,
          level: HierarchyLevel.organization,
          id: 'org-a',
          onOpenInventory: (_, _, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Leave organization'), findsOneWidget);
    expect(find.text('Rename'), findsNothing);
    await tester.tap(find.text('Leave organization'));
    await tester.pumpAndSettle();
    expect(find.text('Leave Acme?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
