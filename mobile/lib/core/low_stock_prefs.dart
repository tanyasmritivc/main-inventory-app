import 'low_stock_notifications.dart';
import 'restock_plan.dart';

class LowStockPrefs {
  static Future<Map<String, int>> loadAll() async {
    return (await RestockPrefs.load()).thresholds;
  }

  static Future<void> setThreshold({
    required String itemId,
    required int? threshold,
  }) async {
    await RestockPrefs.setThreshold(itemId, threshold);
    if (threshold != null && threshold >= 0) {
      await LowStockNotifications.enable();
    }
  }
}
