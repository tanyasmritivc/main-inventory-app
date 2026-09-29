import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';

void main() {
  InventoryItem item({String? partNumber}) => InventoryItem(
    itemId: 'item-1',
    name: 'Washer for 14mm Bearing with 8mm REX shaft',
    category: 'Supplies',
    quantity: 1,
    location: 'Fastener db',
    createdAt: DateTime(2026, 9, 7),
    partNumber: partNumber,
  );

  test('part number is the primary display label when present', () {
    final inventoryItem = item(partNumber: 'PN-F280');

    expect(inventoryItem.displayName, 'PN-F280');
    expect(
      inventoryItem.displayDescription,
      'Washer for 14mm Bearing with 8mm REX shaft',
    );
  });

  test('name remains primary when no part number exists', () {
    final inventoryItem = item();

    expect(
      inventoryItem.displayName,
      'Washer for 14mm Bearing with 8mm REX shaft',
    );
    expect(inventoryItem.displayDescription, isNull);
  });

  test('item timestamps without a zone are read as UTC', () {
    final parsed = InventoryItem.fromJson({
      'item_id': 'item-2',
      'name': 'Screwdriver',
      'category': 'Tools',
      'quantity': 1,
      'location': 'Cabinet',
      'created_at': '2026-09-28T05:22:39.14675',
    });

    expect(parsed.createdAt.isUtc, isTrue);
    expect(parsed.createdAt.hour, 5);
    expect(parsed.createdAt.day, 28);
  });
}
