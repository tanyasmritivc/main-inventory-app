import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void onboardingEvent(String name, [Map<String, Object> values = const {}]) {
  developer.log('$name $values', name: 'findez.onboarding');
}

/// Pre-auth answers are never attached to an arbitrary returning session.
/// The separate receipt binds retries (including email verification) to a user.
class OnboardingV5Store {
  static const key = 'findez_onboarding';
  static const receiptKey = 'findez_onboarding_v5_receipts';
  static const attemptKey = 'findez_onboarding_v5_attempt';
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function(SharedPreferences) action) {
    final next = _tail.then(
      (_) async => action(await SharedPreferences.getInstance()),
    );
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Map<String, dynamic> _decode(String? raw) {
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  Future<Map<String, dynamic>> read() =>
      _serial((p) async => _decode(p.getString(key)));

  Future<void> save(Map<String, dynamic> answers) => _serial((p) async {
    if (!await p.setString(key, jsonEncode(answers))) {
      throw StateError('Could not save answers');
    }
  });

  Future<void> discard() => _serial((p) async {
    await p.remove(key);
    await p.remove(attemptKey);
    // Account-bound failed writes remain available to their original account.
  });

  Future<void> beginAuth(String method, bool signup) => _serial((p) async {
    if (!signup) {
      await p.remove(key);
      await p.remove(attemptKey);
      return;
    }
    final answers = _decode(p.getString(key));
    answers['completed_at'] = DateTime.now().toUtc().toIso8601String();
    if (!await p.setString(key, jsonEncode(answers)) ||
        !await p.setString(
          attemptKey,
          jsonEncode({
            'method': method,
            'started_at': DateTime.now().toUtc().toIso8601String(),
            'answers': answers,
          }),
        )) {
      throw StateError('Could not save answers');
    }
  });

  /// Native ID-token auth does not expose an is-new-user flag. Only a user
  /// created during this explicit signup attempt can acquire an unbound draft.
  Future<bool> bind(User user) => _serial((p) async {
    final receipts = _decode(p.getString(receiptKey));
    if (receipts.containsKey(user.id)) return true;
    final attempt = _decode(p.getString(attemptKey));
    final started = DateTime.tryParse('${attempt['started_at']}');
    final created = DateTime.tryParse(user.createdAt);
    if (started == null ||
        created == null ||
        created.isBefore(started.subtract(const Duration(seconds: 5))) ||
        created.isAfter(
          DateTime.now().toUtc().add(const Duration(seconds: 5)),
        ) ||
        user.userMetadata?['onboarding'] != null) {
      return false;
    }
    // An email signup with an empty identity list can be an obfuscated duplicate.
    if (attempt['method'] == 'email' && (user.identities?.isEmpty ?? true)) {
      return false;
    }
    receipts[user.id] = attempt;
    if (!await p.setString(receiptKey, jsonEncode(receipts))) {
      throw StateError('Could not retain answers');
    }
    await p.remove(attemptKey);
    return true;
  });

  Future<bool> hasPending(String userId) => _serial(
    (p) async => _decode(p.getString(receiptKey)).containsKey(userId),
  );

  Future<String?> sync(SupabaseClient client) async {
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) return null;
    final receipt = await _serial(
      (p) async => _decode(p.getString(receiptKey))[user.id],
    );
    if (receipt is! Map || client.auth.currentUser?.id != user.id) return null;
    final answers = Map<String, dynamic>.from(receipt['answers'] as Map);
    final response = await client.auth.updateUser(
      UserAttributes(data: {'onboarding': answers}),
    );
    if (response.user?.id != user.id) {
      throw StateError('Account changed while saving answers');
    }
    await _serial((p) async {
      final receipts = _decode(p.getString(receiptKey));
      receipts.remove(user.id);
      await p.setString(receiptKey, jsonEncode(receipts));
      // Do not erase a different person's newer draft during a late response.
      if (p.getString(key) == jsonEncode(answers)) await p.remove(key);
    });
    return receipt['method'] as String?;
  }
}
