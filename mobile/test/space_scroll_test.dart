import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/hierarchy_fixture.dart';

Future<void> Function(String)? spaceScrollCapture;

void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  for (final brightness in Brightness.values) {
    testWidgets('Space has one lazy scrolling viewport ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final items = List.generate(
        1000,
        (i) => InventoryItem.fromJson({
          'item_id': 'item-$i',
          'name': 'Timing belt ${i.toString().padLeft(4, '0')}',
          'quantity': i % 12 + 1,
          'category': 'Hardware',
          'location': 'Workbench',
        }),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('space-scroll-frame'),
          child: MaterialApp(
            theme: AppTheme.create(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 44, bottom: 34),
                viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
                viewInsets: EdgeInsets.zero,
              ),
              child: child!,
            ),
            home: LocationItemsPage(
              api: fixture.api,
              location: 'Workbench',
              items: items,
              allItems: items,
              thresholds: const {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Timing belt 0999'), findsNothing);
      expect(find.byType(Dismissible).evaluate().length, lessThan(20));
      await spaceScrollCapture?.call('detail-${brightness.name}');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(find.text('Review').hitTestable(), findsNothing);
      expect(find.byType(Dismissible).evaluate().length, lessThan(25));
      await spaceScrollCapture?.call('detail-scrolled-${brightness.name}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
