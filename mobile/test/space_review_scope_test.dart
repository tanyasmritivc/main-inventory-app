import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/inventory_context.dart';
import 'package:mobile/features/review/review_queue_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  final fixture = HierarchyFixture();
  setUpAll(() => fixture.initialize());
  tearDownAll(() => Supabase.instance.dispose());
  testWidgets('Space Review lists only that destination and opens its editor', (
    tester,
  ) async {
    fixture.respond = (request) {
      if (request.path.endsWith('/review-items')) {
        return {
          'pending_count': 2,
          'items': [
            {
              'review_id': 'pantry-review',
              'status': 'pending',
              'name': 'Unknown pantry item',
              'category': 'Other',
              'location': 'Pantry',
              'quantity': 1,
              'scan_evidence': {
                'needs_review': true,
                'quantity_basis': 'unknown',
              },
            },
            {
              'review_id': 'garage-review',
              'status': 'pending',
              'name': 'Garage object',
              'category': 'Other',
              'location': 'Garage',
              'quantity': 1,
            },
          ],
        };
      }
      return {'unread_count': 0, 'notifications': [], 'display_name': 'Test'};
    };
    final api = ApiClient.forInventory(
      fixture.api,
      InventoryContext.fromJson(
        inventory('personal-items'),
        accountId: 'actor-a',
        expectedInventory: 'personal-items',
      ),
      isCurrent: () => true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewQueuePage(api: api, location: 'Pantry'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unknown pantry item'), findsOneWidget);
    expect(find.text('Garage object'), findsNothing);
    expect(find.textContaining('saved in Pantry for review'), findsOneWidget);
    expect(
      fixture.requests.any(
        (r) => r.path == '/inventories/personal-items/review-items',
      ),
      isTrue,
    );
    await tester.tap(find.text('Unknown pantry item'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('Pantry'), findsOneWidget);
    expect(fixture.requests.where((r) => r.method != 'GET'), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
