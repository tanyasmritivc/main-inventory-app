import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/low_stock_prefs.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/glass_card.dart';
import '../../core/ui/primary_gradient_button.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.api, this.onInventoryMutated});

  final ApiClient api;
  final VoidCallback? onInventoryMutated;

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

enum _PendingMutationKind { add, delete }

class _PendingMutation {
  const _PendingMutation._({
    required this.kind,
    this.name,
    this.quantity,
    this.query,
  });

  final _PendingMutationKind kind;
  final String? name;
  final int? quantity;
  final String? query;

  factory _PendingMutation.add({required String name, int? quantity}) {
    return _PendingMutation._(
      kind: _PendingMutationKind.add,
      name: name,
      quantity: quantity,
    );
  }

  factory _PendingMutation.delete({required String query}) {
    return _PendingMutation._(kind: _PendingMutationKind.delete, query: query);
  }
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  final _suggestions = const [
    'Find my receipts',
    "What’s low stock?",
    'Summarize my last upload',
    'Show items I should restock',
  ];

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

  _PendingMutation? _pendingMutation;

  final List<String> _pendingAttachments = [];

  List<DocumentEntry>? _pendingDocChoices;

  static const _fallbackNoResponse = 'Hmm, try asking that a different way 🙂';
  static const _fallbackToolFailed =
      'I couldn’t do that right now—want me to try again?';
  static const _fallbackAddFailed =
      'I couldn’t add that right now—try again.';

  static const _fakeTypingText = 'Let me check that for you…';

  bool _resultLooksFailed(Object? result) {
    if (result == null) return false;
    if (result is Map) {
      final m = result.cast<String, dynamic>();
      final ok = m['ok'];
      final success = m['success'];
      final error = m['error']?.toString().trim();
      if (ok == false || success == false) return true;
      if (error != null && error.isNotEmpty) return true;
    }
    return false;
  }

  bool _isInventoryMutationTool(String toolName) {
    final t = toolName.trim().toLowerCase();
    return t == 'add_inventory_item' ||
        t == 'add_inventory_items' ||
        t == 'update_inventory_item' ||
        t == 'update_inventory_items' ||
        t == 'delete_inventory_item' ||
        t == 'delete_inventory_items';
  }

  void _replaceAssistantMessage(int assistantIndex, String text) {
    if (!mounted) return;
    _fakeTypingTimer?.cancel();
    _fakeTypingAssistantIndex = -1;
    _firstTokenFallbackTimer?.cancel();
    setState(() {
      if (assistantIndex >= 0 && assistantIndex < _messages.length) {
        _messages[assistantIndex] = _ChatMessage(
          role: _Role.assistant,
          text: text,
          isTyping: false,
        );
      } else {
        _messages.add(_ChatMessage(role: _Role.assistant, text: text));
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
      if (m.role != _Role.assistant || !m.isTyping) {
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
        _messages[assistantIndex] = m.copyWith(text: nextText, isTyping: true);
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
      if (m.role != _Role.assistant) return;
      if (!m.isTyping) return;
      setState(() {
        _messages[assistantIndex] =
            m.copyWith(text: 'Thinking…', isTyping: true);
      });
      _scrollToBottom();
    });
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
    if (kind == null) return;

    var assistantIndex = -1;

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

      setState(() {
        _sending = true;
        _progress = 'Uploading file...';
        _sentFirstMessage = true;
        _messages.add(
          _ChatMessage(
            role: _Role.user,
            text:
                'Uploaded ${kind == _UploadKind.image ? 'image' : 'file'}: $name',
          ),
        );
        _messages.add(
          _ChatMessage(role: _Role.assistant, text: '', isTyping: true),
        );
      });

      _scrollToBottom(animated: false);

      assistantIndex = _messages.length - 1;

      setState(() {
        if (assistantIndex >= 0 && assistantIndex < _messages.length) {
          _messages[assistantIndex] =
              _messages[assistantIndex].copyWith(text: 'Typing…', isTyping: true);
        }
      });

      _startFakeTyping(assistantIndex);

      _startThinkingFallbackTimer(assistantIndex);

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
        setState(() {
          if (assistantIndex >= 0 && assistantIndex < _messages.length) {
            final prevText = _messages[assistantIndex].text;
            final prev = _messages[assistantIndex].isTyping ||
                    prevText == 'Thinking...' ||
                    prevText == 'Thinking…'
                ? ''
                : prevText;
            _messages[assistantIndex] = _ChatMessage(
              role: _Role.assistant,
              text: prev + add,
              isTyping: false,
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
            setState(() => _progress = evt.message);
            continue;
          }
          if (evt.type == 'delta') {
            final d = evt.delta ?? '';
            if (d.isEmpty) continue;
            if (!streamedAny) {
              _firstTokenFallbackTimer?.cancel();
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
      if (!streamedAny) {
        _replaceAssistantMessage(assistantIndex, _fallbackNoResponse);
      }
    } on dio.DioException catch (e) {
      if (!mounted) return;
      _firstTokenFallbackTimer?.cancel();
      _replaceAssistantMessage(assistantIndex, _fallbackNoResponse);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyRequestError(e))));
    } catch (e) {
      if (!mounted) return;
      _firstTokenFallbackTimer?.cancel();
      _replaceAssistantMessage(assistantIndex, _fallbackNoResponse);
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

  bool _isConfirmYes(String q) {
    final s = q.trim().toLowerCase();
    return s == 'yes' ||
        s == 'y' ||
        s == 'confirm' ||
        s == 'confirmed' ||
        s == 'ok' ||
        s == 'okay' ||
        s == 'do it';
  }

  bool _isConfirmNo(String q) {
    final s = q.trim().toLowerCase();
    return s == 'no' ||
        s == 'n' ||
        s == 'cancel' ||
        s == 'never mind' ||
        s == 'nevermind' ||
        s == 'stop';
  }

  _PendingMutation? _parsePendingMutationFromUserText(String q) {
    final lower = q.trim().toLowerCase();
    if (lower.startsWith('how do i ') || lower.startsWith('how to ')) {
      return null;
    }

    final add = RegExp(
      r'^(please\s+)?(can you\s+)?(add|create|insert)\s+(.+)$',
      caseSensitive: false,
    );
    final bought = RegExp(
      r'^(i\s+)?(bought|got)\s+(.+?)(,\s*add\s+them)?\.?$',
      caseSensitive: false,
    );
    final remove = RegExp(
      r'^(please\s+)?(can you\s+)?(remove|delete)\s+(.+)$',
      caseSensitive: false,
    );
    final getRidOf = RegExp(
      r'^(please\s+)?(can you\s+)?(get rid of|throw away)\s+(.+)$',
      caseSensitive: false,
    );

    String cleanItem(String raw) {
      var s = raw.trim();
      s = s
          .replaceAll(
            RegExp(
              r'\b(from|to|in)\s+(my\s+)?inventory\b',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      s = s.replaceAll(RegExp(r'\bfrom my\b', caseSensitive: false), '').trim();
      s = s.replaceAll(RegExp(r'\bto my\b', caseSensitive: false), '').trim();
      s = s.replaceAll(RegExp(r'\bthe\b', caseSensitive: false), '').trim();
      s = s.replaceAll(RegExp(r'[\.?!]$'), '').trim();
      return s;
    }

    int? qty;
    String? item;

    final mAdd = add.firstMatch(q);
    if (mAdd != null) {
      item = cleanItem((mAdd.group(4) ?? '').trim());
      final mQty = RegExp(
        r'^(\d+)\s*(x\s*)?(.+)$',
        caseSensitive: false,
      ).firstMatch(item);
      if (mQty != null) {
        qty = int.tryParse(mQty.group(1) ?? '');
        item = cleanItem((mQty.group(3) ?? '').trim());
      }
      if (item.isEmpty) return null;
      return _PendingMutation.add(name: item, quantity: qty);
    }

    final mBought = bought.firstMatch(q);
    if (mBought != null) {
      item = cleanItem((mBought.group(3) ?? '').trim());
      final mQty = RegExp(
        r'^(\d+)\s*(x\s*)?(.+)$',
        caseSensitive: false,
      ).firstMatch(item);
      if (mQty != null) {
        qty = int.tryParse(mQty.group(1) ?? '');
        item = cleanItem((mQty.group(3) ?? '').trim());
      }
      if (item.isEmpty) return null;
      return _PendingMutation.add(name: item, quantity: qty);
    }

    final mRem = remove.firstMatch(q);
    if (mRem != null) {
      item = cleanItem((mRem.group(4) ?? '').trim());
      if (item.isEmpty) return null;
      return _PendingMutation.delete(query: item);
    }

    final mRid = getRidOf.firstMatch(q);
    if (mRid != null) {
      item = cleanItem((mRid.group(4) ?? '').trim());
      if (item.isEmpty) return null;
      return _PendingMutation.delete(query: item);
    }

    return null;
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
      final t = error.type;
      if (t == dio.DioExceptionType.connectionTimeout ||
          t == dio.DioExceptionType.sendTimeout ||
          t == dio.DioExceptionType.receiveTimeout) {
        return 'That took longer than expected. Try again.';
      }
    }
    return 'Something went wrong. Try again.';
  }

  Future<void> _submit(String text) async {
    final q = text.trim();
    if (q.isEmpty || _sending) return;

    if (_pendingDocChoices != null) {
      final s = q.trim();
      final docs = _pendingDocChoices ?? const <DocumentEntry>[];

      DocumentEntry? picked;
      final idx = int.tryParse(s);
      if (idx != null && idx > 0 && idx <= docs.length) {
        picked = docs[idx - 1];
      } else {
        final lower = s.toLowerCase();
        for (final d in docs) {
          final name =
              ((d.displayName ?? '').trim().isEmpty
                      ? d.filename
                      : d.displayName!)
                  .toLowerCase();
          if (name.isNotEmpty && lower.contains(name)) {
            picked = d;
            break;
          }
        }
      }

      if (picked == null) {
        setState(() {
          _sentFirstMessage = true;
          _messages.add(_ChatMessage(role: _Role.user, text: q));
          _messages.add(
            _ChatMessage(
              role: _Role.assistant,
              text: 'Reply with the number of the document.',
            ),
          );
        });
        _controller.clear();
        return;
      }

      _pendingDocChoices = null;
      setState(() {
        _sending = true;
        _progress = 'Thinking…';
        _sentFirstMessage = true;
        _messages.add(_ChatMessage(role: _Role.user, text: q));
        _messages.add(_ChatMessage(role: _Role.assistant, text: '', isTyping: true));
      });
      _controller.clear();
      _scrollToBottom(animated: false);

      final assistantIndex = _messages.length - 1;
      setState(() {
        if (assistantIndex >= 0 && assistantIndex < _messages.length) {
          _messages[assistantIndex] =
              _messages[assistantIndex].copyWith(text: 'Typing…', isTyping: true);
        }
      });
      _startFakeTyping(assistantIndex);
      _startThinkingFallbackTimer(assistantIndex);
      try {
        final title = (picked.displayName ?? '').trim().isEmpty
            ? picked.filename
            : picked.displayName!.trim();
        final msg =
            'Summarize this document in a few short bullets. Document: "$title". storage_path: "${picked.documentId}".';
        final out = await widget.api.aiCommand(message: msg);
        if (!mounted) return;
        _fakeTypingTimer?.cancel();
        _fakeTypingAssistantIndex = -1;
        _firstTokenFallbackTimer?.cancel();
        setState(() {
          _messages[assistantIndex] = _ChatMessage(
            role: _Role.assistant,
            text: out.assistantMessage.trim().isEmpty
                ? _fallbackNoResponse
                : out.assistantMessage,
          );
        });
        _scrollToBottom();
      } catch (e) {
        if (!mounted) return;
        _fakeTypingTimer?.cancel();
        _fakeTypingAssistantIndex = -1;
        _firstTokenFallbackTimer?.cancel();
        _replaceAssistantMessage(assistantIndex, _fallbackNoResponse);
      } finally {
        if (mounted) {
          setState(() {
            _sending = false;
            _progress = null;
          });
        }
      }
      return;
    }

    if (_looksLikeSummarizeMyDocument(q)) {
      final docs = await _loadDocChoices();
      if (docs.length > 1) {
        _pendingDocChoices = docs;
        final lines = <String>[];
        for (var i = 0; i < docs.length; i++) {
          final d = docs[i];
          final name = (d.displayName ?? '').trim().isEmpty
              ? d.filename
              : d.displayName!.trim();
          lines.add('${i + 1}. $name');
        }
        setState(() {
          _sentFirstMessage = true;
          _messages.add(_ChatMessage(role: _Role.user, text: q));
          _messages.add(
            _ChatMessage(
              role: _Role.assistant,
              text: 'Which document?\n\n${lines.join('\n')}',
            ),
          );
        });
        _controller.clear();
        return;
      }
    }

    if (_pendingMutation != null) {
      if (_isConfirmYes(q)) {
        final pending = _pendingMutation;
        _pendingMutation = null;
        setState(() {
          _sending = true;
          _sentFirstMessage = true;
          _messages.add(_ChatMessage(role: _Role.user, text: q));
        });
        _controller.clear();

        try {
          if (pending != null && pending.kind == _PendingMutationKind.add) {
            final qty = pending.quantity ?? 1;
            await widget.api.addItem(
              item: AddItemRequest(
                name: pending.name ?? '',
                category: 'Unsorted',
                quantity: qty,
                location: 'Unsorted',
              ),
            );
            if (!mounted) return;
            widget.onInventoryMutated?.call();
            unawaited(_prefetchInventorySnapshot());
            setState(() {
              _messages.add(
                _ChatMessage(
                  role: _Role.assistant,
                  text: 'Added ${pending.name} to your inventory.',
                ),
              );
            });
            return;
          }

          if (pending != null && pending.kind == _PendingMutationKind.delete) {
            final query = (pending.query ?? '').trim();
            if (query.isEmpty) throw StateError('Missing query');
            final res = await widget.api.searchItems(query: query);
            final items = res.items;
            if (!mounted) return;
            if (items.isEmpty) {
              setState(() {
                _messages.add(
                  _ChatMessage(
                    role: _Role.assistant,
                    text: 'I couldn’t find "$query" in your inventory.',
                  ),
                );
              });
              return;
            }
            if (items.length != 1) {
              setState(() {
                _messages.add(
                  _ChatMessage(
                    role: _Role.assistant,
                    text:
                        'I found multiple matches for "$query". Please be more specific.',
                  ),
                );
              });
              return;
            }

            final item = items.first;
            final ok = await widget.api.deleteItem(itemId: item.itemId);
            if (!mounted) return;
            if (!ok) {
              setState(() {
                _messages.add(
                  _ChatMessage(
                    role: _Role.assistant,
                    text: 'That didn’t work. Try again.',
                  ),
                );
              });
              return;
            }

            widget.onInventoryMutated?.call();
            unawaited(_prefetchInventorySnapshot());
            setState(() {
              _messages.add(
                _ChatMessage(
                  role: _Role.assistant,
                  text: 'Removed ${item.name} from your inventory.',
                ),
              );
            });
            return;
          }
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _messages.add(
              _ChatMessage(
                role: _Role.assistant,
                text: _fallbackToolFailed,
              ),
            );
          });
          return;
        } finally {
          if (mounted) setState(() => _sending = false);
        }
      }

      if (_isConfirmNo(q)) {
        _pendingMutation = null;
        setState(() {
          _sentFirstMessage = true;
          _messages.add(_ChatMessage(role: _Role.user, text: q));
          _messages.add(
            _ChatMessage(
              role: _Role.assistant,
              text: 'Okay — no changes made.',
            ),
          );
        });
        _controller.clear();
        return;
      }

      setState(() {
        _sentFirstMessage = true;
        _messages.add(_ChatMessage(role: _Role.user, text: q));
        _messages.add(
          _ChatMessage(
            role: _Role.assistant,
            text: 'Reply Yes to go ahead, or No to cancel.',
          ),
        );
      });
      _controller.clear();
      return;
    }

    final mutation = _parsePendingMutationFromUserText(q);
    if (mutation != null) {
      _pendingMutation = mutation;
      final confirmText = mutation.kind == _PendingMutationKind.add
          ? 'I can add "${mutation.name}" (Qty ${mutation.quantity ?? 1}) — should I go ahead?'
          : 'I can remove "${mutation.query}" — should I go ahead?';
      setState(() {
        _sentFirstMessage = true;
        _messages.add(_ChatMessage(role: _Role.user, text: q));
        _messages.add(_ChatMessage(role: _Role.assistant, text: confirmText));
      });
      _controller.clear();
      return;
    }

    final parsed = _parseSimpleInventoryQuery(q);
    if (parsed.type != null && parsed.query != null) {
      setState(() {
        _sending = true;
        _progress = 'Checking your inventory…';
        _sentFirstMessage = true;
        _messages.add(_ChatMessage(role: _Role.user, text: q));
        _messages.add(
          _ChatMessage(role: _Role.assistant, text: 'Typing…', isTyping: true),
        );
      });
      _controller.clear();
      _scrollToBottom(animated: false);

      final assistantIndex = _messages.length - 1;
      _startFakeTyping(assistantIndex);
      _startThinkingFallbackTimer(assistantIndex);
      try {
        final ans = await _answerSimpleInventoryQueryWithFetch(
          type: parsed.type!,
          query: parsed.query!,
        );
        if (!mounted) return;
        _fakeTypingTimer?.cancel();
        _fakeTypingAssistantIndex = -1;
        _firstTokenFallbackTimer?.cancel();
        setState(() {
          if (assistantIndex >= 0 && assistantIndex < _messages.length) {
            _messages[assistantIndex] = _ChatMessage(
              role: _Role.assistant,
              text: ans,
            );
          }
        });
        _scrollToBottom();
      } catch (_) {
        if (!mounted) return;
        _fakeTypingTimer?.cancel();
        _fakeTypingAssistantIndex = -1;
        _firstTokenFallbackTimer?.cancel();
        setState(() {
          if (assistantIndex >= 0 && assistantIndex < _messages.length) {
            _messages[assistantIndex] = _ChatMessage(
              role: _Role.assistant,
              text: _fallbackNoResponse,
            );
          }
        });
        _scrollToBottom();
      } finally {
        if (mounted) {
          setState(() {
            _progress = null;
            _sending = false;
          });
        }
      }
      return;
    }

    final wantLowStock = _isLowStockQuery(q);
    final lowStockFuture = wantLowStock
        ? _lowStockSummary().timeout(
            const Duration(milliseconds: 900),
            onTimeout: () => null,
          )
        : Future<String?>(() async => null);

    final aiMsg = _messageWithAttachments(q);

    _phaseTimer1?.cancel();
    _phaseTimer2?.cancel();

    setState(() {
      _sending = true;
      _progress = 'Checking your inventory…';
      _sentFirstMessage = true;
      _messages.add(_ChatMessage(role: _Role.user, text: q));
      _messages.add(
        _ChatMessage(role: _Role.assistant, text: 'Typing…', isTyping: true),
      );
    });
    _controller.clear();
    _scrollToBottom(animated: false);

    _phaseTimer1 = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || !_sending) return;
      setState(() => _progress = 'Looking for similar items…');
    });
    _phaseTimer2 = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || !_sending) return;
      setState(() => _progress = 'Thinking…');
    });

    final assistantIndex = _messages.length - 1;

    try {
      bool streamedAny = false;
      bool sawMutationTool = false;
      bool addToolFailed = false;
      try {
        await for (final evt
            in widget.api
                .aiCommandStream(message: aiMsg)
                .timeout(const Duration(seconds: 25))) {
          if (!mounted) return;

          if (evt.tool != null && (evt.tool ?? '').trim().isNotEmpty) {
            final toolName = (evt.tool ?? '').trim();
            developer.log('TOOL EXECUTED: $toolName');
            developer.log(
              'AI RESPONSE: ${jsonEncode(<String, dynamic>{
                'type': evt.type,
                'tool': toolName,
                'result': evt.result,
              })}',
            );
            if (_isInventoryMutationTool(toolName)) {
              sawMutationTool = true;
            }
            if (toolName.trim().toLowerCase().startsWith('add_inventory') &&
                _resultLooksFailed(evt.result)) {
              addToolFailed = true;
            }
          }

          if (evt.type == 'status' && (evt.message ?? '').isNotEmpty) {
            setState(() => _progress = evt.message);
            continue;
          }
          if (evt.type == 'delta') {
            final d = evt.delta ?? '';
            if (d.isEmpty) continue;
            if (!streamedAny) {
              _phaseTimer1?.cancel();
              _phaseTimer2?.cancel();
              _firstTokenFallbackTimer?.cancel();
              _fakeTypingTimer?.cancel();
              _fakeTypingAssistantIndex = -1;
              setState(() => _progress = null);
            }
            streamedAny = true;
            setState(() {
              if (assistantIndex >= 0 && assistantIndex < _messages.length) {
                final prevText = _messages[assistantIndex].text;
                final prev = _messages[assistantIndex].isTyping ||
                        prevText == 'Thinking...' ||
                        prevText == 'Thinking…'
                    ? ''
                    : prevText;
                _messages[assistantIndex] = _ChatMessage(
                  role: _Role.assistant,
                  text: prev + d,
                  isTyping: false,
                );
              }
            });
            _scrollToBottom();
          }
          if (evt.type == 'done') {
            break;
          }
        }
      } catch (_) {
        streamedAny = false;
      } finally {
      }

      final lowStock = await lowStockFuture;

      if (!mounted) return;
      if (streamedAny) {
        _pendingAttachments.clear();
        if (wantLowStock && lowStock != null && lowStock.trim().isNotEmpty) {
          setState(() {
            if (assistantIndex >= 0 && assistantIndex < _messages.length) {
              _messages[assistantIndex] = _ChatMessage(
                role: _Role.assistant,
                text: '$lowStock\n\n${_messages[assistantIndex].text}',
              );
            }
          });
          _scrollToBottom();
        }

        if (sawMutationTool) {
          widget.onInventoryMutated?.call();
          unawaited(_prefetchInventorySnapshot());
        }
        if (addToolFailed) {
          _messages.add(
            _ChatMessage(role: _Role.assistant, text: _fallbackAddFailed),
          );
          _scrollToBottom();
        }
        return;
      }

      final out = await widget.api.aiCommand(message: aiMsg);
      developer.log(
        'AI RESPONSE: ${jsonEncode(<String, dynamic>{
          'tool': out.tool,
          'result': out.result,
          'assistant_message': out.assistantMessage,
        })}',
      );
      if (out.tool != null && (out.tool ?? '').trim().isNotEmpty) {
        developer.log('TOOL EXECUTED: ${out.tool}');
      }
      _pendingAttachments.clear();
      if (!mounted) return;
      _fakeTypingTimer?.cancel();
      _fakeTypingAssistantIndex = -1;
      _firstTokenFallbackTimer?.cancel();
      setState(() {
        final base = out.assistantMessage.trim().isEmpty
            ? _fallbackNoResponse
            : out.assistantMessage;
        final text =
            (wantLowStock && lowStock != null && lowStock.trim().isNotEmpty)
            ? '$lowStock\n\n$base'
            : base;
        if (assistantIndex >= 0 && assistantIndex < _messages.length) {
          _messages[assistantIndex] = _ChatMessage(
            role: _Role.assistant,
            text: text,
          );
        }
      });
      _scrollToBottom();

      final tool = (out.tool ?? '').trim();
      if (tool.isNotEmpty && _isInventoryMutationTool(tool)) {
        widget.onInventoryMutated?.call();
        unawaited(_prefetchInventorySnapshot());
      }
      if (tool.toLowerCase().startsWith('add_inventory') &&
          _resultLooksFailed(out.result)) {
        _messages.add(
          _ChatMessage(role: _Role.assistant, text: _fallbackAddFailed),
        );
        _scrollToBottom();
      }
    } on dio.DioException catch (e) {
      final status = e.response?.statusCode;

      if (!mounted) return;
      if (status == 404) {
        if (mounted) setState(() => _progress = 'Searching inventory…');
        try {
          final res = await widget.api.searchItems(query: q);
          if (!mounted) return;
          setState(() {
            if (_messages.isNotEmpty &&
                _messages.last.role == _Role.assistant &&
                (_messages.last.isTyping || _messages.last.text.isEmpty)) {
              _messages[_messages.length - 1] = _ChatMessage(
                role: _Role.assistant,
                text: res.items.isEmpty
                    ? 'No matches found.'
                    : 'Found ${res.items.length} items. Top: ${res.items.take(3).map((i) => i.name).join(', ')}',
              );
            } else {
              _messages.add(
                _ChatMessage(
                  role: _Role.assistant,
                  text: res.items.isEmpty
                      ? 'No matches found.'
                      : 'Found ${res.items.length} items. Top: ${res.items.take(3).map((i) => i.name).join(', ')}',
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
        _replaceAssistantMessage(assistantIndex, _fallbackNoResponse);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyRequestError(e))));
      }
    } catch (e) {
      if (!mounted) return;
      _replaceAssistantMessage(assistantIndex, _fallbackNoResponse);
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
        });
      }
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_prefetchInventorySnapshot());
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

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final muted = Colors.white.withValues(alpha: 0.55);
    final hideSuggestions = _focusNode.hasFocus || _sentFirstMessage;

    const bgGradient = LinearGradient(
      colors: [
        Color(0xFF020617),
        Color(0xFF020617),
        Color(0xFF0F172A),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Assist'),
        centerTitle: true,
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
            Text(
              'FindEZ',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w400,
                letterSpacing: -0.2,
                fontSize: isIOS ? 24 : null,
              ),
            ),
            SizedBox(height: isIOS ? 4 : 6),
            Text(
              'Find anything in seconds.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: muted,
                height: isIOS ? 1.25 : null,
              ),
            ),
            SizedBox(height: isIOS ? 16 : 18),
            if (!hideSuggestions) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Suggestions',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: isIOS ? 8 : 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _suggestions
                    .map(
                      (s) => _SuggestionChip(
                        label: s,
                        onTap: () {
                          _submit(s);
                        },
                        isIOS: isIOS,
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: isIOS ? 12 : 14),
            ],
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        'Start by searching for an item.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        top: isIOS ? 8 : 10,
                        bottom: isIOS ? 8 : 10,
                      ),
                      itemCount: _messages.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final m = _messages[index];
                        final align = m.role == _Role.user
                            ? Alignment.centerRight
                            : Alignment.centerLeft;
                        final isUser = m.role == _Role.user;
                        final isTyping = !isUser && m.isTyping;
                        final radius = BorderRadius.circular(18);
                        return Align(
                          alignment: align,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: isUser
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      borderRadius: radius,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isIOS ? 14 : 14,
                                        vertical: isIOS ? 11 : 12,
                                      ),
                                      child: Text(
                                        m.text,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.92,
                                          ),
                                          height: isIOS ? 1.2 : 1.25,
                                        ),
                                      ),
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: radius,
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 12,
                                        sigmaY: 12,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: isTyping ? 0.06 : 0.04,
                                          ),
                                          gradient: isTyping
                                              ? null
                                              : LinearGradient(
                                                  colors: [
                                                    const Color(0xFF5EEAD4)
                                                        .withValues(alpha: 0.25),
                                                    const Color(0xFFC084FC)
                                                        .withValues(alpha: 0.25),
                                                    const Color(0xFFF472B6)
                                                        .withValues(alpha: 0.25),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                          borderRadius: radius,
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.12,
                                            ),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isIOS ? 14 : 14,
                                            vertical: isIOS ? 11 : 12,
                                          ),
                                          child: isTyping
                                              ? (m.text.trim().isEmpty
                                                  ? const _TypingDots()
                                                  : Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          m.text,
                                                          style: TextStyle(
                                                            color: Colors.white
                                                                .withValues(
                                                              alpha: 0.72,
                                                            ),
                                                            height: isIOS
                                                                ? 1.2
                                                                : 1.25,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        const _TypingDots(),
                                                      ],
                                                    ))
                                              : Text(
                                                  m.text,
                                                  style: TextStyle(
                                                    color:
                                                        Colors.white.withValues(
                                                      alpha: 0.82,
                                                    ),
                                                    height: isIOS ? 1.2 : 1.25,
                                                  ),
                                                ),
                                        ),
                                      ),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (rect) => accent.createShader(rect),
                    blendMode: BlendMode.srcIn,
                    child: IconButton(
                      onPressed: _attachDocument,
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'Attach',
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Search your stuff…',
                        isDense: true,
                      ),
                      onSubmitted: (v) => _submit(v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 92,
                    child: PrimaryGradientButton(
                      onPressed: _sending
                          ? null
                          : () => _submit(_controller.text),
                      height: isIOS ? 46 : 44,
                      borderRadius: 999,
                      child: ShaderMask(
                        shaderCallback: (rect) => accent.createShader(rect),
                        blendMode: BlendMode.srcIn,
                        child: Text(
                          _sending ? '…' : 'Send',
                          style: const TextStyle(color: Colors.white),
                        ),
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

enum _Role { user, assistant }

class _ChatMessage {
  _ChatMessage({required this.role, required this.text, this.isTyping = false});

  final _Role role;
  final String text;
  final bool isTyping;

  _ChatMessage copyWith({String? text, bool? isTyping}) {
    return _ChatMessage(
      role: role,
      text: text ?? this.text,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.onTap,
    required this.isIOS,
  });

  final String label;
  final VoidCallback onTap;
  final bool isIOS;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isIOS
              ? AppColors.surface.withValues(alpha: 0.52)
              : AppColors.chip,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
        ),
      ),
    );
  }
}
