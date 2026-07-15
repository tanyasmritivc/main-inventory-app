import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class ProStatus {
  static bool _isPro = false;

  static bool get isPro => _isPro;

  static Future<bool> refresh(ApiClient api) async {
    try {
      final result = await api.getSubscriptionStatus();
      _isPro = result;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_pro', result);
      return result;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      _isPro = prefs.getBool('is_pro') ?? false;
      return _isPro;
    }
  }

  static Future<void> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool('is_pro') ?? false;
  }

  static Future<void> setProImmediate() async {
    _isPro = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_pro', true);
  }

  static void reset() {
    _isPro = false;
  }
}
