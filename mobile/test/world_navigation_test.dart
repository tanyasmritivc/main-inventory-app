import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/inventory/labels_page.dart';
import 'package:mobile/features/inventory/world_views.dart';

class _WorldApi extends ApiClient {
  _WorldApi() : super(baseUrl: 'https://invalid.test');

  bool failPlaces = false;

  @override
  Future<List<Map<String, dynamic>>> listSpaces() async {
    if (failPlaces) throw StateError('offline');
    return [
      {'id': 'space-one', 'name': 'Workshop'},
    ];
  }

  @override
  Future<SearchItemsResult> searchItems({required String query}) async =>
      SearchItemsResult(
        items: [
          InventoryItem.fromJson({
            'item_id': 'item-one',
            'name': 'Clamp',
            'category': 'Tools',
            'quantity': 1,
            'space_id': 'space-one',
            'location': 'Workshop',
          }),
        ],
        parsed: const {},
      );
}

void main() {
  testWidgets('All objects loads its own items when opened from More', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: AllObjectsPage(api: _WorldApi())),
    );
    await tester.pumpAndSettle();

    expect(find.text('All objects'), findsOneWidget);
    expect(find.text('Clamp'), findsOneWidget);
  });

  testWidgets('Labels lists real places and keeps scan available', (
    tester,
  ) async {
    var scan = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LabelsPage(
          api: _WorldApi(),
          onScan: () => scan = true,
          onAddPlace: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Labels'), findsOneWidget);
    expect(find.text('Workshop'), findsOneWidget);
    await tester.tap(find.text('Scan a label'));
    expect(scan, isTrue);
  });

  testWidgets('Labels reports a place read error and offers retry', (
    tester,
  ) async {
    final api = _WorldApi()..failPlaces = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LabelsPage(api: api, onScan: () {}, onAddPlace: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Places could not be loaded.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Scan a label'), findsOneWidget);
  });
}
