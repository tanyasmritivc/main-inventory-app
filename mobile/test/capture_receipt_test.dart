import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';

void main() {
  Map<String, dynamic> receipt({
    List<Object>? indices,
    List<Map<String, dynamic>> failures = const [],
  }) => {
    'inserted': [
      {
        'item_id': 'saved',
        'name': 'Bolt',
        'category': 'Hardware',
        'quantity': 1,
        'location': 'Drawer',
      },
    ],
    'failures': failures,
    if (indices != null) 'accepted_indices': indices,
  };

  test('partial save removes only the confirmed input', () {
    final result = BulkCreateResult.fromJson(
      receipt(
        indices: [1],
        failures: [
          {'index': 0},
        ],
      ),
    );
    expect(result.confirmedIndices(2), {1});
    expect(
      BulkCreateResult.fromJson(
        receipt(
          failures: [
            {'index': 0},
          ],
        ),
      ).confirmedIndices(2),
      isEmpty,
    );
    expect(BulkCreateResult.fromJson(receipt()).confirmedIndices(1), {0});
  });

  test('invalid or conflicting receipts never erase a draft', () {
    for (final indices in <List<Object>>[
      [0, 0],
      [-1],
      [2],
      [0.5],
      [0, 1],
    ]) {
      expect(
        () => BulkCreateResult.fromJson(
          receipt(indices: indices),
        ).confirmedIndices(2),
        throwsFormatException,
      );
    }
    expect(
      () => BulkCreateResult.fromJson(
        receipt(
          indices: [0],
          failures: [
            {'index': 0},
          ],
        ),
      ).confirmedIndices(1),
      throwsFormatException,
    );
  });
}
