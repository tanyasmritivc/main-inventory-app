import 'dart:async';
import '../notifications/notification_bell.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_error.dart';
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
  bool _creating = false;
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
    var manageOrganizations = false;
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
          onOrganizations: () {
            manageOrganizations = true;
            Navigator.of(context).pop();
          },
          onManageOrganization: (org) async {
            organization = org;
            Navigator.of(context).pop();
          },
        ),
      );
    } finally {
      // The parent remains mounted while this directory sheet is open.
    }
    if (!mounted) return;
    if (manageOrganizations) {
      await _organizations();
      return;
    }
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
              '${data.inventories.length} ${data.inventories.length == 1 ? 'inventory' : 'inventories'}',
              style: PlaceTokens.text(13, color: PlaceTokens.dim),
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
        PlaceCardList(
          children: [
            for (final inv in data.inventories)
              InventoryDirectoryRow(
                inventory: inv,
                api: session.api,
                onOpen: () => _open(inv),
                refresh: session.refresh,
                contained: false,
              ),
          ],
        ),
    ],
  );

  Future<void> _organizations() => _push(
    HierarchyPage(
      api: session.api,
      onOpenInventory: widget.onOpenInventory,
      organizationsOnly: true,
      onOpenWorkspace: (id) async {
        Navigator.of(context).pop();
        await session.select(LastPlace.workspace(id));
      },
    ),
  );

  Future<void> _workspaceAction(String action, PlaceData data) async {
    if (action == 'delete') return _deleteWorkspace(data);
    if (action == 'organizations') return _organizations();
    if (action == 'organization') {
      return _push(
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
      );
    }
    if (action == 'tasks') {
      return _push(
        TeamBoardPage(api: session.api, initialTeamId: data.place.id),
      );
    }
    if (action == 'files') {
      return _push(TeamDocumentsPage(api: session.api, teamId: data.place.id));
    }
    return _push(
      HierarchyPage(
        api: session.api,
        onOpenInventory: widget.onOpenInventory,
        level: HierarchyLevel.workspace,
        id: data.place.id,
        name: data.name,
        organizationId: data.organizationId,
        panel: action == 'people'
            ? HierarchyPanel.people
            : action == 'activity'
            ? HierarchyPanel.activity
            : null,
      ),
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
          appBar: AppBar(
            title: Text('Inventories', style: PlaceTokens.title),
            centerTitle: false,
            actions: [
              NotificationBell(api: session.api),
              if (data != null)
                IconButton(
                  onPressed: _search,
                  tooltip: 'Search',
                  icon: const Icon(Icons.search, size: 22),
                ),
              if (data != null)
                PopupMenuButton<String>(
                  tooltip: 'Workspace options',
                  onSelected: (value) => _workspaceAction(value, data),
                  itemBuilder: (_) => [
                    if (!data.place.isPersonal) ...[
                      const PopupMenuItem(
                        value: 'people',
                        child: Text('People'),
                      ),
                      const PopupMenuItem(
                        value: 'settings',
                        child: Text('Workspace settings'),
                      ),
                      const PopupMenuItem(value: 'tasks', child: Text('Tasks')),
                      const PopupMenuItem(value: 'files', child: Text('Files')),
                      const PopupMenuItem(
                        value: 'activity',
                        child: Text('Activity'),
                      ),
                      if (data.organizationId != null)
                        const PopupMenuItem(
                          value: 'organization',
                          child: Text('Organization settings'),
                        ),
                      const PopupMenuDivider(),
                    ],
                    const PopupMenuItem(
                      value: 'organizations',
                      child: Text('Organizations'),
                    ),
                    if (!data.place.isPersonal &&
                        data.resource['owner_user_id'] ==
                            session.accountId) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete workspace',
                          style: TextStyle(color: PlaceTokens.destructive),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: session.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (session.loading) const LinearProgressIndicator(),
                  if (!session.loading && session.error != null) ...[
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
                  if (!session.loading &&
                      session.error == null &&
                      data != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        container: true,
                        button: true,
                        label:
                            'Switch workspace. Current: ${data.name}${data.organizationName == null ? '' : ' in ${data.organizationName}'}',
                        onTap: _switcher,
                        child: ExcludeSemantics(
                          child: TextButton.icon(
                            onPressed: _switcher,
                            style: TextButton.styleFrom(
                              foregroundColor: PlaceTokens.dim,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 10,
                              ),
                            ),
                            icon: const Icon(Icons.folder_outlined, size: 18),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    data.name,
                                    style: PlaceTokens.text(
                                      14,
                                      weight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.keyboard_arrow_down, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (data.organizationName != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          data.organizationName!,
                          style: PlaceTokens.subtitle,
                        ),
                      ),
                    const SizedBox(height: 18),
                    _inventoryBlock(data),
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
    this.onOrganizations,
  });
  final PlaceSession session;
  final Future<bool> Function(String) onCreate;
  final Future<void> Function(Map<String, dynamic>) onManageOrganization;
  final VoidCallback? onOrganizations;
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
    final workspaces = [...?_directory?.workspaces]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return PlaceTheme(
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: PlaceTokens.outline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Workspaces',
                      style: PlaceTokens.text(18, weight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 22),
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
                    if (_busy && _directory == null)
                      const LinearProgressIndicator(),
                    if (_error != null) ...[
                      Text(
                        describeError(_error!).$1,
                        style: PlaceTokens.subtitle,
                      ),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                    PlaceCardList(
                      children: [
                        PlaceRow(
                          title: 'Personal',
                          subtitle: 'Only you',
                          leading: const Icon(
                            Icons.person_outline,
                            size: 20,
                            color: PlaceTokens.dim,
                          ),
                          selected: widget.session.current.isPersonal,
                          showChevron: false,
                          onTap: () => Navigator.pop(
                            context,
                            const LastPlace.personal(),
                          ),
                        ),
                        for (final workspace in workspaces)
                          PlaceRow(
                            title: workspace.name,
                            subtitle: [
                              workspace.organizationName ??
                                  'Independent workspace',
                              '${workspace.inventories.length} ${workspace.inventories.length == 1 ? 'inventory' : 'inventories'}',
                            ].join(' · '),
                            leading: const Icon(
                              Icons.folder_outlined,
                              size: 20,
                              color: PlaceTokens.dim,
                            ),
                            selected: workspace.place == widget.session.current,
                            showChevron: false,
                            onTap: () =>
                                Navigator.pop(context, workspace.place),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: widget.onOrganizations,
                        icon: const Icon(Icons.business_outlined, size: 18),
                        label: const Text('Organizations'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _create('workspace'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New workspace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
