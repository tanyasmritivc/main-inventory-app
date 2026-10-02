import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/invitation.dart';
import '../../core/ui/app_colors.dart';
import 'invitation_dialog.dart';
import 'shared_inventory_page.dart';

/// Shared/joined spaces forward the owner's link, not a new share of the
/// recipient's own inventory with the same name.
class ShareSpaceSheet extends StatefulWidget {
  const ShareSpaceSheet({
    super.key,
    required this.spaceName,
    required this.api,
    this.shareId,
    this.teamId,
  });
  final String spaceName;
  final ApiClient api;
  final String? shareId;
  final String? teamId;
  @override
  State<ShareSpaceSheet> createState() => _ShareSpaceSheetState();
}

class _ShareSpaceSheetState extends State<ShareSpaceSheet> {
  final _code = TextEditingController();
  final _owner = Supabase.instance.client.auth.currentUser?.id;
  List<Map<String, dynamic>> _owned = [], _joined = [];
  Map<String, dynamic>? _invite;
  String _permission = 'view';
  String? _error;
  bool _busy = false, _loading = true;
  bool get _personal => widget.shareId == null && widget.teamId == null;
  bool get _sameAccount =>
      _owner != null && Supabase.instance.client.auth.currentUser?.id == _owner;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (!_personal) {
        final raw = widget.teamId != null
            ? await widget.api.getTeamInvite(widget.teamId!)
            : await widget.api.getSpaceInvite(widget.shareId!);
        final invite = widget.teamId != null
            ? {
                ...raw,
                'share_code': raw['join_code'],
                'share_name': raw['team_name'],
                'permission': 'member',
              }
            : raw;
        if (mounted && _sameAccount) setState(() => _invite = invite);
      } else {
        final results = await Future.wait([
          widget.api.getMyShares(),
          widget.api.getJoinedShares(),
        ]);
        if (!mounted || !_sameAccount) return;
        setState(() {
          _owned = results[0]
              .map((s) => Map<String, dynamic>.from(s as Map))
              .where((s) => s['share_name'] == widget.spaceName)
              .toList();
          _joined = results[1]
              .map((s) => Map<String, dynamic>.from(s as Map))
              .toList();
        });
      }
      if (mounted && _sameAccount) setState(() => _error = null);
    } catch (error) {
      if (mounted && _sameAccount) {
        setState(() => _error = friendlyApiError(error));
      }
    } finally {
      if (mounted && _sameAccount) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy || !_sameAccount) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } catch (error) {
      if (mounted && _sameAccount) {
        setState(() => _error = friendlyApiError(error));
      }
    } finally {
      if (mounted && _sameAccount) setState(() => _busy = false);
    }
  }

  Future<void> _generate() => _run(() async {
    final created = await widget.api.createShare(
      shareName: widget.spaceName,
      permission: _permission,
    );
    if (!mounted || !_sameAccount) return;
    final id = created['share_id']?.toString() ?? '';
    if (id.isEmpty) throw StateError('Invitation unavailable');
    final invite = await widget.api.getSpaceInvite(id);
    if (!mounted || !_sameAccount) return;
    setState(() => _invite = invite);
    await _load();
  });
  String _url(Map<String, dynamic> invite) {
    final parsed = Invitation.fromUri(
      Uri(
        scheme: 'findez',
        host: widget.teamId == null ? 'space-invite' : 'team-invite',
        queryParameters: {'code': invite['share_code']?.toString() ?? ''},
      ),
    );
    if (parsed == null) throw StateError('Invitation unavailable');
    return parsed.url;
  }

  Future<void> _copy(Map<String, dynamic> invite) => _run(() async {
    await Clipboard.setData(ClipboardData(text: _url(invite)));
    if (mounted && _sameAccount) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation link copied')));
    }
  });
  Future<void> _share(Map<String, dynamic> invite, BuildContext source) =>
      _run(() async {
        final box = source.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            subject: 'Join ${widget.spaceName} on FindEZ',
            text: 'Join ${widget.spaceName} on FindEZ.\n${_url(invite)}',
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          ),
        );
      });
  Future<void> _revoke(Map<String, dynamic> share) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop sharing?'),
        content: const Text(
          'This link will stop working and everyone who joined through it will lose access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop sharing'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await _run(() async {
      await widget.api.deleteShare(share['share_id'].toString());
      if (!mounted || !_sameAccount) return;
      if (_invite?['share_id'] == share['share_id']) {
        setState(() => _invite = null);
      }
      await _load();
    });
  }

  Future<void> _join() => _run(() async {
    final invitation = Invitation.fromUri(
      Uri(
        scheme: 'findez',
        host: 'space-invite',
        queryParameters: {'code': _code.text.trim().toUpperCase()},
      ),
    );
    if (invitation == null) {
      setState(() => _error = 'Enter the 6-character invitation code.');
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InvitationDialog(
        api: widget.api,
        invitation: invitation,
        userId: _owner!,
      ),
    );
    if (!mounted || !_sameAccount || result?['accepted'] != true) return;
    _code.clear();
    await _load();
    if (mounted && _sameAccount) _open(result!);
  });
  void _open(Map<String, dynamic> share) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => SharedInventoryPage(
        api: widget.api,
        shareId: share['share_id'].toString(),
        shareName: (share['share_name'] ?? 'Shared space').toString(),
        permission: (share['permission'] ?? 'view').toString(),
      ),
    ),
  );

  Widget _linkCard(
    Map<String, dynamic> invite, {
    bool owner = false,
  }) => Material(
    color: AppColors.surface2,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.teamId != null
                ? 'Team member access'
                : invite['permission'] == 'edit'
                ? 'Can edit inventory'
                : 'View-only access',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Anyone with this link can join. The owner can revoke it at any time.',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          SelectableText(
            _url(invite),
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (source) => Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _share(invite, source),
                    child: const Text('Share link'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _copy(invite),
                    child: const Text('Copy link'),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Code: ${invite['share_code']}',
            style: const TextStyle(color: AppColors.hint, fontSize: 12),
          ),
          if (owner)
            TextButton(
              onPressed: _busy ? null : () => _revoke(invite),
              child: const Text(
                'Stop sharing',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: _personal ? 2 : 1,
    child: Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.spaceName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            if (_personal)
              const TabBar(
                tabs: [
                  Tab(text: 'Share'),
                  Tab(text: 'Join'),
                ],
              ),
            if (_busy || _loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (_invite != null && !_personal) _linkCard(_invite!),
                      if (_personal) ...[
                        const Text(
                          'Invite people to this space',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Choose the access everyone joining this link will have.',
                          style: TextStyle(color: AppColors.muted, height: 1.4),
                        ),
                        const SizedBox(height: 18),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'view',
                              label: Text('View only'),
                            ),
                            ButtonSegment(
                              value: 'edit',
                              label: Text('Can edit'),
                            ),
                          ],
                          selected: {_permission},
                          onSelectionChanged: _busy
                              ? null
                              : (values) =>
                                    setState(() => _permission = values.first),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _busy || _loading ? null : _generate,
                          child: const Text('Create invitation link'),
                        ),
                        if (_owned.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Active invitations',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 12),
                          for (final share in _owned)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _linkCard(share, owner: true),
                            ),
                        ],
                        if (_invite != null &&
                            !_owned.any(
                              (s) => s['share_id'] == _invite!['share_id'],
                            ))
                          _linkCard(_invite!, owner: true),
                      ] else if (_invite == null && !_loading)
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                    ],
                  ),
                  if (_personal)
                    ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        TextField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'Invitation code',
                          ),
                          onSubmitted: (_) => _join(),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _busy ? null : _join,
                          child: const Text('Review invitation'),
                        ),
                        if (_joined.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Joined spaces',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          for (final membership in _joined)
                            Builder(
                              builder: (context) {
                                final share = Map<String, dynamic>.from(
                                  membership['team_shares'] ?? const {},
                                );
                                return ListTile(
                                  title: Text(
                                    (share['share_name'] ?? 'Shared space')
                                        .toString(),
                                  ),
                                  subtitle: Text(
                                    share['permission'] == 'edit'
                                        ? 'Can edit'
                                        : 'View only',
                                  ),
                                  onTap: () => _open(share),
                                );
                              },
                            ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
