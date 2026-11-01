import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPrefs {
  /// Legacy authentication signal retained for existing signup flows.
  /// Guided-tour eligibility uses installation storage instead.
  static bool justSignedUp = false;

  static const _kCompleted = 'onboarding_completed';
  static const _kPersona = 'onboarding_persona';
  static const _kPostSignupPending = 'onboarding_post_signup_pending';
  static const _kPendingFirstSpaceName = 'onboarding_first_space_name';
  static const _kCoachmarkPendingPrefix = 'coachmark_pending_';
  static const _kCoachmarkSeenPrefix = 'coachmark_seen_';
  static const _kTourInstall = 'guided_tour_install_state';
  static Future<void>? _tourPending;

  static Future<T> _withTourStorage<T>(Future<T> Function() action) async {
    while (_tourPending != null) {
      await _tourPending;
    }
    final lock = Completer<void>();
    _tourPending = lock.future;
    try {
      return await action();
    } finally {
      _tourPending = null;
      lock.complete();
    }
  }

  /// Called before authentication UI can write new onboarding preferences.
  /// An update of an existing installation must never schedule another tour.
  static Future<void> prepareGuidedTourInstall({required bool hasSession}) =>
      _withTourStorage(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        if (prefs.containsKey(_kTourInstall)) return;
        final legacy =
            hasSession ||
            prefs.getKeys().any(
              (key) =>
                  key.startsWith('onboarding_') ||
                  key.startsWith('tutorial_done_') ||
                  key.startsWith('coachmark_') ||
                  key.startsWith('space_discovery_done_'),
            );
        if (!await prefs.setString(
          _kTourInstall,
          legacy ? 'consumed' : 'pending',
        )) {
          throw StateError('Tour launch state could not be saved');
        }
      });

  /// Consume the installation's one automatic attempt before displaying it.
  /// A closed/interrupted tour, new login or new account cannot re-arm it.
  static Future<bool> claimGuidedTour() => _withTourStorage(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.get(_kTourInstall) != 'pending') return false;
    return prefs.setString(_kTourInstall, 'consumed');
  });

  static String _coachmarkPendingKey(String userId) =>
      '$_kCoachmarkPendingPrefix$userId';
  static String _coachmarkSeenKey(String userId) =>
      '$_kCoachmarkSeenPrefix$userId';

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
    // Read confirmed storage, not a cache populated by a failed platform write.
    await prefs.reload();
    return prefs.get(_kCompleted) == true;
  }

  static Future<void> setCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_kCompleted, value)) {
      throw StateError('Onboarding progress was not saved');
    }
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

  static Future<String?> getPendingFirstSpaceName() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kPendingFirstSpaceName)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static Future<void> setPendingFirstSpaceName(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      await prefs.remove(_kPendingFirstSpaceName);
      return;
    }
    await prefs.setString(_kPendingFirstSpaceName, normalized);
  }
}
