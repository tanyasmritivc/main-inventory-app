import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/inventory/item_sort.dart';

void main() {
  final examples = [
    {
      'item_id': 'a',
      'name': 'Zulu description',
      'part_number': 'A-020',
      'category': 'Tools',
      'quantity': 9,
      'created_at': '2026-01-03T00:00:00Z',
    },
    {
      'item_id': 'b',
      'name': 'Alpha description',
      'part_number': 'B-010',
      'category': 'Hardware',
      'quantity': 2,
      'created_at': '2026-01-01T00:00:00Z',
    },
    {
      'item_id': 'c',
      'name': 'C item without number',
      'category': 'Hardware',
      'quantity': 5,
      'created_at': '2026-01-02T00:00:00Z',
    },
  ];
  final orders = {
    ItemSortOption.nameAZ: ['a', 'b', 'c'],
    ItemSortOption.nameZA: ['c', 'b', 'a'],
    ItemSortOption.quantityLowHigh: ['b', 'c', 'a'],
    ItemSortOption.quantityHighLow: ['a', 'c', 'b'],
    ItemSortOption.categoryAZ: ['b', 'c', 'a'],
    ItemSortOption.dateNewest: ['a', 'c', 'b'],
    ItemSortOption.dateOldest: ['b', 'c', 'a'],
  };
  for (final entry in orders.entries) {
    test('Stored values match ${itemSortLabel(entry.key)}', () {
      final items = examples.map(InventoryItem.fromJson).toList();
      sortInventoryItems(items, entry.key);
      expect(items.map((i) => i.itemId), entry.value);
      expect(items.singleWhere((i) => i.itemId == 'a').displayName, 'A-020');
      expect(
        items.singleWhere((i) => i.itemId == 'a').name,
        'Zulu description',
      );
      final raw = examples.map((e) => Map<String, dynamic>.from(e)).toList();
      sortRawItems(raw, entry.key);
      expect(raw.map((i) => i['item_id']), entry.value);
    });
  }
}
