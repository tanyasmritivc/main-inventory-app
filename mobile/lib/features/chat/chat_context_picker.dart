import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/chat_source.dart';

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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(switch (widget.kind) {
        'space' => 'Spaces',
        'item' => 'Items',
        'project' => 'Projects',
        _ => 'Documents and notes',
      }),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, selected),
          child: Text('Done (${selected.length})'),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              children: [
                const Text(
                  'Use selected content in this chat. Your save destination stays separate.',
                ),
                const SizedBox(height: 12),
                if (inventories.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: inventory,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Inventory'),
                    items: [
                      for (final row in inventories)
                        DropdownMenuItem(
                          value: row['inventory_id'] as String,
                          child: Text(
                            '${row['name']} - ${row['workspace_name'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      debounce?.cancel();
                      inventory = value;
                      unawaited(_load());
                    },
                  ),
                const SizedBox(height: 12),
                TextField(
                  maxLength: 100,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(CupertinoIcons.search),
                    hintText: 'Search context',
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
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (error != null)
                  ListTile(
                    title: Text(error!),
                    trailing: TextButton(
                      onPressed: () =>
                          inventories.isEmpty ? _directory() : _load(),
                      child: const Text('Retry'),
                    ),
                  ),
                if (!busy && error == null && rows.isEmpty)
                  const ListTile(title: Text('No matching context.')),
                for (final row in rows)
                  CheckboxListTile(
                    value: selected.any((s) => s.key == row.key),
                    title: Text(row.name),
                    subtitle: Text(row.inventoryName ?? ''),
                    onChanged: (checked) {
                      if (checked == true && selected.length >= 8) {
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
                        if (checked == true) selected.add(row);
                      });
                    },
                  ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (!busy && next != null)
                  TextButton(
                    onPressed: () => _load(more: true),
                    child: const Text('Load more'),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
