import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

InventoryItem part({
  String id = 'target',
  String number = 'PN-F156',
  String category = 'Supplies',
}) => InventoryItem(
  itemId: id,
  name: 'Black steel spring',
  partNumber: number,
  category: category,
  quantity: 14,
  location: 'Drawer B',
  spaceId: 'drawer',
  createdAt: DateTime(2026),
  brand: 'Acme',
  tags: ['fragile'],
  notes: 'Store dry',
  barcode: '000112',
  purchaseSource: 'McMaster',
  importData: const ImportedItemData(
    filename: 'private.csv',
    sheet: 'Sheet 1',
    fields: [ImportedItemField(name: 'Finish', value: 'stainless')],
  ),
);

class SearchApi extends ApiClient {
  SearchApi() : super(baseUrl: 'https://api.test');
  @override
  Future<Map<String, dynamic>> getNotifications() async => {'unread_count': 0};
}

void main() {
  for (final query in [
    'PN-F',
    'pn f156',
    'PNF156',
    'F156',
    'steel black',
    'drawer spring',
    'supplies acme',
    'fragile',
    'McMaster',
    'stainless',
    'black sprign',
    'dry',
    '000112',
  ]) {
    test(
      'finds saved detail: $query',
      () => expect(part().searchScore(query), greaterThan(0)),
    );
  }
  for (final query in [
    'PN-F157',
    'PNF157',
    'F157',
    '000113',
    'black copper',
    'private',
    '%(),',
  ]) {
    test(
      'does not invent a match: $query',
      () => expect(part().searchScore(query), 0),
    );
  }
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test',
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  testWidgets(
    'Space search finds displayed part numbers and imported details; category filter remains active',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final items = [
        part(),
        part(id: 'other', number: 'PN-F157', category: 'Tools'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(Brightness.light),
          home: LocationItemsPage(
            api: SearchApi(),
            location: 'Drawer B',
            spaceId: 'drawer',
            items: items,
            allItems: items,
            thresholds: const {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byType(TextField).first;
      await tester.enterText(input, 'Pn-F');
      await tester.pumpAndSettle();
      expect(find.text('PN-F156'), findsOneWidget);
      await tester.enterText(input, 'PNF156');
      await tester.pumpAndSettle();
      expect(find.text('PN-F156'), findsOneWidget);
      expect(find.text('PN-F157'), findsNothing);
      await tester.enterText(input, 'stainless sprign');
      await tester.pumpAndSettle();
      expect(find.text('PN-F156'), findsOneWidget);
      await tester.tap(find.text('Tools').first);
      await tester.pumpAndSettle();
      expect(find.text('PN-F156'), findsNothing);
      expect(find.text('PN-F157'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
