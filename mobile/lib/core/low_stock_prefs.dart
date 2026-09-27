import 'api_client.dart';
import 'low_stock_notifications.dart';

class LowStockPrefs {
  static Future<Map<String, int>> loadAll(ApiClient api) async {
    final items = (await api.searchItems(query: '')).items;
    return {
      for (final item in items)
        if (item.reorderPoint != null && item.reorderPoint! > 0)
          item.itemId: item.reorderPoint!,
    };
  }

  static Future<void> setThreshold({
    required ApiClient api,
    required String itemId,
    required int? threshold,
  }) async {
    await api.setReorderPoint(
      itemId,
      threshold != null && threshold > 0 ? threshold : null,
    );
    if (threshold != null && threshold > 0) {
      await LowStockNotifications.enable();
    }
  }
}
