import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/inventory_context.dart';
import '../../core/ui/app_text.dart';
import '../notifications/notifications_page.dart';
import '../sharing/shared_inventory_page.dart';
import '../sharing/invitation_dialog.dart';
import '../../core/invitation.dart';
import '../profile/profile_page.dart';
import 'invitation_page.dart';
import 'place_ui.dart';
import 'inventory_actions.dart';
import 'workspace_actions.dart';

List<Map<String, dynamic>> rows(Object? value) => (value as List? ?? [])
    .map((row) => Map<String, dynamic>.from(row as Map))
    .toList();
Map<String, dynamic> record(Object? value) =>
    Map<String, dynamic>.from(value as Map? ?? {});

typedef OpenInventory =
    Future<void> Function(
      String id,
      String workspaceId,
      String? organizationId,
    );

enum HierarchyLevel { organizations, organization, workspace, inventory }

enum HierarchyPanel { people, activity }

class _HierarchySection extends StatelessWidget {
  const _HierarchySection(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(title.toUpperCase(), style: PlaceTokens.section),
  );
}

/// Phone navigation uses focused lists; it does not reproduce the web sidebar.
class HierarchyPage extends StatefulWidget {
  const HierarchyPage({
    super.key,
    required this.api,
    required this.onOpenInventory,
    this.level = HierarchyLevel.organizations,
    this.id,
    this.name,
    this.organizationId,
    this.onClose,
    this.panel,
    this.focusSearch = false,
    this.onOpenWorkspace,
  });
  final ApiClient api;
  final VoidCallback? onClose;
  final OpenInventory onOpenInventory;
  final HierarchyLevel level;
  final String? id, name, organizationId;
  final HierarchyPanel? panel;
  final bool focusSearch;
  final Future<void> Function(String id)? onOpenWorkspace;
  @override
  State<HierarchyPage> createState() => _HierarchyPageState();
}

class _HierarchyPageState extends State<HierarchyPage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _inventories = [],
      _invitations = [],
      _requests = [],
      _audit = [],
      _spaces = [];
  Object? _error;
  bool _loading = true, _busy = false;
  int _generation = 0;
  String _query = '';
  bool _organizationPeople = false;
  String get _id => Uri.encodeComponent(widget.id ?? '');
  bool get _org => widget.level == HierarchyLevel.organization;
  bool get _workspace => widget.level == HierarchyLevel.workspace;
  bool get _inventory => widget.level == HierarchyLevel.inventory;
  Map<String, dynamic> get _resource => record(
    _data?[_org
        ? 'organization'
        : _inventory
        ? 'inventory'
        : 'workspace'],
  );
  bool get _personal => _workspace && widget.id == 'personal';
  bool get _manager => _inventory
      ? _resource['can_manage'] == true && _resource['team_id'] != null
      : (_org ? ['owner', 'admin'] : ['owner', 'mentor']).contains(
          _resource['role'],
        );
  bool get _owner => _resource['owner_user_id'] == widget.api.accountId;
  String get _scope => _org
      ? 'organization'
      : _inventory
      ? 'inventory'
      : 'workspace';
  String get _base => _org
      ? '/organizations/$_id'
      : _inventory
      ? '/inventories/$_id'
      : '/inventory-workspaces/$_id';
  String get _title => widget.level == HierarchyLevel.organizations
      ? 'Your world'
      : (_resource['name'] ?? widget.name ?? 'Loading...').toString();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) unawaited(_load());
  }

  Future<List<Map<String, dynamic>>> _directory({String? workspaceId}) async {
    final workspace = workspaceId ?? widget.id!;
    final base = '/inventory-workspaces/${Uri.encodeComponent(workspace)}';
    final result = <Map<String, dynamic>>[];
    int? offset = 0;
    do {
      final data = await widget.api.collaboration(
        '$base/directory',
        query: {'offset': offset},
      );
      final page = rows(data['inventories']);
      if (page.any((row) => row['workspace_id'] != workspace)) {
        throw const FormatException(
          'This directory changed. Refresh and choose again.',
        );
      }
      result.addAll(page);
      final next = data['next_offset'] as int?;
      if (next != null && next <= offset!) {
        throw const FormatException('The directory could not be loaded.');
      }
      offset = next;
      if (!mounted) return [];
    } while (offset != null);
    return result;
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      Map<String, dynamic> data;
      var inventories = <Map<String, dynamic>>[],
          invitations = <Map<String, dynamic>>[],
          requests = <Map<String, dynamic>>[],
          audit = <Map<String, dynamic>>[],
          spaces = <Map<String, dynamic>>[];
      switch (widget.level) {
        case HierarchyLevel.organizations:
          final results = await Future.wait([
            widget.api.collaboration('/organizations'),
            widget.api.collaboration('/inventory-workspaces'),
          ]);
          data = {
            ...results[0],
            ...results[1],
            'shared': await widget.api.getJoinedShares(),
          };
        case HierarchyLevel.organization:
          data = await widget.api.collaboration(_base);
          if (data['organization']?['organization_id'] != widget.id) {
            throw const FormatException('Organization changed.');
          }
        case HierarchyLevel.workspace:
          if (_personal) {
            data = {
              'workspace': {
                'workspace_id': 'personal',
                'name': 'Personal',
                'role': 'owner',
              },
            };
          } else {
            data = await widget.api.collaboration('$_base/overview');
            if (data['workspace']?['workspace_id'] != widget.id ||
                (widget.organizationId != null &&
                    data['workspace']?['organization_id'] !=
                        widget.organizationId)) {
              throw const FormatException(
                'Workspace belongs to another organization.',
              );
            }
            audit = rows(
              (await widget.api.collaboration('$_base/audit'))['activity'],
            );
          }
          inventories = await _directory();
        case HierarchyLevel.inventory:
          data = await widget.api.collaboration('$_base/access');
          if (data['inventory']?['inventory_id'] != widget.id) {
            throw const FormatException('Inventory changed.');
          }
          final entry = await widget.api.collaboration(
            '/inventory-directory/$_id',
          );
          data['directory'] = entry['inventory'];
          audit = rows(
            (await widget.api.collaboration('$_base/audit'))['activity'],
          );
          spaces = rows(
            (await widget.api.collaboration('$_base/spaces'))['spaces'],
          );
      }
      final resource = record(
        data[_org
            ? 'organization'
            : _inventory
            ? 'inventory'
            : 'workspace'],
      );
      final manager = _inventory
          ? resource['can_manage'] == true && resource['team_id'] != null
          : (_org ? ['owner', 'admin'] : ['owner', 'mentor']).contains(
              resource['role'],
            );
      if (manager &&
          !_personal &&
          widget.level != HierarchyLevel.organizations) {
        invitations = rows(
          (await widget.api.collaboration(
            '/access-invitations',
            query: {'scope': _scope, 'resource_id': widget.id},
          ))['invitations'],
        );
      }
      if (_workspace && !_personal) {
        requests = rows(
          (await widget.api.collaboration(
            '$_base/access-requests',
          ))['requests'],
        );
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        _inventories = inventories;
        _invitations = invitations;
        _requests = requests;
        _audit = audit;
        _spaces = spaces;
        _loading = false;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _load();
  }

  Future<void> _navigate(
    HierarchyLevel level,
    String id,
    String name, {
    String? org,
  }) => _push(
    HierarchyPage(
      api: widget.api,
      onOpenInventory: widget.onOpenInventory,
      level: level,
      id: id,
      name: name,
      organizationId: org,
    ),
  );
  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: AppText(message)));

  Future<bool> _mutate(
    String path, {
    String method = 'POST',
    Map<String, dynamic>? data,
  }) async {
    if (_busy) return false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.collaboration(
        path,
        method: method,
        data: data,
      );
      if (!mounted) return false;
      if (result.isEmpty) {
        throw const FormatException(
          'The change could not be confirmed. Refresh before retrying.',
        );
      }
      if (method == 'DELETE' &&
          (path == _base || path == '/teams/$_id') &&
          result['deleted'] != true) {
        throw const FormatException(
          'Deletion could not be confirmed. Refresh before retrying.',
        );
      }
      if (method == 'DELETE' &&
          path.endsWith('/leave') &&
          result['left'] != true) {
        throw const FormatException(
          'Leaving could not be confirmed. Refresh before retrying.',
        );
      }
      if (method == 'PATCH' && data?['name'] != null) {
        final saved = record(
          result['organization'] ?? result['workspace'] ?? result['inventory'],
        );
        if (saved['name'] != data!['name']) {
          throw const FormatException(
            'The name could not be confirmed saved. Refresh before retrying.',
          );
        }
      }
      if (result['invite_url'] != null && result['join_code'] != null) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const AppText('Workspace invitation'),
            content: SelectableText(
              '${result['invite_url']}\nCode: ${result['join_code']}\nThey must choose Join to gain access.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const AppText('Done'),
              ),
            ],
          ),
        );
      }
      if (!mounted) return false;
      if (result['invitation'] != null) {
        if (result['code'] == null || result['invite_url'] == null) {
          throw const FormatException(
            'Invitation could not be confirmed. Refresh before retrying.',
          );
        }
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const AppText('Invitation ready'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    result['email_sent'] == true
                        ? 'Email sent. They must accept to gain access.'
                        : 'Email could not be sent. Share this link or code. They must accept to gain access.',
                  ),
                  const SizedBox(height: 12),
                  SelectableText(result['invite_url'].toString()),
                  const SizedBox(height: 12),
                  SelectableText('Code: ${result['code']}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const AppText('Done'),
              ),
            ],
          ),
        );
      }
      if (mounted) await _load();
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = error);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _text(
    String title, {
    String initial = '',
    String label = 'Name',
    int limit = 100,
    bool allowEmpty = false,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: AppText(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: limit,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (allowEmpty || text.isNotEmpty) Navigator.pop(context, text);
            },
            child: const AppText('Continue'),
          ),
        ],
      ),
    );
    // Dialog exit animations still reference their controllers for one frame.
    Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
    return result;
  }

  Future<String?> _choose(String title, Map<String, String> choices) =>
      showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .5,
          minChildSize: .25,
          builder: (context, scroll) => ListView(
            controller: scroll,
            children: [
              ListTile(
                title: AppText(title, style: const TextStyle(fontSize: 20)),
              ),
              for (final choice in choices.entries)
                ListTile(
                  title: AppText(choice.value),
                  onTap: () => Navigator.pop(context, choice.key),
                ),
            ],
          ),
        ),
      );
  Future<bool> _confirm(String title, String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: AppText(title),
          content: AppText(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('Confirm'),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _join() async {
    final value = await _text(
      'Review invitation',
      label: 'Invitation link or code',
      limit: 300,
    );
    if (!mounted || value == null) return;
    final uri = Uri.tryParse(value);
    final linked = uri != null && uri.hasScheme
        ? Invitation.fromUri(uri)
        : null;
    final code = linked?.code ?? value.toUpperCase();
    if (linked?.kind == 'access' || RegExp(r'^[A-Z2-9]{12}$').hasMatch(code)) {
      await _push(AccessInvitationPage(api: widget.api, code: code));
      return;
    }
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
      _notice('Use a FindEZ invitation link or code.');
      return;
    }
    final kind =
        linked?.kind ??
        await _choose('Invitation type', {
          'team': 'Workspace',
          'space': 'Shared Space',
        });
    if (!mounted || kind == null) return;
    await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => InvitationDialog(
        api: widget.api,
        invitation: Invitation(
          kind: kind,
          code: code,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
        userId: widget.api.accountId ?? '',
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _rename([Map<String, dynamic>? inventory]) async {
    final target = inventory ?? _resource;
    final name = await _text('Rename', initial: target['name'].toString());
    if (name == null || !mounted) return;
    await _mutate(
      inventory != null ? '/inventories/${inventory['inventory_id']}' : _base,
      method: 'PATCH',
      data: {'name': name},
    );
  }

  Future<void> _deleteOrganization() async {
    final name = await _text(
      'Delete organization',
      label: 'Type the exact name: ${_resource['name']}',
    );
    if (!mounted || name == null) return;
    if (name != _resource['name']) {
      _notice('The name does not match.');
      return;
    }
    final ok = await _mutate(_base, method: 'DELETE', data: {'name': name});
    if (mounted && ok) Navigator.pop(context);
  }

  Future<void> _deleteWorkspace() async {
    if (!_owner || _busy) return;
    final deleted = await confirmWorkspaceDeletion(
      context,
      widget.api,
      id: widget.id!,
      name: _resource['name'].toString(),
    );
    if (mounted && deleted) Navigator.pop(context);
  }

  Future<void> _moveSpace(Map<String, dynamic> space) async {
    try {
      final workspace = record(_resource['workspace'])['workspace_id'];
      final directory = await _directory(workspaceId: workspace.toString());
      if (!mounted) return;
      final targets = directory.where(
        (row) =>
            row['workspace_id'] == workspace &&
            row['inventory_id'] != widget.id &&
            row['can_edit'] == true,
      );
      final target = await _choose('Move Space to inventory', {
        for (final row in targets)
          row['inventory_id'].toString(): row['name'].toString(),
      });
      if (!mounted || target == null) return;
      if (!await _confirm(
        'Move Space?',
        'Move this Space and its items to the selected inventory? Linked records may prevent the move.',
      )) {
        return;
      }
      if (mounted) {
        await _mutate(
          '$_base/spaces/${space['id']}/move',
          data: {'inventory_id': target},
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _create(String kind) async {
    final name = await _text('New $kind');
    if (!mounted || name == null) return;
    final path = kind == 'organization'
        ? '/organizations'
        : kind == 'workspace'
        ? '$_base/workspaces'
        : '$_base/inventories';
    await _mutate(path, data: {'name': name});
  }

  Future<void> _inviteOrganization() async {
    final email = await _text('Invite member', label: 'Email', limit: 254);
    if (!mounted || email == null) return;
    final role = await _choose('Organization role', {
      'member': 'Member',
      if (_resource['role'] == 'owner') 'admin': 'Admin',
    });
    if (!mounted || role == null) return;
    await _mutate('$_base/members', data: {'email': email, 'role': role});
  }

  Future<void> _assign() async {
    final members =
        rows(_inventory ? (_data?['members']) : (_data?['candidates'])).where(
          (row) =>
              !_inventory ||
              !['owner', 'mentor'].contains(row['workspace_role']),
        );
    final id = await _choose('Choose member', {
      for (final row in members)
        row['user_id'].toString(): row['display_name'].toString(),
    });
    if (!mounted || id == null) return;
    final role = await _choose('Role', {
      'viewer': 'Viewer',
      'editor': 'Editor',
      if (_inventory || _resource['role'] == 'owner') 'admin': 'Admin',
      'none': _inventory ? 'No access' : 'Remove from workspace',
      if (_inventory) 'inherit': 'Use default',
    });
    if (!mounted || role == null) return;
    if (!await _confirm(
      'Update access?',
      'New access requires the recipient to accept an invitation. Role changes and revocation apply immediately.',
    )) {
      return;
    }
    if (!mounted) return;
    await _mutate(
      '$_base/${_inventory ? 'access' : 'members'}/$id',
      method: 'PUT',
      data: {'role': role},
    );
  }

  Future<void> _workspaceMember(Map<String, dynamic> member) async {
    // Existing independent workspaces still support role changes and removal.
    final role = await _choose('Role', {
      'viewer': 'Viewer',
      'editor': 'Editor',
      if (_resource['role'] == 'owner') 'admin': 'Admin',
      'none': 'Remove from workspace',
    });
    if (!mounted || role == null) return;
    if (!await _confirm(
      'Update member?',
      'Apply this workspace role change?',
    )) {
      return;
    }
    if (mounted) {
      await _mutate(
        '$_base/members/${member['user_id']}',
        method: 'PUT',
        data: {'role': role},
      );
    }
  }

  Future<void> _location() async {
    final locations = rows(_data?['locations']);
    if (_inventory) {
      final id = await _choose('Attach workspace location', {
        for (final row in locations)
          row['location_id'].toString(): physicalLocationPath(row, locations),
      });
      if (mounted && id != null) {
        await _mutate('$_base/locations', data: {'location_id': id});
      }
    } else {
      final name = await _text('New physical location');
      if (!mounted || name == null) return;
      final parent = await _choose('Inside', {
        '': 'Top level',
        for (final row in locations)
          row['location_id'].toString(): physicalLocationPath(row, locations),
      });
      if (mounted && parent != null) {
        await _mutate(
          '$_base/locations',
          data: {'name': name, 'parent_id': parent.isEmpty ? null : parent},
        );
      }
    }
  }

  Future<void> _policy() async {
    final mode = await _choose('Inventory access', {
      'workspace': 'Workspace members',
      'restricted': 'Assigned members only',
    });
    if (!mounted || mode == null) return;
    final role = mode == 'restricted'
        ? 'viewer'
        : await _choose('Default role', {
            'viewer': 'Viewer',
            'editor': 'Editor',
          });
    if (mounted && role != null) {
      await _mutate(
        '$_base/access',
        method: 'PATCH',
        data: {'access_mode': mode, 'default_role': role},
      );
    }
  }

  Future<void> _directorySettings() async {
    final current = record(_data?['directory']);
    final description = await _text(
      'Directory description',
      label: 'Description',
      initial: current['description']?.toString() ?? '',
      limit: 500,
      allowEmpty: true,
    );
    if (!mounted || description == null) return;
    final visibility = await _choose('Directory visibility', {
      'workspace': 'Visible to workspace members',
      'hidden': 'Hidden without access',
    });
    if (mounted && visibility != null) {
      await _mutate(
        '/inventory-directory/$_id',
        method: 'PATCH',
        data: {'directory_visibility': visibility, 'description': description},
      );
    }
  }

  Widget _heading(String text) => widget.level != HierarchyLevel.organizations
      ? _HierarchySection(text)
      : Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: AppText(
            text,
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary(context),
            ),
          ),
        );
  Widget _row(
    String title, {
    String? detail,
    VoidCallback? onTap,
    Widget? trailing,
  }) => widget.level != HierarchyLevel.organizations
      ? PlaceRow(
          title: title,
          subtitle: detail,
          trailing: trailing,
          onTap: _busy ? null : onTap,
        )
      : ListTile(
          title: AppText(title),
          subtitle: detail == null ? null : AppText(detail),
          onTap: _busy ? null : onTap,
          trailing:
              trailing ??
              (onTap == null
                  ? null
                  : const Icon(Icons.chevron_right, size: 20)),
        );
  bool _matches(Object? name) =>
      name.toString().toLowerCase().contains(_query.toLowerCase());
  Widget _menu(Map<String, VoidCallback> actions) => PopupMenuButton<String>(
    tooltip: 'Actions',
    enabled: !_busy,
    onSelected: (action) => actions[action]!(),
    itemBuilder: (_) => actions.keys
        .map((name) => PopupMenuItem(value: name, child: AppText(name)))
        .toList(),
  );

  Future<void> _organizationMember(Map<String, dynamic> member) async {
    if (!await _confirm(
      'Remove member?',
      'Remove this person from the organization? Workspace assignments must be removed first.',
    )) {
      return;
    }
    if (mounted) {
      await _mutate('$_base/members/${member['user_id']}', method: 'DELETE');
    }
  }

  Future<void> _attachWorkspace() async {
    final id = await _choose('Choose your workspace', {
      for (final row in rows(_data?['attachable']))
        row['team_id'].toString(): row['name'].toString(),
    });
    if (mounted && id != null) await _mutate('$_base/workspaces/$id');
  }

  Widget _placeSection(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      title.toUpperCase(),
      style: PlaceTokens.section.copyWith(
        color: PlaceTokens.muted(context, PlaceTokens.label),
      ),
    ),
  );

  List<Widget> _organizationContents() {
    final workspaces = rows(
      _data?['workspaces'],
    ).where((w) => _matches(w['name'])).toList();
    final members = rows(
      _data?['members'],
    ).where((m) => m['role'] != 'none' && _matches(m['display_name'])).toList();
    return [
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Workspaces')),
          ButtonSegment(value: true, label: Text('People')),
        ],
        selected: {_organizationPeople},
        showSelectedIcon: false,
        onSelectionChanged: (value) => setState(() {
          _organizationPeople = value.single;
          _query = '';
        }),
      ),
      const SizedBox(height: 20),
      if (!_organizationPeople) ...[
        if (_manager) ...[
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _create('workspace'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New workspace'),
              style: FilledButton.styleFrom(
                backgroundColor: PlaceTokens.darkOrange,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (workspaces.isEmpty)
          PlaceCardList(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _query.isNotEmpty
                          ? 'No matching workspaces'
                          : 'No workspaces yet',
                      style: PlaceTokens.rowTitle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _manager
                          ? 'Create a workspace for your team or project.'
                          : 'Workspaces shared with you will appear here.',
                      style: PlaceTokens.text(13, color: PlaceTokens.dim),
                    ),
                  ],
                ),
              ),
            ],
          ),
        for (final ws in workspaces) ...[
          PlaceCardList(
            children: [
              PlaceRow(
                title: ws['name'].toString(),
                leading: PlaceBadge(ws['name'].toString()),
                subtitle: 'Workspace',
                onTap: _busy
                    ? null
                    : () async {
                        if (widget.onOpenWorkspace != null) {
                          await widget.onOpenWorkspace!(
                            ws['team_id'].toString(),
                          );
                        } else {
                          await _navigate(
                            HierarchyLevel.workspace,
                            ws['team_id'].toString(),
                            ws['name'].toString(),
                            org: widget.id,
                          );
                        }
                      },
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (_manager && rows(_data?['attachable']).isNotEmpty)
          TextButton(
            onPressed: _busy ? null : _attachWorkspace,
            child: const Text('Add existing workspace'),
          ),
      ] else ...[
        if (_manager) ...[
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy ? null : _inviteOrganization,
              child: const Text('Invite member'),
            ),
          ),
          const SizedBox(height: 14),
        ],
        PlaceCardList(
          children: [
            for (final (index, member) in members.indexed)
              PlaceRow(
                title: member['display_name']?.toString() ?? 'Member',
                leading: PlaceAvatar(
                  member['display_name']?.toString() ?? 'Member',
                  current: member['user_id'] == widget.api.accountId,
                  index: index,
                ),
                trailing: RoleTag(member['role']?.toString() ?? 'member'),
                onTap:
                    !_manager ||
                        _busy ||
                        member['role'] == 'owner' ||
                        member['role'] == 'admin' && !_owner
                    ? null
                    : () => _organizationMember(member),
              ),
            if (members.isEmpty) const PlaceRow(title: 'No matching people'),
          ],
        ),
        if (_invitations.isNotEmpty) ...[
          const SizedBox(height: 20),
          _placeSection('Pending invitations'),
          PlaceCardList(children: _pending().skip(1).toList()),
        ],
      ],
    ];
  }

  List<Widget> _inventorySearchContents() {
    final visible = _inventories.where((inv) => _matches(inv['name'])).toList();
    return [
      _placeSection('Inventories'),
      PlaceCardList(
        children: [
          for (final inv in visible)
            PlaceRow(
              title: inv['name'].toString(),
              subtitle: inv['can_open'] == true
                  ? [
                      if (inv['item_count'] is num)
                        '${inv['item_count']} items',
                      membershipRoleLabel(inv['role']?.toString() ?? ''),
                    ].where((s) => s.isNotEmpty).join(' · ')
                  : 'Access restricted',
              onTap: () async {
                if (inv['can_open'] == true) {
                  await widget.onOpenInventory(
                    inv['inventory_id'].toString(),
                    widget.id!,
                    _resource['organization_id']?.toString(),
                  );
                } else {
                  await _push(
                    RestrictedInventoryPage(
                      api: widget.api,
                      id: inv['inventory_id'].toString(),
                      workspaceId: widget.id!,
                      onOpenInventory: widget.onOpenInventory,
                    ),
                  );
                }
              },
            ),
          if (visible.isEmpty) const PlaceRow(title: 'No matching inventories'),
        ],
      ),
    ];
  }

  List<Widget> _managementContents() {
    if (widget.panel != null) return _contents();
    final result = <Widget>[];
    var group = <Widget>[];
    void flush() {
      if (group.isNotEmpty) {
        result.add(PlaceCardList(children: group));
        group = [];
      }
    }

    for (final child in _contents()) {
      if (child is _HierarchySection) {
        flush();
        if (result.isNotEmpty) result.add(const SizedBox(height: 20));
        result.add(_placeSection(child.title));
      } else if (child is ExpansionTile) {
        flush();
        result.add(const SizedBox(height: 20));
        result.add(child);
      } else {
        group.add(child);
      }
    }
    flush();
    return result;
  }

  Widget _placeDirectoryPage() => PlaceTheme(
    child: Builder(
      builder: (context) => Scaffold(
        backgroundColor: PlaceTokens.background,
        appBar: AppBar(
          backgroundColor: PlaceTokens.background,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          toolbarHeight: 32 + MediaQuery.textScalerOf(context).scale(24) * 2,
          title: Text(
            widget.panel == HierarchyPanel.people
                ? 'People'
                : widget.panel == HierarchyPanel.activity
                ? 'Activity'
                : _title,
            style: PlaceTokens.title,
            maxLines: 2,
          ),
          actions: [
            if (_data != null &&
                !widget.focusSearch &&
                (_org && _owner ||
                    _workspace && _owner && !_personal ||
                    _inventory && _resource['can_rename'] == true))
              _menu({
                'Rename': () => _rename(),
                if (_org && _owner) 'Delete': _deleteOrganization,
                if (_workspace && _owner && !_personal)
                  'Delete workspace': _deleteWorkspace,
              }),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              if (_loading || _busy) const LinearProgressIndicator(),
              if (_error != null) ...[
                Text(describeError(_error!).$1, style: PlaceTokens.rowTitle),
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Retry'),
                ),
              ],
              if (_data != null) ...[
                if (!_inventory && widget.panel == null) ...[
                  TextField(
                    autofocus: widget.focusSearch,
                    style: PlaceTokens.rowTitle,
                    decoration: InputDecoration(
                      hintText: _org
                          ? (_organizationPeople
                                ? 'Search people'
                                : 'Search workspaces')
                          : 'Search inventories',
                      semanticCounterText: 'Search workspaces and people',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: PlaceTokens.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: PlaceTokens.orange),
                      ),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 20),
                ],
                ...(_org
                    ? _organizationContents()
                    : widget.focusSearch
                    ? _inventorySearchContents()
                    : _managementContents()),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _contents() {
    if (_data == null) return [];
    if (_workspace && widget.panel == HierarchyPanel.activity) {
      return _history();
    }
    if (_workspace && widget.panel == HierarchyPanel.people) {
      return [
        Padding(
          padding: EdgeInsets.zero,
          child: PlaceCardList(
            children: [
              for (final (index, member) in rows(
                _data?['members'],
              ).where((m) => m['role'] != 'none').indexed)
                PlaceRow(
                  title: member['display_name']?.toString() ?? 'Member',
                  leading: PlaceAvatar(
                    member['display_name']?.toString() ?? 'Member',
                    current: member['user_id'] == widget.api.accountId,
                    index: index,
                  ),
                  trailing: RoleTag(
                    membershipRoleLabel(member['role'].toString()),
                  ),
                  onTap:
                      _manager &&
                          member['role'] != 'owner' &&
                          (!['admin', 'mentor'].contains(member['role']) ||
                              _owner)
                      ? () => _workspaceMember(member)
                      : null,
                ),
            ],
          ),
        ),
        if (_manager)
          _row(
            'Manage workspace',
            onTap: () => _navigate(
              HierarchyLevel.workspace,
              widget.id!,
              _title,
              org: widget.organizationId,
            ),
          ),
        if (_manager && _resource['organization_id'] != null)
          _row('Assign organization member', onTap: _assign),
        if (_manager && _resource['organization_id'] == null)
          _row(
            'Invite workspace member',
            onTap: () async {
              final email = await _text(
                'Invite member',
                label: 'Email',
                limit: 254,
              );
              if (mounted && email != null) {
                await _mutate('/teams/$_id/invite', data: {'email': email});
              }
            },
          ),
        ..._pending(),
        if (_requests.isNotEmpty) ...[
          _heading('Access requests'),
          for (final request in _requests)
            _row(
              request['inventory_name'].toString(),
              detail: request['requester_name']?.toString(),
              onTap: () async {
                final action = await _choose('Access request', {
                  'approve': 'Approve viewer access',
                  'decline': 'Decline',
                });
                if (mounted && action != null) {
                  await _mutate(
                    '/inventory-access-requests/${request['request_id']}/decision',
                    data: {'action': action},
                  );
                }
              },
            ),
        ],
        if (!_owner)
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            child: TextButton(
              onPressed: _leaveWorkspace,
              style: TextButton.styleFrom(
                foregroundColor: PlaceTokens.destructive,
                minimumSize: const Size(44, 44),
              ),
              child: Text(
                'Leave workspace',
                style: PlaceTokens.text(
                  16,
                  weight: FontWeight.w500,
                  color: PlaceTokens.destructive,
                ),
              ),
            ),
          ),
      ];
    }
    if (widget.level == HierarchyLevel.organizations) {
      final orgs = rows(
        _data?['organizations'],
      ).where((row) => _matches(row['name']));
      final workspaces = rows(
        _data?['workspaces'],
      ).where((row) => row['kind'] != 'personal' && _matches(row['name']));
      return [
        _row(
          'Personal',
          detail: 'Your private inventories',
          onTap: () =>
              _navigate(HierarchyLevel.workspace, 'personal', 'Personal'),
        ),
        _heading('Organizations'),
        if (orgs.isEmpty)
          ListTile(
            title: AppText(
              _query.isEmpty
                  ? 'No organizations yet'
                  : 'No matching organizations',
            ),
          ),
        for (final org in orgs)
          _row(
            org['name'].toString(),
            detail: org['role'].toString(),
            onTap: () => _navigate(
              HierarchyLevel.organization,
              org['organization_id'].toString(),
              org['name'].toString(),
            ),
          ),
        _row('New organization', onTap: () => _create('organization')),
        _heading('Workspaces'),
        for (final ws in workspaces)
          _row(
            ws['name'].toString(),
            detail: membershipRoleLabel(ws['role'].toString()),
            onTap: () => _navigate(
              HierarchyLevel.workspace,
              ws['workspace_id'].toString(),
              ws['name'].toString(),
            ),
          ),
        if (workspaces.isEmpty)
          const ListTile(title: AppText('No assigned workspaces')),
        _row(
          'New workspace',
          onTap: () async {
            final name = await _text('New workspace');
            if (mounted && name != null) {
              await _mutate(
                '/teams',
                data: {
                  'name': name,
                  'program': 'other',
                  'custom_category': 'Workspace',
                },
              );
            }
          },
        ),
        if (rows(_data?['shared']).isNotEmpty) _heading('Shared with me'),
        for (final membership in rows(_data?['shared'])) _sharedRow(membership),
        _heading('Account'),
        _row(
          'Notifications and invitations',
          onTap: () => _push(NotificationsPage(api: widget.api)),
        ),
        _row('Join with a code', onTap: _join),
        _row(
          'Profile and settings',
          onTap: () => _push(ProfilePage(api: widget.api)),
        ),
      ];
    }
    if (_org) return _organizationContents();
    if (_workspace) {
      return [
        _heading('Inventories'),
        if (_manager)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _create('inventory'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New inventory'),
            ),
          ),
        for (final inv in _inventories.where((row) => _matches(row['name'])))
          InventoryDirectoryRow(
            inventory: inv,
            api: widget.api,
            refresh: _load,
            onOpen: () async {
              if (inv['can_open'] == true) {
                await widget.onOpenInventory(
                  inv['inventory_id'].toString(),
                  widget.id!,
                  _resource['organization_id']?.toString(),
                );
              } else {
                await _push(
                  RestrictedInventoryPage(
                    api: widget.api,
                    id: inv['inventory_id'].toString(),
                    workspaceId: widget.id!,
                    onOpenInventory: widget.onOpenInventory,
                  ),
                );
              }
            },
          ),
        if (_inventories.isEmpty) const PlaceRow(title: 'No inventories yet'),
        if (!_personal) ...[
          _heading('Settings'),
          _row(
            'Workspace name',
            detail: _resource['name']?.toString(),
            onTap: _owner ? () => _rename() : null,
          ),
          _row(
            'Your role',
            detail: membershipRoleLabel(_resource['role']?.toString() ?? ''),
          ),
          if (_owner)
            TextButton(
              onPressed: _busy ? null : _deleteWorkspace,
              style: TextButton.styleFrom(
                foregroundColor: PlaceTokens.destructive,
              ),
              child: const Text('Delete workspace'),
            ),
          if (_manager) ..._locations(),
          _row(
            'People and access',
            onTap: () => _push(
              HierarchyPage(
                api: widget.api,
                onOpenInventory: widget.onOpenInventory,
                level: HierarchyLevel.workspace,
                id: widget.id,
                name: _resource['name']?.toString(),
                panel: HierarchyPanel.people,
              ),
            ),
          ),
        ],
      ];
    }
    return [
      _row(
        'Your role',
        detail: membershipRoleLabel(_resource['role']?.toString() ?? ''),
      ),
      if (_resource['can_manage'] == true && _resource['team_id'] != null) ...[
        _row(
          'Inventory access',
          detail: _resource['access_mode'] == 'restricted'
              ? 'Assigned members only'
              : 'Workspace permissions',
          onTap: _policy,
        ),
        _row('Directory visibility and description', onTap: _directorySettings),
      ],
      ..._people(),
      if (_manager) _row('Assign member access', onTap: _assign),
      ..._pending(),
      if (_manager) ..._locations(),
      _heading('Inventory Spaces'),
      for (final space in _spaces)
        _row(
          space['name'].toString(),
          detail: _resource['can_edit'] == true
              ? 'Move to another inventory'
              : null,
          onTap: _resource['can_edit'] != true ? null : () => _moveSpace(space),
        ),
      if (_spaces.isEmpty)
        const ListTile(title: AppText('No Spaces yet. Add one in Find.')),
      ..._history(),
    ];
  }

  Widget _sharedRow(Map<String, dynamic> membership) {
    final shared = record(membership['team_shares'] ?? membership);
    return _row(
      shared['share_name']?.toString() ?? 'Shared Space',
      detail: membership['permission'] == 'edit' ? 'Editor' : 'Viewer',
      onTap: () => _push(
        SharedInventoryPage(
          api: widget.api,
          shareId: shared['share_id'].toString(),
          shareName: shared['share_name']?.toString() ?? 'Shared Space',
          permission: membership['permission']?.toString() ?? 'view',
        ),
      ),
    );
  }

  List<Widget> _people() => [
    _heading('People'),
    for (final member in rows(
      _data?['members'],
    ).where((row) => row['role'] != 'none'))
      _row(
        member['display_name']?.toString() ?? 'Member',
        detail:
            '${_org ? member['role'] : membershipRoleLabel(member['role'].toString())}${member['source'] == 'workspace' ? ' | inherited' : ''}',
        onTap:
            !_manager ||
                member['role'] == 'owner' ||
                (['admin', 'mentor'].contains(member['role']) && !_owner)
            ? null
            : () async {
                if (_org) {
                  if (!await _confirm(
                    'Remove member?',
                    'Remove this person from the organization? Workspace assignments must be removed first.',
                  )) {
                    return;
                  }
                  if (mounted) {
                    await _mutate(
                      '$_base/members/${member['user_id']}',
                      method: 'DELETE',
                    );
                  }
                } else if (_workspace) {
                  await _workspaceMember(member);
                } else {
                  await _assign();
                }
              },
      ),
  ];
  List<Widget> _pending() => _invitations.isEmpty
      ? []
      : [
          _heading('Pending invitations'),
          for (final invite in _invitations)
            _row(
              invite['recipient_email']?.toString() ??
                  invite['email']?.toString() ??
                  'Invited member',
              detail: '${invite['role']} | ${invite['status']}',
              onTap: () async {
                if (!await _confirm(
                  'Cancel invitation?',
                  'This will prevent the recipient from accepting it.',
                )) {
                  return;
                }
                if (mounted) {
                  await _mutate(
                    '/access-invitations/${invite['invitation_id']}/decision',
                    data: {'action': 'cancel'},
                  );
                }
              },
            ),
        ];
  List<Widget> _locations() {
    final locations = rows(_data?['locations']);
    return [
      _heading('Shared physical locations'),
      for (final location in locations)
        _row(physicalLocationPath(location, locations)),
      _row(
        _inventory ? 'Attach workspace location' : 'New physical location',
        onTap: _location,
      ),
    ];
  }

  List<Widget> _history() => [
    ExpansionTile(
      title: const AppText('Activity'),
      shape: const Border(),
      collapsedShape: const Border(),
      children: [
        for (final event in _audit)
          _row(
            event['action'].toString().replaceAll('_', ' '),
            detail: event['created_at']?.toString(),
          ),
        if (_audit.isEmpty)
          const ListTile(title: AppText('No recorded changes yet')),
      ],
    ),
  ];

  Future<void> _leaveWorkspace() async {
    if (!await _confirm(
      'Leave workspace?',
      'You will lose this workspace access. Your own physical records remain yours.',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await _mutate('/teams/$_id/leave', method: 'DELETE');
    if (mounted && ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) =>
      widget.level != HierarchyLevel.organizations
      ? _placeDirectoryPage()
      : Scaffold(
          appBar: AppBar(
            leading: widget.onClose == null
                ? null
                : CloseButton(onPressed: widget.onClose),
            title: AppText(
              widget.panel == HierarchyPanel.people
                  ? 'People'
                  : widget.panel == HierarchyPanel.activity
                  ? 'Activity'
                  : _title,
            ),
            actions: [
              if (_data != null &&
                  (_org && _owner ||
                      _workspace && _owner && !_personal ||
                      _inventory && _resource['can_rename'] == true))
                _menu({
                  'Rename': () => _rename(),
                  if (_org && _owner) 'Delete': _deleteOrganization,
                  if (_workspace && _owner && !_personal)
                    'Delete workspace': _deleteWorkspace,
                }),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading || _busy ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_loading || _busy) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(describeError(_error!).$1),
                        TextButton(
                          onPressed: _busy ? null : _load,
                          child: const AppText('Retry'),
                        ),
                      ],
                    ),
                  ),
                if (_data != null && !_inventory && widget.panel == null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      autofocus: widget.focusSearch,
                      decoration: const InputDecoration(
                        labelText: 'Search names',
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                if (!_loading) ..._contents(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
}

class RestrictedInventoryPage extends StatefulWidget {
  const RestrictedInventoryPage({
    super.key,
    required this.api,
    required this.id,
    required this.workspaceId,
    required this.onOpenInventory,
  });
  final ApiClient api;
  final String id, workspaceId;
  final OpenInventory onOpenInventory;
  @override
  State<RestrictedInventoryPage> createState() =>
      _RestrictedInventoryPageState();
}

class _RestrictedInventoryPageState extends State<RestrictedInventoryPage> {
  Map<String, dynamic>? _data;
  Object? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
      _data = null;
    });
    try {
      final result = await widget.api.collaboration(
        '/inventory-directory/${widget.id}',
      );
      if (result['workspace']?['workspace_id'] != widget.workspaceId) {
        throw const FormatException('This inventory moved. Choose it again.');
      }
      if (mounted) setState(() => _data = result);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pending = record(_data?['request']);
      final result = await widget.api.collaboration(
        pending.isEmpty
            ? '/inventory-directory/${widget.id}/request'
            : '/inventory-access-requests/${pending['request_id']}/decision',
        method: 'POST',
        data: pending.isEmpty ? null : {'action': 'cancel'},
      );
      if (result['request']?['request_id'] == null) {
        throw const FormatException(
          'The request could not be confirmed. Refresh before retrying.',
        );
      }
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('Inventory access')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) AppText(describeError(_error!).$1),
        if (_data != null) ...[
          AppText(
            _data!['inventory']['name'].toString(),
            style: const TextStyle(fontSize: 24),
          ),
          if (_data!['inventory']['can_open'] == true)
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => widget.onOpenInventory(
                      widget.id,
                      widget.workspaceId,
                      _data!['workspace']['organization_id']?.toString(),
                    ),
              child: const AppText('Open inventory'),
            )
          else ...[
            const SizedBox(height: 16),
            const AppText(
              'Access restricted. An administrator must approve viewer access.',
            ),
            if (_data!['request'] != null)
              const AppText('Your request is pending.'),
            TextButton(
              onPressed: _busy ? null : _request,
              child: AppText(
                _data!['request'] == null
                    ? 'Request viewer access'
                    : 'Cancel request',
              ),
            ),
          ],
        ],
        TextButton(
          onPressed: _busy ? null : _load,
          child: const AppText('Check access'),
        ),
      ],
    ),
  );
}
