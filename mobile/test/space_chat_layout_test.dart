import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/inventory_context.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/hierarchy_fixture.dart';

Future<void> Function(String)? layoutCapture;
void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  for (final brightness in Brightness.values) {
    for (final empty in [false, true]) {
      testWidgets(
        'header search and in-flow Ask ${brightness.name} empty=$empty',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          fixture.respond = (_) => <String, dynamic>{};
          final api = ApiClient.forInventory(
            fixture.api,
            InventoryContext.fromJson(
              inventory('layout-inventory'),
              accountId: 'actor-a',
              expectedInventory: 'layout-inventory',
            ),
            isCurrent: () => true,
          );
          final items = empty
              ? <InventoryItem>[]
              : ['Screws', 'Washers']
                    .map(
                      (name) => InventoryItem.fromJson({
                        'item_id': name,
                        'name': name,
                        'quantity': 2,
                        'category': 'Hardware',
                        'location': 'Workbench',
                      }),
                    )
                    .toList();
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('layout-frame'),
              child: MaterialApp(
                theme: AppTheme.create(brightness),
                home: LocationItemsPage(
                  api: api,
                  location: 'Workbench',
                  items: items,
                  allItems: items,
                  thresholds: const {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsNothing);
          final ask = find.text('Ask FindEZ');
          expect(ask.hitTestable(), findsOneWidget);
          expect(
            tester.getBottomLeft(ask).dy,
            lessThan(
              tester
                  .getTopLeft(
                    find.text(empty ? 'This space is empty' : 'Screws'),
                  )
                  .dy,
            ),
          );
          expect(
            tester
                .getRect(ask)
                .overlaps(tester.getRect(find.byIcon(Icons.add_rounded).last)),
            isFalse,
          );
          await layoutCapture?.call(
            '${brightness.name}-${empty ? 'empty' : 'items'}',
          );
          await tester.tap(find.byTooltip('Search this space'));
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsOneWidget);
          if (!empty) {
            await tester.enterText(find.byType(TextField), 'Washer');
            await tester.pumpAndSettle();
            expect(find.text('Screws'), findsNothing);
            expect(find.text('Washers'), findsOneWidget);
          }
          await tester.tap(find.byTooltip('Close search'));
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsNothing);
          if (!empty) expect(find.text('Screws'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
