import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';
import 'config.dart';

/// A shell-owned, memory-only account snapshot. Never reused across accounts.
class ProfileStore extends ChangeNotifier {
  ProfileStore({required this.api, String? Function()? ownerId})
    : _ownerId =
          ownerId ?? (() => Supabase.instance.client.auth.currentUser?.id) {
    _owner = _ownerId();
    _auth = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (_owner == _ownerId()) return;
      _resetOwner();
      if (_owner != null) unawaited(load());
    });
  }
  final ApiClient api;
  final String? Function() _ownerId;
  StreamSubscription<AuthState>? _auth;
  String? _owner;
  Map<String, dynamic> _profile = {};
  Future<void>? _pending;
  DateTime? _loadedAt;
  int _generation = 0;
  bool _disposed = false;
  bool loading = false;
  bool failed = false;
  int photoRevision = 0;

  String? get owner => _ownerId();
  Map<String, dynamic> get profile =>
      _owner == owner ? Map.unmodifiable(_profile) : const {};
  String text(String field) =>
      profile[field] is String ? (profile[field] as String).trim() : '';
  String get name => text('display_name');
  String get email => text('email');
  String get color => text('avatar_color');
  String get photoUrl =>
      trustedProfilePhotoUrl(
        text('avatar_url'),
        owner: owner,
        origins: [api.baseUrl, AppConfig.supabaseUrl],
      ) ??
      '';

  void _resetOwner() {
    photoRevision++;
    _generation++;
    _owner = owner;
    _profile = {};
    _pending = null;
    _loadedAt = null;
    loading = false;
    failed = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> load({bool force = false}) {
    if (_disposed) return Future.value();
    if (_owner != owner) _resetOwner();
    if (_pending != null && !force) return _pending!;
    if (!force &&
        _loadedAt != null &&
        !failed &&
        DateTime.now().difference(_loadedAt!) < const Duration(minutes: 5)) {
      return Future.value();
    }
    final requestOwner = owner;
    final generation = ++_generation;
    loading = true;
    failed = false;
    notifyListeners();
    return _pending = _read(requestOwner, generation);
  }

  Future<void> _read(String? requestOwner, int generation) async {
    bool current() =>
        !_disposed && generation == _generation && requestOwner == owner;
    try {
      final result = await api.getMyProfile();
      if (!current()) return;
      if (result['user_id'] != null && result['user_id'] != requestOwner) {
        throw StateError('Profile owner mismatch');
      }
      _profile = Map.from(result);
      photoRevision++;
      _loadedAt = DateTime.now();
    } catch (_) {
      if (current()) failed = true;
    } finally {
      if (current()) {
        loading = false;
        _pending = null;
        notifyListeners();
      }
    }
  }

  /// Called only after an authenticated write succeeds for the same owner.
  void applySaved(Map<String, dynamic> changes, {required String? forOwner}) {
    if (_disposed || forOwner != owner || _owner != owner) return;
    _generation++; // An older read must not undo a just-saved avatar or name.
    _pending = null;
    _profile = {..._profile, ...changes};
    if (changes.containsKey('avatar_url')) photoRevision++;
    loading = false;
    failed = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _auth?.cancel();
    _profile = {};
    super.dispose();
  }
}

String? trustedProfilePhotoUrl(
  String? value, {
  required String? owner,
  required List<String> origins,
}) {
  if (value == null || owner == null || owner.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      !origins.any((origin) {
        final allowed = Uri.tryParse(origin);
        return allowed?.hasAuthority == true && allowed!.origin == uri.origin;
      })) {
    return null;
  }
  final p = uri.pathSegments;
  if (p.length != 7 ||
      p[0] != 'storage' ||
      p[1] != 'v1' ||
      p[2] != 'object' ||
      !{'sign', 'public'}.contains(p[3]) ||
      p[4] != 'profile-photos' ||
      p[5] != owner ||
      !RegExp(r'^avatar\.(jpg|jpeg|png|webp|heic|heif)$').hasMatch(p[6])) {
    return null;
  }
  return uri.toString();
}
