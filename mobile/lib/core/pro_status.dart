import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProStatus {
  /// Display fallback only; billing and access remain controlled by the API.
  static const defaultPilotNotice =
      'Free pre-launch access. Plan quotas are not enforced during this period. '
      'There is no automatic cutoff date. '
      'You will not be charged automatically.';

  static String _tier = 'free';
  static int _generation = 0;
  static bool _limitsEnabled = false;
  static String? _currentAccount() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static String? _apiAccount(ApiClient api) {
    try {
      return api.accountId;
    } catch (_) {
      return null;
    }
  }

  static bool get shouldOfferUpgrade => _limitsEnabled && !_isPilotMode;
  static String? _teamName;
  static bool _isPilotMode = false;
  static String? _pilotEndsAt;
  static String? _pilotNotice;

  static bool get isPro => _tier != 'free';
  static bool get isTeamCovered => _tier == 'team_member';
  static bool get isPilotMode => _isPilotMode;
  static String? get pilotEndsAt => _pilotEndsAt;
  static String? get pilotNotice => _pilotNotice;
  static String get tier => _tier;
  static String? get teamName => _teamName;

  static Future<void> refresh(ApiClient api) async {
    final actor = _apiAccount(api);
    final run = ++_generation;
    _limitsEnabled = false;
    try {
      final data = await api.getMyLimits();
      if (run != _generation || _apiAccount(api) != actor) return;
      _limitsEnabled =
          data['limits_enabled'] == true && data['pilot_mode'] == false;
      _tier = (data['tier'] as String?) ?? 'free';
      _teamName = data['plan']?['name'] as String?;
      _isPilotMode = (data['pilot_mode'] as bool?) ?? false;
      _pilotEndsAt = data['pilot_ends_at'] as String?;
      _pilotNotice = data['pilot_notice'] as String?;
      final prefs = await SharedPreferences.getInstance();
      if (actor != null) {
        await prefs.setString('plan_owner', actor);
      } else {
        await prefs.remove('plan_owner');
      }
      await prefs.setString('plan_tier', _tier);
      await prefs.setBool('pilot_mode', _isPilotMode);
      if (_teamName != null) {
        await prefs.setString('team_name', _teamName!);
      } else {
        await prefs.remove('team_name');
      }
      if (_pilotEndsAt != null) {
        await prefs.setString('pilot_ends_at', _pilotEndsAt!);
      } else {
        await prefs.remove('pilot_ends_at');
      }
      if (_pilotNotice != null) {
        await prefs.setString('pilot_notice', _pilotNotice!);
      } else {
        await prefs.remove('pilot_notice');
      }
    } catch (_) {
      if (run != _generation || _apiAccount(api) != actor) return;
      await _loadFor(actor, run);
    }
  }

  static Future<void> loadCached() =>
      _loadFor(_currentAccount(), ++_generation);

  static Future<void> _loadFor(String? actor, int run) async {
    final prefs = await SharedPreferences.getInstance();
    if (run != _generation) return;
    final matches = actor != null && prefs.getString('plan_owner') == actor;
    _tier = matches ? (prefs.getString('plan_tier') ?? 'free') : 'free';
    _teamName = matches ? prefs.getString('team_name') : null;
    // Pilot is a service-wide presentation policy, never a paid entitlement.
    _isPilotMode = prefs.getBool('pilot_mode') ?? false;
    _pilotEndsAt = prefs.getString('pilot_ends_at');
    // Old app versions cached a fixed November cutoff. It is not an access rule.
    _pilotNotice = _isPilotMode ? defaultPilotNotice : null;
    _limitsEnabled =
        false; // Never offer an upgrade from an unverified cached quota.
  }

  static void reset() {
    _generation++;
    _limitsEnabled = false;
    _tier = 'free';
    _teamName = null;
    _isPilotMode = false;
    _pilotEndsAt = null;
    _pilotNotice = null;
  }
}
