import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';

class PushNotifications {
  static const _channel = MethodChannel('com.findez.app/push');
  static Future<void> Function(Map<String, dynamic>)? _onNotificationTap;
  static bool _initialized = false;
  static Future<bool>? _registration;
  static String? _registrationAccount;
  static int _generation = 0;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<String> authorizationStatus() async {
    if (!supported) return 'unsupported';
    return await _channel.invokeMethod<String>('authorizationStatus') ??
        'notDetermined';
  }

  /// A launch or resume may reconnect existing permission, never request it.
  static Future<bool> registerIfAuthorized(ApiClient api) async {
    final status = await authorizationStatus();
    if (!['authorized', 'provisional', 'ephemeral'].contains(status)) {
      return false;
    }
    return register(api);
  }

  static Future<void> initialize({
    required Future<void> Function(Map<String, dynamic>) onNotificationTap,
  }) async {
    if (!supported) return;
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
    if (!supported) return false;
    final account = api.accountId;
    if (account == null) return false;
    final pending = _registration;
    if (pending != null) {
      if (_registrationAccount == account) return pending;
      try {
        await pending;
      } catch (_) {
        /* The new account can retry independently. */
      }
      if (api.accountId != account) return false;
      return register(api);
    }
    final generation = _generation;
    final request = _register(api, account, generation);
    _registration = request;
    _registrationAccount = account;
    try {
      return await request;
    } finally {
      if (identical(_registration, request)) {
        _registration = null;
        _registrationAccount = null;
      }
    }
  }

  static Future<bool> _register(
    ApiClient api,
    String account,
    int generation,
  ) async {
    final result = await _channel.invokeMapMethod<String, dynamic>('register');
    if (api.accountId != account || generation != _generation) return false;
    final token = result?['deviceToken']?.toString() ?? '';
    final environment = result?['environment']?.toString() ?? 'production';
    if (token.isEmpty) return false;
    await api.registerPushDevice(token: token, environment: environment);
    return api.accountId == account && generation == _generation;
  }

  /// Stop OS delivery and clear displayed alerts before leaving an account.
  /// The server token is reassigned to the authenticated user on the next registration.
  static Future<void> stop() async {
    _generation++;
    _onNotificationTap = null;
    if (!supported) return;
    await _channel.invokeMethod<void>('unregister');
  }

  static Future<void> setBadgeCount(int count) async {
    if (!supported) return;
    await _channel.invokeMethod<void>('setBadgeCount', {
      'count': count < 0 ? 0 : count,
    });
  }
}
