import '../../core/api_client.dart';

class ReviewCapturePlan {
  const ReviewCapturePlan({
    required this.inventoryItems,
    required this.reviewCount,
  });

  final List<ExtractedInventoryItem> inventoryItems;
  final int reviewCount;
}

/// Persists edits to uncertain results and returns only items that are safe to
/// create as ordinary inventory.
Future<ReviewCapturePlan> prepareCaptureForSave({
  required ApiClient api,
  required List<ExtractedInventoryItem> items,
}) async {
  final inventoryItems = <ExtractedInventoryItem>[];
  var reviewCount = 0;
  for (final item in items) {
    if (!item.needsReview) {
      inventoryItems.add(item);
      continue;
    }
    final reviewId = item.reviewId;
    if (reviewId == null || reviewId.isEmpty) {
      throw StateError(
        'An uncertain item was not safely stored. Please scan the photo again.',
      );
    }
    if (item.reviewStatus != 'pending') {
      throw StateError(
        'This photo was already reviewed. Take a new photo to capture it again.',
      );
    }
    await api.updateReviewItem(reviewId: reviewId, item: item);
    reviewCount++;
  }
  return ReviewCapturePlan(
    inventoryItems: inventoryItems,
    reviewCount: reviewCount,
  );
}
