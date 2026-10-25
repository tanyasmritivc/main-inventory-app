import 'package:shared_preferences/shared_preferences.dart';

/// Per-account, device-local cue; never creates or imports demo inventory.
class FirstCameraHint {
  static String _key(String account) => 'findez.first-camera.$account';
  static Future<void> arm(String account) async {
    final prefs = await SharedPreferences.getInstance();
    // Do not re-arm after the first tap, including an interrupted handoff retry.
    if (!prefs.containsKey(_key(account)) &&
        !await prefs.setBool(_key(account), true)) {
      throw StateError('Could not remember camera hint');
    }
  }

  static Future<bool> pending(String account) async =>
      (await SharedPreferences.getInstance()).getBool(_key(account)) == true;
  static Future<void> consume(String account) async {
    if (!await (await SharedPreferences.getInstance()).setBool(
      _key(account),
      false,
    )) {
      throw StateError('Could not finish camera hint');
    }
  }
}
