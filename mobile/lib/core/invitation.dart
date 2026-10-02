import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Invitation metadata is a handoff, never proof of membership or permission.
class Invitation {
  const Invitation({
    required this.kind,
    required this.code,
    required this.createdAt,
  });
  final String kind;
  final String code;
  final int createdAt;
  static const metadataKey = 'findez_pending_invitation';
  static final _code = RegExp(r'^[A-Z0-9]{6}$');
  String get key => '$kind:$code';
  String get url =>
      'https://www.findez.ai/join/${kind == 'team' ? 'team/' : ''}$code';

  static Invitation? fromUri(Uri uri) {
    if (uri.userInfo.isNotEmpty || uri.hasPort && uri.port != 443) return null;
    String? kind, code;
    if (uri.scheme == 'findez' && uri.path.isEmpty) {
      kind = switch (uri.host) {
        'space-invite' => 'space',
        'team-invite' => 'team',
        _ => null,
      };
      code = uri.queryParameters['code'];
    } else if (uri.scheme == 'https' &&
        const ['findez.ai', 'www.findez.ai'].contains(uri.host)) {
      final parts = uri.pathSegments;
      if (parts.length == 3 && parts[0] == 'join' && parts[1] == 'team') {
        kind = 'team';
        code = parts[2];
      } else if (parts.length == 2 && parts[0] == 'join') {
        kind = 'space';
        code = parts[1];
      } else if (parts.length == 1 && parts[0] == 'join') {
        kind = 'space';
        code = uri.queryParameters['code'];
      }
    }
    code = code?.toUpperCase();
    if (kind == null || code == null || !_code.hasMatch(code)) return null;
    return Invitation(
      kind: kind,
      code: code,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Invitation? fromData(dynamic data, {int? now}) {
    if (data is! Map || data['v'] != 1) return null;
    final kind = data['kind'], code = data['code'], date = data['created_at'];
    final current = now ?? DateTime.now().millisecondsSinceEpoch;
    if (!const ['space', 'team'].contains(kind) ||
        code is! String ||
        !_code.hasMatch(code) ||
        date is! int ||
        date > current + 300000 ||
        current - date > const Duration(days: 30).inMilliseconds) {
      return null;
    }
    return Invitation(kind: kind as String, code: code, createdAt: date);
  }

  Map<String, dynamic> toData() => {
    'v': 1,
    'kind': kind,
    'code': code,
    'created_at': createdAt,
  };
}

class InvitationInbox {
  static const _storageKey = 'findez.invitation.v1';
  Invitation? pending;
  String? ownerId;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final data = jsonDecode(raw);
      if (data is! Map) return;
      pending = Invitation.fromData(data['invitation']);
      ownerId = data['owner'] is String ? data['owner'] as String : null;
    } catch (_) {
      pending = null;
      ownerId = null;
    }
  }

  Future<void> queue(Invitation invitation, {String? owner}) async {
    pending = invitation;
    ownerId = owner;
    await _save();
  }

  Future<void> bind(String owner) async {
    ownerId = owner;
    await _save();
  }

  bool availableFor(String owner) =>
      pending != null &&
      Invitation.fromData(pending!.toData()) != null &&
      (ownerId == null || ownerId == owner);
  Future<void> clear(Invitation invitation) async {
    if (pending?.key != invitation.key ||
        pending?.createdAt != invitation.createdAt) {
      return;
    }
    pending = null;
    ownerId = null;
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (pending == null) {
      await prefs.remove(_storageKey);
      return;
    }
    await prefs.setString(
      _storageKey,
      jsonEncode({'invitation': pending?.toData(), 'owner': ownerId}),
    );
  }
}
