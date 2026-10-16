import 'dart:async';
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
  bool _switcherOpen = false;
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

  Future<bool> _create(String kind) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _CreatePlaceDialog(kind: kind),
    );
    if (!mounted || name == null) return false;
    try {
      final data = kind == 'workspace'
          ? {'name': name, 'program': 'other', 'custom_category': 'Workspace'}
          : {'name': name};
      final path = kind == 'workspace'
          ? '/teams'
          : kind == 'organization'
          ? '/organizations'
          : '/inventory-workspaces/${Uri.encodeComponent(session.current.id)}/inventories';
      final saved = await session.api.collaboration(
        path,
        method: 'POST',
        data: data,
      );
      if (saved.isEmpty) {
        throw const FormatException(
          'The change could not be confirmed. Refresh before retrying.',
        );
      }
      if (mounted) await session.refresh();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(e).$1)));
      }
      return false;
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

  Widget _inventoryBlock(PlaceData data) {
    final inventories = data.inventories;
    if (inventories.isEmpty) {
      return PlaceCardList(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No inventory yet', style: PlaceTokens.rowTitle),
                if (data.canCreate) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _create('inventory'),
                    child: const Text('Create inventory'),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }
    if (inventories.length == 1) {
      final inv = inventories.single;
      final editable =
          inv['can_open'] == true &&
          (inv['can_edit'] == true ||
              ['owner', 'admin', 'editor'].contains(inv['role']));
      final status = inv['can_open'] != true
          ? 'Access restricted'
          : editable
          ? 'You can edit'
          : 'View only';
      return Semantics(
        button: true,
        label: '${inv['name']}. $status. Open inventory',
        onTap: () => _open(inv),
        child: ExcludeSemantics(
          child: Material(
            color: PlaceTokens.darkOrange,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _open(inv),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          Text(
                            'Inventory',
                            style: PlaceTokens.text(
                              13,
                              weight: FontWeight.w600,
                              color: const Color(0xFFFCD9C4),
                            ),
                          ),
                          Text(
                            status,
                            style: PlaceTokens.text(
                              13,
                              color: const Color(0xFFFCD9C4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      inv['name'].toString(),
                      style: PlaceTokens.text(
                        22,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ).copyWith(height: 1.2),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: inv['item_count'] == null
                              ? const SizedBox.shrink()
                              : Text(
                                  '${inv['item_count']} items',
                                  style: PlaceTokens.text(
                                    15,
                                    color: const Color(0xFFFFF1E8),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Text(
                            'Open',
                            style: PlaceTokens.text(
                              15,
                              weight: FontWeight.w600,
                              color: PlaceTokens.ownerText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('INVENTORIES', style: PlaceTokens.section),
        const SizedBox(height: 10),
        PlaceCardList(
          children: [
            for (final inv in inventories)
              PlaceRow(
                title: inv['name'].toString(),
                subtitle: inv['can_open'] == true ? null : 'Access restricted',
                onTap: () => _open(inv),
                trailing: inv['item_count'] == null
                    ? null
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${inv['item_count']}',
                            style: PlaceTokens.text(
                              16,
                              weight: FontWeight.w600,
                              color: PlaceTokens.darkOrange,
                            ),
                          ),
                          Text(
                            'items',
                            style: PlaceTokens.text(12, color: PlaceTokens.dim),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ],
    );
  }

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
                          const SizedBox(width: 12),
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
                    const SizedBox(height: 23),
                    Opacity(
                      opacity: _switcherOpen ? 0 : 1,
                      child: _inventoryBlock(data),
                    ),
                    if (!data.place.isPersonal) ...[
                      const SizedBox(height: 20),
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
    await widget.onCreate(kind);
    if (mounted) await _load();
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
                  for (final org in organizations) ...[
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Semantics(
                        button: true,
                        label:
                            'Open organization ${(org['name'] ?? '').toString()}',
                        child: InkWell(
                          onTap: () async {
                            await widget.onManageOrganization(org);
                            if (mounted) await _load();
                          },
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    (org['name'] ?? '')
                                        .toString()
                                        .toUpperCase(),
                                    style: PlaceTokens.section.copyWith(
                                      color: PlaceTokens.muted(
                                        context,
                                        PlaceTokens.label,
                                      ),
                                    ),
                                  ),
                                  if (org['role'] != null)
                                    Text(
                                      'Organization · ${placeRole(org['role'].toString())}',
                                      style: PlaceTokens.subtitle.copyWith(
                                        color: PlaceTokens.muted(
                                          context,
                                          PlaceTokens.secondary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if ((groups[org['organization_id']] ?? []).isNotEmpty)
                      _places(groups[org['organization_id']]!),
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
