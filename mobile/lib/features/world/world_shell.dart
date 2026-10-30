import '../../core/ui/scroll_glass.dart';
import '../../core/ui/skeleton.dart';
import '../../core/ui/content_loading.dart';
import 'package:dio/dio.dart';
import '../../core/account_refresh.dart';
import 'native_bottom_tabs.dart';
import 'retained_tab_transition.dart';
import '../notifications/notification_bell.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../../core/ui/liquid_surface.dart';
import '../../core/ui/native_menu_button.dart';
import '../../core/ui/native_presentation.dart';
import 'world_style.dart';
import '../inventory/space_directory.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/chat_source.dart';
import '../../core/api_error.dart';
import '../../core/inventory_context.dart';
import '../../core/place_session.dart';
import '../../core/profile_store.dart';
import '../../core/low_stock_prefs.dart';
import '../../core/ui/member_avatar.dart';
import '../chat/chat_page.dart';
import '../inventory/inventory_page.dart';
import '../inventory/item_detail_sheet.dart';
import '../../core/ask_answer.dart';
import '../profile/account_menu.dart';
import '../workspaces/organization_pill.dart';
import '../workspaces/workspace_home.dart';
import '../scan/import_sheet_page.dart';
import '../scan/space_barcode_flow.dart';
import '../review/review_queue_page.dart';
import '../home/home_page.dart';
import '../documents/documents_page.dart';
import '../checkout/checkout_page.dart';
import '../scan/project_kits_page.dart';

/// Organization is a knowledge boundary; inventory clients remain explicit for writes.
class WorldShell extends StatefulWidget {
  const WorldShell({
    super.key,
    required this.session,
    this.initialChatSource,
    this.onInitialChatReady,
  });
  final PlaceSession session;
  final ChatSource? initialChatSource;
  final VoidCallback? onInitialChatReady;
  @override
  State<WorldShell> createState() => _WorldShellState();
}

class _WorldShellState extends State<WorldShell> {
  late final AccountRefresh _accountRefresh;
  late ApiClient _chatApi;
  late ProfileStore _profile;
  String _world = '';
  int _tab = 0, _revision = 0;
  bool _chatFocused = false;
  bool _loadedNavigation = false;
  VoidCallback? _history;
  Map<String, dynamic>? _directory;
  List<Map<String, dynamic>>? _spaceGroups;
  Object? _spacesError;
  Object? _error;
  int _loadGeneration = 0;
  final _search = TextEditingController();
  bool _searchingSpaces = false;
  bool _creatingSpace = false;
  @override
  void initState() {
    super.initState();
    _accountRefresh = AccountRefresh(
      refresh: _load,
      isActive: () =>
          mounted &&
          (ModalRoute.of(context)?.isCurrent ?? true) &&
          (_loadedNavigation &&
              !widget.session.loading &&
              !_creatingSpace &&
              !_chatFocused),
    );
    _profile = ProfileStore(api: widget.session.api)
      ..addListener(_profileChanged);
    unawaited(_profile.load());
    widget.session.addListener(_changed);
    _selectWorld();
  }

  void _profileChanged() {
    if (mounted) setState(() {});
  }

  void _changed() {
    if (!mounted) return;
    if ((widget.session.organizationId ?? 'personal') != _world ||
        (!_loadedNavigation &&
            widget.session.navigationReady &&
            !widget.session.loading)) {
      _selectWorld();
    }
    setState(() {});
  }

  void _selectWorld() {
    _world = widget.session.organizationId ?? 'personal';
    final world = _world;
    _chatApi = ApiClient.forWorld(
      widget.session.api,
      world,
      isCurrent: () =>
          mounted &&
          _world == world &&
          widget.session.navigationReady &&
          !widget.session.loading &&
          widget.session.error == null &&
          widget.session.organizationId == (world == 'personal' ? null : world),
    );
    _directory = null;
    _spaceGroups = null;
    _spacesError = null;
    _error = null;
    _tab = 0;
    _chatFocused = false;
    _history = null;
    _search.clear();
    _searchingSpaces = false;
    _loadedNavigation =
        widget.session.navigationReady && !widget.session.loading;
    if (_loadedNavigation) unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final data = await _chatApi.collaboration('/worlds/$_world/directory');
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _directory = data;
          _error = null;
        });
        try {
          final spaces = await _chatApi.collaboration('/worlds/$_world/spaces');
          if (mounted && generation == _loadGeneration) {
            setState(() {
              _spaceGroups = placeRows(spaces['inventories']);
              _spacesError = null;
            });
          }
        } catch (error) {
          if (mounted && generation == _loadGeneration) {
            setState(() => _spacesError = error);
          }
        }
      }
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _error = error;
          if (error is DioException &&
              [401, 403, 404, 410].contains(error.response?.statusCode)) {
            _directory = null;
            _spaceGroups = null;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _accountRefresh.dispose();
    _loadGeneration++;
    widget.session.removeListener(_changed);
    _profile.removeListener(_profileChanged);
    _profile.dispose();
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _inventories =>
      placeRows(_directory?['inventories']);
  Future<void> _push(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => WorldStyle(child: page)));
    if (mounted) unawaited(_load());
  }

  Future<ApiClient> _inventory(Map<String, dynamic> row) async {
    final world = _world;
    final data = await widget.session.api.collaboration(
      '/inventories/${row['inventory_id']}',
    );
    final inventory = InventoryContext.fromJson(
      Map<String, dynamic>.from(data['inventory'] as Map),
      accountId: widget.session.accountId,
      expectedInventory: row['inventory_id'],
      expectedWorkspace: row['workspace_id'],
    );
    if ((inventory.organizationId ?? 'personal') != world ||
        !mounted ||
        world != _world) {
      throw const FormatException('The organization changed. Choose again.');
    }
    return ApiClient.forInventory(
      widget.session.api,
      inventory,
      isCurrent: () => mounted && _world == world,
    );
  }

  Future<ApiClient?> _chooseInventory({bool writable = false}) async {
    final rows = _inventories
        .where((r) => !writable || r['can_edit'] == true)
        .toList();
    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Create an inventory in Ask, or choose an inventory you can edit.',
            ),
          ),
        );
      }
      return null;
    }
    final choice = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Choose inventory')),
          for (final row in rows)
            ListTile(
              title: Text(row['name'].toString()),
              subtitle: Text(row['workspace_name'].toString()),
              onTap: () => Navigator.pop(context, row),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return null;
    return _inventory(choice);
  }

  Future<void> _guard(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
      }
    }
  }

  Future<void> _capture(String kind) => _guard(() async {
    final api = await _chooseInventory(writable: true);
    if (api == null || !mounted) return;
    final spaces = await api.listSpaces();
    if (!mounted) return;
    final space = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Save to Space')),
          if (spaces.isEmpty)
            const ListTile(title: Text('Create a Space in Ask first.')),
          for (final row in spaces)
            ListTile(
              title: Text(row['name'].toString()),
              onTap: () => Navigator.pop(context, row),
            ),
        ],
      ),
    );
    if (space == null || !mounted) return;
    var saved = false;
    if (kind == 'spreadsheet') {
      saved =
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) =>
                  ImportSheetPage(api: api, location: space['name'].toString()),
            ),
          ) ==
          true;
    } else {
      await runSpaceBarcodeFlow(
        context: context,
        api: api,
        preselectedSpace: space['name'].toString(),
        onItemsSaved: () async {
          saved = true;
        },
      );
    }
    if (saved && mounted) {
      await _openSpace(api, space);
    }
    if (mounted) unawaited(_load());
  });
  Future<void> _account() async {
    await showAccountMenu(context, api: widget.session.api, profile: _profile);
    if (mounted) await _profile.load(force: true);
  }

  Future<void> _openChatResource(Map<String, dynamic> value) => _guard(
    () async {
      final link = AskResourceLink.parse(value);
      if (link == null) return;
      final world = _world;
      final data = await _chatApi.collaboration(
        '/worlds/$world/resources/${link.inventoryId}/${link.kind}/${link.id}',
      );
      if (!mounted || world != _world) return;
      final api = await _inventory(data);
      if (!mounted || world != _world) return;
      api.assertCurrentContext();
      final resource = Map<String, dynamic>.from(data['resource'] as Map);
      if (link.kind == 'inventory') {
        await _push(InventorySpacesPage(api: api));
      } else if (link.kind == 'project') {
        await _push(
          ProjectKitDetailPage(
            api: api,
            initial: ProjectKitDetail.fromJson(resource),
          ),
        );
      } else if (link.kind == 'space') {
        await _openSpace(api, resource);
      } else {
        final item = InventoryItem.fromJson(resource);
        await showItemDetailSheet(
          context,
          item: item,
          api: api,
          spaceName: item.location,
          permission: api.canEdit ? 'edit' : 'view',
          onItemUpdated: (_) => unawaited(_load()),
        );
      }
    },
  );

  Future<void> _openSpace(ApiClient api, Map<String, dynamic> space) async {
    final result = await api.searchItems(query: '');
    final thresholds = await LowStockPrefs.loadAll();
    if (!mounted) return;
    api.assertCurrentContext();
    final name = space['name'].toString();
    await _push(
      LocationItemsPage(
        api: api,
        location: name,
        items: result.items
            .where(
              (item) => item.spaceId != null
                  ? item.spaceId == space['id']
                  : item.location == name,
            )
            .toList(),
        allItems: result.items,
        thresholds: thresholds,
        spaceId: space['id']?.toString(),
        readOnly: !api.canEdit,
      ),
    );
  }

  Future<void> _newSpace() async {
    if (_creatingSpace) return;
    setState(() => _creatingSpace = true);
    try {
      await _guard(() async {
        final api = await _chooseInventory(writable: true);
        if (api == null || !mounted) return;
        if (await createDirectorySpace(context, api)) await _load();
      });
    } finally {
      if (mounted) setState(() => _creatingSpace = false);
    }
  }

  Widget _spaces(BuildContext context) {
    final error = _error ?? _spacesError;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(describeError(error).$1),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_spaceGroups == null) {
      return const ContentLoading(label: 'Loading Spaces...');
    }
    final query = _search.text.trim().toLowerCase();
    final rows = <Map<String, dynamic>>[];
    for (final group in _spaceGroups!) {
      for (final space in placeRows(group['spaces'])) {
        if ('${space['name']} ${group['name']} ${group['workspace_name']}'
            .toLowerCase()
            .contains(query)) {
          rows.add({'group': group, 'space': space});
        }
      }
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 82, 20, 100),
        children: [
          if (_searchingSpaces)
            LiquidSurface(
              radius: 24,
              quiet: true,
              shadow: false,
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search Spaces',
                  prefixIcon: Icon(CupertinoIcons.search, size: 20),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          if (_searchingSpaces) const SizedBox(height: 16),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                query.isNotEmpty
                    ? 'No matching Spaces.'
                    : 'Your world starts with one thing. Describe it in Ask or add a photo.',
              ),
            ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SpaceDirectoryTile(
                key: ValueKey(
                  '${row['group']['inventory_id']}:${spaceIdentifier(row['space'])}',
                ),
                space: row['space'],
                subtitle:
                    '${row['group']['workspace_name']} · ${row['group']['name']}',
                resolveApi: () => _inventory(row['group']),
                onChanged: _load,
              ),
            ),
          TextButton.icon(
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Browse inventories'),
            onPressed: () => _guard(() async {
              final api = await _chooseInventory();
              if (api != null && mounted) {
                await _push(InventorySpacesPage(api: api));
              }
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _openInventorySpaces(
    String id,
    String workspace,
    String? organization,
  ) => _guard(() async {
    if (organization != widget.session.organizationId) return;
    final api = await _inventory({
      'inventory_id': id,
      'workspace_id': workspace,
    });
    if (mounted) await _push(InventorySpacesPage(api: api));
  });

  Future<void> _tool(String kind) => _guard(() async {
    final api = await _chooseInventory();
    if (api == null || !mounted) return;
    if (kind == 'Projects') {
      final spaces = await api.listSpaces();
      if (!mounted) return;
      final name = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        builder: (context) => ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose a Space')),
            for (final space in spaces)
              ListTile(
                title: Text(space['name'].toString()),
                onTap: () => Navigator.pop(context, space['name'].toString()),
              ),
          ],
        ),
      );
      if (name != null && mounted) {
        await _push(ProjectKitsPage(api: api, location: name));
      }
      return;
    }
    final page = switch (kind) {
      'Review' => ReviewQueuePage(api: api),
      'Documents and notes' => DocumentsPage(api: api),
      'Lent items' => CheckoutPage(api: api),
      _ => Scaffold(
        appBar: AppBar(title: const Text('Overview')),
        body: HomePage(
          api: api,
          onOpenAsk: (message) =>
              _push(ChatPage(api: _chatApi, initialMessage: message)),
          onOpenReview: () => _push(ReviewQueuePage(api: api)),
          onOpenCheckouts: () => _push(CheckoutPage(api: api)),
          onOpenSpace: (_) =>
              _push(InventoryPage(api: api, refreshToken: _revision)),
        ),
      ),
    };
    await _push(page);
  });
  Widget _more(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      for (final label in [
        ('Overview', CupertinoIcons.square_grid_2x2),
        ('Review', CupertinoIcons.checkmark_seal),
        ('Projects', CupertinoIcons.cube_box),
        ('Documents and notes', CupertinoIcons.doc_text),
        ('Lent items', CupertinoIcons.arrow_right_arrow_left),
      ])
        ListTile(
          leading: Icon(label.$2),
          title: Text(label.$1),
          trailing: const Icon(CupertinoIcons.chevron_right, size: 15),
          onTap: () => _tool(label.$1),
        ),
      const Divider(),
      ListTile(
        leading: const Icon(CupertinoIcons.person_2),
        title: const Text('Workspaces and team tools'),
        subtitle: const Text('People, tasks, files, activity and settings'),
        trailing: const Icon(CupertinoIcons.chevron_right, size: 15),
        onTap: () => _push(
          WorkspaceHome(
            session: widget.session,
            onOpenInventory: _openInventorySpaces,
          ),
        ),
      ),
      ListTile(
        leading: const Icon(CupertinoIcons.gear),
        title: const Text('Account settings'),
        trailing: const Icon(CupertinoIcons.chevron_right, size: 15),
        onTap: _account,
      ),
    ],
  );
  @override
  Widget build(BuildContext context) =>
      WorldStyle(child: Builder(builder: _buildWorld));

  Widget _tabHeader(BuildContext context, int index) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
    child: Row(
      children: [
        Expanded(
          child: Align(
            heightFactor: 1,
            alignment: Alignment.centerLeft,
            child: index != 0
                ? Text(
                    index == 1 ? 'Spaces' : 'More',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : OrganizationPill(
                    api: widget.session.api,
                    id: widget.session.organizationId,
                    name: widget.session.organizationName,
                    glass: true,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.2,
                    ),
                    onSelected: widget.session.selectOrganization,
                  ),
          ),
        ),
        if (index == 0) NotificationBell(api: _chatApi),
        if (index == 0)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: usesNativePresentation
                ? NativeToolbarButton(
                    symbol: 'clock',
                    label: 'Chat history',
                    glass: false,
                    symbolSize: 18,
                    onPressed: _history,
                  )
                : IconButton(
                    tooltip: 'Chat history',
                    onPressed: _history,
                    icon: const Icon(CupertinoIcons.clock, size: 18),
                  ),
          ),
        if (index == 1)
          IconButton(
            tooltip: _searchingSpaces ? 'Close Space search' : 'Search Spaces',
            icon: Icon(
              _searchingSpaces ? CupertinoIcons.xmark : CupertinoIcons.search,
              size: 22,
            ),
            onPressed: () => setState(() {
              _searchingSpaces = !_searchingSpaces;
              _search.clear();
            }),
          ),
        if (index == 0)
          IconButton(
            tooltip: 'Account',
            onPressed: _account,
            icon: MemberAvatar(
              name: _profile.name,
              photoUrl: _profile.photoUrl,
              size: 36,
            ),
          ),
      ],
    ),
  );

  Widget _buildWorld(BuildContext context) {
    if (!_loadedNavigation) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: widget.session.error == null
                ? const SkeletonPage(layout: SkeletonLayout.chat)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(describeError(widget.session.error!).$1),
                      TextButton(
                        onPressed: widget.session.restoreNavigation,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final focused = _tab == 0 && _chatFocused;
    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.white,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: !dark && !_chatFocused && _tab == 0
              ? RadialGradient(
                  center: const Alignment(.3, 1.2),
                  radius: 1.15,
                  colors: [
                    Colors.black.withValues(alpha: .035),
                    Colors.transparent,
                  ],
                )
              : null,
        ),
        child: SafeArea(
          top: !focused,
          child: Column(
            children: [
              Expanded(
                key: const ValueKey('world-content'),
                child: RetainedTabTransition(
                  index: _tab,
                  children: [
                    Column(
                      children: [
                        if (!_chatFocused) _tabHeader(context, 0),
                        Expanded(
                          child: ChatPage(
                            key: ValueKey(_world),
                            api: _chatApi,
                            onInitialSourceReady: widget.onInitialChatReady,
                            initialSource: _world == 'personal'
                                ? widget.initialChatSource
                                : null,
                            inPageView: true,
                            worldHeading: _directory == null
                                ? 'Your physical world, remembered.'
                                : _directory?['has_items'] != true
                                ? 'Create your inventory world.'
                                : "Find what's in your world.",
                            onChatStateChanged: (value) {
                              if (mounted) setState(() => _chatFocused = value);
                            },
                            onRegisterOpenHistory: (callback) {
                              _history = callback;
                            },
                            onBack: () {
                              if (mounted) setState(() => _chatFocused = false);
                            },
                            onCaptureAction: _capture,
                            onOpenDestination: _openChatResource,
                            onInventoryMutated: () {
                              _revision++;
                              unawaited(_load());
                            },
                          ),
                        ),
                      ],
                    ),
                    Stack(
                      children: [
                        Positioned.fill(child: _spaces(context)),
                        Align(
                          alignment: Alignment.topCenter,
                          child: ScrollGlass(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _tabHeader(context, 1),
                            ),
                          ),
                        ),
                        if (!keyboard &&
                            _inventories.any((row) => row['can_edit'] == true))
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 8,
                                bottom: 12,
                              ),
                              child: LiquidSurface(
                                radius: 28,
                                child: TextButton.icon(
                                  onPressed: _creatingSpace ? null : _newSpace,
                                  icon: const Icon(
                                    CupertinoIcons.plus,
                                    size: 19,
                                  ),
                                  label: Text(
                                    _creatingSpace
                                        ? 'Creating...'
                                        : 'New space',
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Column(
                      children: [
                        _tabHeader(context, 2),
                        Expanded(child: _more(context)),
                      ],
                    ),
                  ],
                ),
              ),
              if (!focused && !keyboard)
                Padding(
                  padding: const EdgeInsets.fromLTRB(54, 8, 54, 10),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 288),
                    child: usesNativeBottomTabs
                        ? NativeBottomTabs(
                            selected: _tab,
                            onSelected: (index) => setState(() => _tab = index),
                          )
                        : LiquidSurface(
                            radius: 40,
                            quiet: true,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: SizedBox(
                                height: 48,
                                child: Stack(
                                  children: [
                                    AnimatedAlign(
                                      alignment: Alignment(
                                        (_tab - 1).toDouble(),
                                        0,
                                      ),
                                      duration: Duration(
                                        milliseconds:
                                            MediaQuery.disableAnimationsOf(
                                              context,
                                            )
                                            ? 0
                                            : RetainedTabTransition
                                                  .duration
                                                  .inMilliseconds,
                                      ),
                                      curve: RetainedTabTransition.curve,
                                      child: FractionallySizedBox(
                                        widthFactor: 1 / 3,
                                        heightFactor: 1,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              28,
                                            ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: dark
                                                  ? [
                                                      Colors.white.withValues(
                                                        alpha: .19,
                                                      ),
                                                      Colors.white.withValues(
                                                        alpha: .08,
                                                      ),
                                                    ]
                                                  : [
                                                      Colors.white.withValues(
                                                        alpha: .96,
                                                      ),
                                                      Colors.white.withValues(
                                                        alpha: .64,
                                                      ),
                                                    ],
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: dark ? .2 : .8,
                                              ),
                                              width: .6,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        for (final entry in [
                                          (
                                            0,
                                            CupertinoIcons.chat_bubble,
                                            CupertinoIcons.chat_bubble_fill,
                                            'Ask',
                                          ),
                                          (
                                            1,
                                            CupertinoIcons.square_grid_2x2,
                                            CupertinoIcons.square_grid_2x2_fill,
                                            'Spaces',
                                          ),
                                          (
                                            2,
                                            CupertinoIcons.ellipsis,
                                            CupertinoIcons.ellipsis,
                                            'More',
                                          ),
                                        ])
                                          Expanded(
                                            child: Semantics(
                                              selected: _tab == entry.$1,
                                              child: Tooltip(
                                                message: entry.$4,
                                                child: IconButton(
                                                  tooltip: null,
                                                  onPressed: () => setState(
                                                    () => _tab = entry.$1,
                                                  ),
                                                  style: IconButton.styleFrom(
                                                    minimumSize: const Size(
                                                      48,
                                                      48,
                                                    ),
                                                  ),
                                                  icon: Icon(
                                                    _tab == entry.$1
                                                        ? entry.$3
                                                        : entry.$2,
                                                    size: 23,
                                                    semanticLabel: entry.$4,
                                                  ),
                                                ),
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}
