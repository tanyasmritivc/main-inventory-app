import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/inventory_cache.dart';

Future<bool> confirmResourceRemoval(
  BuildContext context,
  ApiClient api, {
  required String kind,
  required String id,
  required String name,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RemovalDialog(api: api, kind: kind, id: id, name: name),
    ) ??
    false;

class _RemovalDialog extends StatefulWidget {
  const _RemovalDialog({
    required this.api,
    required this.kind,
    required this.id,
    required this.name,
  });
  final ApiClient api;
  final String kind, id, name;
  @override
  State<_RemovalDialog> createState() => _RemovalState();
}

class _RemovalState extends State<_RemovalDialog> {
  Map<String, dynamic>? preview;
  String? error, action;
  String entered = '', destination = '';
  bool busy = false;
  late final String? account = widget.api.accountId;
  String get path =>
      '/resource-removal/${widget.kind}/${Uri.encodeComponent(widget.id)}';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final value = await widget.api.collaboration(path);
      if (!mounted) return;
      if (widget.api.accountId != account ||
          value['id'] != widget.id ||
          value['kind'] != widget.kind ||
          value['name'] != widget.name ||
          value['destinations'] is! List) {
        throw const FormatException(
          'The resource changed. Reopen the confirmation.',
        );
      }
      setState(() => preview = value);
    } catch (reason) {
      if (mounted) setState(() => error = describeError(reason).$1);
    }
  }

  Future<void> save() async {
    if (busy || preview == null || action == null || entered != widget.name) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.api.accountId != account) {
        throw const FormatException('Your account changed. Reopen this page.');
      }
      final result = await widget.api.collaboration(
        path,
        method: 'POST',
        data: {
          'name': widget.name,
          'action': action,
          if (action == 'move' &&
              (widget.kind == 'space' || widget.kind == 'inventory') &&
              destination != 'personal')
            'destination_id': destination,
        },
      );
      if (!mounted) return;
      if (widget.api.accountId != account ||
          result['id'] != widget.id ||
          result['kind'] != widget.kind ||
          result['action'] != action ||
          result['deleted'] != true && result['moved'] != true) {
        throw const FormatException(
          'The change could not be confirmed. Refresh before retrying.',
        );
      }
      InventoryCache.clear();
      Navigator.pop(context, true);
    } catch (reason) {
      if (mounted) {
        setState(() {
          busy = false;
          error = describeError(reason).$1;
        });
      }
    }
  }

  String get moveLabel => switch (widget.kind) {
    'organization' => 'Keep workspaces outside this organization',
    'workspace' => 'Move inventories to their owners’ Personal area',
    'inventory' => 'Move this inventory somewhere else',
    _ => 'Move items to another Space',
  };
  String get moveExplanation => switch (widget.kind) {
    'organization' =>
      'Workspaces and their contents stay together. Existing workspace members keep their access. The organization and its memberships are removed.',
    'workspace' =>
      'Inventories, Spaces, items and photos stay with their existing owners. Workspace tasks, files and memberships are removed; inventory sharing is revoked.',
    'inventory' =>
      'Spaces, items and photos stay together with the existing owner. Previous sharing is revoked. Members of the destination workspace receive access through its permissions.',
    _ =>
      'Items, bins, photos and pending identifications move to the chosen Space. The original Space and its sharing links are removed.',
  };
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      scrollable: true,
      title: Text('Delete ${widget.kind}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose what happens to “${widget.name}” and its contents before continuing.',
          ),
          if (preview == null && error == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Checking contents…'),
            ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (preview == null && error != null)
            TextButton(onPressed: load, child: const Text('Retry')),
          if (preview != null) ...[
            const SizedBox(height: 12),
            Text(
              '${preview!['workspaces']} workspaces · ${preview!['inventories']} inventories · ${preview!['spaces']} Spaces · ${preview!['items']} items',
            ),
            const SizedBox(height: 12),
            const Text('What would you like to do?'),
            if (preview!['can_move'] == true)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(moveLabel),
                value: action == 'move',
                onChanged: busy ? null : (_) => setState(() => action = 'move'),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Delete ${widget.kind} and all its contents'),
              value: action == 'delete',
              onChanged: busy ? null : (_) => setState(() => action = 'delete'),
            ),
            if (action == 'move') Text(moveExplanation),
            if (action == 'move' &&
                (widget.kind == 'space' || widget.kind == 'inventory'))
              DropdownButtonFormField<String>(
                initialValue: destination.isEmpty ? null : destination,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Destination'),
                items: [
                  for (final value in preview!['destinations'] as List)
                    DropdownMenuItem(
                      value: value['id'].toString(),
                      child: Text(
                        value['name'].toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (value) => setState(() => destination = value ?? ''),
              ),
            if (action == 'delete')
              Text(
                'All contents inside this ${widget.kind} will be permanently removed. This cannot be undone. Other resources are preserved.',
              ),
            const SizedBox(height: 16),
            TextFormField(
              enabled: !busy,
              decoration: InputDecoration(
                labelText: 'Type ${widget.name} to confirm',
              ),
              onChanged: (value) => setState(() => entered = value),
            ),
          ],
          const SizedBox(height: 24),
          // Keep actions in the same scrollable area as the choices. Pinned
          // AlertDialog actions can consume the entire viewport with iOS safe
          // areas, large text and the keyboard visible.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed:
                    busy ||
                        preview == null ||
                        action == null ||
                        entered != widget.name ||
                        action == 'move' &&
                            (widget.kind == 'space' ||
                                widget.kind == 'inventory') &&
                            destination.isEmpty
                    ? null
                    : save,
                child: Text(
                  busy
                      ? 'Saving…'
                      : action == 'move'
                      ? 'Move and continue'
                      : 'Delete ${widget.kind}',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
