import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class ProStatus {
  static String _tier = 'free';
  static String? _teamName;

  static bool get isPro => _tier != 'free';
  static bool get isTeamCovered => _tier == 'team_member';
  static String get tier => _tier;
  static String? get teamName => _teamName;

  static Future<void> refresh(ApiClient api) async {
    try {
      final data = await api.getMyLimits();
      _tier = (data['tier'] as String?) ?? 'free';
      _teamName = data['plan']?['name'] as String?;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('plan_tier', _tier);
      if (_teamName != null) await prefs.setString('team_name', _teamName!);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      _tier = prefs.getString('plan_tier') ??
          ((prefs.getBool('is_pro') ?? false) ? 'pro' : 'free');
      _teamName = prefs.getString('team_name');
    }
  }

  static Future<void> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    _tier = prefs.getString('plan_tier') ??
        ((prefs.getBool('is_pro') ?? false) ? 'pro' : 'free');
    _teamName = prefs.getString('team_name');
  }

  static Future<void> setProImmediate() async {
    _tier = 'pro';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('plan_tier', 'pro');
  }

  static void reset() {
    _tier = 'free';
    _teamName = null;
  }
}
