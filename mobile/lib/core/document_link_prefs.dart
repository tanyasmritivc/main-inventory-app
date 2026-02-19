import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DocumentLinkPrefs {
  static const _kKey = 'document_links';

  static Future<Map<String, Map<String, String>>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return <String, Map<String, String>>{};

    try {
      final obj = (json.decode(raw) as Map).cast<String, dynamic>();
      final out = <String, Map<String, String>>{};
      for (final e in obj.entries) {
        final v = e.value;
        if (v is Map) {
          out[e.key] = v.cast<String, dynamic>().map((k, val) => MapEntry(k, val.toString()));
        }
      }
      return out;
    } catch (_) {
      return <String, Map<String, String>>{};
    }
  }

  static Future<void> setLink({required String documentId, String? itemId, String? itemName}) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();

    final cleanItemId = (itemId ?? '').trim();
    if (cleanItemId.isEmpty) {
      all.remove(documentId);
    } else {
      all[documentId] = <String, String>{
        'item_id': cleanItemId,
        if (itemName != null && itemName.trim().isNotEmpty) 'item_name': itemName.trim(),
      };
    }

    await prefs.setString(_kKey, json.encode(all));
  }
}
