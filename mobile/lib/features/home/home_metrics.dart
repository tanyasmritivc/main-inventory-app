import '../../core/api_client.dart';

class HomeMetrics {
  const HomeMetrics({
    required this.items,
    required this.thresholds,
    required this.kits,
    required this.checkouts,
  });

  final List<InventoryItem> items;
  final Map<String, int> thresholds;
  final List<ProjectKitDetail> kits;
  final List<Map<String, dynamic>> checkouts;

  List<InventoryItem> get needsIdentifyingItems =>
      items.where((item) => !item.identityConfirmed).toList();

  int get needsIdentifying => needsIdentifyingItems.length;

  int get runningLow => items.where((item) {
    final point = thresholds[item.itemId];
    return point != null && point > 0 && item.quantity < point;
  }).length;

  int get missing => kits.fold(
    0,
    (total, kit) =>
        total + kit.items.fold(0, (sum, item) => sum + item.missingQuantity),
  );

  int get lentOut => checkouts.length;
}
