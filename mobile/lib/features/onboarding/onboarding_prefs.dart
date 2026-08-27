import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPrefs {
  /// In-memory only, synchronous signal set the instant a signup is
  /// initiated (before any async calls). Used to avoid a race where
  /// Supabase's onAuthStateChange stream navigates to MainShell before the
  /// persisted coachmark-pending flag write has completed.
  static bool justSignedUp = false;

  static const _kCompleted = 'onboarding_completed';
  static const _kPersona = 'onboarding_persona';
  static const _kPostSignupPending = 'onboarding_post_signup_pending';
  static const _kCoachmarkPendingPrefix = 'coachmark_pending_';
  static const _kCoachmarkSeenPrefix = 'coachmark_seen_';

  static String _coachmarkPendingKey(String userId) => '$_kCoachmarkPendingPrefix$userId';
  static String _coachmarkSeenKey(String userId) => '$_kCoachmarkSeenPrefix$userId';

  static Future<bool> isCoachmarkPending(String userId) async {
    if (userId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final key = _coachmarkPendingKey(userId);
    final result = prefs.getBool(key) ?? false;
    return result;
  }

  static Future<void> setCoachmarkPending(String userId, bool value) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _coachmarkPendingKey(userId);
    await prefs.setBool(key, value);
  }

  static Future<bool> hasSeenCoachmark(String userId) async {
    if (userId.isEmpty) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_coachmarkSeenKey(userId)) ?? false;
  }

  static Future<void> markCoachmarkSeen(String userId) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_coachmarkSeenKey(userId), true);
    await prefs.setBool(_coachmarkPendingKey(userId), false);
  }

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kCompleted) ?? false;
  }

  static Future<void> setCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCompleted, value);
  }

  static Future<bool> isPostSignupPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPostSignupPending) ?? false;
  }

  static Future<void> setPostSignupPending(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPostSignupPending, value);
  }

  static Future<String?> getPersona() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPersona);
  }

  static Future<void> setPersona(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_kPersona);
      return;
    }
    await prefs.setString(_kPersona, value.trim());
  }
}
