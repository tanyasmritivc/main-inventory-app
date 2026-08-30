import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:dio/dio.dart' as dio;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http_parser/http_parser.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/config.dart';
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
    this.onScanTap,
    this.onOpenInventory,
    this.inPageView = false,
    this.onRegisterReset,
    this.onRegisterOpenHistory,
    this.onChatStateChanged,
    this.pageController,
    this.onOpenDestination,
  });

  final ApiClient api;
  final VoidCallback? onInventoryMutated;
  final String? initialMessage;
  final VoidCallback? onProfileTap;
  final VoidCallback? onScanTap;
  final VoidCallback? onOpenInventory;
  final bool inPageView;
  final void Function(VoidCallback)? onRegisterReset;
  final void Function(VoidCallback)? onRegisterOpenHistory;
  final void Function(bool hasMessages)? onChatStateChanged;
  final PageController? pageController;
  final Future<void> Function(Map<String, dynamic>)? onOpenDestination;

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
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        double dot(double phase) {
          final v = (t + phase) % 1.0;
          return 0.35 + (0.65 * (1.0 - (2.0 * (v - 0.5)).abs()));
        }

        final color = Colors.white.withValues(alpha: 0.4);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(opacity: dot(0.0), color: color),
            const SizedBox(width: 6),
            _Dot(opacity: dot(0.2), color: color),
            const SizedBox(width: 6),
            _Dot(opacity: dot(0.4), color: color),
          ],
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

class _ChatSession {
  static final _ChatSession _instance = _ChatSession._internal();
  factory _ChatSession() => _instance;
  _ChatSession._internal();

  List<_ChatMessage> messages = [];
  bool hasStarted = false;
}

class _ChatPageState extends State<ChatPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  bool _sending = false;
  String? _progress;
  final _session = _ChatSession();
  String _userInitial = '';

  // Conversation history
  String? _currentConversationId;
  // Retained for the intentionally detached history panel (68f5e83).
  // ignore: unused_field
  bool _historyOpen = false;
  bool _historyLoading = false;
  bool _historyLoadFailed = false;
  List<ConversationSummary> _conversations = [];

  Timer? _phaseTimer1;
  Timer? _phaseTimer2;
  Timer? _firstTokenFallbackTimer;
  Timer? _presentationTimer;
  final Map<int, StringBuffer> _presentationBuffers = {};
  final Queue<({int index, String text})> _presentationQueue = Queue();
  final Map<int, Map<String, dynamic>?> _presentationHints = {};
  final Set<int> _presentationComplete = <int>{};
  final Queue<String> _queuedFollowUps = Queue();
  bool _canQueueFollowUp = false;

  Timer? _fakeTypingTimer;
  int _fakeTypingAssistantIndex = -1;

  List<InventoryItem>? _inventorySnapshot;

  final List<String> _pendingAttachments = [];

  Map<String, dynamic>? _pendingNavHint;

  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;

  List<DocumentEntry>? _pendingDocChoices;

  static const _fallbackNoResponse = 'Hmm, try asking that a different way 🙂';

  static const _unknownActionResponse =
      'I’m not totally sure what you meant, but I can help you add, remove, or find items.';

  static const _guaranteedFallbackResponse =
      "I couldn’t process that, but try something like 'add 2 items'.";

  static const _AiIntent _safeFallbackIntent =
      _AiIntent(action: 'unknown', items: <_IntentItem>[], query: '');

  int _nowTs() => DateTime.now().millisecondsSinceEpoch;

  Future<void> _openNavHint(Map<String, dynamic> hint) async {
    try {
      if (widget.onOpenDestination != null) {
        await widget.onOpenDestination!(hint);
      } else {
        widget.pageController?.animateToPage(3, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  String _navHintLabel(Map<String, dynamic> hint) {
    final name = (hint['name'] ?? hint['space_name'] ?? '').toString();
    if (hint['type'] == 'project_kit') return 'Open project kit${name.isEmpty ? '' : ': $name'}';
    if (hint['type'] == 'item') return 'Open ${hint['space_name'] ?? 'item location'}';
    return 'Open ${name.isEmpty ? 'space' : name}';
  }

  String _renderableStreamingMarkdown(String content) {
    final boldMarkers = RegExp(r'\*\*').allMatches(content).length;
    return boldMarkers.isOdd ? '$content**' : content;
  }

  void _enqueuePresentation(int index, String content) {
    final pending = '${_presentationBuffers[index]?.toString() ?? ''}$content';
    final whitespace = RegExp(r'\s').allMatches(pending).toList();
    if (whitespace.isEmpty) {
      _presentationBuffers[index] = StringBuffer(pending);
      return;
    }
    final splitAt = whitespace.last.end;
    _presentationBuffers[index] = StringBuffer(pending.substring(splitAt));
    _queuePresentationWords(index, pending.substring(0, splitAt));
  }

  void _queuePresentationWords(int index, String content) {
    for (final match in RegExp(r'\S+\s*').allMatches(content)) {
      _presentationQueue.add((index: index, text: match.group(0)!));
    }
    _presentationTimer ??= Timer.periodic(const Duration(milliseconds: 48), (_) {
      if (!mounted) return;
      if (_presentationQueue.isEmpty) {
        _presentationTimer?.cancel();
        _presentationTimer = null;
        return;
      }
      final chunk = _presentationQueue.removeFirst();
      if (chunk.index < 0 || chunk.index >= _session.messages.length) return;
      final isLast = _presentationComplete.contains(chunk.index) &&
          !_presentationQueue.any((entry) => entry.index == chunk.index);
      setState(() {
        final message = _session.messages[chunk.index];
        _session.messages[chunk.index] = message.copyWith(
          content: message.content + chunk.text,
          isStreaming: !isLast,
          navHint: isLast ? _presentationHints.remove(chunk.index) : null,
        );
      });
      if (isLast) _presentationComplete.remove(chunk.index);
      _scrollToBottom(animated: false);
    });
  }

  void _completePresentation(int index, Map<String, dynamic>? hint) {
    if (!mounted || index < 0 || index >= _session.messages.length) return;
    var remainder = _presentationBuffers.remove(index)?.toString() ?? '';
    final hasQueued = _presentationQueue.any((entry) => entry.index == index);
    if (remainder.isEmpty && !hasQueued && _session.messages[index].content.isEmpty) {
      remainder = 'Something went wrong. Please try again.';
    }
    _presentationHints[index] = hint;
    _presentationComplete.add(index);
    if (remainder.isNotEmpty) _queuePresentationWords(index, remainder);
    if (!_presentationQueue.any((entry) => entry.index == index)) {
      setState(() {
        _session.messages[index] = _session.messages[index].copyWith(
          isStreaming: false,
          navHint: _presentationHints.remove(index),
        );
      });
      _presentationComplete.remove(index);
    }
  }

  void _cancelPresentation(int index) {
    _presentationBuffers.remove(index);
    _presentationQueue.removeWhere((entry) => entry.index == index);
    _presentationHints.remove(index);
    _presentationComplete.remove(index);
  }

  void _resetChat() {
    _presentationTimer?.cancel();
    _presentationTimer = null;
    _presentationBuffers.clear();
    _presentationQueue.clear();
    _presentationHints.clear();
    _presentationComplete.clear();
    _queuedFollowUps.clear();
    _phaseTimer1?.cancel();
    _phaseTimer2?.cancel();
    _firstTokenFallbackTimer?.cancel();
    _fakeTypingTimer?.cancel();
    _fakeTypingAssistantIndex = -1;

    _controller.clear();
    _focusNode.unfocus();

    if (!mounted) return;
    setState(() {
      _sending = false;
      _canQueueFollowUp = false;
      _progress = null;
      _session.messages.clear();
      _session.hasStarted = false;
      _pendingAttachments.clear();
      _currentConversationId = null;
    });
    widget.onChatStateChanged?.call(false);
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
    final short = userText.length > 200
        ? userText.substring(0, 200)
        : userText;
    final miniPrompt =
        'Inventory app command. Return JSON only: '
        '{"action":"add_item"|"remove_item"|'
        '"find_item"|"list_items",'
        '"items":[{"name":"string","qty":1}],'
        '"query":"string"}. '
        'User said: $short';
    try {
      final out = await widget.api.aiCommand(message: miniPrompt);
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
      _cancelPresentation(assistantIndex);
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
            if (_session.messages.isNotEmpty &&
                _session.messages.last.role == 'assistant' &&
                _session.messages.last.content.isEmpty) {
              _session.messages[_session.messages.length - 1] = _ChatMessage(
                role: 'assistant',
                content: res.items.isEmpty
                    ? 'No matches found.'
                    : 'Found ${res.items.length} items. Top: ${res.items.take(3).map((i) => i.name).join(', ')}',
                timestamp: _nowTs(),
              );
            } else {
              _session.messages.add(
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
      _cancelPresentation(assistantIndex);
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
        return await _deterministicFindResponse(q);
      }
      if (action == 'list_items') {
        return await _deterministicListResponse();
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
      if (assistantIndex >= 0 && assistantIndex < _session.messages.length) {
        _session.messages[assistantIndex] = _ChatMessage(
          role: 'assistant',
          content: text,
          timestamp: _nowTs(),
        );
      } else {
        _session.messages.add(
          _ChatMessage(role: 'assistant', content: text, timestamp: _nowTs()),
        );
      }
    });
    _scrollToBottom();
  }

  void _startFakeTyping(int assistantIndex) {
    _fakeTypingTimer?.cancel();
    _fakeTypingAssistantIndex = assistantIndex;
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
      if (assistantIndex < 0 || assistantIndex >= _session.messages.length) return;
      final m = _session.messages[assistantIndex];
      if (m.role != 'assistant') return;
      setState(() {
        _session.messages[assistantIndex] = m.copyWith(content: 'Thinking…');
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

    if (assistantIndex < 0 || assistantIndex >= _session.messages.length) return;
    setState(() {
      _session.messages[assistantIndex] =
          _session.messages[assistantIndex].copyWith(content: '');
    });
    _scrollToBottom(animated: false);

    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    _fakeTypingAssistantIndex = -1;
    _presentationBuffers[assistantIndex] = StringBuffer(text);
    _completePresentation(assistantIndex, null);
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
        _session.hasStarted = true;
        _session.messages.add(
          _ChatMessage(
            role: 'user',
            content:
                'Uploaded ${kind == _UploadKind.image ? 'image' : 'file'}: $name',
            timestamp: _nowTs(),
          ),
        );
      });

      _scrollToBottom(animated: false);

      assistantIndex = _session.messages.length;

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
            _session.messages.add(
              _ChatMessage(
                role: 'assistant',
                content: add,
                timestamp: _nowTs(),
              ),
            );
            assistantIndex = _session.messages.length - 1;
          } else if (assistantIndex >= 0 && assistantIndex < _session.messages.length) {
            final prev = _session.messages[assistantIndex].content;
            _session.messages[assistantIndex] = _session.messages[assistantIndex].copyWith(
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
          _session.messages.add(
            _ChatMessage(
              role: 'assistant',
              content: 'Something went wrong. Please try again.',
              timestamp: _nowTs(),
            ),
          );
        });
        _scrollToBottom();
      } else if (assistantIndex >= 0 && assistantIndex < _session.messages.length) {
        final prev = _session.messages[assistantIndex].content;
        if (prev.trim().isEmpty) {
          setState(() {
            _session.messages[assistantIndex] = _session.messages[assistantIndex].copyWith(
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
          _session.messages.add(
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
          _session.messages.add(
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
      final documents = await widget.api.getDocuments();
      return documents
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
      final result = await widget.api.searchItems(query: '');
      if (!mounted) return;
      _inventorySnapshot = result.items;
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<String?> _lowStockSummary() async {
    final thresholds = await LowStockPrefs.loadAll();
    if (thresholds.isEmpty) return null;

    final result = await widget.api.searchItems(query: '');
    final low = <({String name, int qty, int thr})>[];
    for (final item in result.items) {
      final thr = thresholds[item.itemId];
      if (thr == null || thr <= 0) continue;

      if (item.quantity <= thr) {
        final name = item.name.trim();
        if (name.isNotEmpty) {
          low.add((name: name, qty: item.quantity, thr: thr));
        }
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

  Future<void> _submit(String text, {bool userAlreadyAdded = false}) async {
    final q = text.trim();
    if (q.isEmpty) return;
    if (_sending) {
      if (!_canQueueFollowUp || userAlreadyAdded) return;
      _queuedFollowUps.add(q);
      setState(() {
        _canQueueFollowUp = false;
        final safeQ = q.length > 1000 ? '${q.substring(0, 1000)}...' : q;
        _session.messages.add(_ChatMessage(role: 'user', content: safeQ, timestamp: _nowTs()));
      });
      _controller.clear();
      _scrollToBottom(animated: false);
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }

    developer.log('ChatPage: Submitting message "$q"');

    if (!mounted) return;

    _phaseTimer1?.cancel();
    _phaseTimer2?.cancel();

    if (!mounted) return;
    setState(() {
      _sending = true;
      _canQueueFollowUp = false;
      _session.hasStarted = true;
      if (!userAlreadyAdded) {
        final safeQ = q.length > 1000 ? '${q.substring(0, 1000)}...' : q;
        _session.messages.add(_ChatMessage(role: 'user', content: safeQ, timestamp: _nowTs()));
      }
      _session.messages.add(_ChatMessage(role: 'assistant', content: '', timestamp: _nowTs(), isStreaming: true));
    });
    widget.onChatStateChanged?.call(true);
    _controller.clear();
    _scrollToBottom(animated: false);

    final assistantIndex = _session.messages.length - 1;
    try {
      developer.log('ChatPage: Calling AI stream...');
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw StateError('Not authenticated');
      final baseUrl = AppConfig.apiBaseUrl.endsWith('/')
          ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
          : AppConfig.apiBaseUrl;

      final request = http.Request('POST', Uri.parse('$baseUrl/ai_command?stream=true'));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Authorization'] = 'Bearer $token';
      request.body = json.encode(<String, dynamic>{
        'message': q,
        if (_currentConversationId != null) 'conversation_id': _currentConversationId,
      });

      final httpClient = http.Client();
      try {
        final streamedResponse = await httpClient
            .send(request)
            .timeout(const Duration(minutes: 2));
        if (streamedResponse.statusCode != 200) {
          throw StateError('HTTP ${streamedResponse.statusCode}');
        }

        await for (final line in streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (!mounted) break;
          final l = line.trimRight();
          if (!l.startsWith('data: ')) continue;
          final raw = l.substring(6).trim();
          if (raw == '[DONE]') break;
          try {
            final decoded = json.decode(raw);
            if (decoded is! Map) continue;
            final content = (decoded['content'] ?? '') as String;
            if (content.isNotEmpty) {
              _enqueuePresentation(assistantIndex, content);
            }
            final navHintData = decoded['nav_hint'];
            if (navHintData is Map) {
              _pendingNavHint = Map<String, dynamic>.from(navHintData.cast<String, dynamic>());
            }
          } catch (_) {}
        }
      } finally {
        httpClient.close();
      }

      if (mounted) {
        final hint = _pendingNavHint;
        _pendingNavHint = null;
        setState(() {
          _sending = false;
          _canQueueFollowUp = false;
          _progress = null;
        });
        _completePresentation(assistantIndex, hint);
        widget.onInventoryMutated?.call();
        unawaited(_prefetchInventorySnapshot());
      }
    } on dio.DioException catch (e) {
      developer.log('ChatPage: DioException: $e');
      if (!mounted) return;
      final dioErrMsg = _friendlyRequestError(e);
      setState(() {
        _session.messages[assistantIndex] = _ChatMessage(
          role: 'assistant',
          content: dioErrMsg.length > 1000 ? '${dioErrMsg.substring(0, 1000)}...' : dioErrMsg,
          timestamp: _session.messages[assistantIndex].timestamp,
          isStreaming: false,
        );
      });
      _scrollToBottom();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dioErrMsg)));
    } catch (e) {
      developer.log('ChatPage: Exception: $e');
      if (!mounted) return;
      setState(() {
        _session.messages[assistantIndex] = _ChatMessage(
          role: 'assistant',
          content: 'Something went wrong. Please try again.',
          timestamp: _session.messages[assistantIndex].timestamp,
          isStreaming: false,
        );
      });
      _scrollToBottom();
    } finally {
      _phaseTimer1?.cancel();
      _phaseTimer2?.cancel();
      if (mounted) {
        setState(() {
          _progress = null;
          _sending = false;
          _canQueueFollowUp = false;
        });
        if (_queuedFollowUps.isNotEmpty) {
          final next = _queuedFollowUps.removeFirst();
          unawaited(_submit(next, userAlreadyAdded: true));
        }
      }
      developer.log('ChatPage: stream finished');
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    unawaited(_speech.initialize());
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    if (email.isNotEmpty) _userInitial = email[0].toUpperCase();
    assert(() {
      final keepAlive = <Object?>[
        _session.hasStarted,
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
        _deterministicResponseAndKickoffExecution,
        _fallbackNoResponse,
        _unknownActionResponse,
        _guaranteedFallbackResponse,
        _safeFallbackIntent,
      ];
      return keepAlive.isNotEmpty;
    }());
    unawaited(_prefetchInventorySnapshot());
    widget.onRegisterReset?.call(_resetChat);
    widget.onRegisterOpenHistory?.call(_openHistory);

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

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      final available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _controller.text = result.recognizedWords;
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
            });
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: 'en_US',
        );
      }
    }
  }

  @override
  void dispose() {
    _presentationTimer?.cancel();
    _phaseTimer1?.cancel();
    _phaseTimer2?.cancel();
    _firstTokenFallbackTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    unawaited(_speech.stop());
    super.dispose();
  }

  // ── Conversation History ─────────────────────────────────────────────────

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }

  Future<void> _openHistory() async {
    if (_historyLoading) return;
    setState(() {
      _historyOpen = true;
      _historyLoading = true;
      _historyLoadFailed = false;
      _conversations = [];
    });
    try {
      final convs = await widget.api.listConversations();
      if (mounted) setState(() { _conversations = convs; _historyLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() { _historyLoading = false; _historyLoadFailed = true; });
      }
    }
  }

  void _closeHistory() => setState(() => _historyOpen = false);

  Future<void> _loadConversation(String id) async {
    _closeHistory();
    try {
      final result = await widget.api.getConversation(id);
      if (!mounted) return;
      final msgs = result.messages.map((m) => _ChatMessage(
        role: m.role,
        content: m.content,
        timestamp: m.createdAt.millisecondsSinceEpoch,
      )).toList();
      setState(() {
        _session.messages = msgs;
        _session.hasStarted = msgs.isNotEmpty;
        _currentConversationId = id;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeError(e).$1)),
      );
    }
  }

  Future<void> _deleteConversation(String id) async {
    // Optimistic removal: Dismissible has already animated the row away.
    final idx = _conversations.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final removed = _conversations[idx];
    setState(() {
      _conversations.removeAt(idx);
      if (_currentConversationId == id) _currentConversationId = null;
    });
    try {
      await widget.api.deleteConversation(id);
    } catch (e) {
      if (mounted) {
        setState(() => _conversations.insert(idx, removed));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e).$1)),
        );
      }
    }
  }

  // Retained while the history UI is intentionally detached (68f5e83).
  // ignore: unused_element
  Widget _buildHistoryPanel() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0x14FFFFFF),
            border: Border(right: BorderSide(color: Color(0x26FFFFFF), width: 1)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 4, 8),
                  child: Row(
                    children: [
                      const Text('Chat History', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        onPressed: _closeHistory,
                        icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.60), size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: () { _closeHistory(); _resetChat(); },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF40C8E0).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF40C8E0).withValues(alpha: 0.40), width: 1),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Color(0xFF40C8E0), size: 16),
                          SizedBox(width: 6),
                          Text('New Chat', style: TextStyle(color: Color(0xFF40C8E0), fontSize: 14, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _historyLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : _historyLoadFailed
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Couldn't load history.",
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
                                  TextButton(
                                    onPressed: _openHistory,
                                    child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  ),
                                ],
                              ),
                            )
                          : _conversations.isEmpty
                              ? Center(child: Text('No past conversations', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13)))
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 16),
                              itemCount: _conversations.length,
                              itemBuilder: (context, i) {
                                final c = _conversations[i];
                                final isActive = c.id == _currentConversationId;
                                return Dismissible(
                                  key: Key(c.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 16),
                                    color: const Color(0x33FF3B30),
                                    child: const Icon(Icons.delete_outline, color: Color(0xFFFF3B30), size: 18),
                                  ),
                                  onDismissed: (_) => unawaited(_deleteConversation(c.id)),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => unawaited(_loadConversation(c.id)),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: const BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Color(0x0FFFFFFF), width: 0.5)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  c.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  _relativeTime(c.updatedAt),
                                                  style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 11),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isActive)
                                            const Icon(Icons.radio_button_checked, color: Color(0xFF40C8E0), size: 12),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.70)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF40C8E0).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF40C8E0), size: 25),
            ),
            const SizedBox(height: 18),
            const Text('How can I help?', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.4)),
            const SizedBox(height: 8),
            const Text('Find an item, open a Project Kit, or ask what is inside any space.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFAEAEB2), fontSize: 14, height: 1.4)),
          ],
        ),
      ),
    );
  }

  MarkdownStyleSheet _assistantMarkdownStyle() => MarkdownStyleSheet(
    p: const TextStyle(color: Color(0xFFF2F2F7), fontSize: 16, fontWeight: FontWeight.w400, height: 1.42, letterSpacing: -0.15),
    strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16, height: 1.42, letterSpacing: -0.15),
    em: const TextStyle(color: Color(0xFFAEAEB2), fontStyle: FontStyle.italic, fontSize: 16),
    listBullet: const TextStyle(color: Color(0xFF40C8E0), fontSize: 16, height: 1.42),
    blockSpacing: 8,
    listIndent: 18,
  );

  Widget _buildAssistantMessage(_ChatMessage message, bool isTyping) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.92),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF40C8E0).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF40C8E0), size: 13),
                  ),
                  const SizedBox(width: 8),
                  const Text('FindEZ', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                child: message.content.trim().isEmpty && isTyping
                    ? const Padding(
                        key: ValueKey('thinking'),
                        padding: EdgeInsets.symmetric(vertical: 7),
                        child: _TypingDots(),
                      )
                    : MarkdownBody(
                        key: ValueKey('answer'),
                        data: isTyping
                            ? _renderableStreamingMarkdown(message.content)
                            : message.content,
                        styleSheet: _assistantMarkdownStyle(),
                        softLineBreak: true,
                      ),
              ),
              if (!isTyping && message.navHint != null)
                GestureDetector(
                  onTap: () => unawaited(_openNavHint(message.navHint!)),
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFF40C8E0).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(message.navHint!['type'] == 'project_kit' ? Icons.construction_outlined : Icons.folder_open_outlined, color: const Color(0xFF40C8E0), size: 15),
                        const SizedBox(width: 7),
                        Flexible(child: Text(_navHintLabel(message.navHint!), overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF40C8E0), fontSize: 13, fontWeight: FontWeight.w600))),
                        const SizedBox(width: 5),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF40C8E0), size: 17),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageEntrance(_ChatMessage message, Widget child) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('${message.role}-${message.timestamp}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, content) => Opacity(opacity: value, child: content),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: widget.inPageView ? null : AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: GestureDetector(
            onTap: widget.onProfileTap,
            child: CircleAvatar(
              backgroundColor: const Color(0xFF2C2C2E),
              radius: 16,
              child: Text(
                _userInitial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPillButton(
              icon: Icons.search_rounded,
              label: 'Search',
              onTap: () => _focusNode.requestFocus(),
            ),
            const SizedBox(width: 8),
            _buildPillButton(
              icon: Icons.qr_code_scanner_outlined,
              label: 'Scan',
              onTap: widget.onScanTap ?? () {},
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (widget.onOpenInventory != null)
            IconButton(
              onPressed: widget.onOpenInventory,
              icon: Icon(Icons.article_outlined, color: Colors.white.withValues(alpha: 0.60)),
            ),
          IconButton(
            onPressed: _resetChat,
            icon: Icon(Icons.refresh_rounded, color: Colors.white.withValues(alpha: 0.60)),
          ),
        ],
      ),
      body: Container(
        color: AppTheme.bg(context),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, isIOS ? 16 : 18, 12, 16),
          child: Column(
            children: [
            Expanded(
              child: _session.messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      itemCount: _session.messages.length,
                      separatorBuilder: (context, index) {
                        final curr = _session.messages[index];
                        final next = _session.messages[index + 1];
                        return SizedBox(height: curr.role == next.role ? 6 : 18);
                      },
                      itemBuilder: (context, index) {
                        final m = _session.messages[index];
                        final isUser = m.role == 'user';
                        final isTyping = !isUser &&
                            (m.isStreaming ||
                                index == _fakeTypingAssistantIndex ||
                                m.content == 'Typing…' ||
                                m.content == 'Thinking…' ||
                                m.content == 'Thinking...');
                        if (!isUser) {
                          return _messageEntrance(m, Padding(padding: const EdgeInsets.only(bottom: 4), child: _buildAssistantMessage(m, isTyping)));
                        }
                        return _messageEntrance(m, Align(
                          alignment: Alignment.centerRight,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            child: Container(
                              margin: const EdgeInsets.only(left: 54, bottom: 2, top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                              decoration: const BoxDecoration(
                                color: Color(0xFF40C8E0),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  topRight: Radius.circular(18),
                                  bottomLeft: Radius.circular(18),
                                  bottomRight: Radius.circular(5),
                                ),
                              ),
                              child: Text(
                                m.content,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                        ));
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
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Container(
              constraints: const BoxConstraints(minHeight: 50, maxHeight: 116),
              padding: const EdgeInsets.fromLTRB(16, 5, 6, 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x1FFFFFFF), width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Ask about your inventory',
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        hintStyle: TextStyle(fontSize: 16, color: Color(0xFF636366)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 38, height: 38),
                    icon: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _isListening ? const Color(0xFF40C8E0) : Colors.white38,
                      size: 21,
                    ),
                    onPressed: _toggleListening,
                  ),
                  GestureDetector(
                    onTap: _sending && !_canQueueFollowUp ? null : () => unawaited(_submit(_controller.text)),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _sending && !_canQueueFollowUp ? const Color(0xFF2C2C2E) : const Color(0xFF40C8E0),
                      ),
                      child: _sending && !_canQueueFollowUp
                          ? const Padding(
                              padding: EdgeInsets.all(9),
                              child: CircularProgressIndicator(strokeWidth: 1.7, color: Color(0xFF8E8E93)),
                            )
                          : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
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
    this.isStreaming = false,
    this.navHint,
  });

  final String role;
  final String content;
  final int timestamp;
  final bool isStreaming;
  final Map<String, dynamic>? navHint;

  _ChatMessage copyWith({String? content, int? timestamp, bool? isStreaming, Map<String, dynamic>? navHint}) {
    return _ChatMessage(
      role: role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      navHint: navHint ?? this.navHint,
    );
  }
}
