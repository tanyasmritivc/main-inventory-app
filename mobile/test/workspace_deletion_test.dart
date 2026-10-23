import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/workspaces/resource_removal.dart';
import 'support/hierarchy_fixture.dart';

Future<void> Function(String)? releaseAuditCapture;

void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  bool? changed;
  setUp(() {
    fixture.requests.clear();
    fixture.status = 200;
    changed = null;
  });
  Map<String, dynamic> preview(String kind) => {
    'kind': kind,
    'id': 'resource',
    'name': 'Workshop',
    'items': 7,
    'spaces': 2,
    'inventories': 1,
    'workspaces': 1,
    'can_move': true,
    'destinations': [
      {'id': 'bench', 'name': 'Bench'},
    ],
  };
  Future<void> mount(
    WidgetTester tester,
    String kind,
    Brightness theme, {
    double scale = 1,
    double keyboard = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(theme),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: RepaintBoundary(
            key: const Key('release-audit-frame'),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                changed = await confirmResourceRemoval(
                  context,
                  fixture.api,
                  kind: kind,
                  id: 'resource',
                  name: 'Workshop',
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

  for (final theme in Brightness.values) {
    for (final kind in ['organization', 'workspace', 'inventory', 'space']) {
      for (final action in ['move', 'delete']) {
        testWidgets('${theme.name} $kind explicit $action confirms receipt', (
          tester,
        ) async {
          fixture.respond = (request) => request.method == 'GET'
              ? preview(kind)
              : {
                  'kind': kind,
                  'id': 'resource',
                  'action': action,
                  'moved': action == 'move',
                  'deleted': action == 'delete',
                };
          await mount(tester, kind, theme);
          expect(
            tester
                .widget<TextButton>(
                  find.widgetWithText(TextButton, 'Delete $kind'),
                )
                .onPressed,
            isNull,
          );
          await tester.enterText(find.byType(TextFormField), 'Workshop');
          await tester.pump();
          expect(
            tester
                .widget<TextButton>(
                  find.widgetWithText(TextButton, 'Delete $kind'),
                )
                .onPressed,
            isNull,
          );
          await tester.tap(
            find.byType(CheckboxListTile).at(action == 'move' ? 0 : 1),
          );
          await tester.pumpAndSettle();
          if ((kind == 'space' || kind == 'inventory') && action == 'move') {
            await tester.ensureVisible(
              find.byType(DropdownButtonFormField<String>),
            );
            await tester.tap(find.byType(DropdownButtonFormField<String>));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Bench').last);
            await tester.pumpAndSettle();
          }
          final button = find.widgetWithText(
            TextButton,
            action == 'move' ? 'Move and continue' : 'Delete $kind',
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(changed, true);
          expect(
            fixture.requests.last.path,
            '/resource-removal/$kind/resource',
          );
          expect(fixture.requests.last.method, 'POST');
          expect(fixture.requests.last.data, {
            'name': 'Workshop',
            'action': action,
            if ((kind == 'space' || kind == 'inventory') && action == 'move')
              'destination_id': 'bench',
          });
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  for (final theme in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '${theme.name} small phone confirmation at ${scale}x with keyboard',
        (tester) async {
          tester.view.physicalSize = const Size(375, 667);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
          tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
          fixture.respond = (r) => r.method == 'GET'
              ? preview('organization')
              : {
                  'kind': 'organization',
                  'id': 'resource',
                  'action': 'delete',
                  'deleted': true,
                };
          await mount(
            tester,
            'organization',
            theme,
            scale: scale,
            keyboard: 230,
          );
          final choice = find.byType(CheckboxListTile).last;
          await tester.ensureVisible(choice);
          await tester.tap(choice);
          await tester.pumpAndSettle();
          final name = find.byType(TextFormField);
          await tester.ensureVisible(name);
          await tester.enterText(name, 'Workshop');
          await tester.pumpAndSettle();
          final submit = find.widgetWithText(TextButton, 'Delete organization');
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          await releaseAuditCapture?.call('deletion-${theme.name}-$scale');
          await tester.tap(submit);
          await tester.pumpAndSettle();
          expect(changed, true);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('Cancel checks counts but never writes', (tester) async {
    fixture.respond = (_) => preview('inventory');
    await mount(tester, 'inventory', Brightness.light);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(changed, false);
    expect(fixture.requests.every((r) => r.method == 'GET'), true);
  });
  testWidgets('wrong receipt retains confirmation and entered name', (
    tester,
  ) async {
    fixture.respond = (r) => r.method == 'GET'
        ? preview('inventory')
        : {
            'kind': 'inventory',
            'id': 'other',
            'action': 'delete',
            'deleted': true,
          };
    await mount(tester, 'inventory', Brightness.dark);
    await tester.tap(find.byType(CheckboxListTile).last);
    await tester.enterText(find.byType(TextFormField), 'Workshop');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Delete inventory'));
    await tester.pumpAndSettle();
    expect(changed, isNull);
    expect(find.textContaining('could not be confirmed'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Workshop',
    );
  });
  testWidgets(
    'failed preview leaves only Retry and Cancel without a destructive action',
    (tester) async {
      fixture.status = 403;
      fixture.respond = (_) => {'detail': 'Access changed'};
      await mount(tester, 'workspace', Brightness.light);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(changed, isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(changed, false);
    },
  );
}
