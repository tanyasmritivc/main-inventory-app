import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/inventory_cache.dart';
import '../../core/low_stock_prefs.dart';
import '../../core/ui/glass_card.dart';
import '../scan/scan_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.api,
    this.onInventoryMutated,
    this.initialMessage,
    this.onProfileTap,
  });

  final ApiClient api;
  final VoidCallback? onInventoryMutated;
  final String? initialMessage;
  final VoidCallback? onProfileTap;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = LinearGradient(
      colors: [
        Color(0xFF5EEAD4),
        Color(0xFF60A5FA),
        Color(0xFFC084FC),
        Color(0xFFF472B6),
        Color(0xFFFCA5A5),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        double dot(double phase) {
          final v = (t + phase) % 1.0;
          return 0.35 + (0.65 * (1.0 - (2.0 * (v - 0.5)).abs()));
        }

        return ShaderMask(
          shaderCallback: (rect) => accent.createShader(rect),
          blendMode: BlendMode.srcIn,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(opacity: dot(0.0), color: Colors.white),
              const SizedBox(width: 6),
              _Dot(opacity: dot(0.2), color: Colors.white),
              const SizedBox(width: 6),
              _Dot(opacity: dot(0.4), color: Colors.white),
            ],
          ),
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.opacity, required this.color});

  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

enum _UploadKind { image, document, file }

class _IntentItem {
  const _IntentItem({required this.name, required this.qty, this.all = false});

  final String name;
  final int qty;
  final bool all;
}

class _AiIntent {
  const _AiIntent({required this.action, required this.items, this.query});

  final String action;
  final List<_IntentItem> items;
  final String? query;
}

class _ChatPageState extends State<ChatPage> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  bool _sending = false;
  String? _progress;
  final List<_ChatMessage> _messages = [];
  bool _sentFirstMessage = false;

  Timer? _phaseTimer1;
  Timer? _phaseTimer2;
  Timer? _firstTokenFallbackTimer;

  Timer? _fakeTypingTimer;
  int _fakeTypingAssistantIndex = -1;
  int _fakeTypingCharIndex = 0;

  List<InventoryItem>? _inventorySnapshot;

  final List<String> _pendingAttachments = [];

  List<DocumentEntry>? _pendingDocChoices;

  static const _fallbackNoResponse = 'Hmm, try asking that a different way 🙂';

  static const _unknownActionResponse =
      'I’m not totally sure what you meant, but I can help you add, remove, or find items.';

  static const _guaranteedFallbackResponse =
      "I couldn’t process that, but try something like 'add 2 items'.";

  static const _AiIntent _safeFallbackIntent =
      _AiIntent(action: 'unknown', items: <_IntentItem>[], query: '');

  static const _fakeTypingText = 'Let me check that for you…';

  int _nowTs() => DateTime.now().millisecondsSinceEpoch;

  void _resetChat() {
    _phaseTimer1?.cancel();
    _phaseTimer2?.cancel();
    _firstTokenFallbackTimer?.cancel();
    _fakeTypingTimer?.cancel();
    _fakeTypingAssistantIndex = -1;
    _fakeTypingCharIndex = 0;

    _controller.clear();
    _focusNode.unfocus();

    if (!mounted) return;
    setState(() {
      _sending = false;
      _progress = null;
      _messages.clear();
      _sentFirstMessage = false;
      _pendingAttachments.clear();
    });
  }

  List<_ChatMessage> _lastHistoryMessages({int limit = 10}) {
    final usable = _messages
        .where(
          (m) =>
              (m.role == 'user' || m.role == 'assistant') &&
              m.content.trim().isNotEmpty,
        )
        .toList();
    if (usable.length <= limit) return usable;
    return usable.sublist(usable.length - limit);
  }

  String _buildIntentPrompt({required String userText}) {
    final history = _lastHistoryMessages(limit: 10)
        .map(
          (m) => <String, dynamic>{
            'role': m.role,
            'content': m.content,
            'timestamp': m.timestamp,
          },
        )
        .toList();

    return '''You are an AI assistant for an inventory management app called "FindEZ".

Your job is to interpret user input and convert it into structured actions. You DO NOT behave like a chatbot. You behave like a command interpreter.

---

## CORE RULES

1. ALWAYS return a valid JSON object.
2. NEVER return plain text outside JSON.
3. DO NOT ask for confirmation.
4. DO NOT explain your reasoning.
5. BE concise and deterministic.
6. If unsure, make the best logical assumption.

---

## SUPPORTED ACTIONS

You must classify every user request into ONE of the following actions:

1. "add_item"
2. "remove_item"
3. "find_item"
4. "list_items"

---

## OUTPUT FORMAT

{
"action": "add_item" | "remove_item" | "find_item" | "list_items",
"items": [
{
"name": string,
"qty": number
"all": boolean
}
],
"query": string
}

Rules:

* "items" is required for add/remove actions
* "query" is required for find actions
* For list_items, both can be empty
* For remove_item, if the user says "remove all items"/"clear inventory"/"delete everything": set query to "ALL_ITEMS" and set items to []
* For remove_item, if the user says "remove all cables": set items to [{"name":"cable","qty":0,"all":true}] and query to ""
* NEVER treat "everything" as an item name

---

## ITEM PARSING RULES (CRITICAL)

1. Extract item names and quantities from natural language.

Examples:

* "add three pencils" → pencil, qty: 3
* "buy 2 batteries" → battery, qty: 2
* "add a laptop" → laptop, qty: 1

2. Convert number words to integers:
   one → 1
   two → 2
   three → 3
   four → 4
   five → 5
   six → 6
   seven → 7
   eight → 8
   nine → 9
   ten → 10

3. If quantity is not specified → default to 1

4. ALWAYS normalize item names to singular form:

* "pencils" → "pencil"
* "batteries" → "battery"

5. Remove unnecessary adjectives unless important:

* "blue water bottle" → "water bottle"
* "big red backpack" → "backpack"

---

## ACTION DETECTION RULES

* If user is adding → use "add_item"
* If user is removing/deleting → use "remove_item"
* If user is searching ("where is", "find", "locate") → use "find_item"
* If user asks for all items → use "list_items"

---

## EXAMPLES

User: "add three pencils"
Response:
{
"action": "add_item",
"items": [
{ "name": "pencil", "qty": 3 }
],
"query": ""
}

User: "remove 2 batteries"
Response:
{
"action": "remove_item",
"items": [
{ "name": "battery", "qty": 2, "all": false }
],
"query": ""
}

User: "where are my cables"
Response:
{
"action": "find_item",
"items": [],
"query": "cable"
}

User: "show everything"
Response:
{
"action": "list_items",
"items": [],
"query": ""
}

User: "remove all items"
Response:
{
"action": "remove_item",
"items": [],
"query": "ALL_ITEMS"
}

---

## FAIL-SAFE BEHAVIOR

* If input is unclear, infer the most likely action
* NEVER return invalid JSON
* NEVER return empty response

---

Conversation history (most recent last): ${jsonEncode(history)}

User message: ${jsonEncode(userText)}
''';
  }

  Map<String, dynamic>? _tryParseJsonObject(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      final decoded = json.decode(s);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      // fall through
    }

    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start < 0 || end < 0 || end <= start) return null;
    final sub = s.substring(start, end + 1);
    try {
      final decoded = json.decode(sub);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
    return null;
  }

  static const Map<String, int> _numberWords = {
    'zero': 0,
    'one': 1,
    'a': 1,
    'an': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
  };

  int _parseQty(Object? v) {
    if (v is num) {
      if (v.isNaN) return 1;
      final asInt = v.toInt();
      return asInt <= 0 ? 1 : asInt;
    }
    final s = (v ?? '').toString().trim().toLowerCase();
    if (s.isEmpty) return 1;
    final asInt = int.tryParse(s);
    if (asInt != null) return asInt <= 0 ? 1 : asInt;
    final w = _numberWords[s];
    if (w != null) return w <= 0 ? 1 : w;
    return 1;
  }

  String _sanitizeUserTextForAi(String text) {
    var s = text.trim().toLowerCase();
    if (s.isEmpty) return s;
    s = s.replaceAll(RegExp(r"[^A-Za-z0-9\s\-']+"), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  bool _isBadItemName(String name) {
    final n = name.trim().toLowerCase();
    return n == 'everything' || n == 'all' || n == 'stuff';
  }

  List<_IntentItem> _mergeDuplicateItems(List<_IntentItem> items) {
    final byKey = <String, _IntentItem>{};
    final order = <String>[];

    for (final it in items) {
      final name = _singularize(it.name).trim();
      if (name.isEmpty) continue;
      if (_isBadItemName(name)) continue;

      final key = name.toLowerCase();
      final prev = byKey[key];
      final nextAll = it.all;
      final nextQty = nextAll ? 0 : (it.qty <= 0 ? 1 : it.qty);

      if (prev == null) {
        order.add(key);
        byKey[key] = _IntentItem(name: name, qty: nextQty, all: nextAll);
        continue;
      }

      final mergedAll = prev.all || nextAll;
      final mergedQty = mergedAll ? 0 : (prev.qty + nextQty);
      byKey[key] = _IntentItem(name: prev.name, qty: mergedQty, all: mergedAll);
    }

    return order.map((k) => byKey[k]!).toList();
  }

  String _singularize(String name) {
    var s = name.trim();
    if (s.isEmpty) return s;
    final lower = s.toLowerCase();
    if (lower.endsWith('ies') && s.length > 3) {
      return '${s.substring(0, s.length - 3)}y';
    }
    if (lower.endsWith('sses') && s.length > 4) {
      return s.substring(0, s.length - 2);
    }
    if (lower.endsWith('s') && !lower.endsWith('ss') && s.length > 1) {
      return s.substring(0, s.length - 1);
    }
    return s;
  }

  String _pluralize(String singular, int qty) {
    final s = singular.trim();
    if (s.isEmpty) return s;
    if (qty == 1) return s;
    final lower = s.toLowerCase();
    if (lower.endsWith('y') && s.length > 1) {
      return '${s.substring(0, s.length - 1)}ies';
    }
    if (lower.endsWith('s')) return s;
    return '${s}s';
  }

  String _joinWithAnd(List<String> parts) {
    final p = parts.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return '';
    if (p.length == 1) return p.first;
    if (p.length == 2) return '${p[0]} and ${p[1]}';
    return '${p.sublist(0, p.length - 1).join(', ')}, and ${p.last}';
  }

  bool _looksLikeClearAllInventory(String text) {
    final s = text.trim().toLowerCase();
    if (s.isEmpty) return false;
    return s == 'clear' ||
        s == 'clear inventory' ||
        s == 'delete everything' ||
        s == 'remove everything' ||
        s == 'remove all' ||
        s == 'remove stuff' ||
        s == 'delete stuff' ||
        s == 'remove all items' ||
        s == 'delete all items' ||
        s == 'clear all' ||
        s == 'clear all items' ||
        s == 'delete all' ||
        s.contains('clear inventory') ||
        s.contains('clear my inventory') ||
        s.contains('remove all items') ||
        s.contains('delete all items') ||
        s.contains('delete everything') ||
        s.contains('remove everything');
  }

  _IntentItem? _parseItemFromPhrase(String phrase) {
    var s = phrase.trim();
    if (s.isEmpty) return null;
    s = s.replaceAll(RegExp(r'[\.!?]$'), '').trim();

    final lower = s.toLowerCase();
    if (lower == 'everything' ||
        lower == 'all' ||
        lower == 'stuff' ||
        lower == 'all items' ||
        lower == 'all item' ||
        lower == 'all inventory' ||
        lower == 'inventory') {
      return null;
    }

    bool all = false;
    if (lower.startsWith('all of ')) {
      all = true;
      s = s.substring(7).trim();
    } else if (lower.startsWith('all ')) {
      all = true;
      s = s.substring(4).trim();
    } else if (lower.startsWith('every ')) {
      all = true;
      s = s.substring(6).trim();
    }
    if (s.isEmpty) return null;

    final m = RegExp(
      r'^(?<qty>\d+|[a-zA-Z]+)\s+(?<name>.+)$',
      caseSensitive: false,
    ).firstMatch(s);
    if (m != null) {
      final qtyRaw = (m.namedGroup('qty') ?? '').trim();
      final nameRaw = (m.namedGroup('name') ?? '').trim();
      final qty = _parseQty(qtyRaw);
      final name = _singularize(nameRaw);
      if (name.isEmpty) return null;
      if (all) return _IntentItem(name: name, qty: 0, all: true);
      return _IntentItem(name: name, qty: qty <= 0 ? 1 : qty);
    }

    final name = _singularize(s);
    if (name.isEmpty) return null;
    if (all) return _IntentItem(name: name, qty: 0, all: true);
    return _IntentItem(name: name, qty: 1);
  }

  List<_IntentItem> _parseItemsFromText(String text) {
    final s = text.trim();
    if (s.isEmpty) return const <_IntentItem>[];

    final cleaned = s
        .replaceAll(RegExp(r'\b(to|my|the|a|an)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final parts = cleaned
        .split(RegExp(r'\s*(?:,|\band\b|\+)\s*', caseSensitive: false))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final out = <_IntentItem>[];
    for (final p in parts) {
      final it = _parseItemFromPhrase(p);
      if (it != null && it.name.trim().isNotEmpty) out.add(it);
    }
    return _mergeDuplicateItems(out);
  }

  _AiIntent? _tryLocalIntentFromUserText(String userText) {
    final s = userText.trim();
    if (s.isEmpty) return null;
    final lower = s.toLowerCase();
    final normalized = lower.replaceAll(RegExp(r"[’']"), '');

    String cleanQuery(String raw) {
      return _singularize(raw)
          .replaceAll(RegExp(r'\b(my|the|a|an)\b', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'[?.!,;:]+$'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    if (_looksLikeClearAllInventory(lower)) {
      return const _AiIntent(action: 'remove_item', items: <_IntentItem>[], query: 'ALL_ITEMS');
    }

    final isList = RegExp(
      r'^(show|list|display)\b|\b(show everything|show all|everything|all items)\b',
      caseSensitive: false,
    ).hasMatch(normalized) ||
        RegExp(
          r'\b(what do i have|what (?:stuff|items) do i have|show (?:me )?(?:my )?items|list (?:my )?items|whats in (?:my )?inventory|what is in (?:my )?inventory|what do i own)\b',
          caseSensitive: false,
        ).hasMatch(normalized);
    if (isList) {
      return const _AiIntent(action: 'list_items', items: <_IntentItem>[]);
    }

    final addMatch = RegExp(r'^(add|buy|get|need|put)\b\s*(.*)$', caseSensitive: false)
        .firstMatch(s);
    if (addMatch != null) {
      final rest = (addMatch.group(2) ?? '').trim();
      final items = _parseItemsFromText(rest);
      if (items.isNotEmpty) {
        return _AiIntent(action: 'add_item', items: items);
      }
    }

    final removeMatch = RegExp(
      r'^(remove|delete|discard|throw away|take out)\b\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(s);
    if (removeMatch != null) {
      final rest = (removeMatch.group(2) ?? '').trim();
      if (_looksLikeClearAllInventory(rest)) {
        return const _AiIntent(action: 'remove_item', items: <_IntentItem>[], query: 'ALL_ITEMS');
      }
      if (_isBadItemName(rest)) {
        return const _AiIntent(action: 'remove_item', items: <_IntentItem>[], query: 'ALL_ITEMS');
      }
      final items = _parseItemsFromText(rest);
      if (items.isNotEmpty) {
        return _AiIntent(action: 'remove_item', items: items);
      }
    }

    final howManyMatch = RegExp(
      r'\bhow many\s+(.+?)\s+do i have\b',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (howManyMatch != null) {
      final q = cleanQuery((howManyMatch.group(1) ?? '').trim());
      if (q.isNotEmpty) {
        return _AiIntent(action: 'find_item', items: const <_IntentItem>[], query: q);
      }
    }

    final whatKindMatch = RegExp(
      r'\bwhat (?:kind|kinds|type|types)\s+of\s+(.+?)\s+do i have\b',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (whatKindMatch != null) {
      final q = cleanQuery((whatKindMatch.group(1) ?? '').trim());
      if (q.isNotEmpty) {
        return _AiIntent(action: 'find_item', items: const <_IntentItem>[], query: q);
      }
    }

    final findMatch = RegExp(
      r'\b(find|locate|search for|where is|where are|do i have)\b\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (findMatch != null) {
      final rest = (findMatch.group(2) ?? '').trim();
      if (rest.isNotEmpty) {
        final q = cleanQuery(rest);
        if (q.isNotEmpty) {
          return _AiIntent(action: 'find_item', items: const <_IntentItem>[], query: q);
        }
      }
    }

    if (normalized.contains('inventory') &&
        (normalized.contains('what') ||
            normalized.contains('show') ||
            normalized.contains('list') ||
            normalized.contains('have'))) {
      return const _AiIntent(action: 'list_items', items: <_IntentItem>[]);
    }

    return null;
  }

  _AiIntent _normalizeIntent(Map<String, dynamic> jsonMap, String userText) {
    try {
      final rawAction = (jsonMap['action'] ?? '').toString().trim();
      final action = rawAction.isEmpty ? 'unknown' : rawAction;
      final query = (jsonMap['query'] ?? '').toString().trim();
      final itemsRaw = (jsonMap['items'] is List) ? (jsonMap['items'] as List) : const [];

      var askedToClearAllViaBadName = false;
      final items = <_IntentItem>[];
      for (final e in itemsRaw) {
        if (e is Map) {
          final m = e.cast<String, dynamic>();
          final name = _singularize((m['name'] ?? '').toString()).trim();
          if (name.isEmpty) continue;
          if (_isBadItemName(name)) {
            askedToClearAllViaBadName = true;
            continue;
          }
          final rawAll = m['all'];
          final all = rawAll == true || rawAll?.toString().toLowerCase() == 'true';
          final qty = _parseQty(m['qty']);
          items.add(
            _IntentItem(
              name: name,
              qty: all ? 0 : qty,
              all: all,
            ),
          );
        }
      }

      final merged = _mergeDuplicateItems(items);

      if (action == 'remove_item' && query.trim().toUpperCase() == 'ALL_ITEMS') {
        return const _AiIntent(
          action: 'remove_item',
          items: <_IntentItem>[],
          query: 'ALL_ITEMS',
        );
      }

      if (action == 'remove_item' && _looksLikeClearAllInventory(userText)) {
        return const _AiIntent(
          action: 'remove_item',
          items: <_IntentItem>[],
          query: 'ALL_ITEMS',
        );
      }

      if (action == 'remove_item' && askedToClearAllViaBadName) {
        return const _AiIntent(
          action: 'remove_item',
          items: <_IntentItem>[],
          query: 'ALL_ITEMS',
        );
      }

      if ((action == 'add_item' || action == 'remove_item') && merged.isEmpty) {
        final cleaned = userText
            .replaceAll(RegExp(r'^(please\s+)?(can you\s+)?', caseSensitive: false), '')
            .replaceAll(RegExp(r'^(add|remove|delete|find|list)\s+', caseSensitive: false), '')
            .trim();
        if (action == 'remove_item' && _looksLikeClearAllInventory(cleaned)) {
          return const _AiIntent(
            action: 'remove_item',
            items: <_IntentItem>[],
            query: 'ALL_ITEMS',
          );
        }
        if (action == 'remove_item' && _isBadItemName(cleaned)) {
          return const _AiIntent(
            action: 'remove_item',
            items: <_IntentItem>[],
            query: 'ALL_ITEMS',
          );
        }
        final parsedItems = _parseItemsFromText(cleaned);
        final mergedParsed = _mergeDuplicateItems(parsedItems);
        if (mergedParsed.isNotEmpty) {
          return _AiIntent(action: action, items: mergedParsed, query: query);
        }
      }

      return _AiIntent(action: action, items: merged, query: query);
    } catch (e) {
      debugPrint('normalizeIntent error: $e');
      return _safeFallbackIntent;
    }
  }

  Future<_AiIntent> _getIntentFromAi({required String userText}) async {
    final prompt = _buildIntentPrompt(userText: userText);
    final buffer = StringBuffer();
    bool streamedAny = false;
    Map<String, dynamic>? earlyParsed;

    try {
      await for (final evt
          in widget.api.aiCommandStream(message: prompt).timeout(const Duration(seconds: 25))) {
        if (!mounted) return _safeFallbackIntent;
        if (evt.type == 'status' && (evt.message ?? '').trim().isNotEmpty) {
          if (!mounted) return _safeFallbackIntent;
          setState(() => _progress = evt.message);
          continue;
        }
        if (evt.type == 'delta') {
          final d = (evt.delta ?? '');
          if (d.isEmpty) continue;
          streamedAny = true;
          buffer.write(d);
          if (d.contains('}')) {
            final m = _tryParseJsonObject(buffer.toString());
            if (m != null && (m['action'] ?? '').toString().trim().isNotEmpty) {
              earlyParsed = m;
              break;
            }
          }
          continue;
        }
        if (evt.type == 'done') {
          break;
        }
      }
    } catch (_) {
      // fall back to non-stream
    }

    if (earlyParsed != null) {
      return _normalizeIntent(earlyParsed, userText);
    }

    final raw = buffer.toString();
    if (streamedAny) {
      final m = _tryParseJsonObject(raw);
      if (m == null) return _safeFallbackIntent;
      return _normalizeIntent(m, userText);
    }

    try {
      final out = await widget.api.aiCommand(message: prompt);
      final m = _tryParseJsonObject(out.assistantMessage);
      if (m == null) return _safeFallbackIntent;
      return _normalizeIntent(m, userText);
    } catch (_) {
      return _safeFallbackIntent;
    }
  }

  void _showAssistantTypingDots(int assistantIndex) {
    if (!mounted) return;
    _fakeTypingTimer?.cancel();
    _firstTokenFallbackTimer?.cancel();
    setState(() {
      _fakeTypingAssistantIndex = assistantIndex;
      _fakeTypingCharIndex = 0;
    });
    _startThinkingFallbackTimer(assistantIndex);
  }

  Future<void> _handleAiIntentFlow({
    required int assistantIndex,
    required String q,
    required String aiMsg,
    required bool wantLowStock,
    required Future<String?> lowStockFuture,
  }) async {
    try {
      final localIntent = _tryLocalIntentFromUserText(q);
      final intent = localIntent ?? await _getIntentFromAi(userText: aiMsg);
      final lowStock = await lowStockFuture;

      String responseText;
      try {
        responseText = await _deterministicResponseAndKickoffExecution(intent);
      } catch (e) {
        debugPrint('deterministic response error: $e');
        responseText = _guaranteedFallbackResponse;
      }
      if (responseText.trim().isEmpty) responseText = _guaranteedFallbackResponse;

      if (!mounted) return;
      _pendingAttachments.clear();
      _phaseTimer1?.cancel();
      _phaseTimer2?.cancel();
      _firstTokenFallbackTimer?.cancel();
      _fakeTypingTimer?.cancel();
      _fakeTypingAssistantIndex = -1;
      if (!mounted) return;
      setState(() => _progress = null);

      final finalText =
          (wantLowStock && lowStock != null && lowStock.trim().isNotEmpty)
              ? '$lowStock\n\n$responseText'
              : responseText;

      await _streamAssistantText(assistantIndex: assistantIndex, text: finalText);
      return;
    } on dio.DioException catch (e) {
      debugPrint('ai intent flow DioException: $e');
      final status = e.response?.statusCode;

      if (!mounted) return;
      if (status == 404) {
        if (!mounted) return;
        setState(() => _progress = 'Searching inventory…');
        try {
          final res = await widget.api.searchItems(query: q);
          if (!mounted) return;
          setState(() {
            if (_messages.isNotEmpty &&
                _messages.last.role == 'assistant' &&
                _messages.last.content.isEmpty) {
              _messages[_messages.length - 1] = _ChatMessage(
                role: 'assistant',
                content: res.items.isEmpty
                    ? 'No matches found.'
                    : 'Found ${res.items.length} items. Top: ${res.items.take(3).map((i) => i.name).join(', ')}',
                timestamp: _nowTs(),
              );
            } else {
              _messages.add(
                _ChatMessage(
                  role: 'assistant',
                  content: res.items.isEmpty
                      ? 'No matches found.'
                      : 'Found ${res.items.length} items. Top: ${res.items.take(3).map((i) => i.name).join(', ')}',
                  timestamp: _nowTs(),
                ),
              );
            }
          });
          _scrollToBottom();
        } catch (e2) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_friendlyRequestError(e2))));
        }
      } else if (status == 429) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rate limited. Try again in ~20 seconds.'),
          ),
        );
      } else {
        _replaceAssistantMessage(assistantIndex, _guaranteedFallbackResponse);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyRequestError(e))));
      }
    } catch (e) {
      debugPrint('ai intent flow error: $e');
      if (!mounted) return;
      _replaceAssistantMessage(assistantIndex, _guaranteedFallbackResponse);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyRequestError(e))));
    } finally {
      _phaseTimer1?.cancel();
      _phaseTimer2?.cancel();
      _firstTokenFallbackTimer?.cancel();
      _fakeTypingTimer?.cancel();
      _fakeTypingAssistantIndex = -1;
      if (mounted) {
        setState(() {
          _progress = null;
          _sending = false;
        });
      }
    }
  }

  String _buildAddResponse(List<_IntentItem> items) {
    final usable = items
        .where((e) => e.name.trim().isNotEmpty)
        .map(
          (e) => _IntentItem(
            name: e.name.trim(),
            qty: e.qty <= 0 ? 1 : e.qty,
            all: false,
          ),
        )
        .toList();
    if (usable.isEmpty) return _fallbackNoResponse;

    if (usable.length == 1) {
      final it = usable.first;
      return 'Added ${it.qty} ${_pluralize(it.name, it.qty)} to your inventory.';
    }

    final parts = usable.take(3).map((it) => '${it.qty} ${_pluralize(it.name, it.qty)}').toList();
    final joined = _joinWithAnd(parts);
    final extra = usable.length > 3 ? ' and ${usable.length - 3} more' : '';
    return 'Added $joined$extra to your inventory.';
  }

  String _buildRemoveResponse(List<_IntentItem> items) {
    final usable = items
        .where((e) => e.name.trim().isNotEmpty)
        .map(
          (e) => _IntentItem(
            name: e.name.trim(),
            qty: e.all ? 0 : (e.qty <= 0 ? 1 : e.qty),
            all: e.all,
          ),
        )
        .toList();
    if (usable.isEmpty) return 'What should I remove?';

    if (usable.length == 1) {
      final it = usable.first;
      if (it.all) {
        return 'Removed all ${_pluralize(it.name, 2)} from your inventory.';
      }
      return 'Removed ${it.qty} ${_pluralize(it.name, it.qty)}.';
    }

    final parts = usable
        .take(3)
        .map(
          (it) => it.all
              ? 'all ${_pluralize(it.name, 2)}'
              : '${it.qty} ${_pluralize(it.name, it.qty)}',
        )
        .toList();
    final joined = _joinWithAnd(parts);
    final extra = usable.length > 3 ? ' and ${usable.length - 3} more' : '';
    final suffix = usable.any((e) => e.all) ? ' from your inventory' : '';
    return 'Removed $joined$extra$suffix.';
  }

  Future<void> _executeAddInBackground(List<_IntentItem> items) async {
    try {
      if (items.isEmpty) return;
      for (final it in items) {
        final qty = it.qty <= 0 ? 1 : it.qty;
        final name = it.name.trim();
        if (name.isEmpty) continue;
        await widget.api.addItem(
          item: AddItemRequest(
            name: name,
            category: 'Unsorted',
            quantity: qty,
            location: 'Unsorted',
          ),
        );
      }
      widget.onInventoryMutated?.call();
      unawaited(_prefetchInventorySnapshot());
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> _executeClearAllInBackground() async {
    try {
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null || uid.isEmpty) return;
      await supabase.from('items').delete().eq('user_id', uid);
      widget.onInventoryMutated?.call();
      unawaited(_prefetchInventorySnapshot());
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> _executeRemoveItemsInBackground(List<_IntentItem> items) async {
    try {
      if (items.isEmpty) return;

      var removedAny = false;
      for (final t in items) {
        final q = t.name.trim();
        if (q.isEmpty) continue;

        final res = await widget.api.searchItems(query: q);
        var matches = res.items;
        if (matches.isEmpty) continue;

        final exact = matches
            .where((it) => it.name.trim().toLowerCase() == q.toLowerCase())
            .toList();
        if (exact.length == 1) {
          matches = exact;
        }

        if (t.all) {
          for (final m in matches) {
            final ok = await widget.api.deleteItem(itemId: m.itemId);
            if (ok) removedAny = true;
          }
          continue;
        }

        var remaining = t.qty <= 0 ? 1 : t.qty;
        for (final m in matches) {
          if (remaining <= 0) break;
          if (m.quantity > remaining) {
            await widget.api.updateItem(
              request: UpdateItemRequest(
                itemId: m.itemId,
                quantity: m.quantity - remaining,
              ),
            );
            removedAny = true;
            remaining = 0;
          } else {
            final ok = await widget.api.deleteItem(itemId: m.itemId);
            if (ok) removedAny = true;
            remaining -= m.quantity;
          }
        }
      }

      if (removedAny) {
        widget.onInventoryMutated?.call();
        unawaited(_prefetchInventorySnapshot());
      }
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<String> _deterministicFindResponse(String query) async {
    final q = _singularize(query)
        .replaceAll(RegExp(r'\b(my|the|a|an)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (q.isEmpty) return 'What item should I look for?';

    if (_inventorySnapshot == null) {
      await _prefetchInventorySnapshot();
    }
    final items = _inventorySnapshot ?? const <InventoryItem>[];

    final qLower = q.toLowerCase();
    final matches = items
        .where((it) => it.name.trim().toLowerCase().contains(qLower))
        .toList();

    if (matches.isEmpty) {
      return "I couldn't find any items matching '$q'.";
    }

    final groups = <String, ({String name, String location, int qty})>{};
    for (final it in matches) {
      final name = it.name.trim();
      final location = it.location.trim();
      final key = '${name.toLowerCase()}@@${location.toLowerCase()}';
      final prev = groups[key];
      groups[key] = (
        name: name,
        location: location,
        qty: (prev?.qty ?? 0) + it.quantity,
      );
    }
    final grouped = groups.values.toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));

    final shown = grouped.take(5).toList();
    final parts = shown.map((g) {
      final loc = g.location.trim().isEmpty ? 'unknown location' : g.location.trim().toLowerCase();
      return '${g.qty} ${_pluralize(g.name, g.qty)} in the $loc';
    }).toList();

    final typesWord = _pluralize(q, shown.length);
    final intro = shown.length == 1
        ? 'You have 1 type of $typesWord:'
        : 'You have ${shown.length} types of $typesWord:';

    final body = parts.length == 1
        ? parts.first
        : '${parts.sublist(0, parts.length - 1).join(' and ')} and ${parts.last}';
    final extra = grouped.length > shown.length ? ' (and ${grouped.length - shown.length} more)' : '';
    return '$intro $body$extra.';
  }

  Future<String> _deterministicListResponse() async {
    if (_inventorySnapshot == null) {
      await _prefetchInventorySnapshot();
    }
    final items = _inventorySnapshot ?? const <InventoryItem>[];
    if (items.isEmpty) return "You don't have any items saved yet.";

    final names = items
        .map((e) => e.name.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final unique = <String>{};
    final top = <String>[];
    for (final n in names) {
      final key = n.toLowerCase();
      if (unique.add(key)) {
        top.add(_pluralize(_singularize(n), 2));
      }
      if (top.length >= 3) break;
    }

    final including = top.isEmpty
        ? ''
        : top.length == 1
            ? ' including ${top.first}'
            : top.length == 2
                ? ' including ${top[0]} and ${top[1]}'
                : ' including ${top[0]}, ${top[1]}, and ${top[2]}';
    return 'You have ${items.length} items$including.';
  }

  Future<String> _deterministicResponseAndKickoffExecution(_AiIntent intent) async {
    try {
      final action = intent.action.trim();

      if (action == 'unknown') {
        return _unknownActionResponse;
      }

      if (action == 'add_item') {
        final merged = _mergeDuplicateItems(intent.items);
        final response = _buildAddResponse(merged);
        unawaited(_executeAddInBackground(merged));
        return response;
      }
      if (action == 'remove_item') {
        final q = (intent.query ?? '').trim();
        if (q.toUpperCase() == 'ALL_ITEMS') {
          unawaited(_executeClearAllInBackground());
          return 'Cleared your entire inventory.';
        }

        final rawTargets = intent.items.isNotEmpty
            ? intent.items
            : <_IntentItem>[if (q.isNotEmpty) _IntentItem(name: q, qty: 1)];
        final targets = _mergeDuplicateItems(rawTargets);
        if (targets.isEmpty && q.isNotEmpty && _isBadItemName(q)) {
          unawaited(_executeClearAllInBackground());
          return 'Cleared your entire inventory.';
        }

        if (targets.isEmpty) {
          return _unknownActionResponse;
        }

        final response = _buildRemoveResponse(targets);
        unawaited(_executeRemoveItemsInBackground(targets));
        return response;
      }
      if (action == 'find_item') {
        final q = (intent.query ?? (intent.items.isNotEmpty ? intent.items.first.name : '')).trim();
        if (q.isEmpty) return _unknownActionResponse;
        return _deterministicFindResponse(q);
      }
      if (action == 'list_items') {
        return _deterministicListResponse();
      }

      return _unknownActionResponse;
    } catch (e) {
      debugPrint('deterministicResponseAndKickoffExecution error: $e');
      return _guaranteedFallbackResponse;
    }
  }

  void _replaceAssistantMessage(int assistantIndex, String text) {
    if (!mounted) return;
    _fakeTypingTimer?.cancel();
    _fakeTypingAssistantIndex = -1;
    _firstTokenFallbackTimer?.cancel();
    setState(() {
      if (assistantIndex >= 0 && assistantIndex < _messages.length) {
        _messages[assistantIndex] = _ChatMessage(
          role: 'assistant',
          content: text,
          timestamp: _nowTs(),
        );
      } else {
        _messages.add(
          _ChatMessage(role: 'assistant', content: text, timestamp: _nowTs()),
        );
      }
    });
    _scrollToBottom();
  }

  void _startFakeTyping(int assistantIndex) {
    _fakeTypingTimer?.cancel();
    _fakeTypingAssistantIndex = assistantIndex;
    _fakeTypingCharIndex = 0;

    _fakeTypingTimer = Timer.periodic(const Duration(milliseconds: 28), (t) {
      if (!mounted) return;
      if (_fakeTypingAssistantIndex != assistantIndex) {
        t.cancel();
        return;
      }
      if (assistantIndex < 0 || assistantIndex >= _messages.length) {
        t.cancel();
        return;
      }
      final m = _messages[assistantIndex];
      if (m.role != 'assistant') {
        t.cancel();
        return;
      }

      final nextLen = _fakeTypingCharIndex + 1;
      if (nextLen > _fakeTypingText.length) {
        t.cancel();
        return;
      }

      _fakeTypingCharIndex = nextLen;
      final nextText = _fakeTypingText.substring(0, nextLen);
      setState(() {
        _messages[assistantIndex] = m.copyWith(content: nextText);
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _startThinkingFallbackTimer(int assistantIndex) {
    _firstTokenFallbackTimer?.cancel();
    _firstTokenFallbackTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (assistantIndex < 0 || assistantIndex >= _messages.length) return;
      final m = _messages[assistantIndex];
      if (m.role != 'assistant') return;
      setState(() {
        _messages[assistantIndex] = m.copyWith(content: 'Thinking…');
      });
      _scrollToBottom();
    });
  }

  Future<void> _streamAssistantText({
    required int assistantIndex,
    required String text,
  }) async {
    if (!mounted) return;
    _fakeTypingTimer?.cancel();
    _fakeTypingAssistantIndex = assistantIndex;
    _fakeTypingCharIndex = 0;

    final safe = text;
    if (assistantIndex < 0 || assistantIndex >= _messages.length) return;
    setState(() {
      _messages[assistantIndex] =
          _messages[assistantIndex].copyWith(content: '');
    });
    _scrollToBottom(animated: false);

    final completer = Completer<void>();
    _fakeTypingTimer = Timer.periodic(const Duration(milliseconds: 18), (t) {
      if (!mounted) {
        t.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }
      if (_fakeTypingAssistantIndex != assistantIndex) {
        t.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }
      if (assistantIndex < 0 || assistantIndex >= _messages.length) {
        t.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }
      final current = _messages[assistantIndex];
      if (current.role != 'assistant') {
        t.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }

      final nextLen = (_fakeTypingCharIndex + 2).clamp(0, safe.length);
      if (nextLen <= _fakeTypingCharIndex) {
        t.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }
      _fakeTypingCharIndex = nextLen;
      final nextText = safe.substring(0, nextLen);
      setState(() {
        _messages[assistantIndex] = current.copyWith(content: nextText);
      });
      _scrollToBottom();

      if (_fakeTypingCharIndex >= safe.length) {
        t.cancel();
        if (!completer.isCompleted) completer.complete();
      }
    });

    await completer.future;

    if (!mounted) return;
    if (_fakeTypingAssistantIndex == assistantIndex) {
      _fakeTypingAssistantIndex = -1;
    }
  }

  dio.Dio _backend() {
    final d = dio.Dio(
      dio.BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 2),
        sendTimeout: const Duration(minutes: 2),
      ),
    );
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token != null && token.isNotEmpty) {
      d.options.headers['Authorization'] = 'Bearer $token';
    }
    return d;
  }

  Future<_UploadKind?> _pickUploadKind() async {
    if (!mounted) return null;
    return showModalBottomSheet<_UploadKind>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GlassCard(
              padding: const EdgeInsets.all(8),
              borderRadius: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: const Text('Upload Image'),
                    onTap: () => Navigator.of(context).pop(_UploadKind.image),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Upload Document'),
                    onTap: () =>
                        Navigator.of(context).pop(_UploadKind.document),
                  ),
                  ListTile(
                    leading: const Icon(Icons.attach_file),
                    title: const Text('Upload File'),
                    onTap: () => Navigator.of(context).pop(_UploadKind.file),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<PlatformFile?> _pickFileForKind(_UploadKind kind) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: switch (kind) {
        _UploadKind.image => FileType.image,
        _UploadKind.document => FileType.custom,
        _UploadKind.file => FileType.any,
      },
      allowedExtensions: kind == _UploadKind.document
          ? const ['pdf', 'txt', 'doc', 'docx', 'rtf', 'md']
          : null,
    );
    if (picked == null || picked.files.isEmpty) return null;
    return picked.files.first;
  }

  Future<void> _attachDocument() async {
    if (_sending) return;
    final kind = await _pickUploadKind();
    if (!mounted) return;
    if (kind == null) return;

    if (kind == _UploadKind.image) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => ScanPage(
            api: widget.api,
            onSaved: () => widget.onInventoryMutated?.call(),
          ),
        ),
      );

      widget.onInventoryMutated?.call();
      unawaited(_prefetchInventorySnapshot());
      return;
    }

    var assistantIndex = -1;
    var createdAssistantMessage = false;

    try {
      final f = await _pickFileForKind(kind);
      if (f == null) return;

      final name = (f.name).trim();
      if (name.isEmpty) return;
      if (_isVideoFile(name)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Videos aren’t supported.')),
        );
        return;
      }

      final bytes = f.bytes;
      if (bytes == null || bytes.isEmpty) return;

      if (!mounted) return;
      setState(() {
        _sending = true;
        _progress = 'Uploading file...';
        _sentFirstMessage = true;
        _messages.add(
          _ChatMessage(
            role: 'user',
            content:
                'Uploaded ${kind == _UploadKind.image ? 'image' : 'file'}: $name',
            timestamp: _nowTs(),
          ),
        );
      });

      _scrollToBottom(animated: false);

      assistantIndex = _messages.length;

      final mime = _guessMimeType(name);
      final ctParts = mime.split('/');
      final mediaType = (ctParts.length == 2)
          ? MediaType(ctParts[0], ctParts[1])
          : null;

      final client = _backend();
      final form = dio.FormData.fromMap({
        'file': dio.MultipartFile.fromBytes(
          bytes,
          filename: name,
          contentType: mediaType,
        ),
      });

      final res = await client.post<dio.ResponseBody>(
        '/ai_upload',
        data: form,
        options: dio.Options(
          responseType: dio.ResponseType.stream,
          headers: const <String, dynamic>{'Accept': 'text/event-stream'},
          receiveTimeout: const Duration(minutes: 2),
          sendTimeout: const Duration(minutes: 2),
        ),
      );

      if (!mounted) return;
      setState(() => _progress = 'Analyzing file...');

      final body = res.data;
      if (body == null) throw StateError('Missing stream body');

      final buffer = StringBuffer();
      Timer? flush;

      void flushNow() {
        if (!mounted) return;
        final add = buffer.toString();
        if (add.isEmpty) return;
        buffer.clear();

        _fakeTypingTimer?.cancel();
        _fakeTypingAssistantIndex = -1;
        _firstTokenFallbackTimer?.cancel();
        if (!mounted) return;
        setState(() {
          if (!createdAssistantMessage) {
            createdAssistantMessage = true;
            _messages.add(
              _ChatMessage(
                role: 'assistant',
                content: add,
                timestamp: _nowTs(),
              ),
            );
            assistantIndex = _messages.length - 1;
          } else if (assistantIndex >= 0 && assistantIndex < _messages.length) {
            final prev = _messages[assistantIndex].content;
            _messages[assistantIndex] = _messages[assistantIndex].copyWith(
              content: prev + add,
              timestamp: _nowTs(),
            );
          }
        });
        _scrollToBottom();
      }

      bool streamedAny = false;
      try {
        await for (final line
            in body.stream
                .cast<List<int>>()
                .transform(utf8.decoder)
                .transform(const LineSplitter())) {
          final l = line.trimRight();
          if (l.isEmpty) continue;
          if (!l.startsWith('data:')) continue;
          final raw = l.substring('data:'.length).trim();
          if (raw.isEmpty) continue;
          final decoded = json.decode(raw);
          if (decoded is! Map) continue;
          final evt = AiStreamEvent.fromJson(decoded.cast<String, dynamic>());

          if (!mounted) return;
          if (evt.type == 'status' && (evt.message ?? '').isNotEmpty) {
            if (!mounted) return;
            setState(() => _progress = evt.message);
            continue;
          }
          if (evt.type == 'delta') {
            final d = evt.delta ?? '';
            if (d.isEmpty) continue;
            if (!streamedAny) {
              _firstTokenFallbackTimer?.cancel();
              if (!mounted) return;
              setState(() => _progress = null);
            }
            streamedAny = true;
            buffer.write(d);
            flush?.cancel();
            flush = null;
            flushNow();
          }
          if (evt.type == 'done') {
            flush?.cancel();
            flushNow();
            break;
          }
        }
      } finally {
        flush?.cancel();
        flushNow();
      }

      if (!mounted) return;
      if (!createdAssistantMessage) {
        setState(() {
          _messages.add(
            _ChatMessage(
              role: 'assistant',
              content: 'Something went wrong. Please try again.',
              timestamp: _nowTs(),
            ),
          );
        });
        _scrollToBottom();
      } else if (assistantIndex >= 0 && assistantIndex < _messages.length) {
        final prev = _messages[assistantIndex].content;
        if (prev.trim().isEmpty) {
          setState(() {
            _messages[assistantIndex] = _messages[assistantIndex].copyWith(
              content: 'Something went wrong. Please try again.',
              timestamp: _nowTs(),
            );
          });
          _scrollToBottom();
        }
      }
    } on dio.DioException catch (e) {
      if (!mounted) return;
      _firstTokenFallbackTimer?.cancel();
      if (!createdAssistantMessage) {
        setState(() {
          _messages.add(
            _ChatMessage(
              role: 'assistant',
              content: _friendlyRequestError(e),
              timestamp: _nowTs(),
            ),
          );
        });
        _scrollToBottom();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyRequestError(e))));
    } catch (e) {
      if (!mounted) return;
      _firstTokenFallbackTimer?.cancel();
      if (!createdAssistantMessage) {
        setState(() {
          _messages.add(
            _ChatMessage(
              role: 'assistant',
              content: _friendlyRequestError(e),
              timestamp: _nowTs(),
            ),
          );
        });
        _scrollToBottom();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyRequestError(e))));
    } finally {
      if (mounted) {
        setState(() {
          _progress = null;
          _sending = false;
        });
      }
      _firstTokenFallbackTimer?.cancel();
    }
  }

  bool _looksLikeSummarizeMyDocument(String q) {
    final s = q.trim().toLowerCase();
    if (!s.contains('summarize')) return false;
    if (!s.contains('document') && !s.contains('docs')) return false;
    return s.contains('my document') ||
        s.contains('my documents') ||
        s.contains('my doc') ||
        s == 'summarize document' ||
        s == 'summarize documents';
  }

  Future<List<DocumentEntry>> _loadDocChoices() async {
    try {
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null || uid.isEmpty) return const [];

      List<Map<String, dynamic>> rows;
      try {
        final resp = await supabase
            .from('documents')
            .select('storage_path,filename,display_name,mime_type,created_at')
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(50);
        rows = (resp as List<dynamic>).cast<Map<String, dynamic>>();
      } catch (_) {
        final resp = await supabase
            .from('documents')
            .select('storage_path,filename,mime_type,created_at')
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(50);
        rows = (resp as List<dynamic>).cast<Map<String, dynamic>>();
      }

      return rows
          .map(DocumentEntry.fromJson)
          .where((d) => d.documentId.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  bool _isVideoFile(String filename) {
    final lower = filename.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm');
  }

  String _guessMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }

  String _messageWithAttachments(String q) {
    if (_pendingAttachments.isEmpty) return q;
    final names = _pendingAttachments.join(', ');
    return '$q\n\nAttached documents: $names';
  }

  bool _isLowStockQuery(String q) {
    final s = q.toLowerCase();
    return s.contains('low stock') ||
        s.contains('restock') ||
        s.contains('running low') ||
        s.contains('out of');
  }

  ({String? type, String? query}) _parseSimpleInventoryQuery(String q) {
    final s = q.trim();
    if (s.isEmpty) return (type: null, query: null);

    final lower = s.toLowerCase();
    final somethingSimilar = RegExp(
      r'^do i have\s+something\s+similar\s+to\s+(.+?)\??$',
      caseSensitive: false,
    );
    final doIHave = RegExp(r'^do i have\s+(.+?)\??$', caseSensitive: false);
    final doIAlreadyOwn = RegExp(
      r'^do i already own\s+(.+?)\??$',
      caseSensitive: false,
    );
    final howMany = RegExp(
      r'^how many\s+(.+?)\s+do i have\??$',
      caseSensitive: false,
    );

    final m2 = howMany.firstMatch(lower);
    if (m2 != null) {
      final query = (m2.group(1) ?? '').trim();
      return (type: 'count', query: query.isEmpty ? null : query);
    }

    final m4 = somethingSimilar.firstMatch(lower);
    if (m4 != null) {
      final query = (m4.group(1) ?? '').trim();
      return (type: 'similar', query: query.isEmpty ? null : query);
    }

    final m1 = doIHave.firstMatch(lower);
    if (m1 != null) {
      final query = (m1.group(1) ?? '').trim();
      return (type: 'have', query: query.isEmpty ? null : query);
    }

    final m3 = doIAlreadyOwn.firstMatch(lower);
    if (m3 != null) {
      final query = (m3.group(1) ?? '').trim();
      return (type: 'have', query: query.isEmpty ? null : query);
    }

    return (type: null, query: null);
  }

  String? _answerSimpleInventoryQuery({
    required String type,
    required String query,
  }) {
    final items = _inventorySnapshot;
    if (items == null || items.isEmpty) return null;
    final q = query.toLowerCase();
    final matches = items
        .where((it) => it.name.toLowerCase().contains(q))
        .toList();
    if (type == 'similar') {
      if (matches.isNotEmpty) {
        final total = matches.fold<int>(0, (acc, it) => acc + it.quantity);
        return 'Yes — you have $total "$query".';
      }

      final tokens = q
          .split(RegExp(r'\s+'))
          .where((t) => t.trim().isNotEmpty)
          .toList();
      final similar = <InventoryItem>[];
      for (final it in items) {
        final n = it.name.toLowerCase();
        if (tokens.any((t) => n.contains(t))) {
          similar.add(it);
        }
      }
      if (similar.isEmpty) {
        return 'No — I don’t see "$query" in your inventory.';
      }

      final top = similar.take(3).map((it) => it.name).toList();
      return 'I didn’t find $query, but you have:\n• ${top.join('\n• ')}';
    }
    if (type == 'have') {
      if (matches.isEmpty) {
        return 'No — I don’t see "$query" in your inventory.';
      }
      final total = matches.fold<int>(0, (acc, it) => acc + it.quantity);
      return 'Yes — you have $total "$query".';
    }
    if (type == 'count') {
      final total = matches.fold<int>(0, (acc, it) => acc + it.quantity);
      return matches.isEmpty
          ? '0 — I don’t see "$query" in your inventory.'
          : '$total.';
    }
    return null;
  }

  Future<String> _answerSimpleInventoryQueryWithFetch({
    required String type,
    required String query,
  }) async {
    if (_inventorySnapshot == null || (_inventorySnapshot?.isEmpty ?? true)) {
      await _prefetchInventorySnapshot();
    }
    return _answerSimpleInventoryQuery(type: type, query: query) ??
        'No — I don’t see "$query" in your inventory.';
  }

  Future<void> _prefetchInventorySnapshot() async {
    try {
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null || uid.isEmpty) return;

      final resp = await supabase
          .from('items')
          .select('item_id,name,category,quantity,location,created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(250);

      final rows = (resp as List<dynamic>).cast<Map<String, dynamic>>();
      final items = rows.map(InventoryItem.fromJson).toList();
      if (!mounted) return;
      _inventorySnapshot = items;
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<String?> _lowStockSummary() async {
    final thresholds = await LowStockPrefs.loadAll();
    if (thresholds.isEmpty) return null;

    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return null;

    final resp = await supabase
        .from('items')
        .select('item_id,name,category,quantity,location,created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(200);

    final rows = (resp as List<dynamic>).cast<Map<String, dynamic>>();
    final low = <({String name, int qty, int thr})>[];
    for (final r in rows) {
      final id = (r['item_id'] ?? '').toString();
      final thr = thresholds[id];
      if (thr == null || thr <= 0) continue;

      final q = (r['quantity'] is num)
          ? (r['quantity'] as num).toInt()
          : int.tryParse((r['quantity'] ?? '').toString()) ?? 0;
      if (q <= thr) {
        final name = (r['name'] ?? '').toString().trim();
        if (name.isNotEmpty) low.add((name: name, qty: q, thr: thr));
      }
    }

    if (low.isEmpty) return null;
    low.sort((a, b) => a.qty.compareTo(b.qty));
    final top = low
        .take(6)
        .map((e) => '${e.name} (Qty ${e.qty} ≤ ${e.thr})')
        .join(', ');
    return 'Low stock: $top.';
  }

  String _friendlyRequestError(Object error) {
    if (error is dio.DioException) {
      return 'Connection issue. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _submit(String text) async {
    final q = text.trim();
    if (q.isEmpty || _sending) return;

    developer.log('ChatPage: Submitting message "$q"');

    if (!mounted) return;

    _phaseTimer1?.cancel();
    _phaseTimer2?.cancel();

    if (!mounted) return;
    setState(() {
      _sending = true;
      _progress = 'Thinking…';
      _sentFirstMessage = true;
      _messages.add(
        _ChatMessage(role: 'user', content: q, timestamp: _nowTs()),
      );
    });
    _controller.clear();
    _scrollToBottom(animated: false);

    try {
      developer.log('ChatPage: Calling aiCommand...');
      final out = await widget.api.aiCommand(message: q);
      developer.log('ChatPage: Received response');
      if (!mounted) return;

      final assistantText = out.assistantMessage;
      final displayText = assistantText.trim().isEmpty
          ? 'Something went wrong. Please try again.'
          : assistantText;

      setState(() {
        _messages.add(
          _ChatMessage(
            role: 'assistant',
            content: displayText,
            timestamp: _nowTs(),
          ),
        );
      });
      _scrollToBottom();

      widget.onInventoryMutated?.call();
      unawaited(_prefetchInventorySnapshot());
    } on dio.DioException catch (e) {
      developer.log('ChatPage: DioException: $e');
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            role: 'assistant',
            content: _friendlyRequestError(e),
            timestamp: _nowTs(),
          ),
        );
      });
      _scrollToBottom();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyRequestError(e))));
    } catch (e) {
      developer.log('ChatPage: Exception: $e');
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            role: 'assistant',
            content: _friendlyRequestError(e),
            timestamp: _nowTs(),
          ),
        );
      });
      _scrollToBottom();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyRequestError(e))));
    } finally {
      _phaseTimer1?.cancel();
      _phaseTimer2?.cancel();
      if (mounted) {
        setState(() {
          _progress = null;
          _sending = false;
        });
      }
      developer.log('ChatPage: _sending reset to false');
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    assert(() {
      final keepAlive = <Object?>[
        _sentFirstMessage,
        _pendingDocChoices,
        _sanitizeUserTextForAi,
        _showAssistantTypingDots,
        _handleAiIntentFlow,
        _startFakeTyping,
        _attachDocument,
        _looksLikeSummarizeMyDocument,
        _loadDocChoices,
        _messageWithAttachments,
        _isLowStockQuery,
        _parseSimpleInventoryQuery,
        _answerSimpleInventoryQueryWithFetch,
        _lowStockSummary,
        _tryLocalIntentFromUserText,
        _getIntentFromAi,
        _buildIntentPrompt,
        _deterministicResponseAndKickoffExecution,
        _fallbackNoResponse,
        _unknownActionResponse,
        _guaranteedFallbackResponse,
        _safeFallbackIntent,
      ];
      return keepAlive.isNotEmpty;
    }());
    unawaited(_prefetchInventorySnapshot());

    final initial = (widget.initialMessage ?? '').trim();
    if (initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.text = initial;
        unawaited(_submit(initial));
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _phaseTimer1?.cancel();
    _phaseTimer2?.cancel();
    _firstTokenFallbackTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildEmptyState() {
    final items = InventoryCache.items;
    final itemCount = items.length;
    final spaces = <String>{};
    for (final it in items) {
      final loc = it.location.trim().isEmpty ? 'Unsorted' : it.location.trim();
      spaces.add(loc.toLowerCase());
    }
    final spaceCount = spaces.length;

    const suggestions = [
      "What's low on stock?",
      'Find something I own',
      'What did I scan recently?',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (itemCount > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
            ),
            child: Text(
              'You have $itemCount ${itemCount == 1 ? 'item' : 'items'} across $spaceCount ${spaceCount == 1 ? 'space' : 'spaces'}.',
              style: const TextStyle(
                color: Color(0x73FFFFFF),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in suggestions)
              GestureDetector(
                onTap: () {
                  _controller.text = s;
                  unawaited(_submit(s));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                  ),
                  child: Text(
                    s,
                    style: const TextStyle(
                      color: Color(0x73FFFFFF),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    const bgGradient = LinearGradient(
      colors: [
        Color(0xFF020617),
        Color(0xFF020617),
        Color(0xFF0F172A),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Ask'),
        centerTitle: true,
        actions: [
          if (widget.onProfileTap != null)
            IconButton(
              onPressed: widget.onProfileTap,
              icon: const Icon(Icons.person_outline),
            ),
          IconButton(
            onPressed: _resetChat,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: bgGradient),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, isIOS ? 16 : 18, 16, 16),
          child: Column(
            children: [
            SizedBox(height: isIOS ? 4 : 8),
            SizedBox(height: isIOS ? 4 : 6),
            SizedBox(height: isIOS ? 16 : 18),
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        top: isIOS ? 8 : 10,
                        bottom: isIOS ? 8 : 10,
                      ),
                      itemCount: _messages.length,
                      separatorBuilder: (context, index) {
                        final curr = _messages[index];
                        final next = _messages[index + 1];
                        return SizedBox(height: curr.role == next.role ? 4 : 12);
                      },
                      itemBuilder: (context, index) {
                        final m = _messages[index];
                        final align = m.role == 'user'
                            ? Alignment.centerRight
                            : Alignment.centerLeft;
                        final isUser = m.role == 'user';
                        final isTyping = !isUser &&
                            (index == _fakeTypingAssistantIndex ||
                                m.content == 'Typing…' ||
                                m.content == 'Thinking…' ||
                                m.content == 'Thinking...');
                        return Align(
                          alignment: align,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: isUser
                                ? Container(
                                    margin: const EdgeInsets.only(left: 48, bottom: 8, top: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: const BoxDecoration(
                                      color: Color(0x1AFFFFFF),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        topRight: Radius.circular(4),
                                        bottomLeft: Radius.circular(20),
                                        bottomRight: Radius.circular(20),
                                      ),
                                    ),
                                    child: Text(
                                      m.content,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                        height: 1.5,
                                      ),
                                    ),
                                  )
                                : Container(
                                    margin: const EdgeInsets.only(right: 48, bottom: 8, top: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0x0AFFFFFF),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        topRight: Radius.circular(20),
                                        bottomLeft: Radius.circular(20),
                                        bottomRight: Radius.circular(20),
                                      ),
                                      border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                                    ),
                                    child: isTyping
                                        ? (m.content.trim().isEmpty
                                            ? const _TypingDots()
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    m.content,
                                                    style: const TextStyle(
                                                      color: Color(0x73FFFFFF),
                                                      fontSize: 15,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  const _TypingDots(),
                                                ],
                                              ))
                                        : MarkdownBody(
                                            data: m.content,
                                            styleSheet: MarkdownStyleSheet(
                                              p: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontFamily: '.SF Pro Text',
                                                fontWeight: FontWeight.w400,
                                                height: 1.6,
                                              ),
                                              strong: const TextStyle(
                                                color: Colors.white,
                                                fontFamily: '.SF Pro Text',
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                              em: const TextStyle(
                                                color: Color(0x73FFFFFF),
                                                fontFamily: '.SF Pro Text',
                                                fontStyle: FontStyle.italic,
                                                fontSize: 15,
                                              ),
                                              listBullet: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontFamily: '.SF Pro Text',
                                              ),
                                              blockSpacing: 8,
                                              listIndent: 16,
                                            ),
                                            softLineBreak: true,
                                          ),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
            if (_sending && _progress != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _progress!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0x0AFFFFFF),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: const Color(0x14FFFFFF),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Ask anything…',
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        hintStyle: TextStyle(color: Color(0x33FFFFFF)),
                      ),
                      onSubmitted: (v) => _submit(v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _sending ? null : () => unawaited(_submit(_controller.text)),
                    child: Text(
                      _sending ? '…' : 'Send',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _ChatMessage {
  _ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  final String role;
  final String content;
  final int timestamp;

  _ChatMessage copyWith({String? content, int? timestamp}) {
    return _ChatMessage(
      role: role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
