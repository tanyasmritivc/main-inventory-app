import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/inventory_context.dart';

class ScanDestination {
  const ScanDestination(this.api, this.id, this.name);
  final ApiClient api;
  final String id, name;
}

class ScanDestinationPage extends StatefulWidget {
  const ScanDestinationPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<ScanDestinationPage> createState() => _ScanDestinationPageState();
}

class _ScanDestinationPageState extends State<ScanDestinationPage> {
  List<Map<String, dynamic>> _groups = [];
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.api.inventoryContext != null) {
        final inventory = widget.api.inventoryContext!;
        _groups = [
          if (inventory.canEdit)
            {
              'inventory_id': inventory.inventoryId,
              'name': inventory.name,
              'workspace_name': inventory.workspaceName,
              'spaces': await widget.api.listSpaces(),
            },
        ];
      } else {
        final response = await widget.api.collaboration(
          '/worlds/${widget.api.worldKey ?? 'personal'}/spaces',
        );
        _groups = (response['inventories'] as List? ?? [])
            .whereType<Map>()
            .where((row) => row['can_edit'] == true)
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
      widget.api.assertCurrentContext();
    } catch (e) {
      _error = describeError(e).$1;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<ApiClient> _scoped(String id) async {
    if (widget.api.inventoryContext?.inventoryId == id) return widget.api;
    final response = await widget.api.collaboration('/inventories/$id');
    widget.api.assertCurrentContext();
    final inventory = InventoryContext.fromJson(
      Map<String, dynamic>.from(response['inventory']),
      accountId: widget.api.accountId!,
      expectedInventory: id,
    );
    // Authorization is checked again on every request; this callback is bound
    // to the originating world, not to the short-lived destination picker.
    return ApiClient.forInventory(
      widget.api,
      inventory,
      isCurrent: () {
        widget.api.assertCurrentContext();
        return true;
      },
    );
  }

  Future<void> _pick(Map<String, dynamic> group, Map space) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final api = await _scoped(group['inventory_id']);
      final id = (space['space_id'] ?? space['id'] ?? '').toString();
      if (id.isEmpty) {
        throw const FormatException('Refresh and choose this Space again.');
      }
      if (mounted) {
        Navigator.pop(
          context,
          ScanDestination(api, id, space['name'].toString()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = describeError(e).$1;
          _busy = false;
        });
      }
    }
  }

  Future<void> _create(Map<String, dynamic>? group) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _SpaceNameDialog(),
    );
    if (name == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var selected = group;
      if (selected == null) {
        // Unique inventory names and a fresh authorized read reconcile a lost
        // creation response. Never replay an unconfirmed POST blindly.
        final list = await widget.api.collaboration(
          '/inventory-workspaces/personal/inventories',
        );
        final existing = (list['inventories'] as List? ?? [])
            .whereType<Map>()
            .where((row) => row['name'] == name && row['can_edit'] == true);
        if (existing.isNotEmpty) {
          selected = Map<String, dynamic>.from(existing.first);
        } else {
          final result = await widget.api.collaboration(
            '/inventory-workspaces/personal/inventories',
            method: 'POST',
            data: {'name': name},
          );
          selected = Map<String, dynamic>.from(result['inventory']);
        }
      }
      final api = await _scoped(selected['inventory_id']);
      final spaces = await api.listSpaces();
      final same = spaces.where((row) => row['name'] == name);
      final space = same.isNotEmpty
          ? same.first
          : await api.createSpace(name: name);
      api.assertCurrentContext();
      final id = (space['space_id'] ?? space['id'] ?? '').toString();
      if (id.isEmpty) {
        throw const FormatException('Space not confirmed. Try again.');
      }
      if (mounted) Navigator.pop(context, ScanDestination(api, id, name));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = describeError(e).$1;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Save to a Space')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) ...[
          Text(_error!),
          TextButton(
            onPressed: _busy ? null : _load,
            child: const Text('Retry'),
          ),
        ],
        if (!_busy &&
            _groups.isEmpty &&
            (widget.api.worldKey == null ||
                widget.api.worldKey == 'personal')) ...[
          const Text(
            'What are you organizing?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => _create(null),
            child: const Text('Name your first Space'),
          ),
        ],
        if (!_busy &&
            _groups.isEmpty &&
            widget.api.worldKey != null &&
            widget.api.worldKey != 'personal')
          const Text(
            'Ask an organization owner to create an inventory or give you edit access.',
          ),
        for (final group in _groups) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              '${group['workspace_name'] ?? ''} · ${group['name']}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          for (final space in (group['spaces'] as List? ?? []).whereType<Map>())
            ListTile(
              title: Text(space['name'].toString()),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : () => _pick(group, space),
            ),
          TextButton(
            onPressed: _busy ? null : () => _create(group),
            child: const Text('New Space'),
          ),
        ],
      ],
    ),
  );
}

class _SpaceNameDialog extends StatefulWidget {
  const _SpaceNameDialog();
  @override
  State<_SpaceNameDialog> createState() => _SpaceNameDialogState();
}

class _SpaceNameDialogState extends State<_SpaceNameDialog> {
  final _name = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Name your Space'),
    content: TextField(
      controller: _name,
      autofocus: true,
      maxLength: 60,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(hintText: 'Robotics bench'),
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _name.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _name.text.trim()),
        child: const Text('Continue'),
      ),
    ],
  );
}
