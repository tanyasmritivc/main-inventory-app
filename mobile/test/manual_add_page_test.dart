import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/inventory/manual_add_page.dart';

class _ManualApi extends ApiClient {
  _ManualApi({required this.hasMatch}) : super(baseUrl: 'https://invalid.test');

  final bool hasMatch;
  final object = InventoryItem(
    itemId: '00000000-0000-0000-0000-000000000001',
    name: 'Test object',
    category: 'Other',
    quantity: 4,
    location: 'Test place',
    createdAt: DateTime(2026),
  );
  int? updatedCount;
  AddItemRequest? added;

  @override
  Future<List<Map<String, dynamic>>> listSpaces() async => [
    {'name': 'Test place'},
  ];

  @override
  Future<SearchItemsResult> searchItems({required String query}) async =>
      SearchItemsResult(items: hasMatch ? [object] : [], parsed: const {});

  @override
  Future<InventoryItem> itemDetail(String itemId) async => object;

  @override
  Future<InventoryItem> updateItem({required UpdateItemRequest request}) async {
    updatedCount = request.quantity;
    return object;
  }

  @override
  Future<InventoryItem> addItem({required AddItemRequest item}) async {
    added = item;
    return object;
  }
}

Future<void> _open(WidgetTester tester, _ManualApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showManualAddPage(
                context,
                api: api,
                initialLocation: 'Test place',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'Test object');
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('choosing a match updates the existing record', (tester) async {
    final api = _ManualApi(hasMatch: true);
    await _open(tester, api);
    expect(find.text('Test object'), findsNWidgets(2));
    await tester.tap(find.text('Test object').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to existing object'));
    await tester.pumpAndSettle();
    expect(api.updatedCount, 5);
    expect(api.added, isNull);
  });

  testWidgets('a new object uses the stepper count', (tester) async {
    final api = _ManualApi(hasMatch: false);
    await _open(tester, api);
    expect(find.text('No matching objects found.'), findsOneWidget);
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save new object'));
    await tester.pumpAndSettle();
    expect(api.added?.name, 'Test object');
    expect(api.added?.quantity, 2);
    expect(api.updatedCount, isNull);
  });
}
