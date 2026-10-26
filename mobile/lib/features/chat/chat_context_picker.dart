import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/chat_source.dart';
import '../../core/ui/app_text.dart';
import '../../core/ui/utility_page.dart';

class ChatContextPicker extends StatefulWidget {
  const ChatContextPicker({
    super.key,
    required this.api,
    required this.kind,
    required this.selected,
  });
  final ApiClient api;
  final String kind;
  final List<ChatSource> selected;
  @override
  State<ChatContextPicker> createState() => _ChatContextPickerState();
}

class _ChatContextPickerState extends State<ChatContextPicker> {
  late final List<ChatSource> selected = List.of(widget.selected);
  List<Map<String, dynamic>> inventories = [];
  List<ChatSource> rows = [];
  String? inventory, error;
  String query = '';
  int generation = 0;
  int? next;
  bool busy = true;
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    unawaited(_directory());
  }

  Future<void> _directory() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await widget.api.collaboration(
        '/worlds/${Uri.encodeComponent(widget.api.worldKey!)}/directory',
      );
      widget.api.assertCurrentContext();
      if (!mounted) return;
      inventories = (data['inventories'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      inventory = inventories.firstOrNull?['inventory_id'] as String?;
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Could not load your inventories. Try again.';
        });
      }
    }
  }

  Future<void> _load({bool more = false}) async {
    final id = ++generation;
    if (inventory == null) {
      setState(() => busy = false);
      return;
    }
    setState(() {
      busy = true;
      error = null;
      if (!more) {
        rows = [];
        next = null;
      }
    });
    try {
      final data = await widget.api.chatSourceChoices(
        inventoryId: inventory!,
        kind: widget.kind,
        query: query,
        offset: more ? next ?? 0 : 0,
      );
      if (!mounted || id != generation) return;
      setState(() {
        rows = [
          ...rows,
          ...(data['sources'] as List? ?? []).map(
            (e) => ChatSource.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        ];
        next = data['next_offset'] as int?;
        busy = false;
      });
    } catch (_) {
      if (mounted && id == generation) {
        setState(() {
          busy = false;
          error = 'Could not load context. Check access and try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    generation++;
    debounce?.cancel();
    super.dispose();
  }

  String get title => switch (widget.kind) {
    'space' => 'Spaces',
    'item' => 'Items',
    'project' => 'Projects',
    _ => 'Documents and notes',
  };
  IconData get icon => switch (widget.kind) {
    'space' => CupertinoIcons.square_grid_2x2,
    'item' => CupertinoIcons.cube_box,
    'project' => CupertinoIcons.folder,
    _ => CupertinoIcons.doc_text,
  };

  void _toggle(ChatSource row) {
    final checked = selected.any((s) => s.key == row.key);
    if (!checked && selected.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use up to 8 sources. Remove one before adding another.',
          ),
        ),
      );
      return;
    }
    setState(() {
      selected.removeWhere((s) => s.key == row.key);
      if (!checked) selected.add(row);
    });
  }

  @override
  Widget build(BuildContext context) => UtilityPage(
    title: title,
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, selected),
        child: AppText(
          MediaQuery.textScalerOf(context).scale(14) > 24
              ? 'Done'
              : 'Done (${selected.length})',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
    ],
    body: CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const UtilityHint(
                  'Choose context for this chat. This does not change where items are saved.',
                ),
                if (inventories.isNotEmpty) ...[
                  const UtilitySection('Inventory'),
                  DropdownButtonFormField<String>(
                    initialValue: inventory,
                    isExpanded: true,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: const InputDecoration(),
                    items: [
                      for (final row in inventories)
                        DropdownMenuItem(
                          value: row['inventory_id'] as String,
                          child: AppText(
                            '${row['name']} - ${row['workspace_name'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      debounce?.cancel();
                      inventory = value;
                      unawaited(_load());
                    },
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  maxLength: 100,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(CupertinoIcons.search, size: 18),
                    hintText: 'Search ${title.toLowerCase()}',
                    counterText: '',
                  ),
                  onChanged: (value) {
                    query = value;
                    generation++;
                    debounce?.cancel();
                    debounce = Timer(
                      const Duration(milliseconds: 250),
                      () => unawaited(_load()),
                    );
                  },
                ),
                if (rows.isNotEmpty)
                  UtilitySection('${selected.length} of 8 sources selected'),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  AppText(
                    error!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () =>
                        inventories.isEmpty ? _directory() : _load(),
                    child: const AppText('Retry'),
                  ),
                ],
                if (!busy && error == null && rows.isEmpty)
                  UtilityEmpty(
                    icon: icon,
                    title: query.isEmpty
                        ? 'No ${title.toLowerCase()} yet'
                        : 'No matches',
                    message: query.isEmpty
                        ? 'Choose another inventory to find saved context.'
                        : 'Try a different keyword or inventory.',
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final checked = selected.any((s) => s.key == row.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: UtilityCard(
                  child: CheckboxListTile(
                    value: checked,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    title: AppText(
                      row.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    subtitle: row.inventoryName?.isNotEmpty == true
                        ? UtilityHint(row.inventoryName!)
                        : null,
                    onChanged: (_) => _toggle(row),
                  ),
                ),
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (busy)
                  const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (!busy && next != null)
                  TextButton(
                    onPressed: () => _load(more: true),
                    child: const AppText('Load more'),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
