import '../../core/api_client.dart';

class ReviewCapturePlan {
  const ReviewCapturePlan({
    required this.inventoryItems,
    required this.reviewCount,
  });

  final List<ExtractedInventoryItem> inventoryItems;
  final int reviewCount;
}

/// Saves uncertain previews or edits saved reviews, and returns items safe to
/// create as ordinary inventory.
Future<ReviewCapturePlan> prepareCaptureForSave({
  required ApiClient api,
  required List<ExtractedInventoryItem> items,
  bool Function()? isCurrent,
}) async {
  final inventoryItems = <ExtractedInventoryItem>[];
  var reviewCount = 0;
  for (final item in items) {
    if (isCurrent != null && !isCurrent()) {
      throw StateError(
        'The capture session changed. No further items were saved.',
      );
    }
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
    if (item.reviewStatus != 'pending' && item.reviewStatus != 'preview') {
      throw StateError(
        'This photo was already reviewed. Take a new photo to capture it again.',
      );
    }
    if (item.reviewStatus == 'preview' &&
        (item.reviewToken == null || item.reviewToken!.isEmpty)) {
      throw StateError(
        'This photo preview is unavailable. Scan the photo again.',
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
