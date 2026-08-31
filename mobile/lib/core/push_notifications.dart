import 'package:flutter/services.dart';

import 'api_client.dart';

class PushNotifications {
  static const _channel = MethodChannel('com.findez.app/push');

  static Future<bool> register(ApiClient api) async {
    final result = await _channel.invokeMapMethod<String, dynamic>('register');
    final token = result?['deviceToken']?.toString() ?? '';
    final environment = result?['environment']?.toString() ?? 'production';
    if (token.isEmpty) return false;
    await api.registerPushDevice(token: token, environment: environment);
    return true;
  }
}
