import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/scan/confirm_scan_sheet.dart';
import 'package:mobile/features/scan/review_capture.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    ExtractedInventoryItem item,
    void Function(List<ExtractedInventoryItem>?) onResult,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  onResult(
                    await showModalBottomSheet<List<ExtractedInventoryItem>>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ConfirmScanSheet(
                        items: [item],
                        defaultLocation: 'Pantry',
                        existingItems: const [],
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  ExtractedInventoryItem item({bool unknown = false}) => ExtractedInventoryItem(
    name: 'Tablets - blister strip',
    category: 'Health',
    quantity: unknown ? 1 : 8,
    reviewId: 'preview-a',
    reviewStatus: 'preview',
    reviewToken: 'signed',
    notes: 'Original photo note.',
    scanEvidence: ScanEvidence(
      needsReview: true,
      identityConfidence: .8,
      quantityBasis: unknown ? 'unknown' : 'estimated_visible',
      quantityUnit: unknown ? null : 'tablet',
      quantityConfidence: unknown ? null : .8,
      quantityNote: unknown ? null : 'Estimated visible count.',
      warnings: const ['Photo is partly obscured.'],
    ),
  );

  testWidgets(
    'Save accepts visible estimates directly and preserves uncertainty',
    (tester) async {
      List<ExtractedInventoryItem>? result;
      await open(tester, item(), (value) => result = value);
      expect(find.textContaining('Keep 1 in Review'), findsNothing);
      await tester.tap(find.text('Save to Space'));
      await tester.pumpAndSettle();
      expect(result!.single.needsReview, isFalse);
      expect(result!.single.quantity, 8);
      expect(result!.single.scanEvidence!.identityConfidence, .8);
      expect(
        result!.single.scanEvidence!.warnings,
        contains('Photo is partly obscured.'),
      );
      expect(result!.single.notes, contains('Quantity unit: tablet.'));
      final plan = await prepareCaptureForSave(
        api: ApiClient(baseUrl: 'https://api.test'),
        items: result!,
      );
      expect(plan.reviewCount, 0);
      expect(plan.inventoryItems, hasLength(1));
    },
  );

  testWidgets(
    'unknown count saves in the chosen Space review without needing a count',
    (tester) async {
      List<ExtractedInventoryItem>? result;
      await open(tester, item(unknown: true), (value) => result = value);
      await tester.tap(find.text('Save to Space'));
      await tester.pumpAndSettle();
      expect(result!.single.quantity, 1);
      expect(result!.single.scanEvidence!.quantityBasis, 'unknown');
      expect(result!.single.notes, contains('not been counted'));
      expect(result!.single.needsReview, isTrue);
      expect(result!.single.location, 'Pantry');
      final api = _ReviewApi();
      final plan = await prepareCaptureForSave(api: api, items: result!);
      expect(plan.inventoryItems, isEmpty);
      expect(plan.reviewCount, 1);
      expect(api.saved!.location, 'Pantry');
    },
  );

  testWidgets('unknown identity goes to Review even when its count is known', (
    tester,
  ) async {
    List<ExtractedInventoryItem>? result;
    final draft = item()..name = 'Unknown item';
    await open(tester, draft, (value) => result = value);
    await tester.tap(find.text('Save to Space'));
    await tester.pumpAndSettle();
    expect(result!.single.quantity, 8);
    expect(result!.single.needsReview, isTrue);
    expect(result!.single.location, 'Pantry');
  });

  testWidgets(
    'quantity and unit edit; invalid count cannot save; Cancel returns no draft',
    (tester) async {
      List<ExtractedInventoryItem>? result;
      await open(tester, item(), (value) => result = value);
      final quantity = find.byKey(const ValueKey('quantity-0'));
      await tester.ensureVisible(quantity);
      await tester.enterText(quantity, '100001');
      await tester.pump();
      await tester.tap(find.text('Save to Space'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.enterText(quantity, '6');
      final unit = find.byKey(const ValueKey('quantity-unit-0'));
      await tester.ensureVisible(unit);
      await tester.enterText(unit, 'tablet');
      await tester.pump();
      await tester.tap(find.text('Save to Space'));
      await tester.pumpAndSettle();
      expect(result!.single.quantity, 6);
      expect(result!.single.scanEvidence!.quantityUnit, 'tablet');
      expect(result!.single.scanEvidence!.quantityBasis, 'user_confirmed');
      result = null;
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    },
  );
}

class _ReviewApi extends ApiClient {
  _ReviewApi() : super(baseUrl: 'https://api.test');
  ExtractedInventoryItem? saved;
  @override
  Future<ReviewItem> updateReviewItem({
    required String reviewId,
    required ExtractedInventoryItem item,
  }) async {
    saved = item;
    return ReviewItem.fromJson({
      ...item.toJson(),
      'review_id': reviewId,
      'status': 'pending',
    });
  }
}
