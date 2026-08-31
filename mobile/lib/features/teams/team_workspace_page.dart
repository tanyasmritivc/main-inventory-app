import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/low_stock_prefs.dart';
import '../../core/ui/app_colors.dart';
import '../inventory/inventory_page.dart';
import 'team_board_page.dart';

class TeamWorkspacePage extends StatefulWidget {
  const TeamWorkspacePage({
    super.key,
    required this.api,
    required this.initialTeamId,
  });

  final ApiClient api;
  final String? initialTeamId;

  @override
  State<TeamWorkspacePage> createState() => _TeamWorkspacePageState();
}

class _TeamWorkspacePageState extends State<TeamWorkspacePage> {
  Map<String, dynamic>? _team;
  List<Map<String, dynamic>> _spaces = const [];
  String _role = 'viewer';
  bool _loading = true;
  String? _error;

  bool get _canEdit => _role != 'viewer';
  bool get _canManage => _role == 'owner' || _role == 'mentor';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final teamId = widget.initialTeamId;
    if (teamId == null || teamId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'This team is unavailable.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.getTeamWorkspace(teamId),
        widget.api.getTeamSpaces(teamId),
      ]);
      if (!mounted) return;
      setState(() {
        _team = Map<String, dynamic>.from(results[0]['team'] ?? const {});
        _role = results[0]['role']?.toString() ?? 'viewer';
        _spaces = List<Map<String, dynamic>>.from(
          results[1]['spaces'] ?? const [],
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = describeError(error).$1;
        _loading = false;
      });
    }
  }

  Future<void> _addSpace() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canManage)
              ListTile(
                leading: const Icon(CupertinoIcons.add_circled),
                title: const Text('Create Team Space'),
                subtitle: const Text(
                  'Create a new Space owned by the team owner',
                ),
                onTap: () => Navigator.pop(context, 'create'),
              ),
            if (_canEdit)
              ListTile(
                leading: const Icon(CupertinoIcons.link),
                title: const Text('Add Existing Space'),
                subtitle: const Text(
                  'Link a Space you own without moving or deleting it',
                ),
                onTap: () => Navigator.pop(context, 'attach'),
              ),
          ],
        ),
      ),
    );
    if (choice == 'create') await _createSpace();
    if (choice == 'attach') await _attachSpace();
  }

  Future<void> _createSpace() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Team Space'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Workshop'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null) return;
    await _runWrite(
      () => widget.api.createTeamSpace(widget.initialTeamId!, name),
    );
  }

  Future<void> _attachSpace() async {
    try {
      final owned = await widget.api.listSpaces();
      final linked = _spaces.map((space) => space['id']?.toString()).toSet();
      final available = owned
          .where((space) => !linked.contains(space['id']?.toString()))
          .toList();
      if (!mounted) return;
      if (available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have no unlinked Spaces to add.')),
        );
        return;
      }
      final spaceId = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Add Existing Space')),
              for (final space in available)
                ListTile(
                  title: Text(space['name']?.toString() ?? 'Space'),
                  subtitle: Text('${space['item_count'] ?? 0} items'),
                  onTap: () => Navigator.pop(context, space['id']?.toString()),
                ),
            ],
          ),
        ),
      );
      if (spaceId == null) return;
      await _runWrite(
        () => widget.api.attachTeamSpace(widget.initialTeamId!, spaceId),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  Future<void> _runWrite(Future<dynamic> Function() action) async {
    try {
      await action();
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  Future<void> _copyJoinCode() async {
    final code = _team?['join_code']?.toString().trim() ?? '';
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Team join code copied')));
  }

  Future<void> _resetInviteCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset invite code?'),
        content: const Text(
          'The current code will stop working immediately. Existing members keep their access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset Code'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final code = await widget.api.rotateTeamJoinCode(widget.initialTeamId!);
      if (!mounted) return;
      setState(() => _team = {...?_team, 'join_code': code});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Old invite code revoked')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  Future<void> _deleteTeam() async {
    final name = _team?['name']?.toString() ?? 'this team';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Team?'),
        content: Text(
          '“$name” and its Board, People, and Activity will be permanently deleted. Linked Spaces and their items will remain in their owners’ accounts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete Team',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.deleteTeam(widget.initialTeamId!);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _team?['name']?.toString() ?? 'Team';
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          if (_canManage && !_loading && _error == null)
            PopupMenuButton<String>(
              tooltip: 'Team settings',
              onSelected: (value) {
                if (value == 'reset_code') unawaited(_resetInviteCode());
                if (value == 'delete') unawaited(_deleteTeam());
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'reset_code',
                  child: Text('Reset Invite Code'),
                ),
                if (_role == 'owner')
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete Team',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _WorkspaceMessage(
              title: 'Couldn’t load workspace',
              message: _error!,
              action: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
                children: [
                  Text(
                    '${_teamTypeLabel((_team?['program'] ?? '').toString())} · ${_roleLabel(_role)}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  if (_canManage &&
                      (_team?['join_code']?.toString().isNotEmpty ??
                          false)) ...[
                    const SizedBox(height: 16),
                    _InviteCodeCard(
                      code: _team!['join_code'].toString(),
                      onCopy: _copyJoinCode,
                    ),
                  ],
                  const SizedBox(height: 20),
                  _WorkspaceRow(
                    icon: CupertinoIcons.archivebox,
                    title: 'Spaces',
                    subtitle: _spaces.isEmpty
                        ? 'No Team Spaces yet'
                        : '${_spaces.length} Team ${_spaces.length == 1 ? 'Space' : 'Spaces'}',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _TeamSpacesPage(
                          api: widget.api,
                          teamId: widget.initialTeamId!,
                          teamName: name,
                          initialSpaces: _spaces,
                          role: _role,
                          onAdd: _addSpace,
                        ),
                      ),
                    ).then((_) => _load()),
                  ),
                  _WorkspaceRow(
                    icon: CupertinoIcons.check_mark_circled,
                    title: 'Board',
                    subtitle: 'Tasks, part requests, and readiness',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeamBoardPage(
                          api: widget.api,
                          initialTeamId: widget.initialTeamId,
                        ),
                      ),
                    ),
                  ),
                  _WorkspaceRow(
                    icon: CupertinoIcons.person_2,
                    title: 'People',
                    subtitle: 'Members, roles, and team code',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _TeamPeoplePage(
                          api: widget.api,
                          teamId: widget.initialTeamId!,
                          joinCode: _team?['join_code']?.toString() ?? '',
                          currentRole: _role,
                          onCopyCode: _copyJoinCode,
                        ),
                      ),
                    ),
                  ),
                  _WorkspaceRow(
                    icon: CupertinoIcons.clock,
                    title: 'Activity',
                    subtitle: 'Recent Space and inventory changes',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _TeamActivityPage(
                          api: widget.api,
                          teamId: widget.initialTeamId!,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _WorkspaceRow extends StatelessWidget {
  const _WorkspaceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: const Color(0xFF19191B),
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: Icon(icon, color: AppColors.accent, size: 23),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(
          CupertinoIcons.chevron_forward,
          color: AppColors.muted,
          size: 16,
        ),
        onTap: onTap,
      ),
    ),
  );
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code, required this.onCopy});

  final String code;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: .30)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.person_badge_plus, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TEAM INVITE CODE',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onCopy, child: const Text('Copy')),
        ],
      ),
    );
  }
}

class _TeamSpacesPage extends StatefulWidget {
  const _TeamSpacesPage({
    required this.api,
    required this.teamId,
    required this.teamName,
    required this.initialSpaces,
    required this.role,
    required this.onAdd,
  });
  final ApiClient api;
  final String teamId;
  final String teamName;
  final List<Map<String, dynamic>> initialSpaces;
  final String role;
  final Future<void> Function() onAdd;

  @override
  State<_TeamSpacesPage> createState() => _TeamSpacesPageState();
}

class _TeamSpacesPageState extends State<_TeamSpacesPage> {
  late List<Map<String, dynamic>> _spaces = widget.initialSpaces;

  Future<void> _refresh() async {
    final result = await widget.api.getTeamSpaces(widget.teamId);
    if (mounted) {
      setState(
        () => _spaces = List<Map<String, dynamic>>.from(
          result['spaces'] ?? const [],
        ),
      );
    }
  }

  Future<void> _remove(Map<String, dynamic> space) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Team?'),
        content: const Text('The Space and its items will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.detachTeamSpace(widget.teamId, space['id'].toString());
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Team Spaces'),
      actions: [
        if (widget.role != 'viewer')
          IconButton(
            onPressed: () async {
              await widget.onAdd();
              await _refresh();
            },
            icon: const Icon(CupertinoIcons.add),
            tooltip: 'Add Space',
          ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: _spaces.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 180),
                _WorkspaceMessage(
                  title: 'No Team Spaces',
                  message:
                      'Create a new Team Space or add one you already own.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: _spaces.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 54),
              itemBuilder: (context, index) {
                final space = _spaces[index];
                return ListTile(
                  leading: const Icon(
                    CupertinoIcons.archivebox,
                    color: AppColors.accent,
                  ),
                  title: Text(space['name']?.toString() ?? 'Space'),
                  subtitle: Text(
                    '${space['item_count'] ?? 0} items${space['owned_by_me'] == true ? ' · You own this Space' : ''}',
                  ),
                  trailing: const Icon(
                    CupertinoIcons.chevron_forward,
                    size: 16,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeamSpaceInventoryPage(
                        api: widget.api,
                        teamId: widget.teamId,
                        space: space,
                        role: widget.role,
                      ),
                    ),
                  ).then((_) => _refresh()),
                  onLongPress:
                      widget.role == 'owner' ||
                          widget.role == 'mentor' ||
                          space['owned_by_me'] == true
                      ? () => _remove(space)
                      : null,
                );
              },
            ),
    ),
  );
}

class TeamSpaceInventoryPage extends StatefulWidget {
  const TeamSpaceInventoryPage({
    super.key,
    required this.api,
    required this.teamId,
    required this.space,
    required this.role,
  });
  final ApiClient api;
  final String teamId;
  final Map<String, dynamic> space;
  final String role;

  @override
  State<TeamSpaceInventoryPage> createState() =>
      _TeamSpaceInventoryShellState();
}

class _TeamSpaceInventoryShellState extends State<TeamSpaceInventoryPage> {
  List<InventoryItem>? _items;
  Map<String, int> _thresholds = const {};
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final inventory = await widget.api.getTeamSpaceItems(
        widget.teamId,
        widget.space['id'].toString(),
      );
      final thresholds = await LowStockPrefs.loadAll();
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(
          inventory['items'] ?? const [],
        ).map(InventoryItem.fromJson).toList();
        _thresholds = thresholds;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeError(error).$1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.space['name']?.toString() ?? 'Team Space';
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(name)),
        body: _WorkspaceMessage(
          title: 'Couldn’t load Space',
          message: _error!,
          action: _load,
        ),
      );
    }
    if (_items == null) {
      return Scaffold(
        appBar: AppBar(title: Text(name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return LocationItemsPage(
      api: ApiClient.forTeamSpace(
        widget.api,
        teamId: widget.teamId,
        spaceId: widget.space['id'].toString(),
      ),
      location: name,
      items: _items!,
      thresholds: _thresholds,
      allItems: _items!,
      spaceId: widget.space['id']?.toString(),
      readOnly: widget.role == 'viewer',
    );
  }
}

class _LegacyTeamSpaceInventoryPage extends StatefulWidget {
  const _LegacyTeamSpaceInventoryPage({
    required this.api,
    required this.teamId,
    required this.space,
    required this.role,
  });
  final ApiClient api;
  final String teamId;
  final Map<String, dynamic> space;
  final String role;

  @override
  State<_LegacyTeamSpaceInventoryPage> createState() =>
      _TeamSpaceInventoryPageState();
}

class _TeamSpaceInventoryPageState
    extends State<_LegacyTeamSpaceInventoryPage> {
  List<InventoryItem> _items = const [];
  bool _loading = true;
  String? _error;
  bool get _canEdit => widget.role != 'viewer';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final result = await widget.api.getTeamSpaceItems(
        widget.teamId,
        widget.space['id'].toString(),
      );
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(
          result['items'] ?? const [],
        ).map(InventoryItem.fromJson).toList();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = describeError(error).$1;
        });
      }
    }
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final category = TextEditingController(text: 'Other');
    final quantity = TextEditingController(text: '1');
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add Item',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: category,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  if (name.text.trim().isNotEmpty) Navigator.pop(context, true);
                },
                child: const Text('Add Item'),
              ),
            ],
          ),
        ),
      ),
    );
    if (submitted != true) return;
    try {
      await widget.api.addTeamSpaceItem(
        widget.teamId,
        widget.space['id'].toString(),
        AddItemRequest(
          name: name.text.trim(),
          category: category.text.trim().isEmpty
              ? 'Other'
              : category.text.trim(),
          quantity: int.tryParse(quantity.text) ?? 1,
          location: widget.space['name'].toString(),
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
      }
    }
  }

  Future<void> _open(InventoryItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(item.name),
              subtitle: Text('${item.quantity} · ${item.category}'),
            ),
            if (_canEdit)
              ListTile(
                leading: const Icon(CupertinoIcons.minus_circle),
                title: const Text('Decrease quantity'),
                onTap: () => Navigator.pop(context, 'decrease'),
              ),
            if (_canEdit)
              ListTile(
                leading: const Icon(CupertinoIcons.plus_circle),
                title: const Text('Increase quantity'),
                onTap: () => Navigator.pop(context, 'increase'),
              ),
            if (_canEdit)
              ListTile(
                leading: const Icon(CupertinoIcons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;
    try {
      if (action == 'delete') {
        await widget.api.deleteTeamSpaceItem(
          widget.teamId,
          widget.space['id'].toString(),
          item.itemId,
        );
      } else {
        final delta = action == 'increase' ? 1 : -1;
        await widget.api.updateTeamSpaceItem(
          widget.teamId,
          widget.space['id'].toString(),
          UpdateItemRequest(
            itemId: item.itemId,
            quantity: (item.quantity + delta).clamp(0, 100000),
          ),
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.space['name']?.toString() ?? 'Team Space'),
    ),
    floatingActionButton: _canEdit
        ? FloatingActionButton(
            onPressed: _add,
            child: const Icon(CupertinoIcons.add),
          )
        : null,
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _WorkspaceMessage(
            title: 'Couldn’t load Space',
            message: _error!,
            action: _load,
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: _items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 180),
                      _WorkspaceMessage(
                        title: 'This Space is empty',
                        message: 'Add the first item when you are ready.',
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 54),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return ListTile(
                        leading: const Icon(
                          CupertinoIcons.cube_box,
                          color: AppColors.accent,
                        ),
                        title: Text(item.name),
                        subtitle: Text(item.category),
                        trailing: Text(
                          '${item.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () => _open(item),
                      );
                    },
                  ),
          ),
  );
}

class _TeamPeoplePage extends StatefulWidget {
  const _TeamPeoplePage({
    required this.api,
    required this.teamId,
    required this.joinCode,
    required this.currentRole,
    required this.onCopyCode,
  });
  final ApiClient api;
  final String teamId;
  final String joinCode;
  final String currentRole;
  final Future<void> Function() onCopyCode;

  @override
  State<_TeamPeoplePage> createState() => _TeamPeoplePageState();
}

class _TeamPeoplePageState extends State<_TeamPeoplePage> {
  List<Map<String, dynamic>>? _members;
  String? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final rows = await widget.api.getTeamMembers(widget.teamId);
      if (mounted) setState(() => _members = rows);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e).$1);
    }
  }

  Future<void> _manage(Map<String, dynamic> member) async {
    final canManage =
        widget.currentRole == 'owner' || widget.currentRole == 'mentor';
    if (member['role'] == 'owner' || !canManage) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(member['display_name']?.toString() ?? 'Team member'),
              subtitle: Text(
                _roleLabel(member['role']?.toString() ?? 'member'),
              ),
            ),
            if (widget.currentRole == 'owner')
              ListTile(
                title: const Text('Manager'),
                onTap: () => Navigator.pop(context, 'mentor'),
              ),
            ListTile(
              title: const Text('Member'),
              onTap: () => Navigator.pop(context, 'member'),
            ),
            ListTile(
              title: const Text('Viewer'),
              onTap: () => Navigator.pop(context, 'viewer'),
            ),
            ListTile(
              title: const Text(
                'Remove from Team',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    try {
      if (action == 'remove') {
        await widget.api.removeTeamMember(
          widget.teamId,
          member['user_id'].toString(),
        );
      } else {
        await widget.api.updateTeamMemberRole(
          widget.teamId,
          member['user_id'].toString(),
          action,
        );
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('People')),
    body: _error != null
        ? _WorkspaceMessage(
            title: 'Couldn’t load people',
            message: _error!,
            action: _load,
          )
        : _members == null
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              if ((widget.currentRole == 'owner' ||
                      widget.currentRole == 'mentor') &&
                  widget.joinCode.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _InviteCodeCard(
                    code: widget.joinCode,
                    onCopy: widget.onCopyCode,
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _members!.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 58),
                  itemBuilder: (context, index) {
                    final member = _members![index];
                    final manageable =
                        member['role'] != 'owner' &&
                        (widget.currentRole == 'owner' ||
                            widget.currentRole == 'mentor');
                    return ListTile(
                      leading: const Icon(CupertinoIcons.person_crop_circle),
                      title: Text(
                        member['display_name']?.toString() ?? 'Team member',
                      ),
                      subtitle: Text(
                        _roleLabel(member['role']?.toString() ?? 'member'),
                      ),
                      trailing: manageable
                          ? const Icon(CupertinoIcons.ellipsis)
                          : null,
                      onTap: manageable ? () => _manage(member) : null,
                    );
                  },
                ),
              ),
            ],
          ),
  );
}

class _TeamActivityPage extends StatefulWidget {
  const _TeamActivityPage({required this.api, required this.teamId});
  final ApiClient api;
  final String teamId;
  @override
  State<_TeamActivityPage> createState() => _TeamActivityPageState();
}

class _TeamActivityPageState extends State<_TeamActivityPage> {
  List<Map<String, dynamic>>? _activity;
  String? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final rows = await widget.api.getTeamActivity(widget.teamId);
      if (mounted) setState(() => _activity = rows);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e).$1);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Activity')),
    body: _error != null
        ? _WorkspaceMessage(
            title: 'Couldn’t load activity',
            message: _error!,
            action: _load,
          )
        : _activity == null
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: _activity!.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 180),
                      _WorkspaceMessage(
                        title: 'No activity yet',
                        message:
                            'Team Space and inventory changes will appear here.',
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: _activity!.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 54),
                    itemBuilder: (context, index) {
                      final row = _activity![index];
                      return ListTile(
                        leading: const Icon(
                          CupertinoIcons.clock,
                          color: AppColors.accent,
                        ),
                        title: Text(
                          row['summary']?.toString() ?? 'Team activity',
                        ),
                        subtitle: Text(
                          _dateLabel(row['created_at']?.toString()),
                        ),
                      );
                    },
                  ),
          ),
  );
}

class _WorkspaceMessage extends StatelessWidget {
  const _WorkspaceMessage({
    required this.title,
    required this.message,
    this.action,
  });
  final String title;
  final String message;
  final FutureOr<void> Function()? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, height: 1.4),
        ),
        if (action != null) ...[
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => action!(),
            child: const Text('Try Again'),
          ),
        ],
      ],
    ),
  );
}

String _roleLabel(String role) => switch (role) {
  'owner' => 'Owner',
  'mentor' => 'Manager',
  'viewer' => 'Viewer',
  _ => 'Member',
};

String _teamTypeLabel(String type) => switch (type) {
  'ftc' => 'FIRST Tech Challenge',
  'frc' => 'FIRST Robotics Competition',
  'fll' => 'FIRST LEGO League',
  'vex' => 'VEX Robotics',
  'robotics' => 'Robotics Team',
  'education' => 'School or Classroom',
  'makerspace' => 'Makerspace or Workshop',
  'club' => 'Club or Community Group',
  'business' => 'Business or Operations',
  _ => 'Team',
};

String _dateLabel(String? value) {
  final date = DateTime.tryParse(value ?? '')?.toLocal();
  if (date == null) return '';
  final now = DateTime.now();
  if (now.difference(date).inDays == 0) {
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    return 'Today at $hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
  return '${date.month}/${date.day}/${date.year}';
}
