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

  test('captured item photo survives extraction payload round trip', () {
    final extracted = ExtractedInventoryItem.fromJson({
      'name': 'Bearing',
      'category': 'Hardware',
      'quantity': 1,
      'image_url': 'https://images.test/crop.jpg',
      'source_frame_url': 'https://images.test/source.jpg',
    });

    expect(extracted.imageUrl, 'https://images.test/crop.jpg');
    expect(extracted.sourceFrameUrl, 'https://images.test/source.jpg');
    expect(extracted.toJson()['image_url'], 'https://images.test/crop.jpg');
    expect(
      extracted.toJson()['source_frame_url'],
      'https://images.test/source.jpg',
    );
  });

  test('item photo mutation returns the updated primary and gallery', () {
    final result = ItemPhotoMutationResult.fromJson({
      'item': {
        'item_id': 'item-1',
        'name': 'Bearing',
        'category': 'Hardware',
        'quantity': 1,
        'location': 'Shop',
        'image_url': 'https://images.test/new.jpg',
        'created_at': '2026-09-28T12:00:00Z',
      },
      'photos': [
        {
          'photo_id': 'photo-1',
          'image_url': 'https://images.test/new.jpg',
          'is_primary': true,
        },
      ],
    });

    expect(result.item.imageUrl, 'https://images.test/new.jpg');
    expect(result.photos, hasLength(1));
    expect(result.photos.single.isPrimary, isTrue);
  });
}
