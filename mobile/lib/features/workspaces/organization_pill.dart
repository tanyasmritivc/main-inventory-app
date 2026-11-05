import 'package:mobile/core/ui/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
    this.glass = false,
  });
  final TextStyle? labelStyle;
  final bool glass;
  final ApiClient api;
  final String? id;
  final String name;
  final Future<void> Function(String?) onSelected;
  @override
  State<OrganizationPill> createState() => _OrganizationPillState();
}

class _OrganizationPillState extends State<OrganizationPill> {
  bool _busy = false;
  Future<void> _open() async {
    if (_busy) return;
    final account = widget.api.accountId;
    setState(() {
      _busy = true;
    });
    try {
      final organizations = widget.api.collaboration('/organizations');
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
        constraints: BoxConstraints(
          minWidth: 220,
          maxWidth: (overlay.size.width - 32).clamp(220, 300),
        ),
        popUpAnimationStyle: AnimationStyle.noAnimation,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF262626)
            : const Color(0xFFF2F2F4),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        items: [
          PopupMenuItem<String>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: _OrganizationChoices(
              organizations: organizations,
              reload: () => widget.api.collaboration('/organizations'),
              selected: widget.id,
            ),
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
        ).showSnackBar(SnackBar(content: AppText(describeError(e).$1)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

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
              title: const AppText('New organization'),
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
                    if (error != null) AppText(describeError(error!).$1),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const AppText('Cancel'),
                ),
                TextButton(
                  onPressed: saving || text.text.trim().isEmpty ? null : save,
                  child: AppText(saving ? 'Creating...' : 'Create'),
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
  Widget build(BuildContext context) {
    return _button(context);
  }

  Widget _button(BuildContext context) => Semantics(
    container: true,
    label: 'Switch organization. Current: ${widget.name}',
    button: true,
    enabled: !_busy,
    onTap: _busy ? null : _open,
    child: ExcludeSemantics(
      child: OutlinedButton(
        onPressed: _busy ? null : _open,
        style:
            OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size(0, widget.glass ? 44 : 40),
              side: BorderSide.none,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF242424)
                  : const Color(0xFFE7E7E9),
              shape: const StadiumBorder(),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ).copyWith(
              backgroundBuilder: (context, states, child) =>
                  child ?? const SizedBox.shrink(),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.glass) ...[
              CircleAvatar(
                radius: 13,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .18),
                child: AppText(
                  widget.name.isEmpty
                      ? '?'
                      : widget.name.characters.first.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: AppText(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    widget.labelStyle ??
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    ),
  );
}

class _OrganizationChoices extends StatefulWidget {
  const _OrganizationChoices({
    required this.organizations,
    required this.reload,
    required this.selected,
  });
  final Future<Map<String, dynamic>> organizations;
  final Future<Map<String, dynamic>> Function() reload;
  final String? selected;
  @override
  State<_OrganizationChoices> createState() => _OrganizationChoicesState();
}

class _OrganizationChoicesState extends State<_OrganizationChoices> {
  late Future<Map<String, dynamic>> _request = widget.organizations;
  Widget _choice(
    String label,
    String value, {
    bool selected = false,
    IconData? icon,
  }) => ListTile(
    dense: true,
    minVerticalPadding: 4,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    leading: icon == null
        ? null
        : Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    title: AppText(
      label,
      style: AppTypography.bodyStyleOf(
        context,
      ).copyWith(color: Theme.of(context).colorScheme.onSurface),
    ),
    trailing: selected
        ? Icon(
            CupertinoIcons.check_mark,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface,
          )
        : null,
    onTap: () => Navigator.of(context).pop(value),
  );
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .65,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _request,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ListTile(
                  title: AppText(describeError(snapshot.error!).$1),
                  trailing: TextButton(
                    onPressed: () => setState(() => _request = widget.reload()),
                    child: const AppText('Retry'),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const ListTile(
                  title: AppText('Loading organizations...'),
                );
              }
              final rows = placeRows(snapshot.data!['organizations'])
                ..sort(
                  (a, b) => a['name'].toString().toLowerCase().compareTo(
                    b['name'].toString().toLowerCase(),
                  ),
                );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final row in rows)
                    _choice(
                      row['name'].toString(),
                      'org:${row['organization_id']}',
                      selected: row['organization_id'] == widget.selected,
                    ),
                ],
              );
            },
          ),
          _choice('Personal', 'personal', selected: widget.selected == null),
          const Divider(height: 1),
          _choice('New organization', 'new', icon: CupertinoIcons.plus),
          _choice('Review invitation', 'invite', icon: CupertinoIcons.envelope),
        ],
      ),
    ),
  );
}
