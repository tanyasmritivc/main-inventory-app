import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/scan/upload_photo_flow.dart';

void main() {
  ExtractedInventoryItem captured(String name, String place) =>
      ExtractedInventoryItem(
        name: name,
        category: 'Tools',
        quantity: 1,
        location: place,
      );

  InventoryItem inserted(String name, String place) => InventoryItem(
    itemId: '$name-$place',
    name: name,
    category: 'Tools',
    quantity: 1,
    location: place,
    createdAt: DateTime.utc(2026),
  );

  test('partial save keeps the unsaved place and explicit failures', () {
    final confirmed = [
      captured('Clamp', 'Workshop'),
      captured('Clamp', 'Storage'),
      captured('Brush', 'Workshop'),
    ];
    final waiting = itemsWaitingAfterBulkSave(
      confirmed: confirmed,
      normalized: confirmed,
      normalizedSourceIndices: const [0, 1, 2],
      result: BulkCreateResult(
        inserted: [
          inserted('Clamp', 'Workshop'),
          inserted('Brush', 'Workshop'),
        ],
        failures: const [
          {'index': 2, 'reason': 'Could not save'},
        ],
      ),
    );

    expect(waiting, [confirmed[1], confirmed[2]]);
  });

  test('aggregated copies in one place are both saved', () {
    final confirmed = [
      captured('Clamp', 'Workshop'),
      captured('Clamp', 'Workshop'),
    ];
    final waiting = itemsWaitingAfterBulkSave(
      confirmed: confirmed,
      normalized: confirmed,
      normalizedSourceIndices: const [0, 1],
      result: BulkCreateResult(
        inserted: [inserted('Clamp', 'Workshop')],
        failures: const [],
      ),
    );

    expect(waiting, isEmpty);
  });
}
