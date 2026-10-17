import 'dart:async';
import '../notifications/notification_bell.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_error.dart';
import '../../core/inventory_context.dart';
import '../../core/last_place.dart';
import '../../core/place_session.dart';
import '../teams/team_board_page.dart';
import '../teams/team_documents_page.dart';
import 'hierarchy_page.dart';
import 'place_ui.dart';
import 'inventory_actions.dart';
import 'workspace_actions.dart';

class WorkspaceHome extends StatefulWidget {
  const WorkspaceHome({
    super.key,
    required this.session,
    required this.onOpenInventory,
  });
  final PlaceSession session;
  final OpenInventory onOpenInventory;
  @override
  State<WorkspaceHome> createState() => _WorkspaceHomeState();
}

class _WorkspaceHomeState extends State<WorkspaceHome>
    with WidgetsBindingObserver {
  PlaceSession get session => widget.session;
  bool _switcherOpen = false, _creating = false;
  Map<String, dynamic>? _createdOrganization;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session.addListener(_changed);
  }

  @override
  void dispose() {
    session.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final notice = session.takeNotice();
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(notice)));
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !session.loading) {
      unawaited(session.refresh());
    }
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await session.refresh();
  }

  Future<void> _open(Map<String, dynamic> inventory) async {
    final place = session.data;
    if (place == null) return;
    if (inventory['can_open'] == true) {
      await widget.onOpenInventory(
        inventory['inventory_id'].toString(),
        place.place.id,
        place.organizationId,
      );
    } else {
      await _push(
        RestrictedInventoryPage(
          api: session.api,
          id: inventory['inventory_id'].toString(),
          workspaceId: place.place.id,
          onOpenInventory: widget.onOpenInventory,
        ),
      );
    }
  }

  Future<void> _switcher() async {
    setState(() => _switcherOpen = true);
    LastPlace? selected;
    Map<String, dynamic>? organization;
    try {
      selected = await showModalBottomSheet<LastPlace>(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        backgroundColor: PlaceTokens.background,
        elevation: 0,
        barrierColor: const Color(0x6B111112),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        constraints: BoxConstraints(
          maxHeight: math.max(250, MediaQuery.sizeOf(context).height - 150),
        ),
        builder: (_) => PlaceSwitcher(
          session: session,
          onCreate: _create,
          onManageOrganization: (org) async {
            organization = org;
            Navigator.of(context).pop();
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _switcherOpen = false);
    }
    if (!mounted) return;
    organization ??= _createdOrganization;
    _createdOrganization = null;
    if (organization != null) {
      final org = organization!;
      final place = await Navigator.of(context).push<LastPlace>(
        MaterialPageRoute(
          builder: (pageContext) => HierarchyPage(
            api: session.api,
            onOpenInventory: widget.onOpenInventory,
            level: HierarchyLevel.organization,
            id: org['organization_id'].toString(),
            name: org['name'].toString(),
            onOpenWorkspace: (id) async =>
                Navigator.of(pageContext).pop(LastPlace.workspace(id)),
          ),
        ),
      );
      if (!mounted) return;
      if (place != null) {
        await session.select(place);
      } else {
        await session.refresh();
      }
    } else if (selected != null) {
      await session.select(selected);
    }
  }

  Future<void> _deleteWorkspace(PlaceData data) async {
    final deleted = await confirmWorkspaceDeletion(
      context,
      session.api,
      id: data.place.id,
      name: data.name,
    );
    if (mounted && deleted) {
      await session.restore(override: const LastPlace.personal());
    }
  }

  Future<bool> _create(String kind) async {
    if (_creating) return false;
    final place = session.current;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _CreatePlaceDialog(kind: kind),
    );
    if (!mounted || name == null || session.current != place) return false;
    setState(() => _creating = true);
    try {
      final data = kind == 'workspace'
          ? {'name': name, 'program': 'other', 'custom_category': 'Workspace'}
          : {'name': name};
      final path = kind == 'workspace'
          ? '/teams'
          : kind == 'organization'
          ? '/organizations'
          : '/inventory-workspaces/${Uri.encodeComponent(place.id)}/inventories';
      final saved = await session.api.collaboration(
        path,
        method: 'POST',
        data: data,
      );
      if ((kind == 'inventory' &&
              (saved['inventory'] as Map?)?['inventory_id'] == null) ||
          (kind == 'workspace' &&
              (saved['team'] as Map?)?['team_id'] == null) ||
          (kind == 'organization' &&
              (saved['organization'] as Map?)?['organization_id'] == null)) {
        throw const FormatException(
          'The change could not be confirmed. Refresh before retrying.',
        );
      }
      if (!mounted) return true;
      if (kind == 'workspace') {
        await session.select(
          LastPlace.workspace((saved['team'] as Map)['team_id'].toString()),
        );
      } else {
        if (kind == 'organization') {
          _createdOrganization = Map<String, dynamic>.from(
            saved['organization'] as Map,
          );
        }
        await session.refresh();
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(e).$1)));
      }
      return false;
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _search() {
    final data = session.data;
    if (data == null) return;
    _push(
      HierarchyPage(
        api: session.api,
        onOpenInventory: widget.onOpenInventory,
        level: HierarchyLevel.workspace,
        id: data.place.id,
        name: data.name,
        organizationId: data.organizationId,
        focusSearch: true,
      ),
    );
  }

  Widget _inventoryBlock(PlaceData data) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              'Inventories',
              style: PlaceTokens.text(18, weight: FontWeight.w600),
            ),
            if (data.canCreate)
              FilledButton.icon(
                onPressed: _creating ? null : () => _create('inventory'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New inventory'),
                style: FilledButton.styleFrom(
                  backgroundColor: PlaceTokens.darkOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (data.inventories.isEmpty)
        PlaceCardList(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No inventories yet', style: PlaceTokens.rowTitle),
                  const SizedBox(height: 8),
                  Text(
                    data.canCreate
                        ? 'Create a collection for this workspace.'
                        : 'Inventories shared with you will appear here.',
                    style: PlaceTokens.text(13, color: PlaceTokens.dim),
                  ),
                ],
              ),
            ),
          ],
        )
      else
        for (final inv in data.inventories) ...[
          InventoryDirectoryRow(
            inventory: inv,
            api: session.api,
            onOpen: () => _open(inv),
            refresh: session.refresh,
          ),
          const SizedBox(height: 10),
        ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final data = session.data;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: PlaceTheme(
        child: Scaffold(
          backgroundColor: PlaceTokens.background,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: session.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (session.loading || session.error != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: NotificationBell(api: session.api),
                    ),
                  if (session.loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (!session.loading && session.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            describeError(session.error!).$1,
                            style: PlaceTokens.rowTitle,
                          ),
                          TextButton(
                            onPressed: session.refresh,
                            child: const Text('Retry'),
                          ),
                          if (!session.current.isPersonal)
                            TextButton(
                              onPressed: () =>
                                  session.select(const LastPlace.personal()),
                              child: const Text('Personal'),
                            ),
                        ],
                      ),
                    ),
                  if (!session.loading &&
                      session.error == null &&
                      data != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Semantics(
                              button: true,
                              label:
                                  'Switch place. Current: ${data.name}${data.organizationName == null ? '' : ' in ${data.organizationName}'}',
                              onTap: _switcher,
                              child: ExcludeSemantics(
                                child: InkWell(
                                  onTap: _switcher,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 44,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!data.place.isPersonal &&
                                            data.organizationName != null) ...[
                                          Text(
                                            data.organizationName!,
                                            style: PlaceTokens.text(
                                              13,
                                              color: PlaceTokens.dim,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                data.name,
                                                style: PlaceTokens.title,
                                              ),
                                            ),
                                            if (!_switcherOpen) ...[
                                              const SizedBox(width: 10),
                                              const PlaceGlyph(
                                                PlaceSymbol.down,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          NotificationBell(api: session.api),
                          Visibility(
                            visible: !_switcherOpen,
                            maintainSize: true,
                            maintainState: true,
                            maintainAnimation: true,
                            child: IconButton(
                              onPressed: _search,
                              tooltip: 'Search',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                  color: PlaceTokens.outline,
                                ),
                                minimumSize: const Size(44, 44),
                                maximumSize: const Size(44, 44),
                              ),
                              icon: const PlaceGlyph(PlaceSymbol.search),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _switcher,
                          child: const Text('Switch workspace'),
                        ),
                        if (data.organizationId != null)
                          TextButton(
                            onPressed: () => _push(
                              HierarchyPage(
                                api: session.api,
                                onOpenInventory: widget.onOpenInventory,
                                level: HierarchyLevel.organization,
                                id: data.organizationId,
                                name: data.organizationName,
                                onOpenWorkspace: (id) async {
                                  Navigator.of(context).pop();
                                  await session.select(LastPlace.workspace(id));
                                },
                              ),
                            ),
                            child: const Text('Organization'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Opacity(
                      opacity: _switcherOpen ? 0 : 1,
                      child: _inventoryBlock(data),
                    ),
                    if (!data.place.isPersonal) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Workspace',
                              style: PlaceTokens.section,
                            ),
                          ),
                          if (data.resource['owner_user_id'] ==
                              session.accountId)
                            PopupMenuButton<String>(
                              tooltip: 'Manage workspace',
                              onSelected: (_) => _deleteWorkspace(data),
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete workspace'),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      PlaceCardList(
                        children: [
                          PlaceRow(
                            title: 'Tasks',
                            minHeight: 54,
                            onTap: () => _push(
                              TeamBoardPage(
                                api: session.api,
                                initialTeamId: data.place.id,
                              ),
                            ),
                          ),
                          PlaceRow(
                            title: 'Files',
                            onTap: () => _push(
                              TeamDocumentsPage(
                                api: session.api,
                                teamId: data.place.id,
                              ),
                            ),
                          ),
                          PlaceRow(
                            title: 'People',
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (data.members != null) ...[
                                  Text(
                                    '${data.members!.length}',
                                    style: PlaceTokens.text(
                                      15,
                                      color: PlaceTokens.dim,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                ],
                                const PlaceGlyph(PlaceSymbol.right),
                              ],
                            ),
                            onTap: () => _push(
                              PlaceTheme(
                                child: HierarchyPage(
                                  api: session.api,
                                  onOpenInventory: widget.onOpenInventory,
                                  level: HierarchyLevel.workspace,
                                  id: data.place.id,
                                  name: data.name,
                                  organizationId: data.organizationId,
                                  panel: HierarchyPanel.people,
                                ),
                              ),
                            ),
                          ),
                          PlaceRow(
                            title: 'Activity',
                            onTap: () => _push(
                              HierarchyPage(
                                api: session.api,
                                onOpenInventory: widget.onOpenInventory,
                                level: HierarchyLevel.workspace,
                                id: data.place.id,
                                name: data.name,
                                organizationId: data.organizationId,
                                panel: HierarchyPanel.activity,
                              ),
                            ),
                          ),
                          PlaceRow(
                            title: 'Workspace settings',
                            onTap: () => _push(
                              HierarchyPage(
                                api: session.api,
                                onOpenInventory: widget.onOpenInventory,
                                level: HierarchyLevel.workspace,
                                id: data.place.id,
                                name: data.name,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatePlaceDialog extends StatefulWidget {
  const _CreatePlaceDialog({required this.kind});
  final String kind;
  @override
  State<_CreatePlaceDialog> createState() => _CreatePlaceDialogState();
}

class _CreatePlaceDialogState extends State<_CreatePlaceDialog> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('New ${widget.kind}'),
    content: TextField(
      controller: _text,
      autofocus: true,
      maxLength: 100,
      decoration: const InputDecoration(labelText: 'Name'),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) {
        if (_text.text.trim().isNotEmpty) {
          Navigator.pop(context, _text.text.trim());
        }
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: _text.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _text.text.trim()),
        child: const Text('Create'),
      ),
    ],
  );
}

class PlaceSwitcher extends StatefulWidget {
  const PlaceSwitcher({
    super.key,
    required this.session,
    required this.onCreate,
    required this.onManageOrganization,
  });
  final PlaceSession session;
  final Future<bool> Function(String) onCreate;
  final Future<void> Function(Map<String, dynamic>) onManageOrganization;
  @override
  State<PlaceSwitcher> createState() => _PlaceSwitcherState();
}

class _PlaceSwitcherState extends State<PlaceSwitcher> {
  PlaceDirectory? _directory;
  Object? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final data = await widget.session.repository.directory();
      if (mounted) setState(() => _directory = data);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _places(List<PlaceData> entries, {bool standalone = false}) {
    final children = <Widget>[];
    var group = <Widget>[];
    void flush() {
      if (group.isNotEmpty) {
        children.add(PlaceCardList(children: group));
        group = [];
      }
    }

    for (final item in entries) {
      final selected = item.place == widget.session.current;
      final role = membershipRoleLabel(item.resource['role']?.toString() ?? '');
      final row = PlaceRow(
        title: item.name,
        leading: PlaceBadge(item.name),
        subtitle: standalone
            ? null
            : '$role · ${item.inventories.length} ${item.inventories.length == 1 ? 'inventory' : 'inventories'}',
        trailing: standalone && !selected ? RoleTag(role) : null,
        selected: selected,
        vertical: standalone && group.isEmpty ? 15.5 : 14.5,
        onTap: () => Navigator.pop(context, item.place),
      );
      if (selected) {
        flush();
        children.add(PlaceCardList(selected: true, children: [row]));
      } else {
        group.add(row);
      }
    }
    flush();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          children[i],
        ],
      ],
    );
  }

  Future<void> _create(String kind) async {
    if (_busy) return;
    setState(() => _busy = true);
    final saved = await widget.onCreate(kind);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final directory = _directory;
    final orgs = directory?.organizations ?? <Map<String, dynamic>>[];
    final workspaces = directory?.workspaces ?? <PlaceData>[];
    final groups = <String, List<PlaceData>>{};
    for (final ws in workspaces) {
      if (ws.organizationId != null) {
        groups.putIfAbsent(ws.organizationId!, () => []).add(ws);
      }
    }
    final organizations = [
      ...orgs,
      for (final id in groups.keys)
        if (!orgs.any((o) => o['organization_id'] == id))
          {'organization_id': id, 'name': groups[id]!.first.organizationName},
    ];
    return PlaceTheme(
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD4D1CB),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 13),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Switch place',
                    style: PlaceTokens.text(18, weight: FontWeight.w600),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Close',
                  onTap: () => Navigator.pop(context),
                  child: ExcludeSemantics(
                    child: InkResponse(
                      onTap: () => Navigator.pop(context),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: PlaceTokens.border,
                            ),
                            child: const PlaceGlyph(PlaceSymbol.close),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  PlaceCardList(
                    selected: widget.session.current.isPersonal,
                    children: [
                      PlaceRow(
                        title: 'Personal',
                        subtitle: 'Only you',
                        leading: const PlaceBadge('Personal', type: 'personal'),
                        selected: widget.session.current.isPersonal,
                        showChevron: false,
                        onTap: () =>
                            Navigator.pop(context, const LastPlace.personal()),
                        vertical: 15,
                      ),
                    ],
                  ),
                  if (_busy && directory == null)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      describeError(_error!).$1,
                      style: PlaceTokens.subtitle,
                    ),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                  if (organizations.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Organizations',
                      style: PlaceTokens.text(16, weight: FontWeight.w600),
                    ),
                  ],
                  for (final org in organizations) ...[
                    const SizedBox(height: 12),
                    PlaceCardList(
                      children: [
                        PlaceRow(
                          title: (org['name'] ?? 'Organization').toString(),
                          leading: PlaceBadge(
                            (org['name'] ?? 'O').toString(),
                            type: 'organization',
                          ),
                          subtitle: org['role'] == null
                              ? 'Organization'
                              : 'Organization · ${placeRole(org['role'].toString())}',
                          onTap: () async {
                            await widget.onManageOrganization(org);
                          },
                        ),
                      ],
                    ),
                    if ((groups[org['organization_id']] ?? []).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _places(groups[org['organization_id']]!),
                    ],
                  ],
                  if (workspaces.any((w) => w.organizationId == null)) ...[
                    const SizedBox(height: 17),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'WORKSPACES',
                        style: PlaceTokens.section.copyWith(
                          color: PlaceTokens.muted(context, PlaceTokens.label),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _places(
                      workspaces
                          .where((w) => w.organizationId == null)
                          .toList(),
                      standalone: true,
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              math.max(16, MediaQuery.viewPaddingOf(context).bottom - 10),
            ),
            child: Row(
              children: [
                for (final kind in ['workspace', 'organization']) ...[
                  if (kind == 'organization') const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _create(kind),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: PlaceTokens.primary,
                        side: const BorderSide(color: PlaceTokens.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(0, 46),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'New $kind',
                        style: PlaceTokens.text(14, weight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
