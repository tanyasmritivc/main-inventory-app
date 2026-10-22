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
  });
  final ApiClient api;
  final String conversationId;
  final Map<String, dynamic> draft;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback? onSaved;
  final ValueChanged<AskResourceLink>? onOpenResource;
  final bool disabled;
  @override
  State<ChatCaptureCard> createState() => ChatCaptureCardState();
}

class ChatCaptureCardState extends State<ChatCaptureCard> {
  late Map<String, dynamic> _draft;
  bool _busy = false, _expanded = false, _choosing = false;
  String? _error;
  int _visibleRows = 40;
  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Need a new inventory or Space? Ask in chat; your extraction stays here.',
              ),
              for (final group in groups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 4),
                  child: Text(
                    '${group['workspace_name']} · ${group['name']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
        key: TextEditingController(text: '${item[key] ?? ''}'),
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
                    'Edit extracted item',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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

  Future<void> selectAndSave(AskResourceLink link) => _run(() async {
    if (link.kind != 'space' || _draft['status'] != 'draft') return;
    _accept(
      await widget.api.collaboration(
        _path,
        method: 'PATCH',
        data: {
          'revision': _draft['revision'],
          'changes': {'inventory_id': link.inventoryId, 'space_id': link.id},
        },
      ),
    );
    if (mounted) await _saveItems();
  });

  Future<void> _save() => _run(_saveItems);
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
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final selected = rows.where((r) => r['selected'] == true).length;
    final receipt = _draft['receipt'] as Map?;
    final saved = _draft['status'] == 'saved';
    final saving = _draft['status'] == 'saving';
    final links = (receipt?['resource_links'] as List? ?? [])
        .map(AskResourceLink.parse)
        .whereType<AskResourceLink>();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  saved ? 'Extraction saved' : 'Auto Extract',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
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
          Text(
            saved
                ? '${receipt?['saved_count'] ?? 0} saved · ${receipt?['review_count'] ?? 0} in Review'
                : '$selected of ${rows.length} selected · Not saved yet',
            style: TextStyle(
              color: AppTheme.textSecondary(context),
              fontSize: 13,
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No items were detected. Try a closer, well-lit photo.',
              ),
            ),
          for (final row
              in (_expanded ? rows.take(_visibleRows) : rows.take(4))) ...[
            const SizedBox(height: 8),
            Row(
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
                        style: const TextStyle(fontSize: 15),
                      ),
                      Text(
                        '${row['item']['category']} · Qty ${row['item']['quantity']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                      if ((row['item']['scan_evidence']
                              as Map?)?['needs_review'] ==
                          true)
                        const Text(
                          'Needs Review',
                          style: TextStyle(fontSize: 12),
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
          ],
          if (rows.length > 4)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? 'Show fewer' : 'Show all ${rows.length} items',
              ),
            ),
          if (_expanded && rows.length > _visibleRows)
            TextButton(
              onPressed: () => setState(() => _visibleRows += 40),
              child: const Text('Show more items'),
            ),
          if (!saved) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _editable ? _destination : null,
              icon: const Icon(Icons.folder_outlined, size: 18),
              label: Text(
                _draft['space_id'] == null
                    ? 'Choose inventory and Space'
                    : '${_draft['destination_label']} / ${_draft['location']}',
              ),
            ),
            Text(
              'Ask chat to refine these items or create a destination. Uncertain items go to Review.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed:
                  _busy ||
                      widget.disabled ||
                      selected == 0 ||
                      _draft['space_id'] == null
                  ? null
                  : _save,
              child: Text(saving ? 'Retry save safely' : 'Save items'),
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
            for (final link in links)
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
  }
}
