import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class ProStatus {
  static String _tier = 'free';
  static String? _teamName;
  static bool _isPilotMode = false;

  static bool get isPro => _tier != 'free';
  static bool get isTeamCovered => _tier == 'team_member';
  static bool get isPilotMode => _isPilotMode;
  static String get tier => _tier;
  static String? get teamName => _teamName;

  static Future<void> refresh(ApiClient api) async {
    try {
      final data = await api.getMyLimits();
      _tier = (data['tier'] as String?) ?? 'free';
      _teamName = data['plan']?['name'] as String?;
      _isPilotMode = (data['pilot_mode'] as bool?) ?? false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('plan_tier', _tier);
      await prefs.setBool('pilot_mode', _isPilotMode);
      if (_teamName != null) await prefs.setString('team_name', _teamName!);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      _tier = prefs.getString('plan_tier') ??
          ((prefs.getBool('is_pro') ?? false) ? 'pro' : 'free');
      _teamName = prefs.getString('team_name');
      // Fall back to cached pilot value so we never unexpectedly show a paywall.
      _isPilotMode = prefs.getBool('pilot_mode') ?? false;
    }
  }

  static Future<void> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    _tier = prefs.getString('plan_tier') ??
        ((prefs.getBool('is_pro') ?? false) ? 'pro' : 'free');
    _teamName = prefs.getString('team_name');
    _isPilotMode = prefs.getBool('pilot_mode') ?? false;
  }

  static Future<void> setProImmediate() async {
    _tier = 'pro';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('plan_tier', 'pro');
  }

  static void reset() {
    _tier = 'free';
    _teamName = null;
    _isPilotMode = false;
  }
}
