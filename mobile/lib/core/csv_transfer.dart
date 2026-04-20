import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CsvTransfer {
  static const List<String> headers = <String>[
    'name',
    'category',
    'quantity',
    'location',
    'subcategory',
    'brand',
    'notes',
    'tags',
  ];

  static Future<void> exportItemsCsv() async {
    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return;

    List<dynamic> resp;
    try {
      resp = await supabase
          .from('items')
          .select('name,category,quantity,location,subcategory,brand,notes,tags')
          .eq('user_id', uid)
          .order('created_at', ascending: false);
    } catch (_) {
      return;
    }

    final rows = <List<String>>[headers];

    for (final r in resp) {
      if (r is! Map) continue;
      final m = Map<String, dynamic>.from(r);

      rows.add(
        <String>[
          _stringOrEmpty(m['name']),
          _stringOrEmpty(m['category']),
          _quantityStringOrEmpty(m['quantity']),
          _stringOrEmpty(m['location']),
          _stringOrEmpty(m['subcategory']),
          _stringOrEmpty(m['brand']),
          _stringOrEmpty(m['notes']),
          _tagsStringOrEmpty(m['tags']),
        ],
      );
    }

    final csv = const ListToCsvConverter().convert(rows);
    final x = XFile.fromData(
      Uint8List.fromList(utf8.encode(csv)),
      mimeType: 'text/csv',
      name: 'items_export.csv',
    );

    try {
      await Share.shareXFiles(<XFile>[x]);
    } catch (_) {}
  }

  static Future<void> importItemsCsv() async {
    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return;

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['csv'],
        withData: true,
      );
    } catch (_) {
      return;
    }

    if (picked == null || picked.files.isEmpty) return;
    final bytes = picked.files.single.bytes;
    if (bytes == null) return;

    final content = utf8.decode(bytes, allowMalformed: true);

    List<List<dynamic>> parsed;
    try {
      final raw = const CsvToListConverter(
        shouldParseNumbers: false,
      ).convert(content);
      parsed = raw.map((e) => e.map((x) => x).toList()).toList();
    } catch (_) {
      return;
    }

    if (parsed.isEmpty) return;

    final headerRow = parsed.first
        .map((e) => e.toString().trim().replaceAll('\uFEFF', ''))
        .toList();

    if (headerRow.length != headers.length) return;
    for (var i = 0; i < headers.length; i++) {
      if (headerRow[i] != headers[i]) return;
    }

    final existingCategories = <String>{};
    try {
      final cats = await supabase
          .from('items')
          .select('category')
          .eq('user_id', uid);
      for (final c in cats) {
        final s = (c['category'] ?? '').toString().trim();
        if (s.isNotEmpty) existingCategories.add(s);
      }
    } catch (_) {}

    for (var i = 1; i < parsed.length; i++) {
      final row = parsed[i];

      final rawCells = <String>[];
      for (var j = 0; j < headers.length; j++) {
        rawCells.add(_cellString(row, j));
      }

      final allEmpty = rawCells.every((e) => e.trim().isEmpty);
      if (allEmpty) continue;

      final name = _nullIfEmpty(rawCells[0]);
      final categoryRaw = _nullIfEmpty(rawCells[1]);
      final quantity = _safeInt(rawCells[2]);
      final location = _nullIfEmpty(rawCells[3]);
      final subcategory = _nullIfEmpty(rawCells[4]);
      final brand = _nullIfEmpty(rawCells[5]);
      final notes = _nullIfEmpty(rawCells[6]);
      final tags = _parseTags(_nullIfEmpty(rawCells[7]));

      final category = (categoryRaw != null && existingCategories.contains(categoryRaw))
          ? categoryRaw
          : 'Unsorted';

      final payload = <String, dynamic>{
        'name': name,
        'category': category,
        'quantity': quantity,
        'location': location,
        'subcategory': subcategory,
        'brand': brand,
        'notes': notes,
        'tags': tags,
        'user_id': uid,
      };

      try {
        await supabase.from('items').insert(payload);
      } catch (_) {}
    }
  }

  static String _cellString(List<dynamic> row, int idx) {
    if (idx < 0 || idx >= row.length) return '';
    final v = row[idx];
    return (v == null) ? '' : v.toString();
  }

  static String _stringOrEmpty(dynamic v) {
    if (v == null) return '';
    return v.toString();
  }

  static String _quantityStringOrEmpty(dynamic v) {
    if (v == null) return '';
    if (v is num) return v.toInt().toString();
    final s = v.toString().trim();
    final i = int.tryParse(s);
    return i?.toString() ?? '';
  }

  static String _tagsStringOrEmpty(dynamic v) {
    if (v == null) return '';
    if (v is List) {
      final parts = v
          .map((e) => (e == null) ? '' : e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return parts.join(',');
    }
    return v.toString();
  }

  static String? _nullIfEmpty(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  static int? _safeInt(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  static List<String>? _parseTags(String? raw) {
    if (raw == null) return null;
    final parts = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    return parts;
  }
}
