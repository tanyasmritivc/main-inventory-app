import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/scan/review_capture.dart';
import 'package:mobile/features/scan/scan_evidence_panel.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'https://api.test');

  final List<String> updatedReviewIds = [];

  @override
  Future<ReviewItem> updateReviewItem({
    required String reviewId,
    required ExtractedInventoryItem item,
  }) async {
    updatedReviewIds.add(reviewId);
    return ReviewItem.fromJson({
      ...item.toJson(),
      'review_id': reviewId,
      'status': 'pending',
      'source_kind': 'photo_scan',
      'created_at': '2026-09-29T12:00:00Z',
    });
  }
}

ExtractedInventoryItem _item({required bool uncertain}) {
  return ExtractedInventoryItem(
    name: uncertain ? 'Unidentified item' : 'M4 bolt',
    category: 'Hardware',
    quantity: 1,
    location: 'Drawer A',
    imageUrl: 'https://images.test/crop.jpg',
    reviewId: uncertain ? 'review-1' : null,
    reviewStatus: uncertain ? 'pending' : null,
    scanEvidence: ScanEvidence(
      identificationReasoning: uncertain
          ? 'The visible details were not distinctive enough.'
          : 'Visible shape and markings support this identification.',
      identityConfidence: uncertain ? 0.3 : 0.94,
      detectionConfidence: 0.88,
      ocrText: 'M4',
      ocrConfidence: 0.8,
      lengthMm: 20,
      widthMm: 4,
      measurementMethod: 'ruler',
      measurementConfidence: 'medium',
      reviewReasons: uncertain
          ? const ['The identification confidence is low.']
          : const [],
      warnings: uncertain
          ? const ['Only part of the photo analysis completed.']
          : const [],
      needsReview: uncertain,
    ),
  );
}

void main() {
  test(
    'uncertain captures are updated in Review, never bulk-save candidates',
    () async {
      final api = _FakeApi();
      final plan = await prepareCaptureForSave(
        api: api,
        items: [_item(uncertain: true), _item(uncertain: false)],
      );

      expect(api.updatedReviewIds, ['review-1']);
      expect(plan.reviewCount, 1);
      expect(plan.inventoryItems, hasLength(1));
      expect(plan.inventoryItems.single.name, 'M4 bolt');
    },
  );

  test('an uncertain capture without durable identity fails closed', () async {
    final item = _item(uncertain: true)..reviewId = null;

    await expectLater(
      prepareCaptureForSave(api: _FakeApi(), items: [item]),
      throwsA(isA<StateError>()),
    );
  });

  test('a previously handled uncertain capture fails closed', () async {
    final api = _FakeApi();
    final item = _item(uncertain: true)..reviewStatus = 'resolved';

    await expectLater(
      prepareCaptureForSave(api: api, items: [item]),
      throwsA(isA<StateError>()),
    );

    expect(api.updatedReviewIds, isEmpty);
  });

  testWidgets('scan evidence shows all user-facing information', (
    tester,
  ) async {
    final item = _item(uncertain: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ScanEvidencePanel(
            evidence: item.scanEvidence!,
            barcode: '12345',
            initiallyExpanded: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Needs your review'), findsOneWidget);
    expect(find.text('The identification confidence is low.'), findsOneWidget);
    expect(find.text('M4 · 80% confidence'), findsOneWidget);
    expect(find.textContaining('20.0 × 4.0 mm'), findsOneWidget);
    expect(
      find.text('Only part of the photo analysis completed.'),
      findsOneWidget,
    );
    expect(find.textContaining('model'), findsNothing);
  });
}
