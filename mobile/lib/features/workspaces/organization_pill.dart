import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/place_session.dart';
import '../sharing/review_invitation_page.dart';
import '../sharing/invitation_navigation.dart';

/// The only cross-organization navigation control. Children never populate it.
class OrganizationPill extends StatefulWidget {
  const OrganizationPill({
    super.key,
    required this.api,
    required this.id,
    required this.name,
    required this.onSelected,
    this.labelStyle,
  });
  final TextStyle? labelStyle;
  final ApiClient api;
  final String? id;
  final String name;
  final Future<void> Function(String?) onSelected;
  @override
  State<OrganizationPill> createState() => _OrganizationPillState();
}

class _OrganizationPillState extends State<OrganizationPill> {
  bool _busy = false, _loading = false;
  Future<void> _open() async {
    if (_busy) return;
    final account = widget.api.accountId;
    setState(() {
      _busy = true;
      _loading = true;
    });
    try {
      final result = await widget.api.collaboration('/organizations');
      if (!mounted || widget.api.accountId != account) return;
      final organizations = placeRows(result['organizations'])
        ..sort(
          (a, b) => a['name'].toString().toLowerCase().compareTo(
            b['name'].toString().toLowerCase(),
          ),
        );
      setState(() => _loading = false);
      final box = context.findRenderObject()! as RenderBox;
      final overlay =
          Navigator.of(context).overlay!.context.findRenderObject()!
              as RenderBox;
      final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
      final value = await showMenu<String>(
        context: context,
        position: RelativeRect.fromRect(
          Rect.fromLTWH(
            origin.dx,
            origin.dy + box.size.height,
            box.size.width,
            0,
          ),
          Offset.zero & overlay.size,
        ),
        constraints: BoxConstraints(maxWidth: overlay.size.width - 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        items: [
          for (final org in organizations)
            PopupMenuItem(
              value: 'org:${org['organization_id']}',
              child: _row(
                org['name'].toString(),
                org['organization_id'] == widget.id,
              ),
            ),
          if (organizations.isNotEmpty) const PopupMenuDivider(),
          PopupMenuItem(
            value: 'personal',
            child: _row('Personal', widget.id == null),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'new', child: Text('New organization')),
          const PopupMenuItem(
            value: 'invite',
            child: Text('Review invitation'),
          ),
        ],
      );
      if (!mounted || value == null || widget.api.accountId != account) return;
      if (value == 'invite') {
        final result = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (_) => ReviewInvitationPage(api: widget.api),
          ),
        );
        if (mounted && widget.api.accountId == account) {
          openInvitationResult(context, widget.api, result);
        }
      } else if (value == 'new') {
        final id = await _create();
        if (mounted && id != null && widget.api.accountId == account) {
          await widget.onSelected(id);
        }
      } else {
        await widget.onSelected(
          value == 'personal' ? null : value.substring(4),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(e).$1)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loading = false;
        });
      }
    }
  }

  Widget _row(String name, bool selected) => Row(
    children: [
      Expanded(
        child: Text(
          name,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
      if (selected)
        const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Icon(Icons.check, size: 18),
        ),
    ],
  );

  Future<String?> _create() async {
    final text = TextEditingController();
    bool saving = false;
    Object? error;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          Future<void> save() async {
            if (saving || text.text.trim().isEmpty) return;
            update(() {
              saving = true;
              error = null;
            });
            try {
              final response = await widget.api.collaboration(
                '/organizations',
                method: 'POST',
                data: {'name': text.text.trim()},
              );
              final id = response['organization']?['organization_id'];
              if (id is! String || id.isEmpty) {
                throw const FormatException(
                  'Organization creation could not be confirmed.',
                );
              }
              if (context.mounted) Navigator.pop(context, id);
            } catch (e) {
              if (context.mounted) {
                update(() {
                  error = e;
                  saving = false;
                });
              }
            }
          }

          return PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: const Text('New organization'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: text,
                      enabled: !saving,
                      autofocus: true,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Organization name',
                        hintText: 'e.g. FindEZ AI',
                      ),
                      onChanged: (_) => update(() {}),
                      onSubmitted: (_) => save(),
                    ),
                    if (error != null) Text(describeError(error!).$1),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: saving || text.text.trim().isEmpty ? null : save,
                  child: Text(saving ? 'Creating...' : 'Create'),
                ),
              ],
            ),
          );
        },
      ),
    );
    // Controllers outlive the dialog's closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    text.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Switch organization. Current: ${widget.name}',
    button: true,
    enabled: !_loading,
    onTap: _loading ? null : _open,
    child: ExcludeSemantics(
      child: OutlinedButton(
        onPressed: _loading ? null : _open,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 40),
          shape: const StadiumBorder(),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    widget.labelStyle ??
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 6),
            if (_loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            else
              const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    ),
  );
}
