import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';

class WorldActionCard extends StatefulWidget {
  const WorldActionCard({
    super.key,
    required this.api,
    required this.action,
    this.onSaved,
    this.onChanged,
  });
  final ApiClient api;
  final Map<String, dynamic> action;
  final VoidCallback? onSaved;
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
        data: {'decision': decision},
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
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
              const SizedBox(height: 8),
            ],
            if (pending)
              const Text(
                'Matching existing inventories and Spaces will be reused. No existing items will be changed.',
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (pending)
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(
                    onPressed: _busy ? null : () => _decide('confirm'),
                    child: Text(_busy ? 'Saving...' : 'Create'),
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
    );
  }
}
