import 'package:mobile/core/ui/app_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:typed_data';
import '../../core/inventory_context.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auto_extract/extract_style.dart';
import 'auto_extract/extract_widgets.dart';
import 'auto_extract/extract_sheets.dart';
import '../../core/ui/content_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/ask_answer.dart';
import '../../core/private_image.dart';

/// One durable FIND draft. No stock is written by toggling or editing a row.
class ChatCaptureCard extends StatefulWidget {
  const ChatCaptureCard({
    super.key,
    required this.api,
    required this.conversationId,
    required this.draft,
    required this.onChanged,
    this.onSaved,
    this.onOpenResource,
    this.disabled = false,
    this.embedded = false,
    this.photoBytes,
    this.onAsk,
    this.onAddPhoto,
    this.scanPreview = false,
    this.onRetake,
  });
  final ApiClient api;
  final String conversationId;
  final Map<String, dynamic> draft;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback? onSaved;
  final ValueChanged<AskResourceLink>? onOpenResource;
  final bool disabled, embedded;
  final Uint8List? photoBytes;
  final ValueChanged<String>? onAsk;
  final VoidCallback? onAddPhoto, onRetake;
  final bool scanPreview;
  @override
  State<ChatCaptureCard> createState() => ChatCaptureCardState();
}

class ChatCaptureCardState extends State<ChatCaptureCard> {
  late Map<String, dynamic> _draft;
  bool _busy = false, _expanded = false, _choosing = false;
  String? _error;
  int _visibleRows = 40;
  final Set<int> _excluded = {};
  final Set<String> _deleted = {};
  bool _undone = false;
  bool _photoReviewOpen = false;
  int? _highlight;
  Timer? _highlightTimer;
  bool get _photoFlow => _draft['source_kind'] == 'photo';
  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    _excluded.addAll(
      (_draft['_extract_excluded'] as List? ?? []).whereType<int>(),
    );
    if (_photoFlow &&
        _draft['status'] == 'draft' &&
        _draft['_extract_initialized'] != true) {
      for (final row in (_draft['items'] as List).whereType<Map>()) {
        if (extractUncertain(row)) _excluded.add(row['index'] as int);
      }
    }
    if (_photoFlow) {
      _draft['_extract_initialized'] = true;
      _draft['_extract_excluded'] = _excluded.toList();
      _deleted.addAll(
        (_draft['_extract_deleted'] as List? ?? []).whereType<String>(),
      );
      _undone = _draft['_extract_undone'] == true;
      if (_draft['status'] == 'draft' && _draft['space_id'] == null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _restoreDestination(),
        );
      }
    }
  }

  @override
  void didUpdateWidget(ChatCaptureCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft) _draft = widget.draft;
  }

  String get _path =>
      '/worlds/${widget.api.worldKey}/conversations/${widget.conversationId}/captures/${_draft['id']}';
  bool get _editable =>
      !_busy && !widget.disabled && _draft['status'] == 'draft';
  List<Map<String, dynamic>> get _rows => (_draft['items'] as List)
      .map(
        (r) => <String, dynamic>{
          ...Map<String, dynamic>.from(r as Map),
          if (_excluded.contains(r['index'])) 'selected': false,
        },
      )
      .toList();
  void _accept(Map<String, dynamic> response) {
    widget.api.assertCurrentContext();
    if (!mounted) return;
    final value = Map<String, dynamic>.from(response['capture'] as Map);
    if (_photoFlow) {
      value['_extract_initialized'] = true;
      value['_extract_excluded'] = _excluded.toList();
    }
    setState(() => _draft = value);
    widget.onChanged(value);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || widget.disabled) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyApiError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _patch(Map<String, dynamic> changes) => _run(() async {
    _accept(
      await widget.api.collaboration(
        _path,
        method: 'PATCH',
        data: {'revision': _draft['revision'], 'changes': changes},
      ),
    );
  });
  Future<void> _refresh() => _run(() async {
    _accept(await widget.api.collaboration(_path));
  });
  Future<void> _destination() => _run(() async {
    final response = await widget.api.collaboration(
      '/worlds/${widget.api.worldKey}/spaces',
    );
    widget.api.assertCurrentContext();
    if (!mounted) return;
    final groups = (response['inventories'] as List? ?? [])
        .whereType<Map>()
        .where((r) => r['can_edit'] == true)
        .toList();
    setState(() => _choosing = true);
    final selected = await _chooseDestination(groups);
    if (mounted) setState(() => _choosing = false);
    if (selected == null || !mounted) return;
    _accept(
      await widget.api.collaboration(
        _path,
        method: 'PATCH',
        data: {'revision': _draft['revision'], 'changes': selected},
      ),
    );
  });
  Future<Map<String, dynamic>?> _chooseDestination(List<Map> groups) =>
      _photoFlow
      ? extractSheet<Map<String, dynamic>>(
          context,
          (_) => ExtractSpaceSheet(
            groups: groups,
            selected: _draft['space_id'] as String?,
            count: _rows.where((r) => r['selected'] == true).length,
            onCreate: (group, name) async {
              final api = await _scopedInventory('${group['inventory_id']}');
              final space = await api.createSpace(name: name);
              api.assertCurrentContext();
              if (!mounted || space['id'] is! String) {
                throw StateError('Space creation incomplete');
              }
              return {
                'inventory_id': group['inventory_id'],
                'space_id': space['id'],
              };
            },
          ),
        )
      : showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .65,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const AppText(
                    'Save to a Space',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 8),
                  const AppText(
                    'Choose a destination. Your items stay in the draft until you save.',
                  ),
                  for (final group in groups) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 4),
                      child: AppText(
                        '${group['workspace_name']} · ${group['name']}',
                        style: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                    ),
                    if ((group['spaces'] as List? ?? []).isEmpty)
                      const AppText('No Spaces yet. Create one through chat.'),
                    for (final space in group['spaces'] as List? ?? [])
                      ListTile(
                        title: AppText(space['name'] as String),
                        leading: const Icon(Icons.inventory_2_outlined),
                        onTap: () => Navigator.pop(context, {
                          'inventory_id': group['inventory_id'],
                          'space_id': space['id'],
                        }),
                      ),
                  ],
                  if (groups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: AppText(
                        'No writable inventories. Ask chat to create one, or request edit access.',
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

  Future<void> _edit(Map<String, dynamic> row) async {
    if (_photoFlow) {
      final result = await extractSheet<Map<String, dynamic>>(
        context,
        (_) => ExtractEditSheet(row: row, missing: _quantityMissing(row)),
      );
      if (!mounted || result == null) return;
      await _photoPatch(result);
      return;
    }
    final item = Map<String, dynamic>.from(row['item'] as Map);
    final controllers = {
      for (final key in [
        'name',
        'category',
        'quantity',
        'brand',
        'part_number',
        'notes',
      ])
        key: TextEditingController(
          text: key == 'quantity' && _quantityMissing(row)
              ? ''
              : '${item[key] ?? ''}',
        ),
    };
    final form = GlobalKey<FormState>();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppText(
                    'Edit item',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
                  ),
                  for (final field in [
                    ('name', 'Name'),
                    ('category', 'Category'),
                    ('quantity', 'Quantity'),
                    ('brand', 'Brand'),
                    ('part_number', 'Part number'),
                    ('notes', 'Notes'),
                  ])
                    TextFormField(
                      controller: controllers[field.$1],
                      decoration: InputDecoration(labelText: field.$2),
                      keyboardType: field.$1 == 'quantity'
                          ? TextInputType.number
                          : TextInputType.text,
                      validator: (value) {
                        if (field.$1 == 'quantity') {
                          if ((value ?? '').trim().isEmpty &&
                              _quantityMissing(row)) {
                            return null;
                          }
                          final n = int.tryParse(value ?? '');
                          return n == null || n < 0 || n > 100000
                              ? 'Enter a quantity from 0 to 100000'
                              : null;
                        }
                        if (['name', 'category'].contains(field.$1) &&
                            (value ?? '').trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      if (!form.currentState!.validate()) return;
                      Navigator.pop(ctx, {
                        'index': row['index'],
                        for (final e in controllers.entries)
                          if (e.key != 'quantity' ||
                              e.value.text.trim().isNotEmpty)
                            e.key: e.key == 'quantity'
                                ? int.parse(e.value.text)
                                : e.value.text.trim(),
                      });
                    },
                    child: const AppText('Update draft'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // The sheet route may still be animating out while its fields are mounted.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (!mounted || result == null) return;
    await _patch({
      'items': [result],
    });
  }

  Future<bool> _duplicates(Map detail) async {
    final links = (detail['resource_links'] as List? ?? [])
        .map(AskResourceLink.parse)
        .whereType<AskResourceLink>()
        .toList();
    setState(() => _choosing = true);
    final choice =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const AppText('Possible existing items'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppText(
                    'These may already be in your inventory. Open a match, ask chat to update it, or save this extraction as separate items.',
                  ),
                  for (final link in links)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                        widget.onOpenResource?.call(link);
                      },
                      child: AppText('Open ${link.label}'),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const AppText('Keep draft'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const AppText('Save separately'),
              ),
            ],
          ),
        ) ??
        false;
    if (mounted) setState(() => _choosing = false);
    return choice;
  }

  bool _quantityMissing(Map<String, dynamic> row) =>
      ((_draft['summary'] as Map?)?['unknown_quantity_indices'] as List? ?? [])
          .contains(row['index']) ||
      (row['item']['scan_evidence'] is Map &&
          ScanEvidence.fromJson(
            Map<String, dynamic>.from(row['item']['scan_evidence']),
          ).quantityMissing);
  List<Map<String, dynamic>> get _missingRows => _rows
      .where((row) => row['selected'] == true && _quantityMissing(row))
      .toList();

  Future<void> _quantity(Map<String, dynamic> row) async {
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppText(
                    'How many ${row['item']['name']}?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      hintText: 'Enter a count',
                    ),
                    validator: (value) {
                      final n = int.tryParse(value ?? '');
                      return n == null || n < 0 || n > 100000
                          ? 'Enter a whole number from 0 to 100000'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(ctx, {
                          'index': row['index'],
                          'quantity': int.parse(controller.text),
                        });
                      }
                    },
                    child: const AppText('Update quantity'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, {
                      'index': row['index'],
                      'selected': false,
                    }),
                    child: const AppText('Leave this item out for now'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    controller.dispose();
    if (!mounted || result == null) return;
    await _patch({
      'items': [result],
    });
  }

  Future<void> saveFromChat() async {
    if (!_editable) return;
    if (_missingRows.isNotEmpty) {
      await _quantity(_missingRows.first);
      if (!mounted || !_editable || _missingRows.isNotEmpty) return;
    }
    if (_draft['space_id'] == null) {
      await _destination();
      if (!mounted || !_editable || _draft['space_id'] == null) return;
    }
    await _run(_saveItems);
  }

  Future<void> _save() async {
    if (_missingRows.isNotEmpty) {
      await _quantity(_missingRows.first);
    } else if (_draft['space_id'] == null) {
      await _destination();
    } else {
      await _run(_saveItems);
    }
  }

  Future<void> _saveItems({bool confirmItems = true}) async {
    if (_excluded.isNotEmpty) {
      _accept(
        await widget.api.collaboration(
          _path,
          method: 'PATCH',
          data: {
            'revision': _draft['revision'],
            'changes': {
              'items': [
                for (final index in _excluded)
                  {'index': index, 'selected': false},
              ],
            },
          },
        ),
      );
      _excluded.clear();
      _draft['_extract_excluded'] = <int>[];
    }
    Future<Map<String, dynamic>> send(bool separate) =>
        widget.api.collaboration(
          '$_path/save',
          method: 'POST',
          data: {
            'revision': _draft['revision'],
            'allow_duplicates': separate,
            'confirm_items': confirmItems,
          },
        );
    Map<String, dynamic> response;
    try {
      response = await send(false);
    } on DioException catch (error) {
      final body = error.response?.data;
      final detail = body is Map ? body['detail'] : null;
      if (detail is! Map || detail['code'] != 'capture_duplicates') rethrow;
      if (!mounted || !await _duplicates(detail)) return;
      response = await send(true);
    }
    _accept(response);
    // Large imports checkpoint each batch on the server. Retry only the frozen
    // draft; partial failures remain visible and never count as a full save.
    while (mounted &&
        _draft['source_kind'] == 'spreadsheet' &&
        _draft['processed_count'] is int &&
        _draft['status'] == 'saving' &&
        ((_draft['receipt'] as Map?)?['failures'] as List? ?? []).isEmpty) {
      response = await send(false);
      _accept(response);
    }
    if (_draft['status'] == 'saved') {
      if (_photoFlow) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(_lastSpaceKey, [
            '${_draft['inventory_id']}',
            '${_draft['space_id']}',
          ]);
        } catch (_) {
          /* A local preference failure must not mask a saved receipt. */
        }
      }
      if (mounted) widget.onSaved?.call();
    }
  }

  void _showSavedItems() {
    final rows = _rows.where((row) => row['selected'] == true).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: AppText(
                  'Extraction details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final item = rows[index]['item'] as Map;
                    final review =
                        ((_draft['receipt'] as Map?)?['reviews'] as List? ?? [])
                            .any(
                              (entry) => entry['index'] == rows[index]['index'],
                            );
                    return ListTile(
                      title: AppText(item['name'] as String),
                      subtitle: AppText(
                        '${item['category']} · Qty ${item['quantity']}${review ? ' · Sent to Review' : ''}',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _lastSpaceKey =>
      'extract.last-space.${Supabase.instance.client.auth.currentUser?.id}.${widget.api.worldKey}';
  Future<void> _restoreDestination() async {
    try {
      final ids = (await SharedPreferences.getInstance()).getStringList(
        _lastSpaceKey,
      );
      if (!mounted || !_editable || ids == null || ids.length != 2) return;
      final directory = await widget.api.collaboration(
        '/worlds/${widget.api.worldKey}/spaces',
      );
      widget.api.assertCurrentContext();
      if (!mounted || !_editable || _draft['space_id'] != null) return;
      final valid = (directory['inventories'] as List? ?? [])
          .whereType<Map>()
          .any(
            (g) =>
                g['inventory_id'] == ids[0] &&
                g['can_edit'] == true &&
                (g['spaces'] as List? ?? []).whereType<Map>().any(
                  (s) => s['id'] == ids[1],
                ),
          );
      if (valid) await _patch({'inventory_id': ids[0], 'space_id': ids[1]});
    } catch (_) {
      /* A remembered destination is optional; the picker remains available. */
    }
  }

  Future<ApiClient> _scopedInventory(String id) async {
    widget.api.assertCurrentContext();
    final account = Supabase.instance.client.auth.currentUser?.id;
    if (account == null) throw StateError('Sign in again');
    final data = await widget.api.collaboration('/inventories/$id');
    widget.api.assertCurrentContext();
    final inventory = InventoryContext.fromJson(
      Map<String, dynamic>.from(data['inventory'] as Map),
      accountId: account,
      expectedInventory: id,
    );
    if (!inventory.canEdit ||
        (inventory.organizationId ?? 'personal') != widget.api.worldKey) {
      throw StateError('Choose an editable inventory in this organization');
    }
    return ApiClient.forInventory(
      widget.api,
      inventory,
      isCurrent: () {
        if (!mounted) return false;
        try {
          widget.api.assertCurrentContext();
          return true;
        } catch (_) {
          return false;
        }
      },
    );
  }

  Future<void> _photoPatch(Map<String, dynamic> change) async {
    if (!_editable) return;
    await _patch({
      'items': [change],
    });
    if (!mounted || _error != null) return;
    setState(() {
      _excluded.remove(change['index']);
      _draft['_extract_excluded'] = _excluded.toList();
      _highlight = change['index'];
    });
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _highlight = null);
    });
  }

  /// Interpret only unambiguous draft edits. Other messages retain normal chat.
  Future<String?> correctFromChat(String text) async {
    if (!_photoFlow || !_editable) return null;
    final words = RegExp(r"[a-z]{4,}")
        .allMatches(text.toLowerCase())
        .map((m) => m[0]!.replaceFirst(RegExp(r's$'), ''))
        .toSet();
    final matches = _rows
        .where(
          (r) => RegExp(r'[a-z]{4,}')
              .allMatches('${r['item']['name']}'.toLowerCase())
              .any(
                (m) => words.contains(m[0]!.replaceFirst(RegExp(r's$'), '')),
              ),
        )
        .toList();
    if (matches.length != 1) return null;
    final row = matches.single;
    final remove = RegExp(
      r'\b(remove|leave out|not|skip|wrong)\b',
      caseSensitive: false,
    ).hasMatch(text);
    final numbers = RegExp(r'\b\d+\b').allMatches(text).toList();
    if (!remove && numbers.length != 1) return null;
    final quantity = numbers.isEmpty ? null : int.tryParse(numbers.single[0]!);
    if (!remove && (quantity == null || quantity > 100000)) return null;
    await _photoPatch({
      'index': row['index'],
      'selected': !remove,
      if (!remove) 'quantity': quantity,
    });
    if (!mounted) return '';
    if (_error != null) {
      return 'Could not update the draft. Your items have not been saved.';
    }
    return remove
        ? 'Left out ${extractName(row)}.'
        : 'Updated: ${extractName(row)} ×$quantity.';
  }

  Widget _photoBody(BuildContext context) {
    final rows = _rows;
    final selected = rows.where((r) => r['selected'] == true).toList();
    final receipt = _draft['receipt'] as Map?;
    final saved = _draft['status'] == 'saved';
    final links = (receipt?['resource_links'] as List? ?? [])
        .map(AskResourceLink.parse)
        .whereType<AskResourceLink>()
        .toList();
    final itemLinks = links
        .where(
          (r) => r.kind == 'item' && r.inventoryId == _draft['inventory_id'],
        )
        .toList();
    final destination = AskResourceLink.parse({
      'kind': 'space',
      'id': _draft['space_id'],
      'inventory_id': _draft['inventory_id'],
      'label': _draft['location'],
      'href': 'findez://space/${_draft['inventory_id']}/${_draft['space_id']}',
    });
    final excluded = rows
        .where(
          (r) => !((r['selected'] as bool?) ?? false) && extractUncertain(r),
        )
        .map((r) => extractName(r).toLowerCase())
        .join(' and ');
    Widget pill(String label, VoidCallback? tap) => FilledButton(
      style: ExtractStyle.pill(height: 38),
      onPressed: tap,
      child: AppText(label),
    );
    return ExtractReply(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: ExtractStyle.curve,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_undone)
              AppText(
                'Undone. Nothing from that photo was saved.',
                style: ExtractStyle.text(15.5),
              )
            else if (saved) ...[
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ExtractStyle.s1,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ExtractStyle.line),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 12,
                      backgroundColor: ExtractStyle.white,
                      child: Icon(
                        Icons.check,
                        size: 13,
                        color: ExtractStyle.ink,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppText(
                        'Saved ${receipt?['saved_count'] ?? 0} ${(receipt?['saved_count'] ?? 0) == 1 ? 'item' : 'items'} to ${_draft['location'] ?? 'your Space'}${(receipt?['review_count'] ?? 0) > 0 ? ' · ${receipt!['review_count']} in Review' : ''}',
                        style: ExtractStyle.text(14.5),
                      ),
                    ),
                    for (final row in selected.take(4))
                      if (row['item']['image_url'] is String)
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: ExtractPhoto(
                            url: row['item']['image_url'],
                            height: 30,
                            width: 30,
                            radius: 8,
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (destination != null)
                    pill(
                      'Open ${destination.label}',
                      widget.onOpenResource == null
                          ? null
                          : () => widget.onOpenResource!(destination),
                    ),
                  if (itemLinks.isNotEmpty &&
                      itemLinks.length == receipt?['saved_count'] &&
                      (receipt?['review_count'] ?? 0) == 0)
                    pill(
                      'Undo',
                      _busy
                          ? null
                          : () => _run(() async {
                              final api = await _scopedInventory(
                                '${_draft['inventory_id']}',
                              );
                              for (final link in itemLinks) {
                                if (_deleted.contains(link.id)) continue;
                                if (!await api.deleteItem(itemId: link.id)) {
                                  throw StateError(
                                    'Could not undo every item. Retry Undo.',
                                  );
                                }
                                _deleted.add(link.id);
                                _draft['_extract_deleted'] = _deleted.toList();
                              }
                              if (!mounted) return;
                              setState(() {
                                _undone = true;
                                _draft['_extract_undone'] = true;
                              });
                              widget.onSaved?.call();
                              if (context.mounted) {
                                extractToast(context, 'Undone');
                              }
                            }),
                    ),
                  pill('Details', _showSavedItems),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (selected.isNotEmpty && widget.onAsk != null)
                    pill(
                      'Where is the ${extractName(selected.first).toLowerCase()}?',
                      () => widget.onAsk!(
                        'Where is the ${extractName(selected.first).toLowerCase()}?',
                      ),
                    ),
                  if (widget.onAddPhoto != null)
                    pill('Add another photo', widget.onAddPhoto),
                ],
              ),
            ] else ...[
              AppText(
                'I found ${rows.length} ${rows.length == 1 ? 'item' : 'items'}.${excluded.isNotEmpty ? " I left out the $excluded because I’m not sure." : ""}',
                style: ExtractStyle.text(15.5).copyWith(height: 1.5),
              ),
              if (widget.photoBytes != null ||
                  _draft['source_url'] is String) ...[
                const SizedBox(height: 12),
                ExtractPhoto(
                  bytes: widget.photoBytes,
                  url: _draft['source_url'] as String?,
                  width: double.infinity,
                ),
              ],
              const SizedBox(height: 12),
              ExtractTiles(
                rows: rows.take(_visibleRows).toList(),
                onToggle: _editable
                    ? (row) => _photoPatch({
                        'index': row['index'],
                        'selected': row['selected'] != true,
                      })
                    : null,
                onEdit: _editable ? _edit : null,
                quantityMissing: _quantityMissing,
                highlight: _highlight,
              ),
              if (rows.length > _visibleRows)
                TextButton(
                  onPressed: () => setState(() => _visibleRows += 40),
                  child: const AppText('Show more items'),
                ),
              if (rows.isEmpty)
                AppText(
                  'No items were detected. Try a closer, well-lit photo.',
                  style: ExtractStyle.text(14, color: ExtractStyle.tx2),
                ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, bounds) {
                  final actions = [
                    FilledButton.icon(
                      style: ExtractStyle.pill(),
                      onPressed: _editable ? _destination : null,
                      icon: const Icon(Icons.location_on_outlined, size: 17),
                      label: AppText(
                        '${_draft['location'] ?? 'Choose a Space'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FilledButton(
                      style: ExtractStyle.pill(primary: true),
                      onPressed: _busy || widget.disabled || selected.isEmpty
                          ? null
                          : _save,
                      child: AppText(
                        _draft['status'] == 'saving'
                            ? 'Retry save safely'
                            : selected.isEmpty
                            ? 'Select items'
                            : 'Save ${selected.length} ${selected.length == 1 ? 'item' : 'items'}',
                      ),
                    ),
                  ];
                  return bounds.maxWidth < 260 ||
                          MediaQuery.textScalerOf(context).scale(15) > 24
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            actions[0],
                            const SizedBox(height: 8),
                            actions[1],
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(flex: 100, child: actions[0]),
                            const SizedBox(width: 8),
                            Expanded(flex: 115, child: actions[1]),
                          ],
                        );
                },
              ),
              const SizedBox(height: 8),
              AppText(
                'Tap an item or its number to leave it out. Tap ✎ to edit.',
                style: ExtractStyle.text(12.5, color: ExtractStyle.tx3),
              ),
              if (_missingRows.isNotEmpty)
                AppText(
                  'Add the missing quantities before saving.',
                  style: ExtractStyle.text(12.5, color: ExtractStyle.tx2),
                ),
              if (_editable &&
                  _draft['space_id'] != null &&
                  _missingRows.isEmpty &&
                  selected.any(
                    (r) =>
                        (r['item']['scan_evidence'] as Map?)?['needs_review'] ==
                        true,
                  ))
                TextButton(
                  onPressed: () => _run(() => _saveItems(confirmItems: false)),
                  child: AppText(
                    'Keep uncertain items in Review',
                    style: ExtractStyle.text(12.5, color: ExtractStyle.tx2),
                  ),
                ),
            ],
            if (_busy && !_choosing)
              const LinearProgressIndicator(
                minHeight: 2,
                color: ExtractStyle.white,
                backgroundColor: ExtractStyle.s2,
              ),
            if (_error != null)
              AppText(
                _error!,
                style: ExtractStyle.text(14, color: ExtractStyle.red),
              ),
            for (final failure in receipt?['failures'] as List? ?? [])
              AppText(
                '${failure['reason']}',
                style: ExtractStyle.text(14, color: ExtractStyle.red),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_photoFlow) {
      if (widget.scanPreview &&
          !_photoReviewOpen &&
          _draft['status'] == 'draft' &&
          widget.photoBytes != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExtractScanning(
              photo: widget.photoBytes!,
              message: '',
              done: true,
              rows: _rows,
              onToggle: _editable
                  ? (row) => _photoPatch({
                      'index': row['index'],
                      'selected': row['selected'] != true,
                    })
                  : null,
              onReview: _editable
                  ? () => setState(() => _photoReviewOpen = true)
                  : null,
              onRetake: _editable ? widget.onRetake : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: AppText(
                  _error!,
                  style: ExtractStyle.text(14, color: ExtractStyle.red),
                ),
              ),
          ],
        );
      }
      return _photoBody(context);
    }
    final rows = _rows;
    final selected = rows.where((r) => r['selected'] == true).length;
    final receipt = _draft['receipt'] as Map?;
    final saved = _draft['status'] == 'saved';
    final saving = _draft['status'] == 'saving';
    final links = (receipt?['resource_links'] as List? ?? [])
        .map(AskResourceLink.parse)
        .whereType<AskResourceLink>()
        .toList();
    final destination =
        AskResourceLink.parse({
          'kind': 'space',
          'id': _draft['space_id'],
          'inventory_id': _draft['inventory_id'],
          'label': _draft['location'],
          'href':
              'findez://space/${_draft['inventory_id']}/${_draft['space_id']}',
        }) ??
        links.where((link) => link.kind == 'space').firstOrNull;
    final review = <Widget>[
      Row(
        children: [
          if (!widget.embedded)
            const Icon(Icons.auto_awesome_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: AppText(
              widget.embedded
                  ? '$selected of ${rows.length} selected · Not saved yet'
                  : saved
                  ? (_draft['source_kind'] == 'text'
                        ? 'Items saved'
                        : 'Extraction saved')
                  : _draft['source_kind'] == 'text'
                  ? 'Inventory draft'
                  : 'Auto Extract',
              style: TextStyle(
                fontSize: widget.embedded ? 13 : 17,
                color: widget.embedded ? AppTheme.textSecondary(context) : null,
                fontWeight: widget.embedded ? FontWeight.w400 : FontWeight.w400,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh extraction',
            onPressed: _busy || widget.disabled ? null : _refresh,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ],
      ),
      if (!widget.embedded)
        AppText(
          saved
              ? '${receipt?['saved_count'] ?? 0} saved · ${receipt?['review_count'] ?? 0} in Review'
              : '$selected of ${rows.length} selected · Not saved yet',
          style: TextStyle(
            color: AppTheme.textSecondary(context),
            fontSize: 13,
          ),
        ),
      if (!saved && rows.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: AppText(
            'No items were detected. Try a closer, well-lit photo.',
          ),
        ),
      for (final row
          in (saved
              ? <Map<String, dynamic>>[]
              : _expanded
              ? rows.take(_visibleRows)
              : rows.take(4))) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!saved)
                Checkbox(
                  value: row['selected'] == true,
                  onChanged: !_editable
                      ? null
                      : (value) => _patch({
                          'items': [
                            {'index': row['index'], 'selected': value},
                          ],
                        }),
                ),
              if (row['item']['image_url'] is String)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: PrivateImage(
                    row['item']['image_url'],
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(Icons.image_outlined),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      row['item']['name'] as String,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                      ),
                    ),
                    AppText(
                      _quantityMissing(row)
                          ? '${row['item']['category']} · Quantity needed'
                          : '${row['item']['category']} · Qty ${row['item']['quantity']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                    if (_quantityMissing(row) && row['selected'] == true)
                      TextButton(
                        onPressed: _editable ? () => _quantity(row) : null,
                        child: const AppText('Add quantity'),
                      ),
                    if ((row['item']['scan_evidence']
                            as Map?)?['needs_review'] ==
                        true)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: AppText(
                          'Check extracted details',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!saved)
                IconButton(
                  tooltip: 'Edit ${row['item']['name']}',
                  onPressed: _editable ? () => _edit(row) : null,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
            ],
          ),
        ),
      ],
      if (!saved && rows.length > 4)
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          child: AppText(
            _expanded ? 'Show fewer' : 'Show all ${rows.length} items',
          ),
        ),
      if (!saved && _expanded && rows.length > _visibleRows)
        TextButton(
          onPressed: () => setState(() => _visibleRows += 40),
          child: const AppText('Show more items'),
        ),
    ];
    final actions = <Widget>[
      if (!saved) ...[
        const SizedBox(height: 12),
        if (!widget.embedded || _draft['space_id'] != null)
          TextButton.icon(
            onPressed: _editable ? _destination : null,
            icon: const Icon(Icons.folder_outlined, size: 18),
            label: AppText(
              _draft['space_id'] == null
                  ? 'Choose a Space'
                  : '${_draft['location']}',
            ),
          ),
        AppText(
          _missingRows.isNotEmpty
              ? 'Add the missing quantities, or uncheck those items to save the rest.'
              : _draft['space_id'] == null
              ? 'Choose where to keep these items.'
              : 'Check the names and quantities. Adding confirms these items for ${_draft['location']}.',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary(context),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy || widget.disabled || selected == 0 ? null : _save,
          child: AppText(
            saving
                ? 'Retry save safely'
                : _missingRows.isNotEmpty
                ? 'Add missing quantity'
                : _draft['space_id'] == null
                ? 'Choose a Space'
                : 'Add to Space',
          ),
        ),
        if (_editable &&
            _draft['space_id'] != null &&
            _missingRows.isEmpty &&
            rows.any(
              (row) =>
                  row['selected'] == true &&
                  (row['item']['scan_evidence'] as Map?)?['needs_review'] ==
                      true,
            ))
          TextButton(
            onPressed: () => _run(() => _saveItems(confirmItems: false)),
            child: const AppText('Keep uncertain items in Review'),
          ),
      ],
      if (_busy && !_choosing) const LinearProgressIndicator(),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: AppText(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (receipt != null) ...[
        for (final failure in receipt['failures'] as List? ?? [])
          AppText(failure['reason'] as String),
        if (destination != null)
          TextButton.icon(
            onPressed: widget.onOpenResource == null
                ? null
                : () => widget.onOpenResource!(destination),
            icon: const Icon(Icons.folder_outlined, size: 18),
            label: AppText('Open ${destination.label}'),
          ),
        if (saved && selected > 0)
          TextButton(
            onPressed: _showSavedItems,
            child: AppText('View $selected extracted items'),
          ),
      ],
    ];
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [...review, ...actions],
    );
    if (widget.embedded) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final pinActions =
              constraints.hasBoundedHeight &&
              constraints.maxHeight >= 380 &&
              _error == null &&
              MediaQuery.textScalerOf(context).scale(16) < 28;
          final scroll = SingleChildScrollView(
            key: const Key('extraction-preview-scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: pinActions
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: review,
                  )
                : content,
          );
          if (!pinActions) return scroll;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: scroll),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .08),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: actions,
                ),
              ),
            ],
          );
        },
      );
    }
    return ContentCard(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: content,
    );
  }
}
