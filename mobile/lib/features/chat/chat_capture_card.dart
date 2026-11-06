import '../../core/ui/content_card.dart';
import 'extraction_progress_panel.dart' show scanMotion;
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
    this.photo,
    this.creationAction,
  });
  final ApiClient api;
  final String conversationId;
  final Map<String, dynamic> draft;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback? onSaved;
  final ValueChanged<AskResourceLink>? onOpenResource;
  final bool disabled, embedded;
  final ImageProvider? photo;
  final Map<String, dynamic>? creationAction;
  @override
  State<ChatCaptureCard> createState() => ChatCaptureCardState();
}

class ChatCaptureCardState extends State<ChatCaptureCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival;
  late Map<String, dynamic> _draft;
  bool _busy = false, _expanded = false, _choosing = false;
  String? _error;
  Object? _highlightedRow;
  int _visibleRows = 40;
  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    _arrival = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatCaptureCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft) {
      if (oldWidget.draft['id'] != widget.draft['id']) {
        _highlightedRow = null;
        _arrival.forward(from: 0);
      }
      _draft = widget.draft;
    }
  }

  String get _path =>
      '/worlds/${widget.api.worldKey}/conversations/${widget.conversationId}/captures/${_draft['id']}';
  bool get _editable =>
      !_busy && !widget.disabled && _draft['status'] == 'draft';
  List<Map<String, dynamic>> get _rows => (_draft['items'] as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
  void _accept(Map<String, dynamic> response) {
    widget.api.assertCurrentContext();
    if (!mounted) return;
    final value = Map<String, dynamic>.from(response['capture'] as Map);
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
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const Text(
                'Save to a Space',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a destination. Your items stay in the draft until you save.',
              ),
              for (final group in groups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 4),
                  child: Text(
                    '${group['workspace_name']} · ${group['name']}',
                    style: const TextStyle(fontWeight: FontWeight.w400),
                  ),
                ),
                if ((group['spaces'] as List? ?? []).isEmpty)
                  const Text('No Spaces yet. Create one through chat.'),
                for (final space in group['spaces'] as List? ?? [])
                  ListTile(
                    title: Text(space['name'] as String),
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
                  child: Text(
                    'No writable inventories. Ask chat to create one, or request edit access.',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
  Future<void> _edit(Map<String, dynamic> row) async {
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
                  const Text(
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
                    child: const Text('Update draft'),
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
            title: const Text('Possible existing items'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'These may already be in your inventory. Open a match, ask chat to update it, or save this extraction as separate items.',
                  ),
                  for (final link in links)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                        widget.onOpenResource?.call(link);
                      },
                      child: Text('Open ${link.label}'),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep draft'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save separately'),
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
                  Text(
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
                    child: const Text('Update quantity'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, {
                      'index': row['index'],
                      'selected': false,
                    }),
                    child: const Text('Leave this item out for now'),
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

  Map<String, dynamic>? get _creation {
    final action = widget.creationAction;
    final binding = action?['capture_destination'];
    if (_draft['space_id'] != null ||
        binding is! Map ||
        binding['capture_id'] != _draft['id'] ||
        !['pending', 'confirmed'].contains(action?['status'])) {
      return null;
    }
    return action;
  }

  String get _destinationHint => _creation == null
      ? 'Choose where to keep these items.'
      : 'New Space: ${(_creation!['capture_destination'] as Map)['place']}';

  Future<void> _createAndSave() => _run(() async {
    final action = _creation;
    if (action == null) return;
    final response = await widget.api.collaboration(
      '/worlds/${widget.api.worldKey}/structure-actions/${action['id']}',
      method: 'POST',
      data: {'decision': 'confirm', 'supports_task_actions': true},
    );
    widget.api.assertCurrentContext();
    if (!mounted) return;
    final confirmed = response['action'];
    if (confirmed is! Map ||
        confirmed['id'] != action['id'] ||
        confirmed['status'] != 'confirmed') {
      throw const FormatException(
        'Creation could not be confirmed. Retry this same draft.',
      );
    }
    action.addAll(Map<String, dynamic>.from(confirmed));
    widget.onSaved
        ?.call(); // Refresh the directory even if item saving needs retry.
    if (response['capture'] is! Map) {
      throw FormatException(
        response['capture_warning'] is String
            ? response['capture_warning'] as String
            : 'Space created. Refresh the draft and choose it to continue.',
      );
    }
    _accept(response);
    if (_draft['status'] != 'saved') await _saveItems();
  });

  Future<void> _save() async {
    if (_missingRows.isNotEmpty) {
      await _quantity(_missingRows.first);
    } else if (_creation != null) {
      await _createAndSave();
    } else if (_draft['space_id'] == null) {
      await _destination();
    } else {
      await _run(_saveItems);
    }
  }

  Future<void> _saveItems() async {
    Future<Map<String, dynamic>> send(bool separate) =>
        widget.api.collaboration(
          '$_path/save',
          method: 'POST',
          data: {'revision': _draft['revision'], 'allow_duplicates': separate},
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
    if (_draft['status'] == 'saved') widget.onSaved?.call();
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
                child: Text(
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
                        (item['scan_evidence'] as Map?)?['needs_review'] ==
                        true;
                    return ListTile(
                      title: Text(item['name'] as String),
                      subtitle: Text(
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

  Widget _photoReview(BuildContext context) {
    final rows = scanDisplayRows(
      _rows,
      missing: _rows.where(_quantityMissing).map((r) => r['index']).toSet(),
    );
    final selected = rows.where((r) => r['selected'] == true).length;
    final unknown = rows.where(scanUnknown).length;
    final firstUnknown = rows.indexWhere(scanUnknown);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? const Color(0xff98989f) : const Color(0xff6c6c70);
    final primary = dark ? Colors.white : Colors.black;
    final saving = _draft['status'] == 'saving';
    final receipt = _draft['receipt'] as Map?;
    final status = Row(
      children: [
        Expanded(
          child: Text(
            '$selected of ${rows.length} selected · Not saved yet',
            style: TextStyle(fontSize: 13, color: secondary),
          ),
        ),
        IconButton(
          tooltip: 'Refresh extraction',
          onPressed: _busy || widget.disabled ? null : _refresh,
          icon: const Icon(Icons.refresh, size: 20),
        ),
      ],
    );
    final footer = Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: dark
                ? primary.withValues(alpha: .08)
                : AppTheme.border(context),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_draft['space_id'] != null)
            TextButton.icon(
              onPressed: _editable ? _destination : null,
              icon: const Icon(Icons.folder_outlined, size: 18),
              label: Text('${_draft['location']}'),
            ),
          Text(
            _missingRows.isNotEmpty
                ? 'Add the missing quantities, or uncheck those items to save the rest.'
                : _draft['space_id'] == null
                ? _destinationHint
                : 'Ready to save to ${_draft['location']}.',
            style: TextStyle(fontSize: 13.5, color: secondary),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy || widget.disabled || selected == 0 ? null : _save,
            style:
                FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: dark ? Colors.black : Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontSize: 15),
                ).copyWith(
                  backgroundBuilder: (_, _, child) =>
                      child ?? const SizedBox.shrink(),
                ),
            child: Text(
              saving
                  ? 'Retry save safely'
                  : _missingRows.isNotEmpty
                  ? 'Add missing quantity'
                  : _draft['space_id'] == null
                  ? (_creation != null
                        ? 'Create Space & save items'
                        : 'Choose a Space')
                  : 'Save items',
            ),
          ),
          if (_busy && !_choosing) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (receipt != null) ...[
            for (final failure in receipt['failures'] as List? ?? [])
              Text('${failure['reason']}'),
            for (final link
                in (receipt['resource_links'] as List? ?? [])
                    .map(AskResourceLink.parse)
                    .whereType<AskResourceLink>())
              TextButton(
                onPressed: widget.onOpenResource == null
                    ? null
                    : () => widget.onOpenResource!(link),
                child: Text('Open ${link.label}'),
              ),
          ],
        ],
      ),
    );
    Widget reviewStatus() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.embedded)
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 4),
            child: Text('Auto Extract', style: TextStyle(fontSize: 17)),
          ),
        status,
      ],
    );
    Widget rowAt(int index) {
      final row = rows[index];
      final item = row['item'] as Map;
      final name = scanDisplayName(row);
      final detail = scanDetail(row);
      final confidence = scanConfidence(row);
      final certainty = confidence == null
          ? null
          : confidence >= .85
          ? 'Confident'
          : confidence >= .6
          ? 'Likely'
          : 'Not sure';
      final color = confidence != null && confidence >= .85
          ? const Color(0xff34c759)
          : confidence != null && confidence >= .6
          ? const Color(0xffe3b45c)
          : const Color(0xff8e8e93);
      final needsReview =
          (item['scan_evidence'] as Map?)?['needs_review'] == true;
      final info = _quantityMissing(row)
          ? '${item['category'] ?? ''} · Quantity needed'
          : '${item['category'] ?? ''} · Qty ${item['quantity']}';
      final thumbnail =
          item['image_url'] is String &&
              (item['image_url'] as String).isNotEmpty
          ? PrivateImage(
              item['image_url'],
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _thumbnailFallback(),
            )
          : _thumbnailFallback();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (index == firstUnknown)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
              child: Text(
                unknown == 1
                    ? 'Not sure about this one'
                    : 'Not sure about these',
                style: TextStyle(fontSize: 12, color: secondary),
              ),
            ),
          Semantics(
            container: true,
            explicitChildNodes: true,
            label:
                '${index + 1}. $name. $detail. $info${certainty == null ? '' : '. $certainty'}${needsReview ? '. Needs Review' : ''}',
            child: Material(
              color: _highlightedRow == row['index']
                  ? primary.withValues(alpha: .06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                key: ValueKey('scan-row-${row['index']}'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _highlightedRow = row['index']),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 52,
                        child: Checkbox(
                          key: ValueKey('scan-select-${row['index']}'),
                          semanticLabel: '$name selected',
                          value: row['selected'] == true,
                          fillColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? primary
                                : Colors.transparent,
                          ),
                          checkColor: dark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                          onChanged: !_editable
                              ? null
                              : (value) => _patch({
                                  'items': [
                                    {'index': row['index'], 'selected': value},
                                  ],
                                }),
                        ),
                      ),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: thumbnail,
                          ),
                          Positioned(
                            top: -4,
                            left: -4,
                            child: ExcludeSemantics(
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 19,
                                  minHeight: 19,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: dark ? Colors.black : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExcludeSemantics(
                              child: Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (detail.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: ExcludeSemantics(
                                  child: Text(
                                    detail,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.25,
                                      color: primary.withValues(alpha: .78),
                                    ),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: ExcludeSemantics(
                                child: Text(
                                  info,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: secondary,
                                  ),
                                ),
                              ),
                            ),
                            if (certainty != null || needsReview)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Wrap(
                                  spacing: 7,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (certainty != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            certainty,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (needsReview)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xffe3b45c,
                                          ).withValues(alpha: dark ? .14 : .20),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          'Needs Review',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: dark
                                                ? const Color(0xffe3b45c)
                                                : const Color(0xff8a5a00),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            if (_quantityMissing(row) &&
                                row['selected'] == true)
                              TextButton(
                                onPressed: _editable
                                    ? () => _quantity(row)
                                    : null,
                                child: const Text('Add quantity'),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: IconButton(
                          tooltip: 'Edit $name',
                          key: ValueKey('scan-edit-${row['index']}'),
                          onPressed: _editable ? () => _edit(row) : null,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget list({required bool bounded}) => ListView.builder(
      key: const Key('extraction-preview-scroll'),
      shrinkWrap: !bounded,
      physics: bounded ? null : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: rows.isEmpty ? 1 : rows.length,
      itemBuilder: (_, i) => rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'No items were detected. Try a closer, well-lit photo.',
              ),
            )
          : i >= 4 || MediaQuery.disableAnimationsOf(context)
          ? rowAt(i)
          : FadeTransition(
              // Stagger the initially visible rows only. Offscreen rows and all
              // controls remain immediately usable, even with a long scan.
              opacity: _arrival.drive(
                CurveTween(
                  curve: Interval(
                    i * 250 / 1200,
                    (i * 250 + 450) / 1200,
                    curve: scanMotion,
                  ),
                ),
              ),
              child: rowAt(i),
            ),
    );
    return LayoutBuilder(
      builder: (context, bounds) {
        final pin =
            bounds.hasBoundedHeight &&
            bounds.maxHeight >= 220 &&
            MediaQuery.textScalerOf(context).scale(16) < 28 &&
            _error == null;
        if (pin) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: reviewStatus(),
              ),
              Expanded(
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [
                      0,
                      ((rect.height - 18) / rect.height).clamp(0.0, 1.0),
                      1,
                    ],
                  ).createShader(rect),
                  child: list(bounded: true),
                ),
              ),
              footer,
            ],
          );
        }
        return SingleChildScrollView(
          key: const Key('extraction-preview-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: reviewStatus(),
              ),
              for (var i = 0; i < rows.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: rowAt(i),
                ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No items were detected. Try a closer, well-lit photo.',
                  ),
                ),
              footer,
            ],
          ),
        );
      },
    );
  }

  Widget _thumbnailFallback() => widget.photo == null
      ? const SizedBox(width: 52, height: 52, child: Icon(Icons.image_outlined))
      : Image(
          image: widget.photo!,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox(
            width: 52,
            height: 52,
            child: Icon(Icons.image_outlined),
          ),
        );

  @override
  Widget build(BuildContext context) {
    final photo = !['text', 'spreadsheet'].contains(_draft['source_kind']);
    if (photo && _draft['status'] != 'saved') {
      final review = _photoReview(context);
      return widget.embedded
          ? review
          : ContentCard(
              margin: const EdgeInsets.symmetric(vertical: 12),
              child: review,
            );
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
            child: Text(
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
        Text(
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
          child: Text('No items were detected. Try a closer, well-lit photo.'),
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
                    Text(
                      row['item']['name'] as String,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                      ),
                    ),
                    Text(
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
                        child: const Text('Add quantity'),
                      ),
                    if ((row['item']['scan_evidence']
                            as Map?)?['needs_review'] ==
                        true)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Needs Review',
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
          child: Text(
            _expanded ? 'Show fewer' : 'Show all ${rows.length} items',
          ),
        ),
      if (!saved && _expanded && rows.length > _visibleRows)
        TextButton(
          onPressed: () => setState(() => _visibleRows += 40),
          child: const Text('Show more items'),
        ),
    ];
    final actions = <Widget>[
      if (!saved) ...[
        const SizedBox(height: 12),
        if (_creation != null || _draft['space_id'] != null)
          TextButton.icon(
            onPressed: _editable ? _destination : null,
            icon: const Icon(Icons.folder_outlined, size: 18),
            label: Text(
              _draft['space_id'] == null
                  ? (_creation != null
                        ? 'Choose another Space'
                        : 'Choose a Space')
                  : '${_draft['location']}',
            ),
          ),
        Text(
          _missingRows.isNotEmpty
              ? 'Add the missing quantities, or uncheck those items to save the rest.'
              : _draft['space_id'] == null
              ? _destinationHint
              : 'Ready to save to ${_draft['location']}.',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary(context),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy || widget.disabled || selected == 0 ? null : _save,
          child: Text(
            saving
                ? 'Retry save safely'
                : _missingRows.isNotEmpty
                ? 'Add missing quantity'
                : _draft['space_id'] == null
                ? (_creation != null
                      ? 'Create Space & save items'
                      : 'Choose a Space')
                : 'Save items',
          ),
        ),
      ],
      if (_busy && !_choosing) const LinearProgressIndicator(),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (receipt != null) ...[
        for (final failure in receipt['failures'] as List? ?? [])
          Text(failure['reason'] as String),
        if (destination != null)
          TextButton.icon(
            onPressed: widget.onOpenResource == null
                ? null
                : () => widget.onOpenResource!(destination),
            icon: const Icon(Icons.folder_outlined, size: 18),
            label: Text('Open ${destination.label}'),
          ),
        if (saved && selected > 0)
          TextButton(
            onPressed: _showSavedItems,
            child: Text('View $selected extracted items'),
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

/// Presentation only. The protocol's original `index` is the stable row ID;
/// never replace it with the sorted position or mutate the draft's items.
double? scanConfidence(Map row) {
  final item = row['item'] as Map;
  final raw =
      (item['scan_evidence'] as Map?)?['identity_confidence'] ??
      item['confidence'];
  final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
  return value != null && value.isFinite && value >= 0 && value <= 1
      ? value
      : null;
}

bool scanUnknown(Map row) {
  final name = '${(row['item'] as Map)['name'] ?? ''}'.trim().toLowerCase();
  final confidence = scanConfidence(row);
  return name.isEmpty ||
      RegExp(
        r'^(unknown|unidentified|unrecognized|unrecognised)(\b|_)',
      ).hasMatch(name) ||
      RegExp(r'^(object|item)(?:\s+\d+)?[.!?]?$').hasMatch(name) ||
      (confidence != null && confidence < .5);
}

String scanDisplayName(Map row) {
  final name = '${(row['item'] as Map)['name'] ?? ''}';
  return name.trim().isEmpty ? 'Unknown item' : name;
}

String scanDetail(Map row) {
  final item = row['item'] as Map;
  final values = [
    item['brand'] ?? item['maker'],
    item['model'],
    item['color'] ?? item['colour'],
    item['material'],
    item['size'] ?? item['dimensions'],
    item['condition'],
    item['description'],
    item['notes'],
    item['what_it_is'],
  ];
  return values
      .where((v) => v != null && '$v'.trim().isNotEmpty)
      .map((v) => '$v')
      .join(' · ');
}

List<Map<String, dynamic>> scanDisplayRows(
  List<Map<String, dynamic>> rows, {
  Set<Object?> missing = const {},
}) {
  int group(Map row) {
    final item = row['item'] as Map;
    final evidence = item['scan_evidence'] as Map? ?? {};
    if (missing.contains(row['index']) ||
        item['quantity'] == null ||
        '${item['category'] ?? ''}'.trim().isEmpty ||
        evidence['quantity_basis'] == 'unknown') {
      return 2;
    }
    if (evidence['needs_review'] == true ||
        (evidence['warnings'] as List? ?? []).isNotEmpty ||
        (evidence['review_reasons'] as List? ?? []).isNotEmpty) {
      return 1;
    }
    return 0;
  }

  final indexed = rows.indexed.toList();
  indexed.sort((a, b) {
    final unknown = (scanUnknown(a.$2) ? 1 : 0).compareTo(
      scanUnknown(b.$2) ? 1 : 0,
    );
    if (unknown != 0) return unknown;
    final ac = scanConfidence(a.$2), bc = scanConfidence(b.$2);
    if (ac != null && bc != null) {
      final score = bc.compareTo(ac);
      return score != 0 ? score : a.$1.compareTo(b.$1);
    }
    if (ac != null || bc != null) return ac != null ? -1 : 1;
    if (scanUnknown(a.$2)) return a.$1.compareTo(b.$1);
    final flags = group(a.$2).compareTo(group(b.$2));
    return flags != 0 ? flags : a.$1.compareTo(b.$1);
  });
  return indexed.map((r) => r.$2).toList();
}
