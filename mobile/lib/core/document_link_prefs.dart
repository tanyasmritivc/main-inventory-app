import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'account_preferences.dart';

class DocumentLinkPrefs {
  static const _kKey = 'document_links';

  static Future<Map<String, Map<String, String>>> loadAll() async {
    final accountKey = accountPreferenceKey(_kKey);
    return _loadForAccount(accountKey);
  }

  static Future<Map<String, Map<String, String>>> _loadForAccount(
    String accountKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(accountKey);
    final legacy = prefs.getString(_kKey);
    if (raw == null && legacy != null && !accountKey.endsWith(':signed-out')) {
      raw = legacy;
      await prefs.setString(accountKey, legacy);
      await prefs.remove(_kKey);
    }
    if (raw == null || raw.trim().isEmpty) {
      return <String, Map<String, String>>{};
    }

    try {
      final obj = (json.decode(raw) as Map).cast<String, dynamic>();
      final out = <String, Map<String, String>>{};
      for (final e in obj.entries) {
        final v = e.value;
        if (v is Map) {
          out[e.key] = v.cast<String, dynamic>().map(
            (k, val) => MapEntry(k, val.toString()),
          );
        }
      }
      return out;
    } catch (_) {
      return <String, Map<String, String>>{};
    }
  }

  static Future<void> setLink({
    required String documentId,
    String? itemId,
    String? itemName,
  }) async {
    // Capture before any await: a switch must not write the old account's links
    // into the newly signed-in account's preferences.
    final accountKey = accountPreferenceKey(_kKey);
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadForAccount(accountKey);

    final cleanItemId = (itemId ?? '').trim();
    if (cleanItemId.isEmpty) {
      all.remove(documentId);
    } else {
      all[documentId] = <String, String>{
        'item_id': cleanItemId,
        if (itemName != null && itemName.trim().isNotEmpty)
          'item_name': itemName.trim(),
      };
    }

    if (!await prefs.setString(accountKey, json.encode(all))) {
      throw StateError('Document link cache was not saved');
    }
  }
}
