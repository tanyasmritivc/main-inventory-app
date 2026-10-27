import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  testWidgets('open Space follows its ID through rename and removal', (
    tester,
  ) async {
    var name = 'Old bench';
    var deleted = false;
    fixture.respond = (request) {
      if (request.path.endsWith('/spaces')) {
        return {
          'spaces': [
            if (!deleted) {'id': 'bench', 'name': name},
          ],
        };
      }
      if (request.path.endsWith('/search_items')) {
        return {'items': [], 'parsed': {}};
      }
      return {'display_name': 'Test', 'unread_count': 0, 'notifications': []};
    };
    await tester.pumpWidget(
      MaterialApp(
        home: LocationItemsPage(
          api: fixture.api,
          location: name,
          spaceId: 'bench',
          items: const <InventoryItem>[],
          allItems: const <InventoryItem>[],
          thresholds: const {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old bench'), findsOneWidget);
    name = 'Renamed on web';
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.text('Old bench'), findsNothing);
    expect(find.text('Renamed on web'), findsOneWidget);
    deleted = true;
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.text('Space unavailable'), findsOneWidget);
    expect(find.text('Renamed on web'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
