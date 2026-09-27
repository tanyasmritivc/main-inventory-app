import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/scan/barcode_answer_sheet.dart';

class _BarcodeApi extends ApiClient {
  _BarcodeApi() : super(baseUrl: 'https://invalid.test');

  final item = InventoryItem(
    itemId: '00000000-0000-0000-0000-000000000001',
    name: 'Test object',
    category: 'Other',
    quantity: 4,
    location: 'Test place',
    createdAt: DateTime(2026),
  );
  int? updatedCount;
  var added = false;

  @override
  Future<BarcodeLookupResult> barcodeLookup({required String barcode}) async =>
      BarcodeLookupResult(
        name: item.name,
        foundInInventory: true,
        existingItem: {'item_id': item.itemId},
      );

  @override
  Future<InventoryItem> itemDetail(String itemId) async => item;

  @override
  Future<List<Map<String, dynamic>>> itemRelationships(String itemId) async =>
      const [];

  @override
  Future<InventoryItem> updateItem({required UpdateItemRequest request}) async {
    updatedCount = request.quantity;
    return item;
  }

  @override
  Future<InventoryItem> addItem({required AddItemRequest item}) async {
    added = true;
    return this.item;
  }
}

void main() {
  testWidgets('scanning owned stock increments its record', (tester) async {
    final api = _BarcodeApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showBarcodeAnswerSheet(
                  context,
                  api: api,
                  barcode: '12345678',
                  destination: 'Test place',
                  onSaved: () {},
                  onPhotograph: () {},
                ),
                child: const Text('Scan'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    expect(find.text('You have'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    await tester.tap(find.text('Add to stock'));
    await tester.pumpAndSettle();
    expect(api.updatedCount, 5);
    expect(api.added, isFalse);
  });
}
