import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Local presentation receipts only. Never reads or writes plan entitlements.
class FoundingAccessStore extends ChangeNotifier {
  static final instance = FoundingAccessStore();
  final _closed = <String>{};
  String seenKey(String id) => 'founding_access_seen_$id';
  String _pendingKey(String id) => 'founding_access_pending_$id';

  /// Bind only an account created during the authentication request. A recent
  /// account restored from disk, or an ordinary OAuth login, is not a signup.
  Future<void> recordSignup(
    User user,
    DateTime started, {
    bool email = false,
  }) async {
    final created = DateTime.tryParse(user.createdAt);
    if (user.isAnonymous ||
        created == null ||
        created.isBefore(started.subtract(const Duration(seconds: 5))) ||
        created.isAfter(
          DateTime.now().toUtc().add(const Duration(seconds: 5)),
        ) ||
        (email && (user.identities?.isEmpty ?? true))) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(seenKey(user.id)) == true ||
          _closed.contains(user.id)) {
        return;
      }
      if (!await prefs.setBool(_pendingKey(user.id), true)) {
        throw StateError('Local signup receipt was not saved');
      }
      notifyListeners();
    } catch (_) {
      debugPrint('Founding Access introduction could not be saved locally.');
    }
  }

  Future<bool> shouldShow(User user) async {
    if (user.isAnonymous ||
        user.emailConfirmedAt == null ||
        _closed.contains(user.id)) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingKey(user.id)) == true &&
        prefs.getBool(seenKey(user.id)) != true;
  }

  Future<void> dismiss(String id) async {
    _closed.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(seenKey(id), true)) {
        throw StateError('Not saved');
      }
      await prefs.remove(_pendingKey(id));
    } catch (_) {
      // Keep the in-process receipt even when device storage is unavailable.
      debugPrint(
        'Founding Access closed; the local receipt could not be saved.',
      );
    }
  }
}
