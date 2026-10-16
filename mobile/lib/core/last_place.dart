import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LastPlace {
  const LastPlace.personal() : id = 'personal', type = 'personal';
  const LastPlace.workspace(this.id) : type = 'workspace';
  final String type, id;
  bool get isPersonal => type == 'personal';
  @override
  bool operator ==(Object other) =>
      other is LastPlace && other.type == type && other.id == id;
  @override
  int get hashCode => Object.hash(type, id);
}

LastPlace? placeFromLink(Uri uri) {
  if (uri.userInfo.isNotEmpty || (uri.hasPort && uri.port != 443)) return null;
  final parts = uri.pathSegments;
  if (uri.scheme == 'https' &&
      ['findez.ai', 'www.findez.ai'].contains(uri.host) &&
      parts.length == 2 &&
      parts.first == 'workspaces' &&
      parts.last.isNotEmpty) {
    return LastPlace.workspace(parts.last);
  }
  if (uri.scheme == 'findez' &&
      uri.host == 'workspaces' &&
      parts.length == 1 &&
      parts.single.isNotEmpty) {
    return LastPlace.workspace(parts.single);
  }
  return null;
}

LastPlace? placeFromNotification(Map<String, dynamic> payload, String userId) {
  if (payload['recipient_user_id'] != null &&
      payload['recipient_user_id'] != userId) {
    return null;
  }
  final metadata = payload['metadata'] is Map
      ? payload['metadata'] as Map
      : const {};
  final id =
      payload['workspace_id'] ??
      payload['team_id'] ??
      metadata['workspace_id'] ??
      metadata['team_id'];
  return id is String && id.isNotEmpty ? LastPlace.workspace(id) : null;
}

/// Serializes device writes per account so sign-out cannot race a late save.
class LastPlaceStore {
  LastPlaceStore(this.userId);
  final String userId;
  static final Map<String, Future<void>> _writes = {};
  String get key => 'last_place_$userId';
  Future<void> _queue(Future<void> Function() action) {
    final previous = _writes[userId] ?? Future<void>.value();
    final next = previous.then((_) => action(), onError: (_) => action());
    _writes[userId] = next;
    return next;
  }

  Future<LastPlace> read() async {
    await (_writes[userId] ?? Future<void>.value());
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return const LastPlace.personal();
    try {
      final value = jsonDecode(raw) as Map;
      if (value['userId'] != userId) return const LastPlace.personal();
      if (value['type'] == 'workspace' &&
          value['id'] is String &&
          (value['id'] as String).isNotEmpty) {
        return LastPlace.workspace(value['id'] as String);
      }
    } on FormatException {
      return const LastPlace.personal();
    } on TypeError {
      return const LastPlace.personal();
    }
    return const LastPlace.personal();
  }

  Future<void> save(LastPlace place, {required bool Function() isCurrent}) =>
      _queue(() async {
        final prefs = await SharedPreferences.getInstance();
        if (!isCurrent()) return;
        final saved = await prefs.setString(
          key,
          jsonEncode({'userId': userId, 'type': place.type, 'id': place.id}),
        );
        if (!saved) {
          throw const FormatException(
            'Your place could not be saved on this phone.',
          );
        }
      });
  Future<void> clear() => _queue(() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(key)) {
      throw const FormatException('Your saved place could not be cleared.');
    }
  });
}
