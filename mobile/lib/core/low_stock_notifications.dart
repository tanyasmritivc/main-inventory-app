import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_preferences.dart';

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

  static Future<bool> enable() async {
    if (!Platform.isIOS) return false;
    await initialize();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final allowed = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(accountPreferenceKey(_enabledKey), allowed);
    return allowed;
  }

  static Future<void> evaluate(List<LowStockCandidate> candidates) async {
    if (!Platform.isIOS || candidates.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final enabledKey = accountPreferenceKey(_enabledKey);
    final enabled = prefs.getBool(enabledKey);
    if (enabled == false) return;
    if (enabled == null && !await enable()) return;
    await initialize();

    final rawActive = prefs.getString(accountPreferenceKey(_activeKey));
    final active = <String>{};
    if (rawActive != null) {
      try {
        active.addAll((json.decode(rawActive) as List).map((e) => e.toString()));
      } catch (_) {
        // A corrupt deduplication cache should never block inventory loading.
      }
    }

    final currentlyLow = candidates
        .where((item) => item.quantity <= item.threshold)
        .map((item) => item.itemId)
        .toSet();
    final evaluatedIds = candidates.map((item) => item.itemId).toSet();
    active.removeWhere((itemId) =>
        evaluatedIds.contains(itemId) && !currentlyLow.contains(itemId));

    for (final item in candidates.where(
      (item) => item.quantity <= item.threshold && !active.contains(item.itemId),
    )) {
      final location = item.spaceName.trim().isEmpty
          ? ''
          : ' in ${item.spaceName.trim()}';
      await _plugin.show(
        id: item.itemId.hashCode & 0x7fffffff,
        title: item.quantity <= 0 ? '${item.name} is out of stock' : '${item.name} is running low',
        body: '${item.quantity} remaining$location. Restock threshold: ${item.threshold}.',
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

    await prefs.setString(
      accountPreferenceKey(_activeKey),
      json.encode(active.toList()),
    );
  }
}
