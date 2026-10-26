import 'message_actions.dart';
import '../../core/first_camera_hint.dart';
import 'chat_progress.dart';
import 'voice_capture.dart';
import 'chat_history_sheet.dart';
import 'dart:math' as math;
import 'chat_photo_attachment_card.dart';
import '../../core/chat_source.dart';
import 'chat_source_menu.dart';
import 'native_chat_menu_button.dart';
import 'chat_context_picker.dart';
import 'assistant_connections_page.dart';
import '../scan/connector_destination_page.dart';
import '../scan/space_barcode_flow.dart';
import 'chat_viewport.dart';
import '../notifications/notification_bell.dart';
import 'package:flutter/services.dart';
import 'chat_capture_card.dart';
import '../world/world_composer.dart';
import '../world/world_action_card.dart';
import '../../core/app_theme.dart';
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import '../../core/ui/liquid_surface.dart';
import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/config.dart';
import '../../core/restock_plan.dart';
import '../../core/ask_answer.dart';
import '../../core/chat_item_action.dart';
import '../../core/ui/glass_card.dart';
import '../../core/ui/frosted_surface.dart';
import 'ask_answer_view.dart';
import '../scan/scan_page.dart';
import 'package:mobile/core/ui/app_text.dart';

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
    this.onBack,
    this.pageController,
    this.onOpenDestination,
    this.photoPicker,
    this.worldHeading,
    this.onCaptureAction,
    this.initialSource,
    this.onInitialSourceReady,
  });

  final String? worldHeading;
  final ChatSource? initialSource;
  final VoidCallback? onInitialSourceReady;
  final Future<void> Function(String)? onCaptureAction;
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
  final VoidCallback? onBack;
  final PageController? pageController;
  final Future<void> Function(Map<String, dynamic>)? onOpenDestination;
  final Future<AskPhoto?> Function(bool camera)? photoPicker;

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

        final color = AppTheme.adaptive(
          context,
          Colors.white.withValues(alpha: 0.4),
        );
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
  static final _scope = AskSessionScope();
  factory _ChatSession() {
    final owner = Supabase.instance.client.auth.currentUser?.id;
    if (_scope.selectAccount(owner)) {
      _instance.messages.clear();
      _instance.hasStarted = false;
      _instance.conversationId = null;
    }
    return _instance;
  }
  _ChatSession._internal();

  List<_ChatMessage> messages = [];
  bool hasStarted = false;
  String? conversationId;
}

class _ChatPageState extends State<ChatPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  final Map<String, Map<String, dynamic>> _responseRatings = {};
  Future<void> _loadRatings(String conversationId) async {
    try {
      final result = await widget.api.collaboration(
        '/response-feedback',
        query: {'conversation_id': conversationId},
      );
      widget.api.assertCurrentContext();
      if (!mounted || _currentConversationId != conversationId) return;
      setState(() {
        for (final row in (result['ratings'] as List? ?? const [])) {
          final value = Map<String, dynamic>.from(row as Map);
          final id = value['message_id'] as String;
          if ((value['revision'] as int) >=
              (_responseRatings[id]?['revision'] as int? ?? 0)) {
            _responseRatings[id] = value;
          }
        }
      });
    } catch (_) {
      /* Optional ratings must not prevent reading chat. */
    }
  }

  final _scrollController = ScrollController();

  bool _worldHome = true;
  bool _sending = false;
  String? _progress;
  late final _ChatSession _session;
  int _requestGeneration = 0;
  final List<ChatSource> _sources = [];
  bool _sourceMenuOpen = false;
  StreamIterator<AiStreamEvent>? _activeReply;

  // Conversation history
  String? get _currentConversationId => _session.conversationId;
  set _currentConversationId(String? value) => _session.conversationId = value;
  bool _historyOpen = false;

  Timer? _phaseTimer1;
  Timer? _phaseTimer2;
  Timer? _firstTokenFallbackTimer;
  final Map<String, GlobalKey<ChatCaptureCardState>> _captureKeys = {};
  final Set<int> _replyHaptics = {};
  Timer? _presentationTimer;
  Timer? _presentationIdleTimer;
  final Map<int, StringBuffer> _presentationBuffers = {};
  final Queue<({int index, String text})> _presentationQueue = Queue();
  final Map<int, Map<String, dynamic>?> _presentationHints = {};
  final Set<int> _presentationComplete = <int>{};
  final Set<String> _actionReplyIds = {};
  final Queue<String> _queuedFollowUps = Queue();
  bool _canQueueFollowUp = false;

  Timer? _fakeTypingTimer;
  int _fakeTypingAssistantIndex = -1;

  List<InventoryItem>? _inventorySnapshot;

  final List<String> _pendingAttachments = [];
  AskPhoto? _photo;
  bool _pickingPhoto = false;
  String? _cameraHintOwner;
  bool get _cameraHint =>
      _cameraHintOwner != null && _cameraHintOwner == widget.api.accountId;
  Future<void> _loadCameraHint() async {
    final owner = widget.api.accountId;
    if (owner == null) return;
    final pending = await FirstCameraHint.pending(owner);
    if (mounted && widget.api.accountId == owner) {
      setState(() => _cameraHintOwner = pending ? owner : null);
    }
  }

  Future<void> _firstCamera() => _attachPhoto(source: true, autoExtract: true);

  Future<bool> _consumeCameraHint() async {
    if (!_cameraHint) return true;
    final owner = widget.api.accountId!;
    try {
      await FirstCameraHint.consume(owner);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not remember this preference. Please try again.',
            ),
          ),
        );
      }
      return false;
    }
    if (!mounted || widget.api.accountId != owner) return false;
    setState(() => _cameraHintOwner = null);
    return true;
  }

  late final VoiceCapture _voice = VoiceCapture(
    recorder: DeviceVoiceRecorder(),
    onSend: (words) {
      if (!mounted || _sending) return;
      widget.api.assertCurrentContext();
      final draft = _controller.text.trim();
      unawaited(_submit(draft.isEmpty ? words : '$draft $words'));
    },
    onError: () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice input could not start. Check microphone and speech permissions, then try again.',
            ),
          ),
        );
      }
    },
  )..addListener(_voiceChanged);
  bool get _isListening => _voice.active;
  void _voiceChanged() {
    if (mounted) setState(() {});
  }

  List<DocumentEntry>? _pendingDocChoices;

  static const _fallbackNoResponse = 'Hmm, try asking that a different way 🙂';

  static const _unknownActionResponse =
      'I’m not totally sure what you meant, but I can help you add, remove, or find items.';

  static const _guaranteedFallbackResponse =
      "I couldn’t process that, but try something like 'add 2 items'.";

  static const _AiIntent _safeFallbackIntent = _AiIntent(
    action: 'unknown',
    items: <_IntentItem>[],
    query: '',
  );

  int _nowTs() => DateTime.now().millisecondsSinceEpoch;

  Future<void> _openNavHint(Map<String, dynamic> hint) async {
    try {
      if (widget.onOpenDestination != null) {
        await widget.onOpenDestination!(hint);
      } else {
        widget.pageController?.animateToPage(
          3,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
    }
  }

  String _renderableStreamingMarkdown(String content) {
    final boldMarkers = RegExp(r'\*\*').allMatches(content).length;
    return boldMarkers.isOdd ? '$content**' : content;
  }

  void _enqueuePresentation(int index, String content) {
    _presentationIdleTimer?.cancel();
    final pending = '${_presentationBuffers[index]?.toString() ?? ''}$content';
    final whitespace = RegExp(r'\s').allMatches(pending).toList();
    if (whitespace.isEmpty) {
      _presentationBuffers[index] = StringBuffer(pending);
    } else {
      final splitAt = whitespace.last.end;
      _presentationBuffers[index] = StringBuffer(pending.substring(splitAt));
      _queuePresentationWords(index, pending.substring(0, splitAt));
    }
    _presentationIdleTimer = Timer(const Duration(milliseconds: 48), () {
      if (!mounted) return;
      final buffered = _presentationBuffers.remove(index)?.toString() ?? '';
      if (buffered.isNotEmpty) _queuePresentationWords(index, buffered);
    });
  }

  void _queuePresentationWords(int index, String content) {
    for (final match in RegExp(r'\s+|\S+\s*').allMatches(content)) {
      _presentationQueue.add((index: index, text: match.group(0)!));
    }
    _presentationTimer ??= Timer.periodic(const Duration(milliseconds: 24), (
      _,
    ) {
      if (!mounted) return;
      if (_presentationQueue.isEmpty) {
        _presentationTimer?.cancel();
        _presentationTimer = null;
        return;
      }
      final index = _presentationQueue.first.index;
      final text = StringBuffer();
      final reduced = MediaQuery.disableAnimationsOf(context);
      final count = reduced
          ? _presentationQueue.length
          : (8 + _presentationQueue.length ~/ 8).clamp(8, 48);
      for (
        var i = 0;
        i < count &&
            _presentationQueue.isNotEmpty &&
            _presentationQueue.first.index == index;
        i++
      ) {
        text.write(_presentationQueue.removeFirst().text);
      }
      if (index < 0 || index >= _session.messages.length) return;
      final isLast =
          _presentationComplete.contains(index) &&
          !_presentationQueue.any((entry) => entry.index == index);
      setState(() {
        final message = _session.messages[index];
        _session.messages[index] = message.copyWith(
          content: message.content + text.toString(),
          isStreaming: !isLast,
          navHint: isLast ? _presentationHints.remove(index) : null,
        );
      });
      _replyVisible(index);
      if (isLast) _presentationComplete.remove(index);
      _scrollToBottom(animated: false);
    });
  }

  void _completePresentation(
    int index,
    Map<String, dynamic>? hint, {
    String? canonical,
  }) {
    if (!mounted || index < 0 || index >= _session.messages.length) return;
    _presentationIdleTimer?.cancel();
    _presentationIdleTimer = null;
    final message = _session.messages[index];
    final pending = StringBuffer(message.content);
    for (final entry in _presentationQueue) {
      if (entry.index == index) pending.write(entry.text);
    }
    pending.write(_presentationBuffers.remove(index)?.toString() ?? '');
    final target = canonical ?? pending.toString();
    if (target.trim().isEmpty) throw StateError('Ask returned no answer');
    _presentationQueue.removeWhere((entry) => entry.index == index);
    // Reconcile formatting without exposing the unseen suffix at completion.
    final shown = message.content.length.clamp(0, target.length);
    _session.messages[index] = message.copyWith(
      content: target.substring(0, shown),
    );
    _presentationHints[index] = hint;
    _presentationComplete.add(index);
    if (shown < target.length) {
      _queuePresentationWords(index, target.substring(shown));
    } else {
      _presentationComplete.remove(index);
      setState(
        () => _session.messages[index] = _session.messages[index].copyWith(
          isStreaming: false,
          navHint: _presentationHints.remove(index),
        ),
      );
    }
  }

  void _cancelPresentation(int index) {
    _presentationBuffers.remove(index);
    _presentationQueue.removeWhere((entry) => entry.index == index);
    _presentationHints.remove(index);
    _presentationComplete.remove(index);
  }

  void _resetChat() {
    _voice.cancel();
    _requestGeneration++;
    final active = _activeReply;
    _activeReply = null;
    if (active != null) unawaited(active.cancel());
    _captureKeys.clear();
    _replyHaptics.clear();
    _presentationTimer?.cancel();
    _presentationTimer = null;
    _presentationIdleTimer?.cancel();
    _presentationIdleTimer = null;
    _presentationBuffers.clear();
    _presentationQueue.clear();
    _presentationHints.clear();
    _presentationComplete.clear();
    _queuedFollowUps.clear();
    _actionReplyIds.clear();
    _responseRatings.clear();
    _phaseTimer1?.cancel();
    _phaseTimer2?.cancel();
    _firstTokenFallbackTimer?.cancel();
    _fakeTypingTimer?.cancel();
    _fakeTypingAssistantIndex = -1;

    _controller.clear();
    _focusNode.unfocus();

    if (!mounted) return;
    setState(() {
      _worldHome = true;
      _photo = null;
      _pickingPhoto = false;
      _sending = false;
      _canQueueFollowUp = false;
      _progress = null;
      _session.messages.clear();
      _session.hasStarted = false;
      _pendingAttachments.clear();
      _sources.clear();
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
      return const _AiIntent(
        action: 'remove_item',
        items: <_IntentItem>[],
        query: 'ALL_ITEMS',
      );
    }

    final isList =
        RegExp(
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

    final addMatch = RegExp(
      r'^(add|buy|get|need|put)\b\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(s);
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
        return const _AiIntent(
          action: 'remove_item',
          items: <_IntentItem>[],
          query: 'ALL_ITEMS',
        );
      }
      if (_isBadItemName(rest)) {
        return const _AiIntent(
          action: 'remove_item',
          items: <_IntentItem>[],
          query: 'ALL_ITEMS',
        );
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
        return _AiIntent(
          action: 'find_item',
          items: const <_IntentItem>[],
          query: q,
        );
      }
    }

    final whatKindMatch = RegExp(
      r'\bwhat (?:kind|kinds|type|types)\s+of\s+(.+?)\s+do i have\b',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (whatKindMatch != null) {
      final q = cleanQuery((whatKindMatch.group(1) ?? '').trim());
      if (q.isNotEmpty) {
        return _AiIntent(
          action: 'find_item',
          items: const <_IntentItem>[],
          query: q,
        );
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
          return _AiIntent(
            action: 'find_item',
            items: const <_IntentItem>[],
            query: q,
          );
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
      final itemsRaw = (jsonMap['items'] is List)
          ? (jsonMap['items'] as List)
          : const [];

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
          final all =
              rawAll == true || rawAll?.toString().toLowerCase() == 'true';
          final qty = _parseQty(m['qty']);
          items.add(_IntentItem(name: name, qty: all ? 0 : qty, all: all));
        }
      }

      final merged = _mergeDuplicateItems(items);

      if (action == 'remove_item' &&
          query.trim().toUpperCase() == 'ALL_ITEMS') {
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
            .replaceAll(
              RegExp(r'^(please\s+)?(can you\s+)?', caseSensitive: false),
              '',
            )
            .replaceAll(
              RegExp(
                r'^(add|remove|delete|find|list)\s+',
                caseSensitive: false,
              ),
              '',
            )
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
    final short = userText.length > 200 ? userText.substring(0, 200) : userText;
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
      if (responseText.trim().isEmpty) {
        responseText = _guaranteedFallbackResponse;
      }

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

      await _streamAssistantText(
        assistantIndex: assistantIndex,
        text: finalText,
      );
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
          ).showSnackBar(SnackBar(content: AppText(_friendlyRequestError(e2))));
        }
      } else if (status == 429) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Rate limited. Try again in ~20 seconds.'),
          ),
        );
      } else {
        _replaceAssistantMessage(assistantIndex, _guaranteedFallbackResponse);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(_friendlyRequestError(e))));
      }
    } catch (e) {
      _cancelPresentation(assistantIndex);
      debugPrint('ai intent flow error: $e');
      if (!mounted) return;
      _replaceAssistantMessage(assistantIndex, _guaranteedFallbackResponse);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(_friendlyRequestError(e))));
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

    final parts = usable
        .take(3)
        .map((it) => '${it.qty} ${_pluralize(it.name, it.qty)}')
        .toList();
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
      if (widget.api.worldKey == null) unawaited(_prefetchInventorySnapshot());
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
      final loc = g.location.trim().isEmpty
          ? 'unknown location'
          : g.location.trim().toLowerCase();
      return '${g.qty} ${_pluralize(g.name, g.qty)} in the $loc';
    }).toList();

    final typesWord = _pluralize(q, shown.length);
    final intro = shown.length == 1
        ? 'You have 1 type of $typesWord:'
        : 'You have ${shown.length} types of $typesWord:';

    final body = parts.length == 1
        ? parts.first
        : '${parts.sublist(0, parts.length - 1).join(' and ')} and ${parts.last}';
    final extra = grouped.length > shown.length
        ? ' (and ${grouped.length - shown.length} more)'
        : '';
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

  Future<String> _deterministicResponseAndKickoffExecution(
    _AiIntent intent,
  ) async {
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
        final q =
            (intent.query ??
                    (intent.items.isNotEmpty ? intent.items.first.name : ''))
                .trim();
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
      // Keep the first question and its collapsed evidence visible as the
      // response grows instead of jumping to the bottom of a long results card.
      if (_session.messages.length <= 2) {
        _scrollController.jumpTo(0);
        return;
      }
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
      if (assistantIndex < 0 || assistantIndex >= _session.messages.length) {
        return;
      }
      final m = _session.messages[assistantIndex];
      if (m.role != 'assistant') return;
      setState(() {
        if (m.content.isEmpty) _progress ??= 'Understanding your request…';
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

    if (assistantIndex < 0 || assistantIndex >= _session.messages.length) {
      return;
    }
    setState(() {
      _session.messages[assistantIndex] = _session.messages[assistantIndex]
          .copyWith(content: '');
    });
    _scrollToBottom(animated: false);

    await Future<void>.delayed(const Duration(milliseconds: 48));
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
                    title: const AppText('Upload Image'),
                    onTap: () => Navigator.of(context).pop(_UploadKind.image),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const AppText('Upload Document'),
                    onTap: () =>
                        Navigator.of(context).pop(_UploadKind.document),
                  ),
                  ListTile(
                    leading: const Icon(Icons.attach_file),
                    title: const AppText('Upload File'),
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
      final savedSpace = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => ScanPage(
            api: widget.api,
            onSaved: () => widget.onInventoryMutated?.call(),
            onCaptureCompleted: (space) => Navigator.of(context).pop(space),
          ),
        ),
      );

      widget.onInventoryMutated?.call();
      if (savedSpace != null && mounted) {
        if (widget.onOpenDestination != null) {
          await widget.onOpenDestination!({'space_name': savedSpace});
        } else {
          widget.onOpenInventory?.call();
        }
      }
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
          const SnackBar(content: AppText('Videos aren’t supported.')),
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
          } else if (assistantIndex >= 0 &&
              assistantIndex < _session.messages.length) {
            final prev = _session.messages[assistantIndex].content;
            _session.messages[assistantIndex] = _session
                .messages[assistantIndex]
                .copyWith(content: prev + add, timestamp: _nowTs());
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
      } else if (assistantIndex >= 0 &&
          assistantIndex < _session.messages.length) {
        final prev = _session.messages[assistantIndex].content;
        if (prev.trim().isEmpty) {
          setState(() {
            _session.messages[assistantIndex] = _session
                .messages[assistantIndex]
                .copyWith(
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
      ).showSnackBar(SnackBar(content: AppText(_friendlyRequestError(e))));
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
      ).showSnackBar(SnackBar(content: AppText(_friendlyRequestError(e))));
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
      return documents.where((d) => d.documentId.isNotEmpty).toList();
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
    if (widget.api.worldKey != null) return;
    try {
      final result = await widget.api.searchItems(query: '');
      if (!mounted) return;
      _inventorySnapshot = result.items;
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<String?> _lowStockSummary() async {
    final account = RestockPrefs.accountKey;
    final plan = await RestockPrefs.load();
    final result = await widget.api.searchItems(query: '');
    if (!mounted || account != RestockPrefs.accountKey) return null;
    final buying = result.items
        .where((i) => plan.needsBuying(i.itemId, i.quantity))
        .toList();
    final ordered = result.items.where((i) => plan.onOrder(i.itemId)).toList();
    if (buying.isEmpty && ordered.isEmpty) return null;
    final lines = <String>[
      if (buying.isNotEmpty)
        'To buy: ${buying.take(6).map((i) => '${i.displayName} (${plan.entry(i.itemId).quantityToBuy(i.quantity)} to buy, ${i.quantity} on hand)').join(', ')}.',
      if (ordered.isNotEmpty)
        'On order: ${ordered.take(6).map((i) => i.displayName).join(', ')}. Stock is unchanged until arrival is confirmed.',
    ];
    return lines.join('\n');
  }

  String _friendlyRequestError(Object error) {
    if (error is dio.DioException) {
      return 'Connection issue. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _replyVisible(int index) {
    if (!_replyHaptics.add(index)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(HapticFeedback.lightImpact());
    });
  }

  Future<void> _submit(
    String text, {
    bool userAlreadyAdded = false,
    bool autoExtract = false,
    String? requestId,
    List<ChatSource>? retrySources,
    int? retryAssistantIndex,
    String? retryOf,
  }) async {
    if (retryAssistantIndex != null &&
        (requestId == null ||
            retryAssistantIndex < 0 ||
            retryAssistantIndex >= _session.messages.length ||
            _session.messages[retryAssistantIndex].role != 'assistant')) {
      return;
    }
    final photo = requestId == null ? _photo : null;
    final sources = List<ChatSource>.of(retrySources ?? _sources);
    final q = text.trim().isEmpty && photo != null
        ? (autoExtract
              ? 'Auto extract the items in this photo. Keep a draft and ask only for any missing destination.'
              : 'Describe this photo briefly and ask what I would like help with.')
        : text.trim().isEmpty && sources.isNotEmpty
        ? 'Help me understand these selected sources.'
        : text.trim();
    if (q.isEmpty) return;
    if (_pickingPhoto) return;
    if (_sending) {
      if (!_canQueueFollowUp || userAlreadyAdded) return;
      _queuedFollowUps.add(q);
      setState(() {
        _canQueueFollowUp = false;
        final safeQ = q;
        _session.messages.add(
          _ChatMessage(role: 'user', content: safeQ, timestamp: _nowTs()),
        );
      });
      if (requestId == null) _controller.clear();
      _scrollToBottom(animated: false);
      return;
    }

    if (_isListening) _voice.cancel();

    if (!mounted) return;
    unawaited(HapticFeedback.lightImpact());
    final requestGeneration = ++_requestGeneration;

    _phaseTimer1?.cancel();
    _phaseTimer2?.cancel();

    if (!mounted) return;
    setState(() {
      _worldHome = false;
      _sending = true;
      _progress = photo == null ? null : 'Reading your photo...';
      if (requestId == null) _photo = null;
      _canQueueFollowUp = false;
      _session.hasStarted = true;
      if (!userAlreadyAdded) {
        final safeQ = q;
        _session.messages.add(
          _ChatMessage(
            role: 'user',
            content: safeQ,
            timestamp: _nowTs(),
            photo: photo,
          ),
        );
      }
      final reply = _ChatMessage(
        role: 'assistant',
        content: '',
        timestamp: retryAssistantIndex == null
            ? _nowTs()
            : _session.messages[retryAssistantIndex].timestamp,
        answerContext: retryAssistantIndex == null
            ? null
            : _session.messages[retryAssistantIndex].answerContext,
        isStreaming: true,
        live: true,
      );
      if (retryAssistantIndex == null) {
        _session.messages.add(reply);
      } else {
        _session.messages[retryAssistantIndex] = reply;
      }
    });
    widget.onChatStateChanged?.call(true);
    if (requestId == null) _controller.clear();
    _scrollToBottom(animated: false);

    final assistantIndex = retryAssistantIndex ?? _session.messages.length - 1;
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final turnId =
        requestId ??
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    _replyHaptics.remove(assistantIndex);
    final retry = photo == null
        ? () {
            if (_sending || !mounted) return;
            setState(
              () => _session.messages[assistantIndex] = _session
                  .messages[assistantIndex]
                  .copyWith(clearRetry: true),
            );
            unawaited(
              _submit(
                q,
                requestId: turnId,
                retrySources: sources,
                retryAssistantIndex: assistantIndex,
                userAlreadyAdded: true,
                retryOf: retryOf,
              ),
            );
          }
        : null;
    try {
      AskAnswerContext? answerContext;
      Map<String, dynamic>? hint;
      String? conversationId;
      var completed = false;
      String? canonical;
      var provisional = '';
      String? savedMessageId;
      DateTime? savedAt;
      final events = retryOf != null && _currentConversationId != null
          ? widget.api.retryChatResponse(
              message: q,
              conversationId: _currentConversationId!,
              messageId: retryOf,
            )
          : photo == null
          ? widget.api.aiCommandStream(
              message: q,
              sources: sources,
              requestId: turnId,
              conversationId: _currentConversationId,
            )
          : widget.api.aiPhotoQuestionStream(
              message: q,
              requestId: turnId,
              sources: sources,
              photo: AskPhoto(bytes: photo.bytes, autoExtract: autoExtract),
              conversationId: _currentConversationId,
            );
      var backendAcknowledged = false;
      final iterator = StreamIterator(events);
      _activeReply = iterator;
      while (await iterator.moveNext()) {
        final event = iterator.current;
        if (!mounted || requestGeneration != _requestGeneration) return;
        if (!backendAcknowledged && event.type != 'error') {
          backendAcknowledged = true;
          unawaited(HapticFeedback.selectionClick());
        }
        if (event.type == 'capture' &&
            event.answerContext?.chatCapture != null) {
          _currentConversationId =
              event.conversationId ?? _currentConversationId;
          setState(() {
            _session.messages[assistantIndex] = _session
                .messages[assistantIndex]
                .copyWith(answerContext: event.answerContext);
          });
        }
        if (event.type == 'capture') _replyVisible(assistantIndex);
        if (event.type == 'reset') {
          provisional = '';
          _cancelPresentation(assistantIndex);
          setState(
            () => _session.messages[assistantIndex] = _session
                .messages[assistantIndex]
                .copyWith(content: ''),
          );
        }
        if (event.type == 'delta' && (event.delta ?? '').isNotEmpty) {
          if (photo != null) _progress = null;
          provisional += event.delta!;
        }
        if (event.type == 'status' && (event.message ?? '').isNotEmpty) {
          setState(() => _progress = event.message);
        }
        if (event.navHint != null) hint = event.navHint;
        if (event.answerContext != null) answerContext = event.answerContext;
        if (event.conversationId != null) {
          conversationId = event.conversationId;
          _currentConversationId = conversationId;
        }
        if (event.type == 'done') {
          completed = true;
          savedMessageId = event.messageId;
          savedAt = event.createdAt;
          canonical = event.assistantMessage ?? provisional;
          if ((_presentationBuffers[assistantIndex]?.isEmpty ?? true) &&
              !_presentationQueue.any(
                (chunk) => chunk.index == assistantIndex,
              ) &&
              _session.messages[assistantIndex].content.isEmpty &&
              canonical.isNotEmpty) {
            _enqueuePresentation(assistantIndex, canonical);
          }
          break;
        }
      }
      if (!completed) throw StateError('Ask response interrupted');
      if (!mounted || requestGeneration != _requestGeneration) return;
      _currentConversationId = conversationId ?? _currentConversationId;
      _session.messages[assistantIndex] = _session.messages[assistantIndex]
          .copyWith(
            answerContext: answerContext,
            messageId: savedMessageId,
            timestamp: savedAt?.millisecondsSinceEpoch ?? _nowTs(),
          );
      if (answerContext?.chatCapture != null) {
        _onCaptureChanged(answerContext!.chatCapture!);
      }

      if (mounted) {
        _completePresentation(assistantIndex, hint, canonical: canonical);
        setState(() {
          _sending = false;
          _canQueueFollowUp = false;
          _progress = null;
        });
        widget.onInventoryMutated?.call();
        unawaited(_prefetchInventorySnapshot());
      }
    } on dio.DioException catch (e) {
      if (!mounted || requestGeneration != _requestGeneration) return;
      _cancelPresentation(assistantIndex);
      final dioErrMsg = _friendlyRequestError(e);
      setState(() {
        _session.messages[assistantIndex] = _ChatMessage(
          role: 'assistant',
          answerContext: _session.messages[assistantIndex].answerContext,
          onRetry: retry,
          failed: true,
          content: dioErrMsg.length > 1000
              ? '${dioErrMsg.substring(0, 1000)}...'
              : dioErrMsg,
          timestamp: _session.messages[assistantIndex].timestamp,
          isStreaming: false,
        );
      });
      _scrollToBottom();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(dioErrMsg)));
    } catch (e) {
      if (!mounted || requestGeneration != _requestGeneration) return;
      _cancelPresentation(assistantIndex);
      setState(() {
        _session.messages[assistantIndex] = _ChatMessage(
          role: 'assistant',
          answerContext: _session.messages[assistantIndex].answerContext,
          onRetry: retry,
          failed: true,
          content: e is AskRequestException
              ? e.message
              : 'This response was interrupted. Please retry.',
          timestamp: _session.messages[assistantIndex].timestamp,
          isStreaming: false,
        );
      });
      _scrollToBottom();
    } finally {
      if (requestGeneration == _requestGeneration) {
        final active = _activeReply;
        _activeReply = null;
        if (active != null) unawaited(active.cancel());
        _phaseTimer1?.cancel();
        _phaseTimer2?.cancel();
      }
      if (mounted && requestGeneration == _requestGeneration) {
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
    }
  }

  @override
  void initState() {
    super.initState();
    _session = widget.api.worldKey == null
        ? _ChatSession()
        : _ChatSession._internal();
    _controller = TextEditingController();
    unawaited(_loadCameraHint());
    if (widget.initialSource != null) _sources.add(widget.initialSource!);
    if (widget.onInitialSourceReady != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onInitialSourceReady?.call();
      });
    }

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onChatStateChanged?.call(_session.messages.isNotEmpty);
    });

    final initial = (widget.initialMessage ?? '').trim();
    if (initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.text = initial;
        unawaited(_submit(initial));
      });
    }
  }

  void _toggleListening() {
    if (_voice.active) {
      unawaited(_voice.release());
    } else {
      unawaited(_voice.start());
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
    final active = _activeReply;
    if (active != null) unawaited(active.cancel());
    _presentationTimer?.cancel();
    _presentationIdleTimer?.cancel();
    _phaseTimer1?.cancel();
    _phaseTimer2?.cancel();
    _firstTokenFallbackTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _voice.dispose();
    super.dispose();
  }

  // ── Conversation History ─────────────────────────────────────────────────

  Future<void> _openHistory() async {
    if (_historyOpen) return;
    _historyOpen = true;
    _focusNode.unfocus();
    final generation = _requestGeneration;
    try {
      final selected = await showChatHistory(
        context,
        api: widget.api,
        currentId: _currentConversationId,
        onDeleted: (id) {
          if (mounted && id == _currentConversationId) {
            _currentConversationId = null;
          }
        },
      );
      if (!mounted || generation != _requestGeneration || selected == null) {
        return;
      }
      widget.api.assertCurrentContext();
      if (selected == ChatHistorySheet.newChat) {
        _resetChat();
      } else {
        await _loadConversation(selected);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
      }
    } finally {
      _historyOpen = false;
    }
  }

  Future<bool> _loadConversation(String id) async {
    _resetChat();
    final generation = _requestGeneration;
    final owner = Supabase.instance.client.auth.currentUser?.id;
    try {
      final result = await widget.api.getConversation(id);
      if (!mounted ||
          generation != _requestGeneration ||
          owner != Supabase.instance.client.auth.currentUser?.id) {
        return false;
      }
      _actionReplyIds.addAll(result.messages.map((message) => message.id));
      final msgs = result.messages
          .map(
            (m) => _ChatMessage(
              role: m.role,
              messageId: m.id,
              content: m.content,
              timestamp: m.createdAt.millisecondsSinceEpoch,
              answerContext: m.answerContext,
            ),
          )
          .toList();
      for (var i = 1; i < msgs.length; i++) {
        if (msgs[i].role != 'assistant' || msgs[i - 1].role != 'user') continue;
        final photoUrl = trustedAskPhotoUrl(
          msgs[i].answerContext?.photoUrl,
          owner: Supabase.instance.client.auth.currentUser?.id,
          origins: [widget.api.baseUrl, AppConfig.supabaseUrl],
          inventoryId: widget.api.inventoryContext?.inventoryId,
        );
        if (photoUrl != null) {
          msgs[i - 1] = msgs[i - 1].copyWith(photoUrl: photoUrl);
        }
      }
      setState(() {
        _worldHome = false;
        _session.messages = msgs;
        _session.hasStarted = msgs.isNotEmpty;
        _currentConversationId = id;
      });
      unawaited(_loadRatings(id));
      widget.onChatStateChanged?.call(msgs.isNotEmpty);
      _scrollToBottom();
      return true;
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(describeError(e).$1)));
    }
    return false;
  }

  Widget _buildHeader() {
    if (widget.worldHeading != null) {
      return Row(
        children: [
          if (widget.onBack != null)
            LiquidIconButton(
              tooltip: 'Back',
              icon: CupertinoIcons.chevron_left,
              onPressed: () {
                _returnToHome();
              },
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Center(
              child: Text(
                'Ask',
                key: const Key('ask-heading'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          NotificationBell(api: widget.api),
          const SizedBox(width: 8),
          LiquidIconButton(
            tooltip: 'New chat',
            icon: CupertinoIcons.square_pencil,
            onPressed: _resetChat,
          ),
        ],
      );
    }
    // The parent Scaffold consumes MediaQuery's keyboard inset when it resizes.
    final compact =
        (View.of(context).viewInsets.bottom > 0 ||
            MediaQuery.viewInsetsOf(context).bottom > 0) &&
        MediaQuery.textScalerOf(context).scale(18) > 36;
    final title = AppText(
      key: const Key('ask-heading'),
      'Ask',
      style: TextStyle(
        color: AppTheme.foreground(context, Color(0xFFF2F2F2)),
        fontSize: 18,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.2,
      ),
    );
    final reset = FrostedSurface(
      radius: 16,
      shadow: false,
      child: TextButton(
        onPressed: _resetChat,
        child: AppText(
          'New chat',
          style: TextStyle(
            color: AppTheme.foreground(context, Color(0xFF85858E)),
            fontSize: 13,
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: compact
          ? Row(
              children: [
                if (widget.onBack != null) _buildBack(),
                Expanded(child: title),
                IconButton(
                  tooltip: 'New chat',
                  onPressed: _resetChat,
                  icon: const Icon(Icons.add_comment_outlined),
                ),
              ],
            )
          : MediaQuery.textScalerOf(context).scale(18) > 36
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [if (widget.onBack != null) _buildBack(), title]),
                if (_session.messages.isNotEmpty) reset,
              ],
            )
          : Row(
              children: [
                if (widget.onBack != null) _buildBack(),
                Expanded(child: title),
                if (_session.messages.isNotEmpty) reset,
              ],
            ),
    );
  }

  void _returnToHome() {
    final pending = _controller.text;
    _resetChat();
    _controller.text = pending;
    widget.onBack?.call();
  }

  Widget _buildBack() => IconButton(
    tooltip: 'Back',
    onPressed: () {
      if (widget.worldHeading != null) {
        _returnToHome();
      } else {
        widget.onBack?.call();
      }
    },
    icon: Icon(
      Icons.arrow_back_ios_new_rounded,
      size: 20,
      color: AppTheme.textPrimary(context),
    ),
  );

  Widget _buildEmptyState() => Padding(
    padding: EdgeInsets.symmetric(
      vertical: widget.worldHeading == null ? 64 : 22,
      horizontal: 16,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text(
          widget.worldHeading ?? 'What would you like to know?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textPrimary(context),
            fontSize: widget.worldHeading == null ? 22 : 24,
            fontWeight: FontWeight.w600,
            fontFamily: 'PlusJakartaSans',
            letterSpacing: widget.worldHeading == null ? null : -0.6,
            height: 1.25,
          ),
        ),
      ),
    ),
  );

  final _attachmentAnchor = GlobalKey();

  Future<void> _captureSource(String kind) async {
    if (_sending || _pickingPhoto) return;
    if (kind != 'barcode') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConnectorDestinationPage(api: widget.api),
        ),
      );
      return;
    }
    if (_sending || _pickingPhoto || widget.api.worldKey == null) return;
    final generation = _requestGeneration;
    final conversationId = _currentConversationId;
    bool current() => mounted && generation == _requestGeneration;
    setState(() => _pickingPhoto = true);
    try {
      final code = await scanBarcodeForDraft(context);
      if (!current() || code == null) return;
      setState(() => _progress = 'Looking up barcode...');
      final result = await widget.api.collaboration(
        '/worlds/${widget.api.worldKey}/captures/barcode',
        method: 'POST',
        data: {
          'barcode': code,
          if (conversationId != null) 'conversation_id': conversationId,
        },
      );
      widget.api.assertCurrentContext();
      if (!mounted || !current()) return;
      final id = result['conversation_id'] as String;
      if (!await _loadConversation(id) || !mounted) return;
      setState(() => _pickingPhoto = false);
      // The durable draft is already visible before the model offers destinations.
      await _submit(
        'Help me review this extraction and choose where to save it.',
      );
    } catch (error) {
      if (mounted && current()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyApiError(error))));
      }
    } finally {
      if (mounted && current()) {
        setState(() {
          _pickingPhoto = false;
          _progress = null;
        });
      }
    }
  }

  Widget? get _sourceChips => _sources.isEmpty
      ? null
      : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final source in _sources)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InputChip(
                    avatar: Icon(
                      source.kind == 'file'
                          ? CupertinoIcons.doc
                          : CupertinoIcons.link,
                      size: 16,
                    ),
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 190),
                      child: Text(
                        '${source.name}${source.truncated ? ' (excerpt)' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    tooltip:
                        '${source.name}${source.inventoryName == null ? '' : ' - ${source.inventoryName}'}',
                    onDeleted: _sending
                        ? null
                        : () => setState(() => _sources.remove(source)),
                    deleteButtonTooltipMessage: 'Remove ${source.name}',
                  ),
                ),
            ],
          ),
        );

  Future<void> _attachChatFile() async {
    if (_sending || _pickingPhoto) return;
    if (_sources.length >= 8 ||
        _sources.where((s) => s.kind == 'file').length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use up to 8 sources, including up to 4 files.'),
        ),
      );
      return;
    }
    final generation = _requestGeneration;
    final owner = Supabase.instance.client.auth.currentUser?.id;
    bool current() =>
        mounted &&
        generation == _requestGeneration &&
        owner == Supabase.instance.client.auth.currentUser?.id;
    setState(() => _pickingPhoto = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'md', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (!current() || result == null) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
        throw const AskRequestException(
          'Choose a nonempty file smaller than 10 MB.',
        );
      }
      if ([
        'jpg',
        'jpeg',
        'png',
        'webp',
      ].contains(file.extension?.toLowerCase())) {
        setState(() => _photo = AskPhoto(bytes: bytes));
        return;
      }
      final source = await widget.api.readChatFile(bytes, file.name);
      if (!mounted || !current()) return;
      if (_sources.fold<int>(0, (count, s) => count + (s.text?.length ?? 0)) +
              (source.text?.length ?? 0) >
          48000) {
        throw const AskRequestException(
          'These files are too long together. Remove a file before adding another.',
        );
      }
      setState(() {
        if (!_sources.any((s) => s.key == source.key)) _sources.add(source);
      });
    } catch (error) {
      if (!mounted || !current()) return;
      final detail = error is dio.DioException
          ? (error.response?.data is Map
                ? error.response?.data['detail']
                : null)
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AskRequestException
                ? error.message
                : detail is String
                ? detail
                : 'Could not read this file. Try a text-based PDF, TXT or Markdown file.',
          ),
        ),
      );
    } finally {
      if (current()) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _worldAttachmentMenu() async {
    if (_sending || _pickingPhoto || _sourceMenuOpen) return;
    final generation = _requestGeneration;
    setState(() => _sourceMenuOpen = true);
    final selected = await showChatSourceMenu(
      context,
      _attachmentAnchor,
      nativeAttach: usesNativeChatMenu,
    );
    if (!mounted) return;
    setState(() => _sourceMenuOpen = false);
    if (selected == null || generation != _requestGeneration) return;
    await _selectChatSource(selected);
  }

  Future<void> _selectChatSource(String selected) async {
    if (!mounted || _sending || _pickingPhoto) return;
    final generation = _requestGeneration;
    if (selected == 'open') {
      await _worldAttachmentMenu();
    } else if (selected == 'auto_extract') {
      await _attachPhoto(autoExtract: true);
    } else if (selected == 'camera' || selected == 'library') {
      await _attachPhoto(source: selected == 'camera');
    } else if (selected == 'file') {
      await _attachChatFile();
    } else if (selected == 'connections') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AssistantConnectionsPage(api: widget.api),
        ),
      );
    } else if (['space', 'item', 'project', 'document'].contains(selected)) {
      final result = await Navigator.of(context).push<List<ChatSource>>(
        MaterialPageRoute(
          builder: (_) => ChatContextPicker(
            api: widget.api,
            kind: selected,
            selected: _sources,
          ),
        ),
      );
      if (!mounted || generation != _requestGeneration || result == null) {
        return;
      }
      widget.api.assertCurrentContext();
      setState(() {
        _sources.clear();
        _sources.addAll(result);
      });
    } else if (selected == 'spreadsheet') {
      final proceed = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Import inventory', style: TextStyle(fontSize: 22)),
                const SizedBox(height: 12),
                const Text(
                  'Choose a CSV or Excel (.xlsx) file up to 10 MB. FindEZ will create a draft for you to review, then choose an inventory and Space before saving.',
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(CupertinoIcons.folder),
                  label: const Text('Choose spreadsheet'),
                ),
              ],
            ),
          ),
        ),
      );
      if (mounted && generation == _requestGeneration && proceed == true) {
        await _captureSource(selected);
      }
    } else {
      await _captureSource(selected);
    }
  }

  Future<void> _attachPhoto({bool? source, bool autoExtract = false}) async {
    if (_sending || _pickingPhoto) return;
    final generation = _requestGeneration;
    final owner = Supabase.instance.client.auth.currentUser?.id;
    final camera =
        source ??
        await showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          backgroundColor: AppTheme.adaptive(context, const Color(0xFF171719)),
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const AppText('Take photo'),
                  onTap: () => Navigator.pop(context, true),
                ),
                ListTile(
                  title: const AppText('Choose photo'),
                  onTap: () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),
        );
    if (camera == null || !mounted || generation != _requestGeneration) return;
    if (camera && !await _consumeCameraHint()) return;
    if (!mounted || generation != _requestGeneration) return;
    setState(() => _pickingPhoto = true);
    var picked = false;
    try {
      AskPhoto? photo;
      if (widget.photoPicker != null) {
        photo = await widget.photoPicker!(camera);
      } else {
        final file = await ImagePicker().pickImage(
          source: camera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 92,
          requestFullMetadata: false,
        );
        if (file != null) {
          if (await file.length() > AskPhoto.maxBytes) {
            throw const AskRequestException(
              'Choose a photo smaller than 10 MB.',
            );
          }
          photo = AskPhoto(bytes: await file.readAsBytes());
        }
      }
      if (!mounted ||
          generation != _requestGeneration ||
          owner != Supabase.instance.client.auth.currentUser?.id) {
        return;
      }
      if (photo != null &&
          (photo.bytes.isEmpty || photo.bytes.length > AskPhoto.maxBytes)) {
        throw const AskRequestException(
          'Choose a valid photo smaller than 10 MB.',
        );
      }
      if (photo != null) {
        picked = true;
        setState(() => _photo = photo);
      }
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            error is AskRequestException
                ? error.message
                : 'Could not open the photo. Check camera or photo access in Settings.',
          ),
        ),
      );
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _pickingPhoto = false);
      }
    }
    if (picked &&
        mounted &&
        generation == _requestGeneration &&
        widget.api.worldKey != null &&
        autoExtract) {
      await _submit(_controller.text, autoExtract: true);
    }
  }

  void _onCaptureChanged(Map<String, dynamic> updated) {
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _session.messages.length; i++) {
        final message = _session.messages[i];
        final data = message.answerContext;
        if (data?.chatCapture?['id'] != updated['id']) continue;
        _session.messages[i] = message.copyWith(
          answerContext: AskAnswerContext(
            chatCapture: updated,
            photoAttachment: data!.photoAttachment,
            worldActions: data.worldActions,
            resourceLinks: data.resourceLinks,
            sources: data.sources,
            rows: data.rows,
            rowsTruncated: data.rowsTruncated,
            photoUrl: data.photoUrl,
            pendingActions: data.pendingActions,
          ),
        );
      }
    });
  }

  void _onItemActionResult(ChatItemActionResult result) {
    if (!mounted) return;
    // ListView may dispose offscreen cards. Retain the actual receipt on the
    // message itself so scrolling back never shows a confirmed card as pending.
    setState(() {
      for (var i = 0; i < _session.messages.length; i++) {
        final message = _session.messages[i];
        final data = message.answerContext;
        if (data == null ||
            !data.pendingActions.any(
              (action) => action.id == result.action.id,
            )) {
          continue;
        }
        _session.messages[i] = message.copyWith(
          answerContext: AskAnswerContext(
            chatCapture: data.chatCapture,
            photoAttachment: data.photoAttachment,
            worldActions: data.worldActions,
            resourceLinks: data.resourceLinks,
            sources: data.sources,
            rows: data.rows,
            rowsTruncated: data.rowsTruncated,
            photoUrl: data.photoUrl,
            pendingActions: data.pendingActions
                .map(
                  (action) =>
                      action.id == result.action.id ? result.action : action,
                )
                .toList(),
          ),
        );
      }
    });
    if (result.action.status != 'confirmed') return;
    widget.onInventoryMutated?.call();
    unawaited(_prefetchInventorySnapshot());
    final text = result.assistantMessage;
    final replyId = result.replyId;
    if (text == null ||
        text.isEmpty ||
        replyId == null ||
        !_actionReplyIds.add(replyId)) {
      return;
    }
    final index = _session.messages.length;
    setState(
      () => _session.messages.add(
        _ChatMessage(
          role: 'assistant',
          content: '',
          timestamp: _nowTs(),
          isStreaming: true,
          live: true,
        ),
      ),
    );
    _enqueuePresentation(index, text);
    _completePresentation(index, null, canonical: text);
  }

  Widget _buildAssistantMessage(_ChatMessage message, bool isTyping) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (message.onRetry != null && !isTyping)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _sending ? null : message.onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry response'),
          ),
        ),
      AskAnswerView(
        key: ValueKey('answer-${message.timestamp}'),
        refined: widget.worldHeading != null,
        answer: isTyping
            ? _renderableStreamingMarkdown(message.content)
            : message.content,
        contextData: message.answerContext,
        isLoading: isTyping,
        animateChunks: message.live,
        api: widget.api,
        onActionResult: _onItemActionResult,
        onOpenResource: widget.onOpenDestination == null
            ? null
            : (link) => unawaited(widget.onOpenDestination!(link.toJson())),
        pendingMessage: _progress ?? 'Checking your things...',
        onOpenSource:
            message.navHint?['type'] != 'project_kit' ||
                message.answerContext?.sources
                        .where((source) => source.kind == 'project')
                        .length !=
                    1
            ? null
            : () => unawaited(_openNavHint(message.navHint!)),
      ),
      if (message.answerContext?.chatCapture != null &&
          _currentConversationId != null &&
          identical(
            message,
            _session.messages.lastWhere(
              (m) =>
                  m.answerContext?.chatCapture?['id'] ==
                  message.answerContext!.chatCapture!['id'],
            ),
          ))
        ChatCaptureCard(
          key: _captureKeys.putIfAbsent(
            message.answerContext!.chatCapture!['id'] as String,
            () => GlobalKey<ChatCaptureCardState>(),
          ),
          api: widget.api,
          conversationId: _currentConversationId!,
          draft: message.answerContext!.chatCapture!,
          disabled: _sending,
          onChanged: _onCaptureChanged,
          onSaved: widget.onInventoryMutated,
          onOpenResource: widget.onOpenDestination == null
              ? null
              : (link) => unawaited(widget.onOpenDestination!(link.toJson())),
        ),
      if (!isTyping && message.answerContext?.photoAttachment != null)
        ChatPhotoAttachmentCard(
          key: ValueKey(message.answerContext!.photoAttachment!['id']),
          api: widget.api,
          attachment: message.answerContext!.photoAttachment!,
          onSaved: widget.onInventoryMutated,
          onChanged: (updated) {
            final target = message.answerContext!.photoAttachment!;
            target.clear();
            target.addAll(updated);
          },
        ),
      if (!isTyping)
        for (final action
            in message.answerContext?.worldActions ?? <Map<String, dynamic>>[])
          WorldActionCard(
            key: ValueKey(action['id']),
            onCaptureChanged: _onCaptureChanged,
            api: widget.api,
            action: action,
            onOpenResource: widget.onOpenDestination == null
                ? null
                : (link) => unawaited(widget.onOpenDestination!(link.toJson())),
            onSaved: widget.onInventoryMutated,
            onChanged: (updated) {
              action.clear();
              action.addAll(updated);
            },
          ),
    ],
  );

  Widget _photoPreview() => Padding(
    key: const Key('ask-photo-preview'),
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        InkWell(
          onTap: _sending ? null : _attachPhoto,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _photo!.bytes,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              semanticLabel: 'Attached photo. Tap to replace.',
              errorBuilder: (_, _, _) => const SizedBox(
                width: 64,
                height: 64,
                child: Icon(
                  Icons.broken_image_outlined,
                  semanticLabel: 'Photo preview unavailable',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Text('Photo attached')),
        IconButton(
          tooltip: 'Remove photo',
          onPressed: _sending ? null : () => setState(() => _photo = null),
          icon: const Icon(Icons.close, size: 20),
        ),
      ],
    ),
  );

  Widget _worldLanding(bool canSend, bool compact) => LayoutBuilder(
    builder: (context, bounds) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bounds.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildEmptyState(),
                    const SizedBox(height: 12),
                    if (_photo != null) _photoPreview(),
                    WorldComposer(
                      onFirstCamera: _cameraHint && !_sending && !_pickingPhoto
                          ? _firstCamera
                          : null,
                      sourceChips: _sourceChips,
                      menuOpen: _sourceMenuOpen,
                      attachmentKey: _attachmentAnchor,
                      onSourceSelected: (value) =>
                          unawaited(_selectChatSource(value)),
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: (_) => setState(() {}),
                      onAttach: _sending || _pickingPhoto
                          ? null
                          : _worldAttachmentMenu,
                      onVoice: _sending ? null : _toggleListening,
                      onVoiceStart: _sending
                          ? null
                          : () => unawaited(_voice.start()),
                      onVoiceEnd: () => unawaited(_voice.release()),
                      onVoiceCancel: _voice.cancel,
                      voiceTranscript: _voice.transcript,
                      onSend: canSend
                          ? () => unawaited(_submit(_controller.text))
                          : null,
                      busy: (_sending && !_canQueueFollowUp) || _pickingPhoto,
                      listening: _isListening,
                      compact: compact,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _messageEntrance(_ChatMessage message, Widget child) {
    if (!message.isStreaming && !message.failed && message.content.isNotEmpty) {
      final index = _session.messages.indexOf(message);
      int userIndex = index;
      while (userIndex >= 0 && _session.messages[userIndex].role != 'user') {
        userIndex--;
      }
      final prompt = userIndex >= 0 ? _session.messages[userIndex] : null;
      final answerIndex = message.role == 'assistant'
          ? index
          : (index + 1 < _session.messages.length &&
                    _session.messages[index + 1].role == 'assistant'
                ? index + 1
                : -1);
      final answer = answerIndex >= 0 ? _session.messages[answerIndex] : null;
      void retry() {
        if (_sending || prompt == null || answer == null) return;
        if (answer.onRetry != null) {
          answer.onRetry!();
          return;
        }
        if (answer.messageId == null) return;
        unawaited(
          _submit(
            prompt.content,
            userAlreadyAdded: true,
            requestId: answer.messageId,
            retryOf: answer.messageId,
            retryAssistantIndex: answerIndex,
          ),
        );
      }

      child = Column(
        crossAxisAlignment: message.role == 'user'
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          child,
          MessageActions(
            api: widget.api,
            content: message.content,
            timestamp: message.timestamp,
            isUser: message.role == 'user',
            messageId: message.messageId,
            rating: _responseRatings[message.messageId],
            disabled: _sending,
            onRating: (rating) =>
                setState(() => _responseRatings[message.messageId!] = rating),
            onRetry:
                (widget.api.worldKey != null && answer?.messageId != null) ||
                    answer?.onRetry != null
                ? retry
                : null,
            onEdit: message.role == 'user'
                ? () {
                    _controller.text = message.content;
                    _controller.selection = TextSelection.collapsed(
                      offset: _controller.text.length,
                    );
                    _focusNode.requestFocus();
                    setState(() {});
                  }
                : null,
          ),
        ],
      );
    }
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey('${message.role}-${message.timestamp}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, content) =>
          Opacity(opacity: value, child: content),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final keyboardVisible =
        View.of(context).viewInsets.bottom > 0 ||
        MediaQuery.viewInsetsOf(context).bottom > 0;
    final compactComposer =
        keyboardVisible && MediaQuery.textScalerOf(context).scale(16) > 32;
    final canSend =
        !_pickingPhoto &&
        (_controller.text.trim().isNotEmpty ||
            _photo != null ||
            _sources.isNotEmpty) &&
        (!_sending || _canQueueFollowUp);

    if (widget.worldHeading != null &&
        (_worldHome || _session.messages.isEmpty)) {
      return _worldLanding(canSend, keyboardVisible || compactComposer);
    }
    if (widget.worldHeading != null) {
      return Scaffold(
        resizeToAvoidBottomInset: !widget.inPageView,
        backgroundColor: Colors.transparent,
        body: ChatViewport(
          header: _buildHeader(),
          controller: _scrollController,
          messages: [
            for (final message in _session.messages)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: message.role == 'user'
                    ? AskQuestionCard(
                        compact: true,
                        question: message.content,
                        photoBytes: message.photo?.bytes,
                        photoUrl: message.photoUrl,
                      )
                    : _buildAssistantMessage(message, message.isStreaming),
              ),
          ],
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pickingPhoto) const LinearProgressIndicator(),
              if (_photo != null) _photoPreview(),
              WorldComposer(
                onFirstCamera: _cameraHint && !_sending && !_pickingPhoto
                    ? _firstCamera
                    : null,
                sourceChips: _sourceChips,
                menuOpen: _sourceMenuOpen,
                attachmentKey: _attachmentAnchor,
                onSourceSelected: (value) =>
                    unawaited(_selectChatSource(value)),
                controller: _controller,
                focusNode: _focusNode,
                onChanged: (_) => setState(() {}),
                onAttach: _sending || _pickingPhoto
                    ? null
                    : _worldAttachmentMenu,
                onVoice: _sending ? null : _toggleListening,
                onVoiceStart: _sending ? null : () => unawaited(_voice.start()),
                onVoiceEnd: () => unawaited(_voice.release()),
                onVoiceCancel: _voice.cancel,
                voiceTranscript: _voice.transcript,
                onSend: canSend
                    ? () => unawaited(_submit(_controller.text))
                    : null,
                busy: (_sending && !_canQueueFollowUp) || _pickingPhoto,
                listening: _isListening,
                compact: true,
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      // MainShell already resizes its PageView for the keyboard.
      resizeToAvoidBottomInset: !widget.inPageView,
      backgroundColor: widget.worldHeading != null
          ? Colors.transparent
          : AppTheme.adaptive(context, const Color(0xFF09090B)),

      body: Container(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            18,
            16,
            // MainShell reserves space for its pill below the page.
            keyboardVisible || widget.inPageView ? 12 : 110,
          ),
          child: Column(
            children: [
              if (_session.messages.isNotEmpty &&
                  (widget.worldHeading == null || !_worldHome)) ...[
                _buildHeader(),
                const SizedBox(height: 12),
              ],
              if (widget.worldHeading != null &&
                  (_worldHome || _session.messages.isEmpty))
                const Spacer(flex: 2),
              if (widget.worldHeading != null &&
                  (_worldHome || _session.messages.isEmpty))
                _buildEmptyState()
              else
                Expanded(
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemCount: _session.messages.isEmpty
                        ? 1
                        : _session.messages.length,
                    separatorBuilder: (context, index) {
                      final curr = _session.messages[index];
                      final next = _session.messages[index + 1];
                      return SizedBox(height: curr.role == next.role ? 12 : 8);
                    },
                    itemBuilder: (context, index) {
                      if (_session.messages.isEmpty) {
                        return _buildEmptyState();
                      }
                      final messageIndex = index;
                      final m = _session.messages[messageIndex];
                      final isUser = m.role == 'user';
                      final isTyping =
                          !isUser &&
                          (m.isStreaming ||
                              messageIndex == _fakeTypingAssistantIndex ||
                              m.content == 'Typing…' ||
                              m.content == 'Thinking…' ||
                              m.content == 'Thinking...');
                      if (!isUser) {
                        return _messageEntrance(
                          m,
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _buildAssistantMessage(m, isTyping),
                          ),
                        );
                      }
                      return _messageEntrance(
                        m,
                        AskQuestionCard(
                          compact: widget.worldHeading != null,
                          question: m.content,
                          photoBytes: m.photo?.bytes,
                          photoUrl: m.photoUrl,
                        ),
                      );
                    },
                  ),
                ),
              if (_sending &&
                  _progress != null &&
                  !_session.messages.any((message) => message.isStreaming)) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ChatProgress(message: _progress!),
                ),
                const SizedBox(height: 10),
              ],
              if (_photo != null) _photoPreview(),
              if (widget.worldHeading != null)
                WorldComposer(
                  onFirstCamera: _cameraHint && !_sending && !_pickingPhoto
                      ? _firstCamera
                      : null,
                  sourceChips: _sourceChips,
                  menuOpen: _sourceMenuOpen,
                  attachmentKey: _attachmentAnchor,
                  onSourceSelected: (value) =>
                      unawaited(_selectChatSource(value)),
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: (_) => setState(() {}),
                  onAttach: _sending || _pickingPhoto
                      ? null
                      : _worldAttachmentMenu,
                  onVoice: _sending ? null : _toggleListening,
                  onVoiceStart: _sending
                      ? null
                      : () => unawaited(_voice.start()),
                  onVoiceEnd: () => unawaited(_voice.release()),
                  onVoiceCancel: _voice.cancel,
                  voiceTranscript: _voice.transcript,
                  onSend: canSend
                      ? () => unawaited(_submit(_controller.text))
                      : null,
                  busy: (_sending && !_canQueueFollowUp) || _pickingPhoto,
                  listening: _isListening,
                  compact: keyboardVisible || compactComposer || !_worldHome,
                )
              else
                Container(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    maxHeight: 150,
                  ),
                  padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
                  decoration: BoxDecoration(
                    color: AppTheme.adaptive(context, const Color(0xFF171719)),
                    borderRadius: BorderRadius.circular(
                      widget.worldHeading != null ? 28 : 18,
                    ),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .08),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: widget.worldHeading != null
                            ? 'Capture or attach'
                            : 'Attach photo',
                        onPressed: _sending || _pickingPhoto
                            ? null
                            : widget.worldHeading != null
                            ? _worldAttachmentMenu
                            : _attachPhoto,
                        icon: _pickingPhoto
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                ),
                              )
                            : Icon(
                                Icons.add_rounded,
                                color: _sending
                                    ? AppTheme.textSecondary(context)
                                    : AppTheme.accentForeground(context),
                                size: 22,
                              ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines:
                              widget.worldHeading != null &&
                                  (_worldHome || _session.messages.isEmpty) &&
                                  !keyboardVisible &&
                                  !compactComposer
                              ? 3
                              : 1,
                          maxLines: compactComposer ? 1 : 4,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          onChanged: (_) => setState(() {}),
                          style: AppTypography.bodyStyleOf(
                            context,
                            TextStyle(
                              color: AppTheme.foreground(context, Colors.white),
                              fontSize: 16,
                            ),
                          ),
                          decoration: InputDecoration(
                            hintText: compactComposer
                                ? 'Ask...'
                                : widget.worldHeading != null
                                ? 'Describe your world...'
                                : 'Ask a question',
                            hintMaxLines: 1,
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            hintStyle: AppTypography.bodyStyleOf(
                              context,
                              TextStyle(
                                fontSize: 16,
                                color: AppTheme.foreground(
                                  context,
                                  Color(0xFF636366),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 38,
                          height: 38,
                        ),
                        icon: Icon(
                          _isListening
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: _isListening
                              ? AppTheme.foreground(
                                  context,
                                  const Color(0xFFF2F2F7),
                                )
                              : AppTheme.foreground(context, Colors.white38),
                          size: 21,
                        ),
                        onPressed: _toggleListening,
                      ),
                      GestureDetector(
                        onTap: canSend
                            ? () => unawaited(_submit(_controller.text))
                            : null,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _sending && !_canQueueFollowUp
                                ? AppTheme.adaptive(
                                    context,
                                    const Color(0xFF2C2C2E),
                                  )
                                : canSend
                                ? AppTheme.action
                                : AppTheme.adaptive(
                                    context,
                                    const Color(0xFF2C2C2E),
                                  ),
                          ),
                          child: _sending && !_canQueueFollowUp
                              ? Padding(
                                  padding: EdgeInsets.all(9),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.7,
                                    color: AppTheme.adaptive(
                                      context,
                                      Color(0xFF8E8E93),
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.arrow_upward_rounded,
                                  color: canSend
                                      ? AppTheme.onAction
                                      : AppTheme.foreground(
                                          context,
                                          const Color(0xFF636366),
                                        ),
                                  size: 20,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.worldHeading != null &&
                  (_worldHome || _session.messages.isEmpty))
                const Spacer(flex: 3),
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
    this.live = false,
    this.navHint,
    this.answerContext,
    this.photo,
    this.photoUrl,
    this.onRetry,
    this.messageId,
    this.failed = false,
  });

  final String? messageId;
  final bool failed;
  final VoidCallback? onRetry;
  final String role;
  final String content;
  final int timestamp;
  final bool isStreaming;
  final bool live;
  final Map<String, dynamic>? navHint;
  final AskAnswerContext? answerContext;
  final AskPhoto? photo;
  final String? photoUrl;

  _ChatMessage copyWith({
    String? content,
    int? timestamp,
    bool? isStreaming,
    Map<String, dynamic>? navHint,
    AskAnswerContext? answerContext,
    String? photoUrl,
    bool clearRetry = false,
    String? messageId,
  }) {
    return _ChatMessage(
      role: role,
      onRetry: clearRetry ? null : onRetry,
      messageId: messageId ?? this.messageId,
      failed: failed,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      live: live,
      navHint: navHint ?? this.navHint,
      answerContext: answerContext ?? this.answerContext,
      photo: photo,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
