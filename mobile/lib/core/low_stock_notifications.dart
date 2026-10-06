import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_preferences.dart';
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

  static Future<bool> enable() => _enableFor(RestockPrefs.accountKey);

  static Future<bool> _enableFor(String account) async {
    if (!Platform.isIOS) return false;
    await initialize();
    if (account != RestockPrefs.accountKey) return false;
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final allowed =
        await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
    final prefs = await SharedPreferences.getInstance();
    if (account != RestockPrefs.accountKey) return false;
    await prefs.setBool(accountPreferenceKey(_enabledKey), allowed);
    return allowed;
  }

  static Future<void> evaluate(List<LowStockCandidate> candidates) async {
    if (!Platform.isIOS || candidates.isEmpty) return;
    final account = RestockPrefs.accountKey;
    final plan = await RestockPrefs.load();
    if (account != RestockPrefs.accountKey) return;
    final prefs = await SharedPreferences.getInstance();
    if (account != RestockPrefs.accountKey) return;
    final enabledKey = accountPreferenceKey(_enabledKey);
    final enabled = prefs.getBool(enabledKey);
    if (enabled == false) return;
    if (enabled == null && !await _enableFor(account)) return;
    await initialize();
    if (account != RestockPrefs.accountKey) return;

    final rawActive = prefs.getString(accountPreferenceKey(_activeKey));
    final active = <String>{};
    if (rawActive != null) {
      try {
        active.addAll(
          (json.decode(rawActive) as List).map((e) => e.toString()),
        );
      } catch (_) {
        // A corrupt deduplication cache should never block inventory loading.
      }
    }

    final currentlyLow = candidates
        .where((item) => plan.needsBuying(item.itemId, item.quantity))
        .map((item) => item.itemId)
        .toSet();
    final evaluatedIds = candidates.map((item) => item.itemId).toSet();
    for (final itemId
        in active
            .where(
              (id) => evaluatedIds.contains(id) && !currentlyLow.contains(id),
            )
            .toList()) {
      if (account != RestockPrefs.accountKey) return;
      await _plugin.cancel(id: itemId.hashCode & 0x7fffffff);
      active.remove(itemId);
    }

    for (final item in candidates.where(
      (item) =>
          plan.needsBuying(item.itemId, item.quantity) &&
          !active.contains(item.itemId),
    )) {
      if (account != RestockPrefs.accountKey) return;
      final location = item.spaceName.trim().isEmpty
          ? ''
          : ' in ${item.spaceName.trim()}';
      await _plugin.show(
        id: item.itemId.hashCode & 0x7fffffff,
        title: '${item.name} is on your to-buy list',
        body:
            '${item.quantity} on hand$location. Open the restock planner to track your purchase.',
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: true,
          ),
        ),
        payload: 'inventory-item:${item.itemId}',
      );
      active.add(item.itemId);
    }

    if (account != RestockPrefs.accountKey) return;
    await prefs.setString(
      accountPreferenceKey(_activeKey),
      json.encode(active.toList()),
    );
  }
}
