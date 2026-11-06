import 'restock_plan.dart';
import 'api_client.dart';

class LowStockPrefs {
  static Future<Map<String, int>> loadAll() async {
    return (await RestockPrefs.load()).thresholds;
  }

  static Future<void> setThreshold({
    required String itemId,
    required int? threshold,
    ApiClient? api,
  }) async {
    final account = RestockPrefs.accountKey;
    if (api != null) await api.syncNotificationStockRules({itemId: threshold});
    if (account != RestockPrefs.accountKey) {
      throw StateError('Account changed. Reopen the item.');
    }
    await RestockPrefs.setThreshold(itemId, threshold);
  }
}
