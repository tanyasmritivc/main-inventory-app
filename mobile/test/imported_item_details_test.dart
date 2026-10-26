import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/inventory/imported_item_details.dart';

void main() {
  final item = InventoryItem.fromJson({
    'item_id': 'test',
    'name': 'Bolt',
    'quantity': 7,
    'import_data': {
      'filename': 'parts.xlsx',
      'sheet': 'Sheet1',
      'fields': [
        {'name': 'Screw Length', 'value': 12},
        {'name': 'Vendor Part #', 'value': '0012'},
        {'name': 'Size', 'value': 'M2'},
        {'name': 'Size', 'value': '12mm'},
        {'name': '', 'value': false},
        {'name': 'Quantity', 'value': 0},
        {
          'name': 'Specs',
          'value': {
            'ports': ['A', 'B'],
          },
        },
        {'name': 'Empty column', 'value': null},
      ],
    },
  });

  test(
    'inventory decoding keeps source values separate from current quantity',
    () {
      expect(item.quantity, 7);
      expect(item.importData!.fields[5].value, 0);
      expect(item.importData!.fields[4].displayValue, 'false');
      expect(item.importData!.fields[1].displayValue, '0012');
      expect(item.importData!.fields[6].displayValue, '{"ports":["A","B"]}');
      expect(InventoryItem.fromJson({'item_id': 'old'}).importData, isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'all imported fields wrap on narrow ${brightness.name} screens with large text',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 700),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ImportedItemDetails(data: item.importData!),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Screw Length'), findsOneWidget);
        expect(find.text('Vendor Part #'), findsOneWidget);
        expect(find.text('Size'), findsNWidgets(2));
        expect(find.text('Column 5'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
        expect(find.text('Empty'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
