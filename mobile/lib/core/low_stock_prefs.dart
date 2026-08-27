import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'account_preferences.dart';

class LowStockPrefs {
  static const _kKey = 'low_stock_thresholds';

  static Future<Map<String, int>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final accountKey = accountPreferenceKey(_kKey);
    var raw = prefs.getString(accountKey);
    final legacy = prefs.getString(_kKey);
    if (raw == null && legacy != null && !accountKey.endsWith(':signed-out')) {
      raw = legacy;
      await prefs.setString(accountKey, legacy);
      await prefs.remove(_kKey);
    }
    if (raw == null || raw.trim().isEmpty) return <String, int>{};

    try {
      final obj = (json.decode(raw) as Map).cast<String, dynamic>();
      final out = <String, int>{};
      for (final e in obj.entries) {
        final v = e.value;
        if (v is num) {
          out[e.key] = v.toInt();
        } else {
          final parsed = int.tryParse(v.toString());
          if (parsed != null) out[e.key] = parsed;
        }
      }
      return out;
    } catch (_) {
      return <String, int>{};
    }
  }

  static Future<void> setThreshold({required String itemId, required int? threshold}) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();

    if (threshold == null || threshold <= 0) {
      all.remove(itemId);
    } else {
      all[itemId] = threshold;
    }

    await prefs.setString(accountPreferenceKey(_kKey), json.encode(all));
  }
}
