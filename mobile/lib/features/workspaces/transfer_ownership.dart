import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';

Future<bool> confirmOwnershipTransfer(
  BuildContext context,
  ApiClient source, {
  required String scope,
  required String id,
  required String name,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _TransferOwnerDialog(
        api: ApiClient.forAccount(source, source.accountId ?? ''),
        scope: scope,
        id: id,
        name: name,
      ),
    ) ==
    true;

class _TransferOwnerDialog extends StatefulWidget {
  const _TransferOwnerDialog({
    required this.api,
    required this.scope,
    required this.id,
    required this.name,
  });
  final ApiClient api;
  final String scope, id, name;
  @override
  State<_TransferOwnerDialog> createState() => _TransferOwnerDialogState();
}

class _TransferOwnerDialogState extends State<_TransferOwnerDialog> {
  final _confirmation = TextEditingController();
  List<Map<String, dynamic>> _members = [];
  String? _target;
  Object? _error;
  bool _busy = false, _loading = true;
  String get _base => widget.scope == 'organization'
      ? '/organizations/${widget.id}'
      : '/inventory-workspaces/${widget.id}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _target = null;
      _members = [];
    });
    try {
      final result = await widget.api.collaboration(
        '$_base${widget.scope == 'workspace' ? '/overview' : ''}',
      );
      if (!mounted) return;
      setState(
        () => _members = (result['members'] as List? ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .where((m) => m['user_id'] != widget.api.accountId)
            .toList(),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _transfer() async {
    if (_busy || _target == null || _confirmation.text != widget.name) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.collaboration(
        '$_base/transfer-owner',
        method: 'POST',
        data: {
          'name': _confirmation.text,
          'user_id': _target,
          'confirmed': true,
        },
      );
      if (result['transferred'] != true ||
          result['scope'] != widget.scope ||
          result['resource_id'] != widget.id ||
          result['owner_user_id'] != _target) {
        throw const FormatException(
          'The transfer could not be confirmed. Refresh before retrying.',
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text('Transfer ${widget.scope} ownership'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The selected member becomes Owner and you become Admin. Restricted inventory access stays unchanged.',
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            DropdownButtonFormField<String>(
              initialValue: _target,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'New owner'),
              items: [
                for (final member in _members)
                  DropdownMenuItem(
                    value: member['user_id'].toString(),
                    child: Text(
                      member['display_name']?.toString() ?? 'Member',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _target = value),
            ),
            TextField(
              controller: _confirmation,
              enabled: !_busy,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Type ${widget.name} to confirm',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(describeError(_error!).$1),
              if (!_busy)
                TextButton(
                  onPressed: _load,
                  child: const Text('Reload members'),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _busy ||
                  _loading ||
                  _target == null ||
                  _confirmation.text != widget.name
              ? null
              : _transfer,
          child: Text(_busy ? 'Transferring...' : 'Confirm transfer'),
        ),
      ],
    ),
  );
}
