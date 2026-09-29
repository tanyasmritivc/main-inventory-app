import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/scan/confirm_scan_sheet.dart';

void main() {
  testWidgets('review keeps the source, crop, evidence, and chosen place', (
    tester,
  ) async {
    List<ExtractedInventoryItem>? saved;
    final detected = ExtractedInventoryItem(
      name: 'Clamp',
      category: 'Tools',
      quantity: 2,
      location: 'Unsorted',
      confidence: 0.8,
      sourceFrameUrl: 'https://invalid.test/source.jpg',
      imageUrl: 'https://invalid.test/crop.jpg',
      scanEvidence: const ScanEvidence(
        detectionConfidence: 0.9,
        needsReview: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await Navigator.of(context)
                    .push<List<ExtractedInventoryItem>>(
                      MaterialPageRoute(
                        builder: (_) => ConfirmScanSheet(
                          items: [detected],
                          defaultLocation: 'Workshop',
                        ),
                      ),
                    );
              },
              child: const Text('Review'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Review objects'), findsOneWidget);
    expect(find.text('Source photo'), findsOneWidget);
    expect(find.text('Object crop'), findsOneWidget);
    await tester.tap(find.text('Save 1 object'));
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
    expect(saved!.single.location, 'Workshop');
    expect(saved!.single.sourceFrameUrl, detected.sourceFrameUrl);
    expect(saved!.single.imageUrl, detected.imageUrl);
    expect(saved!.single.confidence, 0.8);
  });

  testWidgets('wrong detection can be removed before save', (tester) async {
    List<ExtractedInventoryItem>? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await Navigator.of(context)
                    .push<List<ExtractedInventoryItem>>(
                      MaterialPageRoute(
                        builder: (_) => ConfirmScanSheet(
                          items: [
                            ExtractedInventoryItem(
                              name: 'Wall',
                              category: 'Other',
                              quantity: 1,
                            ),
                          ],
                          defaultLocation: 'Workshop',
                        ),
                      ),
                    );
              },
              child: const Text('Review'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Discard photo'), findsOneWidget);
    await tester.tap(find.text('Discard photo'));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
  });
}
