import 'dart:async';
import '../notifications/notification_bell.dart';
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
import 'organization_pill.dart';
import '../profile/account_button.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session.addListener(_changed);
    unawaited(session.initializeNavigation());
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
    if (!session.navigationReady && !session.loading && session.error == null) {
      unawaited(session.initializeNavigation());
    }
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
        inventory['can_manage'] == true
            ? HierarchyPage(
                api: session.api,
                onOpenInventory: widget.onOpenInventory,
                level: HierarchyLevel.inventory,
                id: inventory['inventory_id'].toString(),
                name: inventory['name'].toString(),
              )
            : RestrictedInventoryPage(
                api: session.api,
                id: inventory['inventory_id'].toString(),
                workspaceId: place.place.id,
                onOpenInventory: widget.onOpenInventory,
              ),
      );
    }
  }

  Future<void> _switcher() async {
    final scope = session.organizationId;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 150,
        16,
        0,
      ),
      items: [
        for (final workspace in session.workspaces)
          PopupMenuItem(
            value: workspace['workspace_id'].toString(),
            child: Text(workspace['name'].toString()),
          ),
        if (session.canCreateWorkspace) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: '__new', child: Text('New workspace')),
        ],
      ],
    );
    if (!mounted || selected == null || session.organizationId != scope) return;
    if (selected == '__new') {
      await _create('workspace');
    } else {
      await session.selectWorkspace(selected);
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
      await session.refresh();
    }
  }

  Future<bool> _create(String kind) async {
    if (_creating) return false;
    final place = session.current;
    final organizationId = session.organizationId;
    final draft = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _CreatePlaceDialog(kind: kind),
    );
    final name = draft?['name'];
    if (!mounted ||
        name == null ||
        session.current != place ||
        session.organizationId != organizationId) {
      return false;
    }
    setState(() => _creating = true);
    try {
      final data = kind == 'workspace'
          ? {'name': name, 'program': 'other', 'custom_category': 'Workspace'}
          : {
              'name': name,
              if (kind == 'inventory')
                'access_mode': draft?['access_mode'] ?? 'workspace',
            };
      final path = kind == 'workspace'
          ? (organizationId == null
                ? '/teams'
                : '/organizations/${Uri.encodeComponent(organizationId)}/workspaces')
          : kind == 'organization'
          ? '/organizations'
          : '/inventory-workspaces/${Uri.encodeComponent(place.id)}/inventories';
      final saved = await session.api.collaboration(
        path,
        method: 'POST',
        data: kind == 'workspace' && organizationId != null
            ? {'name': name}
            : data,
      );
      if ((kind == 'inventory' &&
              (saved['inventory'] as Map?)?['inventory_id'] == null) ||
          (kind == 'workspace' &&
              ((saved['workspace'] ?? saved['team']) as Map?)?['team_id'] ==
                  null) ||
          (kind == 'organization' &&
              (saved['organization'] as Map?)?['organization_id'] == null)) {
        throw const FormatException(
          'The change could not be confirmed. Refresh before retrying.',
        );
      }
      if (!mounted ||
          session.current != place ||
          session.organizationId != organizationId) {
        return true;
      }
      if (kind == 'workspace') {
        await session.selectOrganization(
          organizationId,
          preferred: LastPlace.workspace(
            ((saved['workspace'] ?? saved['team']) as Map)['team_id']
                .toString(),
          ),
        );
      } else {
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
              style: PlacePalette.of(
                context,
              ).text(13, color: PlacePalette.of(context).dim),
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
                  Text(
                    'No inventories yet',
                    style: PlacePalette.of(context).rowTitle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.canCreate
                        ? 'Create a collection for this workspace.'
                        : 'Inventories shared with you will appear here.',
                    style: PlacePalette.of(
                      context,
                    ).text(13, color: PlacePalette.of(context).dim),
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

  Future<void> _organizationSettings() async {
    final id = session.organizationId;
    if (id == null) return;
    await _push(
      HierarchyPage(
        api: session.api,
        onOpenInventory: widget.onOpenInventory,
        level: HierarchyLevel.organization,
        id: id,
        name: session.organizationName,
        onOrganizationLeft: (_) => session.selectOrganization(null),
        onOpenWorkspace: (workspace) async {
          Navigator.of(context).pop();
          await session.selectOrganization(
            id,
            preferred: LastPlace.workspace(workspace),
          );
        },
      ),
    );
  }

  Future<void> _workspaceAction(String action, PlaceData data) async {
    if (action == 'delete') return _deleteWorkspace(data);
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
    final ready = !session.loading && session.error == null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: PlaceTheme(
        child: Scaffold(
          backgroundColor: PlacePalette.of(context).background,
          appBar: AppBar(
            toolbarHeight:
                (MediaQuery.textScalerOf(context).scale(13) * 1.4 + 24).clamp(
                  56,
                  double.infinity,
                ),
            centerTitle: false,
            title: OrganizationPill(
              api: session.api,
              id: session.organizationId,
              name: session.organizationName,
              onSelected: session.selectOrganization,
            ),
            actions: [
              NotificationBell(api: session.api),
              if (session.organizationId != null)
                IconButton(
                  tooltip: 'Organization settings',
                  onPressed: _organizationSettings,
                  icon: const Icon(Icons.settings_outlined, size: 22),
                ),
              AccountButton(api: session.api),
            ],
          ),
          body: SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: session.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  if (session.loading) const LinearProgressIndicator(),
                  if (!session.loading && session.error != null) ...[
                    Text(
                      describeError(session.error!).$1,
                      style: PlacePalette.of(context).rowTitle,
                    ),
                    TextButton(
                      onPressed: session.refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                  if (ready && data == null) ...[
                    Text('Workspaces', style: PlacePalette.of(context).title),
                    const SizedBox(height: 24),
                    Text(
                      'No workspaces yet',
                      style: PlacePalette.of(context).rowTitle,
                    ),
                    if (session.canCreateWorkspace)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _creating
                              ? null
                              : () => _create('workspace'),
                          icon: const Icon(Icons.add),
                          label: const Text('New workspace'),
                        ),
                      ),
                  ],
                  if (ready && data != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Workspace',
                                style: PlacePalette.of(
                                  context,
                                ).text(12, color: PlacePalette.of(context).dim),
                              ),
                              Semantics(
                                container: true,
                                onTap: _switcher,
                                label:
                                    'Switch workspace. Current: ${data.name}',
                                button: true,
                                child: ExcludeSemantics(
                                  child: TextButton(
                                    onPressed: _switcher,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      alignment: Alignment.centerLeft,
                                      foregroundColor: PlacePalette.of(
                                        context,
                                      ).primary,
                                    ),
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            data.name,
                                            style: PlacePalette.of(
                                              context,
                                            ).title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.expand_more, size: 22),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!data.place.isPersonal)
                          PopupMenuButton<String>(
                            tooltip: 'Workspace settings',
                            onSelected: (value) =>
                                _workspaceAction(value, data),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'settings',
                                child: Text('Workspace settings'),
                              ),
                              const PopupMenuItem(
                                value: 'activity',
                                child: Text('Activity'),
                              ),
                              if ((data.resource['owner_user_id'] ==
                                      session.accountId ||
                                  ['owner', 'admin'].contains(
                                    data.resource['organization_role'],
                                  )))
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete workspace',
                                    style: TextStyle(
                                      color: PlacePalette.of(
                                        context,
                                      ).destructive,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                    if (!data.place.isPersonal) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in {
                            'people': (Icons.people_outline, 'People'),
                            'tasks': (Icons.checklist_outlined, 'Tasks'),
                            'files': (Icons.folder_outlined, 'Files'),
                          }.entries)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _workspaceAction(entry.key, data),
                              icon: Icon(entry.value.$1, size: 18),
                              label: Text(entry.value.$2),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Inventories',
                            style: PlacePalette.of(
                              context,
                            ).text(20, weight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          onPressed: _search,
                          tooltip: 'Search',
                          icon: const Icon(Icons.search, size: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
  String _accessMode = 'workspace';
  void _submit() {
    if (_text.text.trim().isNotEmpty) {
      Navigator.pop(context, {
        'name': _text.text.trim(),
        'access_mode': _accessMode,
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('New ${widget.kind}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _text,
            autofocus: true,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              _submit();
            },
          ),
          if (widget.kind == 'inventory')
            DropdownButtonFormField<String>(
              initialValue: _accessMode,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Access'),
              items: const [
                DropdownMenuItem(
                  value: 'workspace',
                  child: Text('Inherited workspace access'),
                ),
                DropdownMenuItem(
                  value: 'restricted',
                  child: Text('Custom access'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _accessMode = value ?? 'workspace'),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: _text.text.trim().isEmpty ? null : _submit,
        child: const Text('Create'),
      ),
    ],
  );
}
