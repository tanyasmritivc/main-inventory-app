import 'package:flutter/material.dart';
import '../../core/ui/liquid_surface.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/ask_answer.dart';

class WorldActionCard extends StatefulWidget {
  const WorldActionCard({
    super.key,
    required this.api,
    required this.action,
    this.onSaved,
    this.onChanged,
    this.onOpenResource,
  });
  final ApiClient api;
  final Map<String, dynamic> action;
  final VoidCallback? onSaved;
  final ValueChanged<AskResourceLink>? onOpenResource;
  final ValueChanged<Map<String, dynamic>>? onChanged;
  @override
  State<WorldActionCard> createState() => _WorldActionCardState();
}

class _WorldActionCardState extends State<WorldActionCard> {
  late Map<String, dynamic> _action = widget.action;
  bool _busy = false;
  String? _error;
  Future<void> _decide(String decision) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.collaboration(
        '/worlds/${widget.api.worldKey}/structure-actions/${_action['id']}',
        method: 'POST',
        data: {'decision': decision, 'supports_task_actions': true},
      );
      final action = Map<String, dynamic>.from(result['action'] as Map);
      if (action['id'] != _action['id'] ||
          !['confirmed', 'cancelled'].contains(action['status'])) {
        throw const FormatException(
          'The result could not be confirmed. Retry this card.',
        );
      }
      if (!mounted) return;
      setState(() => _action = action);
      widget.onChanged?.call(action);
      if (action['status'] == 'confirmed') widget.onSaved?.call();
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error).$1);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _action['plan'] is Map ? _action['plan'] as Map : const {};
    final inventories = plan['inventories'] is List
        ? (plan['inventories'] as List).whereType<Map>()
        : const <Map>[];
    final pending = _action['status'] == 'pending';
    final receipt = _action['receipt'] is Map
        ? _action['receipt'] as Map
        : const {};
    final links = AskAnswerContext.fromJson({
      'resource_links': [
        ...((receipt['resource_links'] as List?) ?? []),
        for (final inventory
            in ((receipt['inventories'] as List?) ?? []).whereType<Map>())
          {
            'kind': 'inventory',
            'id': inventory['inventory_id'],
            'inventory_id': inventory['inventory_id'],
            'label': inventory['name'],
            'href':
                'findez://inventory/${inventory['inventory_id']}/${inventory['inventory_id']}',
          },
      ],
    }).resourceLinks;
    final hasItems = inventories.any(
      (i) =>
          (i['items'] is List && (i['items'] as List).isNotEmpty) ||
          (i['moves'] is List && (i['moves'] as List).isNotEmpty),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LiquidSurface(
        radius: 24,
        shadow: false,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pending
                    ? 'Review your inventory world'
                    : _action['status'] == 'confirmed'
                    ? 'Saved to your world'
                    : 'Cancelled',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (_action['workspace_label'] != null)
                Text('Workspace: ${_action['workspace_label']}'),
              for (final inventory in inventories) ...[
                Text(
                  inventory['name'].toString(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final space
                    in (inventory['spaces'] is List
                        ? inventory['spaces'] as List
                        : const []))
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Text(space.toString()),
                  ),
                for (final item
                    in (inventory['items'] is List
                            ? inventory['items'] as List
                            : const [])
                        .whereType<Map>())
                  Text(
                    'Add ${item['quantity']} ${item['name']} to ${item['location']}',
                  ),
                for (final item
                    in (inventory['moves'] is List
                            ? inventory['moves'] as List
                            : const [])
                        .whereType<Map>())
                  Text('Move ${item['name']} to ${item['target_location']}'),
                const SizedBox(height: 8),
              ],
              if (pending)
                Text(
                  hasItems
                      ? 'Confirm once to create the destination and complete the item changes shown above.'
                      : 'Matching existing inventories and Spaces will be reused.',
                ),
              if (!pending && _action['status'] == 'confirmed')
                for (final link in links)
                  TextButton.icon(
                    onPressed: widget.onOpenResource == null
                        ? null
                        : () => widget.onOpenResource!(link),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text('Open ${link.label}'),
                  ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (pending)
                Wrap(
                  spacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : () => _decide('confirm'),
                      child: Text(
                        _busy
                            ? 'Saving...'
                            : hasItems
                            ? 'Create and complete'
                            : 'Create',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _decide('cancel'),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
