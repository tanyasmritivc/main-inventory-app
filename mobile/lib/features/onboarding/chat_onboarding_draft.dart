import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';

/// Device-only trial. Request IDs are assigned once, before any server write.
class TrialItem {
  TrialItem(this.item, this.spot);
  final ExtractedInventoryItem item;
  final String spot;
  bool quantityEdited = false;
  Map<String, dynamic> toJson() => {
    'item': item.toJson(),
    'spot': spot,
    'quantityEdited': quantityEdited,
  };
  factory TrialItem.fromJson(Map<String, dynamic> json) => TrialItem(
    ExtractedInventoryItem.fromJson(Map<String, dynamic>.from(json['item'])),
    json['spot'] as String,
  )..quantityEdited = json['quantityEdited'] == true;
}

class ChatOnboardingDraft {
  ChatOnboardingDraft({String? id}) : id = id ?? _id();
  final String id;
  String option = '', input = '', space = 'Home', method = '', question = '';
  String? photoPath, owner, inventoryId, spaceId, extractedBy;
  List<TrialItem> items = [];
  bool answered = false,
      keep = false,
      photoPending = false,
      saving = false,
      complete = false;
  int found = -1;
  static String _id() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'option': option,
    'input': input,
    'space': space,
    'method': method,
    'question': question,
    'photo': photoPath,
    'owner': owner,
    'extractedBy': extractedBy,
    'inventory': inventoryId,
    'spaceId': spaceId,
    'items': items.map((i) => i.toJson()).toList(),
    'answered': answered,
    'keep': keep,
    'photoPending': photoPending,
    'saving': saving,
    'complete': complete,
    'found': found,
  };
  factory ChatOnboardingDraft.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported trial draft');
    }
    return ChatOnboardingDraft(id: json['id'] as String)
      ..option = json['option'] as String
      ..input = json['input'] as String
      ..space = json['space'] as String
      ..method = json['method'] as String
      ..question = json['question'] as String? ?? ''
      ..photoPath = json['photo'] as String?
      ..owner = json['owner'] as String?
      ..extractedBy = json['extractedBy'] as String?
      ..inventoryId = json['inventory'] as String?
      ..spaceId = json['spaceId'] as String?
      ..items = (json['items'] as List)
          .map((i) => TrialItem.fromJson(Map<String, dynamic>.from(i)))
          .toList()
      ..answered = json['answered'] == true
      ..keep = json['keep'] == true
      ..photoPending = json['photoPending'] == true
      ..saving = json['saving'] == true
      ..complete = json['complete'] == true
      ..found = json['found'] as int;
  }
}

class ChatOnboardingStore {
  static const key = 'findez.chat-onboarding.v1';
  static Future<void>? _tail;
  static Future<T> _serial<T>(Future<T> Function() work) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    Future<T> run() async {
      try {
        if (previous != null) await previous;
        return await work();
      } finally {
        if (identical(_tail, done.future)) _tail = null;
        done.complete();
      }
    }

    return run();
  }

  static Future<ChatOnboardingDraft?> read() => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(key);
    return raw == null ? null : ChatOnboardingDraft.fromJson(jsonDecode(raw));
  });
  static Future<void> save(ChatOnboardingDraft draft) {
    // Snapshot at invocation: later edits cannot change a queued write.
    final raw = jsonEncode(draft.toJson());
    return _serial(() async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, raw)) {
        throw StateError('Could not save trial');
      }
    });
  }

  static Future<void> clear(String id) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw != null &&
        jsonDecode(raw)['id'] == id &&
        !await prefs.remove(key)) {
      throw StateError('Could not finish trial');
    }
  });
}

class TrialTemplates {
  TrialTemplates(this.templates);
  final List<Map<String, dynamic>> templates;
  static Future<TrialTemplates> load() async => TrialTemplates(
    (jsonDecode(
              await rootBundle.loadString(
                'assets/onboarding/templates.json',
                cache: false,
              ),
            )
            as List)
        .map((t) => Map<String, dynamic>.from(t))
        .toList(),
  );
  Map<String, dynamic> pick(String text) => templates.firstWhere(
    (t) =>
        t['space'] != 'Home' &&
        RegExp(t['keyword'], caseSensitive: false).hasMatch(text),
    orElse: () => templates.last,
  );
  static String title(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
  void describe(ChatOnboardingDraft draft, String text) {
    final template = pick(text);
    draft.space = template['space'] == 'Home' && text.length < 22
        ? title(
            text.replaceFirst(
              RegExp(r'^(my|the|our|a)\s+', caseSensitive: false),
              '',
            ),
          )
        : template['space'];
    final spots = template['spots'] as List;
    draft.items = (template['items'] as List)
        .asMap()
        .entries
        .map(
          (entry) => TrialItem(
            ExtractedInventoryItem(
              name: entry.value[0],
              category: '',
              quantity: entry.value[1],
            ),
            spots[(entry.key * 5) % spots.length],
          ),
        )
        .toList();
  }

  void list(ChatOnboardingDraft draft, String text) {
    final template = pick(text), spots = template['spots'] as List;
    draft.space = template['space'];
    draft.items = parseList(text)
        .asMap()
        .entries
        .map((entry) => TrialItem(entry.value, spots[entry.key % spots.length]))
        .toList();
  }

  static List<ExtractedInventoryItem> parseList(String text) {
    const numbers = {
      'a': 1,
      'an': 1,
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
      'twelve': 12,
      'dozen': 12,
      'some': 5,
      'few': 3,
      'couple': 2,
      'pair': 2,
    };
    final parts = text
        .replaceFirst(
          RegExp(
            r'^(please\s+)?(add|put|save|track|i have|we have|there are)\s+',
            caseSensitive: false,
          ),
          '',
        )
        .replaceFirst(RegExp(r'[.!?]$'), '')
        .split(RegExp(r'\s*,\s*|\s+and\s+|\s*;\s*|\n+', caseSensitive: false));
    final result = <ExtractedInventoryItem>[];
    for (final raw in parts) {
      final part = raw.trim();
      if (part.isEmpty) continue;
      final match = RegExp(
        r'^(\d+|an?|one|two|three|four|five|six|seven|eight|nine|ten|twelve|dozen|some|few|couple|pair)\s+(?:x\s+)?(.+)$',
        caseSensitive: false,
      ).firstMatch(part);
      if (match == null && part.split(' ').length > 5) continue;
      result.add(
        ExtractedInventoryItem(
          name: title(match?[2] ?? part),
          category: '',
          quantity: match == null
              ? 1
              : int.tryParse(match[1]!) ??
                    numbers[match[1]!.toLowerCase()] ??
                    1,
        ),
      );
    }
    return result; // Never silently discard items beyond the shelf's 12 blocks.
  }

  static int matchQuestion(String question, List<TrialItem> items) {
    final normalized = question.toLowerCase().replaceAll(RegExp(r'[?.!]'), '');
    var best = -1, score = 0.0;
    for (var i = 0; i < items.length; i++) {
      final words = items[i].item.name
          .toLowerCase()
          .split(RegExp(r'[\s,]+'))
          .where((w) => w.length > 2)
          .toList();
      final candidate =
          words
              .where(
                (w) => normalized.contains(w.replaceFirst(RegExp(r's$'), '')),
              )
              .length /
          max(1, words.length);
      if (candidate > score) {
        best = i;
        score = candidate;
      }
    }
    return best;
  }
}
