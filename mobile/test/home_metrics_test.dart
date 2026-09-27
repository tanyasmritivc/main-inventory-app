import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/home/home_metrics.dart';

InventoryItem item(
  String id,
  String name,
  int quantity, {
  double? confidence,
  String? barcode,
}) => InventoryItem(
  itemId: id,
  name: name,
  category: 'Hardware',
  quantity: quantity,
  location: 'Store',
  createdAt: DateTime.utc(2026, 1, 1),
  confidence: confidence,
  barcode: barcode,
);

void main() {
  test(
    'Home counts use unresolved identities, reorder points, kit gaps, and checkouts',
    () {
      final kit = ProjectKitDetail(
        id: 'kit-1',
        name: 'Fixture kit',
        location: 'Store',
        updatedAt: DateTime.utc(2026, 1, 1),
        summary: BomAnalysisSummary(
          totalLines: 1,
          readyLines: 0,
          partialLines: 1,
          missingLines: 0,
          readinessPercent: 0,
        ),
        items: [
          BomAnalysisItem(
            name: 'Bracket',
            partNumber: null,
            brand: null,
            requiredQuantity: 8,
            availableQuantity: 5,
            missingQuantity: 3,
            reservedQuantity: 0,
            unreservedAvailableQuantity: 5,
            status: 'partial',
          ),
        ],
        canReserve: true,
      );
      final metrics = HomeMetrics(
        items: [
          item('unresolved', 'Unidentified item', 2),
          item('weak', 'Metal bracket', 1, confidence: 0.6),
          item('confirmed', 'Cable', 3, confidence: 0.6, barcode: '123'),
          item('at-point', 'Washers', 5),
        ],
        thresholds: {'weak': 4, 'at-point': 5},
        kits: [kit],
        checkouts: [
          {'checkout_id': 'one'},
          {'checkout_id': 'two'},
        ],
      );

      expect(metrics.needsIdentifying, 2);
      expect(metrics.runningLow, 1);
      expect(metrics.missing, 3);
      expect(metrics.lentOut, 2);
    },
  );
}
