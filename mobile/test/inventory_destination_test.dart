import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/scan/connector_destination_page.dart';
import 'package:mobile/features/scan/import_sheet_page.dart';
import 'package:mobile/features/world/inventory_picker_sheet.dart';
import 'package:mobile/features/world/world_style.dart';
import 'support/hierarchy_fixture.dart';

Future<void> Function(String, Uint8List)? inventoryPickerCapture;

void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  var current = true;
  Map<String, dynamic> row(String id, {bool editable = true}) => {
    'inventory_id': id,
    'name': id,
    'workspace_id': 'workspace-a',
    'workspace_name': 'Robotics workspace',
    'can_edit': editable,
  };
  setUp(() {
    current = true;
    fixture.requests.clear();
    fixture.status = 200;
    fixture.respond = (r) {
      if (r.path == '/worlds/org-a/directory') {
        return {
          'world': 'org-a',
          'inventories': [row('Hardware'), row('Viewer', editable: false)],
        };
      }
      if (r.path == '/inventories/Hardware') {
        return {'inventory': inventory('Hardware')};
      }
      if (r.path == '/inventories/Hardware/spaces') {
        return {
          'spaces': [
            {'name': 'Workbench'},
          ],
        };
      }
      return <String, dynamic>{};
    };
  });
  ApiClient api([String world = 'org-a']) =>
      ApiClient.forWorld(fixture.api, world, isCurrent: () => current);
  Widget frame(Widget child, {Brightness brightness = Brightness.dark}) =>
      MaterialApp(
        theme: AppTheme.create(brightness),
        home: WorldStyle(child: child),
      );
  testWidgets(
    'chat import only requests its organization directory and editable inventories',
    (tester) async {
      await tester.pumpWidget(frame(ConnectorDestinationPage(api: api())));
      await tester.pumpAndSettle();
      expect(find.text('Hardware'), findsOneWidget);
      expect(find.text('Viewer'), findsNothing);
      expect(fixture.requests.map((r) => r.path), ['/worlds/org-a/directory']);
      await tester.tap(find.text('Hardware'));
      await tester.pumpAndSettle();
      expect(find.text('Workbench'), findsOneWidget);
      await tester.tap(find.text('Workbench'));
      await tester.pumpAndSettle();
      final page = tester.widget<ImportSheetPage>(find.byType(ImportSheetPage));
      expect(page.api.inventoryContext?.organizationId, 'org-a');
      expect(page.api.inventoryContext?.inventoryId, 'Hardware');
      expect(page.location, 'Workbench');
      current = false;
      expect(page.api.assertCurrentContext, throwsA(isA<Exception>()));
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final change in ['organization', 'permission', 'workspace']) {
    testWidgets(
      'chat destination rejects changed $change before reading Spaces',
      (tester) async {
        final fallback = fixture.respond;
        fixture.respond = (r) => r.path == '/inventories/Hardware'
            ? {
                'inventory': inventory(
                  'Hardware',
                  organization: change == 'organization' ? 'org-b' : 'org-a',
                  role: change == 'permission' ? 'viewer' : 'editor',
                  workspace: change == 'workspace'
                      ? 'workspace-b'
                      : 'workspace-a',
                ),
              }
            : fallback(r);
        await tester.pumpWidget(frame(ConnectorDestinationPage(api: api())));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hardware'));
        await tester.pumpAndSettle();
        expect(find.text('Choose Space'), findsNothing);
        expect(
          fixture.requests.where((r) => r.path.endsWith('/spaces')),
          isEmpty,
        );
        expect(find.text('Try again'), findsOneWidget);
      },
    );
  }
  testWidgets(
    'late directory after organization switch never displays destinations',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      fixture.respond = (_) => pending.future;
      await tester.pumpWidget(frame(ConnectorDestinationPage(api: api())));
      await tester.pump();
      current = false;
      pending.complete({
        'world': 'org-a',
        'inventories': [row('Hardware')],
      });
      await tester.pumpAndSettle();
      expect(find.text('Hardware'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    },
  );
  testWidgets(
    'Personal chat uses its own directory including independent workspaces',
    (tester) async {
      fixture.respond = (r) {
        if (r.path == '/worlds/personal/directory') {
          return {
            'world': 'personal',
            'inventories': [row('Garage')],
          };
        }
        if (r.path == '/inventories/Garage') {
          final result = inventory('Garage');
          (result['workspace'] as Map)['organization_id'] = null;
          return {'inventory': result};
        }
        if (r.path == '/inventories/Garage/spaces') {
          return {
            'spaces': [
              {'name': 'Shelf'},
            ],
          };
        }
        return <String, dynamic>{};
      };
      await tester.pumpWidget(
        frame(ConnectorDestinationPage(api: api('personal'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Garage'));
      await tester.pumpAndSettle();
      expect(find.text('Shelf'), findsOneWidget);
      expect(
        fixture.requests.any((r) => r.path == '/inventory-workspaces'),
        isFalse,
      );
    },
  );
  testWidgets('unscoped destination retains account-wide workspace selection', (
    tester,
  ) async {
    fixture.respond = (r) => r.path == '/inventory-workspaces'
        ? {
            'workspaces': [
              {'workspace_id': 'workspace-a', 'name': 'A'},
              {'workspace_id': 'workspace-b', 'name': 'B'},
            ],
          }
        : {
            'inventories': [
              row(r.path.contains('workspace-a') ? 'A items' : 'B items'),
            ],
          };
    await tester.pumpWidget(frame(ConnectorDestinationPage(api: fixture.api)));
    await tester.pumpAndSettle();
    expect(find.text('A items'), findsOneWidget);
    expect(find.text('B items'), findsOneWidget);
    expect(fixture.requests.first.path, '/inventory-workspaces');
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.6]) {
      testWidgets(
        'inventory sheet ${brightness.name} $scale supports long labels, scrolling and cancel',
        (tester) async {
          tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          Map<String, dynamic>? chosen;
          final rows = [
            for (var i = 0; i < 16; i++)
              {
                ...row('Inventory $i'),
                'workspace_name': 'FTC Season 2026-2027 Workspace',
              },
          ];
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.create(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(key: key, child: child!),
              ),
              home: WorldStyle(
                child: Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () async {
                          chosen = await showInventoryPicker(context, rows);
                        },
                        child: const Text('Open picker'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open picker'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (inventoryPickerCapture != null) {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await inventoryPickerCapture!(
              '${brightness.name}-$scale',
              bytes!.buffer.asUint8List(),
            );
            image.dispose();
          }
          await tester.scrollUntilVisible(
            find.text('Inventory 15'),
            180,
            scrollable: find.descendant(
              of: find.byType(InventoryPickerSheet),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          await Scrollable.ensureVisible(
            tester.element(find.text('Inventory 15')),
            alignment: .5,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Inventory 15'));
          await tester.pumpAndSettle();
          expect(chosen?['inventory_id'], 'Inventory 15');
          await tester.tap(find.text('Open picker'));
          await tester.pumpAndSettle();
          await tester.dragFrom(
            tester.getRect(find.byType(BottomSheet)).topCenter +
                const Offset(0, 16),
            const Offset(0, 500),
          );
          await tester.pumpAndSettle();
          expect(chosen, isNull);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
