import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_preferences.dart';
import 'api_client.dart';
import 'restock_plan.dart';

class LowStockCandidate {
  const LowStockCandidate({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.threshold,
    required this.spaceName,
  });

  final String itemId;
  final String name;
  final int quantity;
  final int threshold;
  final String spaceName;
}

class LowStockNotifications {
  static const _enabledKey = 'low_stock_notifications_enabled';
  static const _activeKey = 'low_stock_notification_active_items';
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized || !Platform.isIOS) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  // Phone-local sends cannot enforce account-wide quiet hours or frequency caps.
  // Retain the compatibility entry point while the server owns all new alerts.
  static Future<bool> enable() async => false;

  static Future<void> evaluate(
    List<LowStockCandidate> candidates, {
    required ApiClient api,
  }) async {
    if (!Platform.isIOS) return;
    final account = RestockPrefs.accountKey;
    // Import only absent rules. A saved server edit/tombstone always wins over
    // another phone's older local copy. Quantities never leave this request.
    for (var offset = 0; offset < candidates.length; offset += 500) {
      if (account != RestockPrefs.accountKey) return;
      final batch = candidates.skip(offset).take(500);
      final rules = await api.syncNotificationStockRules({
        for (final item in batch)
          item.itemId: item.threshold < 0 ? null : item.threshold,
      }, importOnly: true);
      if (account != RestockPrefs.accountKey) return;
      if (rules != null) {
        for (final item in batch) {
          if (!rules.containsKey(item.itemId)) continue;
          final value = (rules[item.itemId] as num?)?.toInt();
          if (value != (item.threshold < 0 ? null : item.threshold)) {
            if (account != RestockPrefs.accountKey) return;
            await RestockPrefs.setThreshold(item.itemId, value);
          }
        }
      }
    }
    final prefs = await SharedPreferences.getInstance();
    if (account != RestockPrefs.accountKey) return;
    final key = accountPreferenceKey(_activeKey);
    final raw = prefs.getString(key);
    if (raw == null) return;
    await initialize();
    List<dynamic> active;
    try {
      active = json.decode(raw) as List<dynamic>;
    } catch (_) {
      active = [];
    }
    for (final itemId in active) {
      if (account != RestockPrefs.accountKey) return;
      await _plugin.cancel(id: itemId.toString().hashCode & 0x7fffffff);
    }
    if (account != RestockPrefs.accountKey) return;
    await prefs.remove(key);
    await prefs.remove(accountPreferenceKey(_enabledKey));
  }
}
