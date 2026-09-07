import 'package:flutter/services.dart';

import 'api_client.dart';

class PushNotifications {
  static const _channel = MethodChannel('com.findez.app/push');
  static Future<void> Function(Map<String, dynamic>)? _onNotificationTap;
  static bool _initialized = false;

  static Future<void> initialize({
    required Future<void> Function(Map<String, dynamic>) onNotificationTap,
  }) async {
    _onNotificationTap = onNotificationTap;
    if (!_initialized) {
      _initialized = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'notificationTapped') return;
        final arguments = call.arguments;
        if (arguments is Map) {
          await _onNotificationTap?.call(Map<String, dynamic>.from(arguments));
        }
      });
    }
    final initial = await _channel.invokeMapMethod<String, dynamic>(
      'getInitialNotification',
    );
    if (initial != null && initial.isNotEmpty) {
      await _onNotificationTap?.call(initial);
    }
  }

  static Future<bool> register(ApiClient api) async {
    final result = await _channel.invokeMapMethod<String, dynamic>('register');
    final token = result?['deviceToken']?.toString() ?? '';
    final environment = result?['environment']?.toString() ?? 'production';
    if (token.isEmpty) return false;
    await api.registerPushDevice(token: token, environment: environment);
    return true;
  }

  static Future<void> setBadgeCount(int count) async {
    await _channel.invokeMethod<void>('setBadgeCount', {
      'count': count < 0 ? 0 : count,
    });
  }
}
