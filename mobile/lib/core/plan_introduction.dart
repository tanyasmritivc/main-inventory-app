import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

const planIntroductionVersion = 1;

/// Email signup carries a pending marker through verification. For a new native
/// OAuth account, creation and first sign-in must agree; an ordinary returning
/// user's sign-in does not qualify. Remember eligibility locally before showing.
bool isNewPlanSignup(User user, DateTime now) {
  if (user.isAnonymous || user.emailConfirmedAt == null) return false;
  if (user.userMetadata?['findez_plan_intro_version'] ==
      planIntroductionVersion) {
    return false;
  }
  if (user.userMetadata?['findez_mobile_plan_intro_pending'] == true) {
    return true;
  }
  final created = DateTime.tryParse(user.createdAt);
  final signedIn = DateTime.tryParse(user.lastSignInAt ?? '');
  if (created == null || signedIn == null) return false;
  final age = now.difference(created);
  return !age.isNegative &&
      age < const Duration(hours: 24) &&
      signedIn.difference(created).abs() < const Duration(minutes: 1);
}

class PlanIntroductionStore {
  PlanIntroductionStore({
    http.Client? client,
    Session? Function()? session,
    this.url = AppConfig.supabaseUrl,
    this.anonKey = AppConfig.supabaseAnonKey,
  }) : _client = client,
       _session =
           session ?? (() => Supabase.instance.client.auth.currentSession);
  final http.Client? _client;
  final Session? Function() _session;
  final String url, anonKey;
  static final _dismissed = <String>{};
  String _key(User user) => 'findez_plan_intro_v1:${user.id}';

  Future<bool> shouldShow(User user) async {
    if (user.isAnonymous || user.emailConfirmedAt == null) return false;
    if (user.userMetadata?['findez_plan_intro_version'] ==
        planIntroductionVersion) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    if (_dismissed.contains(user.id) ||
        prefs.getString(_key(user)) == 'dismissed') {
      await _sync(
        user,
      ); // Best-effort retry, never reopen an offline dismissal.
      return false;
    }
    if (prefs.getString(_key(user)) == 'pending' ||
        isNewPlanSignup(user, DateTime.now().toUtc())) {
      await prefs.setString(_key(user), 'pending');
      return true;
    }
    return false;
  }

  /// Returns whether the server confirmed synchronization, not just local close.
  /// No subscription or inventory entitlement is written here.
  Future<bool> dismiss(User user) async {
    _dismissed.add(user.id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(user), 'dismissed');
    } catch (_) {
      // Memory fallback prevents repeat prompts this process; server still tried.
    }
    return _sync(user);
  }

  Future<bool> _sync(User user) async {
    final session = _session();
    if (session == null || session.user.id != user.id || session.isExpired) {
      return false;
    }
    final client = _client ?? http.Client();
    try {
      // Capture the bearer: a later account switch cannot redirect this write.
      final response = await client
          .put(
            Uri.parse('$url/auth/v1/user'),
            headers: {
              'apikey': anonKey,
              'Authorization': 'Bearer ${session.accessToken}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'data': {
                'findez_plan_intro_version': planIntroductionVersion,
                'findez_mobile_plan_intro_pending': false,
              },
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      return data is Map &&
          data['id'] == user.id &&
          data['user_metadata']?['findez_plan_intro_version'] ==
              planIntroductionVersion;
    } catch (_) {
      return false; // Caller knows sync is pending; no claim of a saved plan.
    } finally {
      if (_client == null) client.close();
    }
  }
}
