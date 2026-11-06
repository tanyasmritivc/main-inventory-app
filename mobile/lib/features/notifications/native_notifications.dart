import 'dart:async';
import 'package:flutter/services.dart';

/// Notifications has its own channel; Chats and Settings are not reconfigured.
class NativeNotifications {
  static const channel = MethodChannel('com.findez.app/notifications');
  static int _next = 0;
  final String token = 'notifications-${++_next}';
  bool _open = false;

  Future<String?> show(
    Map<String, dynamic> model,
    Future<void> Function(String) onAction,
  ) async {
    _open = true;
    channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      if (!_open ||
          call.method != 'action' ||
          args is! Map ||
          args['token'] != token ||
          args['id'] is! String) {
        return;
      }
      await onAction(args['id'] as String);
    });
    try {
      return await channel.invokeMethod<String>('present', {
        ...model,
        'token': token,
      });
    } finally {
      _open = false;
      channel.setMethodCallHandler(null);
    }
  }

  Future<void> update(Map<String, dynamic> model) async {
    if (_open) {
      await channel.invokeMethod<void>('update', {...model, 'token': token});
    }
  }

  void dispose() {
    if (!_open) return;
    _open = false;
    unawaited(channel.invokeMethod<void>('dismiss', {'token': token}));
  }
}
