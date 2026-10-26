import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';
import 'personalization_notifications.dart';

class PushNotifications {
  static const _channel = MethodChannel('com.findez.app/push');
  static Future<void> Function(Map<String, dynamic>)? _onNotificationTap;
  static final _received = StreamController<void>.broadcast();
  static Stream<void> get received => _received.stream;
  static bool _initialized = false;
  static ApiClient? _feedbackApi;
  static Map<String, dynamic>? _pendingTap;
  static Future<bool>? _registration;
  static Future<bool>? _permissionRequest;
  static String? _registrationAccount;
  static int _generation = 0;
  static ApiClient? _registeredApi;
  static String? _registeredToken, _registeredAccount;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<String> authorizationStatus() async {
    if (!supported) return 'unsupported';
    return await _channel.invokeMethod<String>('authorizationStatus') ??
        'notDetermined';
  }

  /// Ask once through iOS before sign-in; never register an anonymous device.
  /// iOS owns the durable decision, so upgrades and relaunches do not re-prompt.
  static Future<bool> requestPermissionIfNeeded() async {
    if (!supported) return false;
    final pending = _permissionRequest;
    if (pending != null) return pending;
    final request = _requestPermissionIfNeeded();
    _permissionRequest = request;
    try {
      return await request;
    } finally {
      if (identical(_permissionRequest, request)) _permissionRequest = null;
    }
  }

  static Future<bool> _requestPermissionIfNeeded() async {
    final status = await authorizationStatus();
    if (status == 'notDetermined') {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    }
    return ['authorized', 'provisional', 'ephemeral'].contains(status);
  }

  /// Authenticated shells and resumes reconnect without opening another prompt.
  static Future<bool> registerIfAuthorized(ApiClient api) async {
    final status = await authorizationStatus();
    if (!['authorized', 'provisional', 'ephemeral'].contains(status)) {
      final token = _registeredToken;
      if (token != null && _registeredAccount == api.accountId) {
        try {
          await api.unregisterPushDevice(token);
          _registeredToken = null;
          _registeredAccount = null;
          _registeredApi = null;
        } catch (_) {
          // Retry revocation on the next resume; iOS already blocks presentation.
        }
      }
      return false;
    }
    return register(api);
  }

  static Future<void> initialize({
    required Future<void> Function(Map<String, dynamic>) onNotificationTap,
    ApiClient? api,
  }) async {
    if (!supported) return;
    _onNotificationTap = onNotificationTap;
    _feedbackApi = api;
    if (!_initialized) {
      _initialized = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'notificationReceived') {
          _received.add(null);
          if (_feedbackApi != null && call.arguments is Map) {
            unawaited(
              PersonalizationNotifications.feedback(
                _feedbackApi!,
                Map<String, dynamic>.from(call.arguments as Map),
                'delivered',
              ),
            );
          }
          return;
        }
        if (call.method == 'notificationDismissed') {
          if (_feedbackApi != null && call.arguments is Map) {
            unawaited(
              PersonalizationNotifications.feedback(
                _feedbackApi!,
                Map<String, dynamic>.from(call.arguments as Map),
                'dismissed',
              ),
            );
          }
          return;
        }
        if (call.method != 'notificationTapped') return;
        final arguments = call.arguments;
        if (arguments is Map) {
          final payload = Map<String, dynamic>.from(arguments);
          if (_onNotificationTap == null) {
            _pendingTap = payload;
          } else {
            await _onNotificationTap!(payload);
          }
        }
      });
    }
    final pending = _pendingTap;
    _pendingTap = null;
    if (pending != null) await _onNotificationTap?.call(pending);
    final initial = await _channel.invokeMapMethod<String, dynamic>(
      'getInitialNotification',
    );
    if (initial != null && initial.isNotEmpty) {
      if (initial['findez_feedback'] == 'dismissed') {
        if (api != null) {
          unawaited(
            PersonalizationNotifications.feedback(api, initial, 'dismissed'),
          );
        }
      } else {
        await _onNotificationTap?.call(initial);
      }
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
    if (api.accountId != account || generation != _generation) return false;
    _registeredApi = api;
    _registeredToken = token;
    _registeredAccount = account;
    return true;
  }

  /// Stop OS delivery and clear displayed alerts before leaving an account.
  /// The server token is reassigned to the authenticated user on the next registration.
  static Future<void> stop() async {
    final api = _registeredApi,
        token = _registeredToken,
        account = _registeredAccount;
    _registeredApi = null;
    _registeredToken = null;
    _registeredAccount = null;
    _generation++;
    _onNotificationTap = null;
    _feedbackApi = null;
    _pendingTap = null;
    if (!supported) return;
    await _channel.invokeMethod<void>('unregister');
    if (api != null && token != null && api.accountId == account) {
      try {
        await api
            .unregisterPushDevice(token)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        /* OS delivery is stopped; the next account registration rebinds the token. */
      }
    }
  }

  static Future<void> setBadgeCount(int count) async {
    if (!supported) return;
    await _channel.invokeMethod<void>('setBadgeCount', {
      'count': count < 0 ? 0 : count,
    });
  }
}
