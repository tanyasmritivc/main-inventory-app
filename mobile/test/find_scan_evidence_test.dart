import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';

void main() {
  test('FIND evidence is parsed and preserved in scan payloads', () {
    final result = MultiExtractResult.fromJson({
      'items': [
        {
          'name': 'micro servo',
          'category': 'Robot Parts',
          'quantity': 1,
          'brand': 'goBILDA',
          'part_number': '2000-0025-0502',
          'barcode': '810069810123',
          'confidence': 0.94,
          'scan_evidence': {
            'identification_reasoning': 'Compact servo with printed label.',
            'ocr_text': '2000-0025-0502',
            'ocr_confidence': 0.91,
            'length_mm': 40.2,
            'width_mm': 20.1,
            'measurement_confidence': 'high',
            'measurement_method': 'ruler',
            'barcode_symbology': 'CODE_128',
            'barcode_confidence': 0.99,
            'detection_confidence': 0.97,
            'needs_review': false,
          },
        },
      ],
      'summary': {
        'total_detected': 1,
        'categories': {'Robot Parts': 1},
        'identified_count': 1,
        'unknown_count': 0,
        'measured_count': 1,
        'ocr_text_count': 1,
        'partial': false,
      },
    });

    final item = result.items.single;
    expect(item.scanEvidence?.ocrText, '2000-0025-0502');
    expect(item.scanEvidence?.hasDimensions, isTrue);
    expect(item.scanEvidence?.barcodeSymbology, 'CODE_128');
    expect(item.toJson()['scan_evidence'], isA<Map<String, dynamic>>());
    expect(result.summary.identifiedCount, 1);
    expect(result.summary.measuredCount, 1);
    expect(result.summary.partial, isFalse);
  });
}
