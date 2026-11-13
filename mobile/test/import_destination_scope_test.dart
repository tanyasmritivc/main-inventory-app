import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/scan/connector_destination_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  Map<String, dynamic> row(String id, {bool editable = true}) => {
    'inventory_id': id,
    'name': id,
    'workspace_name': 'Workspace',
    'can_edit': editable,
  };
  Widget page(ApiClient api) => MaterialApp(
    theme: AppTheme.create(Brightness.light),
    home: ConnectorDestinationPage(api: api),
  );
  setUp(() {
    fixture.requests.clear();
    fixture.status = 200;
  });
  for (final world in ['org-a', 'org-b', 'personal']) {
    testWidgets(
      'import picker reads only $world directory and saves within that scope',
      (tester) async {
        fixture.respond = (request) {
          if (request.path == '/worlds/$world/directory') {
            return {
              'world': world,
              'inventories': [row('chosen'), row('read-only', editable: false)],
            };
          }
          if (request.path == '/inventories/chosen') {
            return {
              'inventory': inventory(
                'chosen',
                workspace: world == 'personal' ? 'personal' : 'team',
                organization: world,
              ),
            };
          }
          if (request.path == '/inventories/chosen/spaces') {
            return {
              'spaces': [
                {'id': 'space', 'name': 'Scoped shelf'},
              ],
            };
          }
          throw StateError('Unexpected endpoint ${request.path}');
        };
        final api = ApiClient.forWorld(
          fixture.api,
          world,
          isCurrent: () => true,
        );
        await tester.pumpWidget(page(api));
        await tester.pumpAndSettle();
        expect(find.text('chosen'), findsOneWidget);
        expect(find.text('read-only'), findsNothing);
        expect(fixture.requests.single.path, '/worlds/$world/directory');
        await tester.tap(find.text('chosen'));
        await tester.pumpAndSettle();
        expect(find.text('Scoped shelf'), findsOneWidget);
        expect(
          fixture.requests.where(
            (r) => r.path.contains('inventory-workspaces'),
          ),
          isEmpty,
        );
      },
    );
  }
  testWidgets(
    'rejects a selected inventory that now belongs to another organization',
    (tester) async {
      fixture.respond = (r) => r.path.endsWith('/directory')
          ? {
              'world': 'org-a',
              'inventories': [row('moved')],
            }
          : {'inventory': inventory('moved', organization: 'org-b')};
      await tester.pumpWidget(
        page(ApiClient.forWorld(fixture.api, 'org-a', isCurrent: () => true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('moved'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Choose an editable inventory'),
        findsOneWidget,
      );
      expect(fixture.requests.any((r) => r.path.endsWith('/spaces')), isFalse);
    },
  );
  testWidgets('wrong-world directory fails closed', (tester) async {
    fixture.respond = (_) => {
      'world': 'personal',
      'inventories': [row('Other inventory')],
    };
    await tester.pumpWidget(
      page(ApiClient.forWorld(fixture.api, 'org-a', isCurrent: () => true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Other inventory'), findsNothing);
    expect(
      find.textContaining('organization could not be verified'),
      findsOneWidget,
    );
  });
  testWidgets('switching organizations discards slow previous results', (
    tester,
  ) async {
    final old = Completer<Object?>();
    fixture.respond = (r) => r.path == '/worlds/org-a/directory'
        ? old.future
        : {
            'world': 'org-b',
            'inventories': [row('B inventory')],
          };
    await tester.pumpWidget(
      page(ApiClient.forWorld(fixture.api, 'org-a', isCurrent: () => true)),
    );
    await tester.pump();
    await tester.pumpWidget(
      page(ApiClient.forWorld(fixture.api, 'org-b', isCurrent: () => true)),
    );
    await tester.pumpAndSettle();
    old.complete({
      'world': 'org-a',
      'inventories': [row('A inventory')],
    });
    await tester.pumpAndSettle();
    expect(find.text('B inventory'), findsOneWidget);
    expect(find.text('A inventory'), findsNothing);
  });
}
