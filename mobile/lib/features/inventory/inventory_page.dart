import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/inventory_cache.dart';
import '../../core/low_stock_prefs.dart';
import '../../core/low_stock_notifications.dart';
import '../../core/pro_status.dart';
import '../../core/upgrade_sheet.dart';
import '../../core/ui/app_colors.dart';
import '../sharing/share_space_sheet.dart';
import 'bin_label_sheet.dart';
import 'item_detail_sheet.dart';
import 'item_editor_sheet.dart';
import 'manual_add_page.dart';
import 'world_views.dart';
import '../scan/upload_photo_flow.dart';
import '../scan/space_barcode_flow.dart';
import '../import/import_sheet_page.dart';
import '../projects/bom_readiness_page.dart';
import '../projects/project_kits_page.dart';
import '../sharing/shared_inventory_page.dart';
import '../sharing/space_members_page.dart';
import '../showcase/tutorial_controller.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.api,
    required this.refreshToken,
    this.initialQuery,
    this.workspaceName,
    this.showAppBar = true,
    this.onRegisterJoinSpace,
    this.onRegisterOpenAssistDestination,
  });

  final ApiClient api;
  final int refreshToken;
  final String? initialQuery;
  final String? workspaceName;
  final bool showAppBar;
  final void Function(VoidCallback)? onRegisterJoinSpace;
  final void Function(Future<void> Function(Map<String, dynamic>))?
  onRegisterOpenAssistDestination;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class LocationItemsPage extends StatefulWidget {
  const LocationItemsPage({
    super.key,
    required this.api,
    required this.location,
    required this.items,
    required this.thresholds,
    required this.allItems,
    this.spaceId,
    this.readOnly = false,
  });

  final ApiClient api;
  final String location;
  final List<InventoryItem> items;
  final Map<String, int> thresholds;
  final List<InventoryItem> allItems;
  final String? spaceId;
  final bool readOnly;

  @override
  State<LocationItemsPage> createState() => _LocationItemsPageState();
}

class _LocationItemsPageState extends State<LocationItemsPage> {
  late List<InventoryItem> _items;
  late Map<String, int> _thresholds;
  bool _changed = false;
  late final TextEditingController _joinCodeCtrl;

  void _showProductInfo(BuildContext context, InventoryItem item) {
    showItemDetailSheet(
      context,
      item: item,
      api: widget.api,
      permission: 'edit',
      initialThreshold: _thresholds[item.itemId],
      spaceName: widget.location,
      onThresholdChanged: (threshold) {
        if (!mounted) return;
        final next = Map<String, int>.from(_thresholds);
        if (threshold == null) {
          next.remove(item.itemId);
        } else {
          next[item.itemId] = threshold;
        }
        setState(() => _thresholds = next);
      },
      onDeleted: () {
        if (!mounted) return;
        setState(() {
          _items.removeWhere((candidate) => candidate.itemId == item.itemId);
          _changed = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _joinCodeCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _joinCodeCtrl = TextEditingController();
    _items = List<InventoryItem>.from(widget.items)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _thresholds = Map<String, int>.from(widget.thresholds);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        TutorialController.instance.maybeShowSpaceStep(context: context),
      );
    });
  }

  Future<void> _editItem(InventoryItem item) async {
    if (widget.readOnly) {
      _showProductInfo(context, item);
      return;
    }
    final currentThreshold = _thresholds[item.itemId];
    final updates = await showModalBottomSheet<ItemEditorResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          ItemEditorSheet(item: item, initialThreshold: currentThreshold),
    );
    if (updates == null) return;

    try {
      final updated = await widget.api.updateItem(request: updates.update);

      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((e) => e.itemId == item.itemId);
        if (idx != -1) {
          _items[idx] = updated;
        }
        _changed = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Inventory updated')));
    } on dio.DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e).$1)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e).$1)));
    }
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text(item.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.deleteItem(itemId: item.itemId);
      if (!mounted) return;
      setState(() {
        _items = _items.where((e) => e.itemId != item.itemId).toList();
        final next = Map<String, int>.from(_thresholds);
        next.remove(item.itemId);
        _thresholds = next;
        _changed = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item deleted')));
    } on dio.DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e).$1)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e).$1)));
    }
  }

  Future<void> _joinSpaceDialog() async {
    _joinCodeCtrl.clear();
    String? error;
    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (_, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.surface2(context),
          title: const Text(
            'Join a Space',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _joinCodeCtrl,
                autofocus: true,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  letterSpacing: 4,
                ),
                decoration: const InputDecoration(
                  hintText: '6-character code',
                  hintStyle: TextStyle(color: Color(0x4DFFFFFF)),
                  counterStyle: TextStyle(color: Color(0x4DFFFFFF)),
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: const TextStyle(
                    color: Color(0xFFFF453A),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final code = _joinCodeCtrl.text.trim().toUpperCase();
                if (code.length != 6) {
                  setDlgState(() => error = 'Enter a 6-character code.');
                  return;
                }
                try {
                  await widget.api.joinShare(code);
                  if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Joined! Check Joined Spaces to view.'),
                      ),
                    );
                  }
                } catch (e) {
                  setDlgState(() => error = 'Invalid code or already joined.');
                }
              },
              child: const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addItem() async {
    final saved = await showManualAddPage(
      context,
      api: widget.api,
      initialLocation: widget.location,
      backLabel: 'Place',
    );
    if (saved == null) return;
    _changed = true;
    try {
      final result = await widget.api.searchItems(query: '');
      if (!mounted) return;
      final locationItems =
          result.items.where((item) => item.spaceId == widget.spaceId).toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
      setState(() {
        _items = locationItems;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Object saved')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Object saved, but this place could not refresh.'),
          ),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    await runUploadPhotoFlow(
      context: context,
      api: widget.api,
      preselectedSpace: widget.location,
      onItemsSaved: () async {
        if (!mounted) return;
        _changed = true;
        try {
          final reload = await widget.api.searchItems(query: '');
          final locationItems =
              reload.items.where((i) => i.spaceId == widget.spaceId).toList()
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );
          if (!mounted) return;
          setState(() {
            _items = locationItems;
          });
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Items saved, but the list could not refresh.'),
            ),
          );
        }
      },
    );
  }

  Future<void> _importSpreadsheet() async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ImportSheetPage(api: widget.api, location: widget.location),
      ),
    );
    if (imported != true) return;

    _changed = true;
    try {
      final reload = await widget.api.searchItems(query: '');
      final locationItems =
          reload.items.where((item) => item.spaceId == widget.spaceId).toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
      if (!mounted) return;
      setState(() {
        _items = locationItems;
      });
    } catch (error) {
      debugPrint('[Inventory] refresh after spreadsheet import failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import finished, but the list could not refresh.'),
        ),
      );
    }
  }

  void _openBuildReadiness() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          BomReadinessPage(api: widget.api, location: widget.location),
    ),
  );

  void _openProjectKits() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          ProjectKitsPage(api: widget.api, location: widget.location),
    ),
  );

  Future<void> _scanBarcode() async {
    await runSpaceBarcodeFlow(
      context: context,
      api: widget.api,
      preselectedSpace: widget.location,
      onItemsSaved: () async {
        if (!mounted) return;
        _changed = true;
        final reload = await widget.api.searchItems(query: '');
        final locationItems =
            reload.items.where((i) => i.spaceId == widget.spaceId).toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
        if (!mounted) return;
        setState(() {
          _items = locationItems;
        });
      },
    );
  }

  Future<void> _worldActions() async {
    const actions = [
      'Manual Add',
      'Upload Photo',
      'Import file',
      'Scan Barcode',
      'Share Space',
      'Join Space',
      'Print Bin Label',
      'Members',
      'Project Kits',
      'Build Readiness',
    ];
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.62,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Place actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: actions.length,
                  itemBuilder: (context, index) {
                    final label = actions[index];
                    return ListTile(
                      title: Text(label),
                      onTap: () => Navigator.of(sheetContext).pop(label),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (action != null && mounted) _onFabItemTap(action);
  }

  Future<void> _worldItemActions(InventoryItem item) async {
    if (widget.readOnly) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Edit object'),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            ListTile(
              title: const Text('Delete object'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') await _editItem(item);
    if (action == 'delete') await _deleteItem(item);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) Navigator.of(context).pop(_changed);
    },
    child: WorldPlacePage(
      api: widget.api,
      name: widget.location,
      items: _items,
      onBack: () => Navigator.of(context).pop(_changed),
      onOpenItem: (item) => showItemDetailSheet(
        context,
        item: item,
        api: widget.api,
        permission: widget.readOnly ? 'view' : 'edit',
        initialThreshold: _thresholds[item.itemId],
        spaceName: widget.location,
      ),
      onLongPressItem: widget.readOnly ? null : _worldItemActions,
      onAdd: widget.readOnly ? null : _addItem,
      onActions: widget.readOnly ? null : _worldActions,
    ),
  );

  void _onFabItemTap(String label) {
    switch (label) {
      case 'Manual Add':
        unawaited(_addItem());
      case 'Upload Photo':
        unawaited(_uploadImage());
      case 'Import file':
        unawaited(_importSpreadsheet());
      case 'Build Readiness':
        _openBuildReadiness();
      case 'Project Kits':
        _openProjectKits();
      case 'Scan Barcode':
        unawaited(_scanBarcode());
      case 'Share Space':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => DraggableScrollableSheet(
            initialChildSize: 0.65,
            maxChildSize: 0.92,
            minChildSize: 0.4,
            builder: (_, _) =>
                ShareSpaceSheet(spaceName: widget.location, api: widget.api),
          ),
        );
      case 'Join Space':
        unawaited(_joinSpaceDialog());
      case 'Print Bin Label':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) =>
              BinLabelSheet(spaceName: widget.location, items: _items),
        );
      case 'Members':
        unawaited(() async {
          try {
            final shares = await widget.api.getMyShares();
            dynamic match;
            for (final s in shares) {
              if ((s['share_name'] ?? '').toString().toLowerCase() ==
                  widget.location.toLowerCase()) {
                match = s;
                break;
              }
            }
            if (match != null && mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SpaceMembersPage(
                    shareId: match['share_id'].toString(),
                    spaceName: widget.location,
                    api: widget.api,
                  ),
                ),
              );
              return;
            }
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Couldn’t load space members. Try again.'),
                ),
              );
            }
            return;
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("This space isn't shared yet")),
            );
          }
        }());
    }
  }
}

class _InventoryPageState extends State<InventoryPage>
    with WidgetsBindingObserver {
  late final TextEditingController _search;
  final ValueNotifier<String> _query = ValueNotifier('');
  final ValueNotifier<List<InventoryItem>> _rows = ValueNotifier(const []);
  final ValueNotifier<bool> _aiSearching = ValueNotifier(false);
  final ValueNotifier<Map<String, int>> _thresholds = ValueNotifier(const {});

  final ValueNotifier<String> _category = ValueNotifier('All');

  bool _loading = true;
  String? _error;
  List<InventoryItem> _items = const [];
  List<Map<String, dynamic>> _joinedShares = [];
  Map<String, int> _joinedShareCounts = {};
  String? _joinedSharesError;
  List<Map<String, dynamic>> _myShares = [];
  List<Map<String, dynamic>> _spaces = const [];
  bool _spacesError = false;

  Timer? _debounce;
  String? _lastAiExpandedFor;

  late final TextEditingController _createSpaceCtrl;
  late final TextEditingController _joinCodeCtrl;
  late final TextEditingController _renameSpaceCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _search = TextEditingController();
    _createSpaceCtrl = TextEditingController();
    _joinCodeCtrl = TextEditingController();
    _renameSpaceCtrl = TextEditingController();

    final initial = (widget.initialQuery ?? '').trim();
    if (initial.isNotEmpty) {
      _search.text = initial;
      _query.value = initial;
    }
    unawaited(
      Future.wait([
        _loadItems(),
        _loadMyShares(),
        _loadJoinedShares(),
        _loadSpaces(),
      ]),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onRegisterJoinSpace?.call(() => _joinSpaceDialog(context));
      widget.onRegisterOpenAssistDestination?.call(_openAssistDestination);
    });
  }

  Future<void> _openAssistDestination(Map<String, dynamic> hint) async {
    if (!mounted) return;
    if ((hint['type'] ?? '').toString() == 'project_kit') {
      final kitId = (hint['id'] ?? '').toString().trim();
      if (kitId.isEmpty) return;
      final detail = await widget.api.getProjectKit(kitId);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              ProjectKitDetailPage(api: widget.api, initial: detail),
        ),
      );
      return;
    }

    final shareId = (hint['share_id'] ?? '').toString().trim();
    final spaceName = (hint['space_name'] ?? hint['name'] ?? 'Unsorted')
        .toString();
    if (shareId.isNotEmpty) {
      final owned = _myShares.where(
        (share) => (share['share_id'] ?? '').toString() == shareId,
      );
      if (owned.isNotEmpty) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SharedInventoryPage(
              shareId: shareId,
              shareName: spaceName,
              permission: 'edit',
              api: widget.api,
            ),
          ),
        );
        return;
      }
      final joined = _joinedShares.where((membership) {
        final share =
            (membership['team_shares'] as Map<String, dynamic>?) ?? const {};
        return (share['share_id'] ?? membership['share_id']).toString() ==
            shareId;
      });
      if (joined.isNotEmpty) {
        await _openSharedSpace(joined.first);
        return;
      }
    }
    await _openLocation(
      location: spaceName,
      thresholds: await LowStockPrefs.loadAll(widget.api),
    );
  }

  Future<void> _leaveJoinedSpace({
    required String shareId,
    required String name,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Space?'),
        content: Text(
          'You will lose access to “$name”. The owner’s Space and items will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Leave Space',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.leaveShare(shareId: shareId);
      await _loadJoinedShares();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Left “$name”')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        Future.wait([
          _loadItems(),
          _loadMyShares(),
          _loadJoinedShares(),
          _loadSpaces(),
        ]),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_items.isEmpty && !_loading) {
      unawaited(
        Future.wait([
          _loadItems(),
          _loadMyShares(),
          _loadJoinedShares(),
          _loadSpaces(),
        ]),
      );
    }
  }

  Future<void> _openLocation({
    required String location,
    required Map<String, int> thresholds,
  }) async {
    if (!mounted) return;
    final loc = location.trim().isEmpty ? 'Unsorted' : location.trim();

    final String? spaceId = (loc == 'Unsorted')
        ? null
        : (_spaces.firstWhere(
                (s) =>
                    (s['name'] as String? ?? '').toLowerCase() ==
                    loc.toLowerCase(),
                orElse: () => const <String, dynamic>{},
              )['id']
              as String?);
    final source = _baseItemsForSelectedCategory();
    final items = source
        .where(
          (it) => spaceId == null
              ? (it.spaceId == null &&
                    (it.location.trim().isEmpty
                                ? 'Unsorted'
                                : it.location.trim())
                            .toLowerCase() ==
                        loc.toLowerCase())
              : it.spaceId == spaceId,
        )
        .toList();

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LocationItemsPage(
          api: widget.api,
          location: loc,
          items: items,
          thresholds: thresholds,
          allItems: _items,
          spaceId: spaceId,
        ),
      ),
    );
    if (changed == true) {
      await _loadItems();
    }
  }

  Future<void> _openSharedSpace(Map<String, dynamic> share) async {
    final ts = (share['team_shares'] as Map<String, dynamic>?) ?? {};
    final shareId = (ts['share_id'] ?? share['share_id']) as String?;
    final shareName = (ts['share_name'] ?? 'Shared Space') as String;
    final permission = (ts['permission'] ?? 'view') as String;
    if (shareId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SharedInventoryPage(
          shareId: shareId,
          shareName: shareName,
          permission: permission,
          api: widget.api,
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant InventoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadItems();
      unawaited(_loadSpaces());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _search.dispose();
    _createSpaceCtrl.dispose();
    _joinCodeCtrl.dispose();
    _renameSpaceCtrl.dispose();
    _query.dispose();
    _rows.dispose();
    _aiSearching.dispose();
    _thresholds.dispose();
    _category.dispose();
    super.dispose();
  }

  List<InventoryItem> _baseItemsForSelectedCategory() {
    final selected = _category.value;
    if (selected == 'All') return _items;
    final target = selected.trim().toLowerCase();
    return _items
        .where((it) => it.category.trim().toLowerCase() == target)
        .toList();
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    final t0 = DateTime.now().millisecondsSinceEpoch;
    debugPrint(
      '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems start',
    );
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      debugPrint(
        '[Inventory][${DateTime.now().millisecondsSinceEpoch}] calling searchItems...',
      );
      final result = await widget.api
          .searchItems(query: '')
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () =>
                throw TimeoutException('searchItems timed out after 20s'),
          );
      debugPrint(
        '[Inventory][${DateTime.now().millisecondsSinceEpoch}] searchItems returned ${result.items.length} items (${DateTime.now().millisecondsSinceEpoch - t0}ms)',
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
      });
      LowStockPrefs.loadAll(widget.api).then((value) {
        if (!mounted) return;
        _thresholds.value = value;
        unawaited(
          LowStockNotifications.evaluate(
            result.items.where((item) => value[item.itemId] != null).map((
              item,
            ) {
              return LowStockCandidate(
                itemId: item.itemId,
                name: item.name,
                quantity: item.quantity,
                threshold: value[item.itemId]!,
                spaceName: item.location,
              );
            }).toList(),
          ),
        );
      });
      _applyLocalSearch(_query.value);
    } on SessionExpiredException {
      debugPrint(
        '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems: SessionExpiredException',
      );
      if (!mounted) return;
      setState(() => _error = 'Session expired. Please sign in again.');
    } on TimeoutException catch (e) {
      debugPrint(
        '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems: TimeoutException: $e',
      );
      if (!mounted) return;
      setState(() => _error = 'connection');
    } on dio.DioException catch (e) {
      debugPrint(
        '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems: DioException: ${e.response?.statusCode}',
      );
      if (!mounted) return;
      if (e.response?.statusCode == 429) {
        setState(
          () =>
              _error = 'Too many requests. Please wait a moment and try again.',
        );
        return;
      }
      setState(() => _error = 'connection');
    } catch (e) {
      debugPrint(
        '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems: catch: $e',
      );
      if (!mounted) return;
      setState(() => _error = 'connection');
    } finally {
      debugPrint(
        '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems finally (total ${DateTime.now().millisecondsSinceEpoch - t0}ms)',
      );
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _loadSpaces() async {
    try {
      final spaces = await widget.api.listSpaces().timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw TimeoutException('listSpaces timed out'),
      );
      if (mounted) {
        setState(() {
          _spaces = spaces;
          _spacesError = false;
        });
      }
      return true;
    } catch (e) {
      debugPrint('[Inventory] _loadSpaces error: $e');
      if (mounted) setState(() => _spacesError = true);
      return false;
    }
  }

  Future<void> _loadJoinedShares() async {
    if (!mounted) return;
    debugPrint(
      '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadJoinedShares start',
    );
    setState(() => _joinedSharesError = null);
    try {
      final shares = await widget.api.getJoinedShares();
      debugPrint(
        '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadJoinedShares returned ${shares.length} shares',
      );
      if (!mounted) return;
      final cast = shares.cast<Map<String, dynamic>>();
      setState(() => _joinedShares = cast);
      final counts = <String, int>{};
      await Future.wait(
        cast.map((share) async {
          final data =
              (share['team_shares'] as Map<String, dynamic>?) ?? const {};
          final id = (data['share_id'] ?? share['share_id'] ?? '').toString();
          if (id.isEmpty) return;
          try {
            counts[id] = (await widget.api.getShareInventory(id)).length;
          } catch (_) {
            // The place remains reachable when its count cannot be loaded.
          }
        }),
      );
      if (mounted) setState(() => _joinedShareCounts = counts);
    } catch (e) {
      debugPrint(
        '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadJoinedShares error: ${describeError(e).$1}',
      );
      if (mounted) setState(() => _joinedSharesError = describeError(e).$1);
    }
  }

  Future<void> _loadMyShares() async {
    debugPrint(
      '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadMyShares start',
    );
    try {
      final shares = await widget.api.getMyShares();
      debugPrint(
        '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadMyShares returned ${shares.length} shares',
      );
      if (!mounted) return;
      setState(() => _myShares = shares.cast<Map<String, dynamic>>());
    } catch (e) {
      debugPrint(
        '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadMyShares error: $e',
      );
    }
  }

  bool _containsToken(String haystack, String token) {
    if (haystack.isEmpty || token.isEmpty) return false;
    return haystack.toLowerCase().contains(token.toLowerCase());
  }

  int _scoreForToken(
    InventoryItem it,
    String token, {
    required String fullQuery,
  }) {
    final name = it.name;
    final category = it.category;
    final location = it.location;
    final notes = (it.notes ?? '');

    final nameLower = name.toLowerCase();
    final tokenLower = token.toLowerCase();
    final fullLower = fullQuery.toLowerCase();

    var score = 0;

    if (nameLower == fullLower) return 10000;
    if (nameLower.startsWith(fullLower) && fullLower.isNotEmpty) score += 7000;

    if (nameLower == tokenLower) score += 4500;
    if (nameLower.startsWith(tokenLower)) score += 2200;
    if (nameLower.contains(tokenLower)) score += 1500;

    if (_containsToken(category, token)) score += 900;

    final tags = it.tags ?? const <String>[];
    for (final t in tags) {
      if (_containsToken(t, token)) {
        score += 750;
        break;
      }
    }

    if (_containsToken(location, token)) score += 600;
    if (_containsToken(notes, token)) score += 450;
    if (_containsToken(it.purchaseSource ?? '', token)) score += 350;
    if (_containsToken(it.barcode ?? '', token)) score += 250;

    return score;
  }

  List<InventoryItem> _smartLocalSearch(
    String rawQuery, {
    List<String> extraTerms = const [],
  }) {
    final base = _baseItemsForSelectedCategory();
    final q = rawQuery.trim();
    if (q.isEmpty) return base;

    final tokens = <String>{
      ...q
          .split(RegExp(r'\s+'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty),
      ...extraTerms.map((t) => t.trim()).where((t) => t.isNotEmpty),
    }.toList();

    final scored = <({InventoryItem item, int score})>[];
    for (final it in base) {
      var s = 0;
      for (final tok in tokens) {
        s += _scoreForToken(it, tok, fullQuery: q);
      }
      if (s > 0) scored.add((item: it, score: s));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.item.createdAt.compareTo(a.item.createdAt);
    });
    return scored.map((e) => e.item).toList();
  }

  Future<List<String>> _expandQueryWithAi(String query) async {
    final msg =
        'Expand this inventory search query into up to 8 related search terms (synonyms, categories, related items). '
        'Return ONLY JSON like {"terms":["term1","term2"]}. Query: "$query"';

    final out = await widget.api.aiCommand(message: msg);
    final text = out.assistantMessage.trim();
    if (text.isEmpty) return const [];

    try {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final jsonStr = text.substring(start, end + 1);
        final obj = (json.decode(jsonStr) as Map).cast<String, dynamic>();
        final terms = obj['terms'];
        if (terms is List) {
          return terms
              .map((e) => e.toString())
              .where((t) => t.trim().isNotEmpty)
              .take(8)
              .toList();
        }
      }
    } catch (_) {
      // fall through
    }

    return text
        .replaceAll(RegExp(r'[^a-zA-Z0-9,\n\s-]'), '')
        .split(RegExp(r'[,\n]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .take(8)
        .toList();
  }

  void _applyLocalSearch(String v) {
    final q = v.trim();
    _query.value = q;
    _aiSearching.value = false;
    _rows.value = _smartLocalSearch(q);

    _debounce?.cancel();
    if (q.isEmpty) {
      _lastAiExpandedFor = null;
      return;
    }

    if (_rows.value.length >= 4) return;
    if (_lastAiExpandedFor == q) return;

    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final active = _query.value;
      if (active != q || active.isEmpty) return;
      if (_rows.value.length >= 4) return;

      _aiSearching.value = true;
      try {
        final terms = await _expandQueryWithAi(active);
        if (!mounted) return;
        if (_query.value != active) return;
        _lastAiExpandedFor = active;
        _rows.value = _smartLocalSearch(active, extraTerms: terms);
      } on dio.DioException {
        // ignore; keep local results
      } catch (_) {
        // ignore; keep local results
      } finally {
        if (mounted && _query.value == active) _aiSearching.value = false;
      }
    });
  }

  Future<void> _createSpace(BuildContext context) async {
    _createSpaceCtrl.clear();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface2(context),
        title: const Text('New Space', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _createSpaceCtrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Space name',
            hintStyle: TextStyle(color: Color(0x4DFFFFFF)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _createSpaceCtrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (!mounted || !context.mounted) return;
    try {
      await widget.api.createSpace(name: name);
    } on dio.DioException catch (e) {
      if (!mounted || !context.mounted) return;
      final status = e.response?.statusCode;
      if (status == 402 || status == 403) {
        if (!ProStatus.isPro) {
          showUpgradeSheet(
            context,
            widget.api,
            reason: 'You\'ve reached the free space limit.',
          );
        } else {
          unawaited(ProStatus.refresh(widget.api));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Something went wrong. Please try again.'),
            ),
          );
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t create the space. Try again.')),
      );
      return;
    }
    await _loadSpaces();
    if (!mounted) return;
    await _openLocation(location: name, thresholds: _thresholds.value);
  }

  Future<void> _joinSpaceDialog(BuildContext context) async {
    _joinCodeCtrl.clear();
    String? error;
    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (_, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Join a Space',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _joinCodeCtrl,
                    autofocus: true,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 4,
                    ),
                    decoration: InputDecoration(
                      hintText: '6-character code',
                      hintStyle: const TextStyle(color: Color(0x4DFFFFFF)),
                      counterStyle: const TextStyle(color: Color(0x4DFFFFFF)),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(12),
                        ),
                        borderSide: BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(12),
                        ),
                        borderSide: BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(12),
                        ),
                        borderSide: const BorderSide(
                          color: Color(0xFFF2F2F7),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: Color(0xFFFF453A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dlgCtx),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.50),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final code = _joinCodeCtrl.text.trim().toUpperCase();
                          if (code.length != 6) {
                            setDlgState(
                              () => error = 'Enter a 6-character code.',
                            );
                            return;
                          }
                          try {
                            await widget.api.joinShare(code);
                            if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                            if (mounted) {
                              await _loadItems();
                              if (!mounted || !context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Joined! Check Joined Spaces to view.',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setDlgState(
                              () => error = 'Invalid code or already joined.',
                            );
                          }
                        },
                        child: const Text('Join'),
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

  Future<void> _renameSpace(
    BuildContext context,
    String oldName,
    String spaceId,
  ) async {
    _renameSpaceCtrl.text = oldName;
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface2(context),
        title: const Text(
          'Rename Space',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: _renameSpaceCtrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintStyle: TextStyle(color: Color(0x4DFFFFFF)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _renameSpaceCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;
    if (!mounted || !context.mounted) return;
    try {
      await widget.api.renameSpace(spaceId: spaceId, name: newName);
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t rename the space. Try again.'),
          ),
        );
      }
      return;
    }
    if (mounted) {
      final spacesOk = await _loadSpaces();
      await _loadItems();
      if (!spacesOk && mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Space renamed, but the view couldn’t refresh.',
            ),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                unawaited(_loadSpaces());
                unawaited(_loadItems());
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteSpace(
    BuildContext context,
    String loc,
    String spaceId,
  ) async {
    final spaceData = _spaces.firstWhere(
      (s) => s['id'] == spaceId,
      orElse: () => const {},
    );
    final itemCount = (spaceData['item_count'] as num?)?.toInt() ?? 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface2(context),
        title: const Text(
          'Delete Space?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          itemCount > 0
              ? 'The space "$loc" and its $itemCount item(s) will be permanently deleted.'
              : 'The space "$loc" will be removed.',
          style: const TextStyle(color: Color(0x73FFFFFF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF453A)),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted || !context.mounted) return;
    try {
      await widget.api.deleteSpace(spaceId: spaceId);
      InventoryCache.removeSpace(spaceId);
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t delete the space. Try again.'),
          ),
        );
      }
      return;
    }
    if (mounted) {
      await _loadSpaces();
      await _loadItems();
    }
  }

  Future<void> _managePlace(String name, String id) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Open place'),
              onTap: () => Navigator.of(context).pop('open'),
            ),
            ListTile(
              title: const Text('Share place'),
              onTap: () => Navigator.of(context).pop('share'),
            ),
            if (id.isNotEmpty) ...[
              ListTile(
                title: const Text('Rename place'),
                onTap: () => Navigator.of(context).pop('rename'),
              ),
              ListTile(
                title: const Text('Delete place'),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'open') {
      await _openLocation(location: name, thresholds: _thresholds.value);
    } else if (action == 'share') {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ShareSpaceSheet(spaceName: name, api: widget.api),
      );
    } else if (action == 'rename') {
      await _renameSpace(context, name, id);
    } else if (action == 'delete') {
      await _deleteSpace(context, name, id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final places = List<Map<String, dynamic>>.from(_spaces);
    final known = places
        .map((s) => (s['name'] ?? '').toString().trim().toLowerCase())
        .toSet();
    for (final item in _items) {
      if (item.spaceId != null) continue;
      final name = item.location.trim().isEmpty
          ? 'Unsorted'
          : item.location.trim();
      if (known.add(name.toLowerCase())) places.add({'id': '', 'name': name});
    }
    places.sort(
      (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
        (b['name'] ?? '').toString().toLowerCase(),
      ),
    );
    final query = _query.value.trim();
    final sharedByYou = _myShares
        .map(
          (share) =>
              (share['share_name'] ?? '').toString().trim().toLowerCase(),
        )
        .where((name) => name.isNotEmpty)
        .toSet();
    final joinedObjectCount = _joinedShareCounts.values.fold<int>(
      0,
      (total, count) => total + count,
    );
    final visiblePlaceCount = places.length + _joinedShares.length;
    final visibleObjectCount = _items.length + joinedObjectCount;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorldHeader(
              title: 'Places',
              subtitle:
                  '$visiblePlaceCount ${visiblePlaceCount == 1 ? 'place' : 'places'} / '
                  '$visibleObjectCount ${visibleObjectCount == 1 ? 'object' : 'objects'}',
              onBack: widget.showAppBar
                  ? () => Navigator.of(context).pop()
                  : null,
              actions: [
                TextButton(
                  onPressed: () => _createSpace(context),
                  child: const Text('Add'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
              child: TextField(
                key: TutorialController.inventorySearchKey,
                controller: _search,
                onChanged: (value) {
                  _applyLocalSearch(value);
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Search objects',
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: t.separator),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: t.separator),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: t.accent),
                  ),
                ),
              ),
            ),
            if (_loading && _items.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text('Loading places', style: TextStyle(color: t.text2)),
                    ],
                  ),
                ),
              )
            else if (_error != null && _items.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Places could not be loaded.',
                        style: TextStyle(color: t.ink, fontSize: 17),
                      ),
                      TextButton(
                        onPressed: _loadItems,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            else if (query.isNotEmpty)
              Expanded(
                child: ValueListenableBuilder<List<InventoryItem>>(
                  valueListenable: _rows,
                  builder: (context, rows, _) => WorldItems(
                    items: rows,
                    onOpen: (item) => showItemDetailSheet(
                      context,
                      item: item,
                      api: widget.api,
                    ),
                    emptyMessage: 'No objects match this search.',
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    if (_spacesError)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextButton(
                          onPressed: _loadSpaces,
                          child: const Text(
                            'Places could not be refreshed. Try again',
                          ),
                        ),
                      ),
                    if (places.isEmpty)
                      WorldSection(
                        flat: true,
                        title: widget.workspaceName?.trim().isNotEmpty == true &&
                                widget.workspaceName != 'Your inventory'
                            ? widget.workspaceName!
                            : 'Your places',
                        children: [
                          WorldRow(
                            title: 'No places yet',
                            subtitle:
                                'Create a place to organize what you capture.',
                            count: '',
                            onTap: () => _createSpace(context),
                          ),
                        ],
                      )
                    else
                      WorldSection(
                        flat: true,
                        title: widget.workspaceName?.trim().isNotEmpty == true &&
                                widget.workspaceName != 'Your inventory'
                            ? widget.workspaceName!
                            : 'Your places',
                        children: [
                          for (var i = 0; i < places.length; i++)
                            Builder(
                              builder: (context) {
                                final place = places[i];
                                final name = (place['name'] ?? '').toString();
                                final id = (place['id'] ?? '').toString();
                                final matching = _items
                                    .where(
                                      (item) =>
                                          (id.isNotEmpty &&
                                              item.spaceId == id) ||
                                          ((item.spaceId == null ||
                                                  item.spaceId!.isEmpty) &&
                                              (item.location.trim().isEmpty
                                                          ? 'Unsorted'
                                                          : item.location
                                                                .trim())
                                                      .toLowerCase() ==
                                                  name.toLowerCase()),
                                    )
                                    .toList();
                                final low = matching.where((item) {
                                  final threshold =
                                      _thresholds.value[item.itemId];
                                  return threshold != null &&
                                      item.quantity <= threshold;
                                }).length;
                                final isShared = sharedByYou.contains(
                                  name.trim().toLowerCase(),
                                );
                                return WorldRow(
                                  key: i == 0
                                      ? TutorialController.firstSpaceCardKey
                                      : null,
                                  title: name,
                                  subtitle: isShared
                                      ? 'Shared by you'
                                      : low > 0
                                      ? '$low running low'
                                      : null,
                                  warning: low > 0,
                                  count: '${matching.length}',
                                  countSemantics: '${matching.length} objects',
                                  onTap: () => _openLocation(
                                    location: name,
                                    thresholds: _thresholds.value,
                                  ),
                                  onLongPress: () => _managePlace(name, id),
                                );
                              },
                            ),
                        ],
                      ),
                    if (_joinedSharesError != null)
                      TextButton(
                        onPressed: _loadJoinedShares,
                        child: const Text(
                          'Shared places could not be loaded. Try again',
                        ),
                      ),
                    if (_joinedShares.isNotEmpty)
                      WorldSection(
                        flat: true,
                        title: 'Shared with you',
                        children: [
                          for (final share in _joinedShares)
                            Builder(
                              builder: (context) {
                                final data =
                                    (share['team_shares']
                                        as Map<String, dynamic>?) ??
                                    const <String, dynamic>{};
                                final name =
                                    (data['share_name'] ?? 'Shared place')
                                        .toString();
                                final id =
                                    (data['share_id'] ?? share['share_id'])
                                        .toString();
                                return WorldRow(
                                  title: name,
                                  subtitle:
                                      (data['permission'] ?? 'view') == 'edit'
                                      ? 'Can edit'
                                      : 'View only',
                                  count:
                                      _joinedShareCounts[id]?.toString() ?? '',
                                  countSemantics:
                                      '${_joinedShareCounts[id] ?? 0} objects',
                                  onTap: () => _openSharedSpace(share),
                                  onLongPress: () => _leaveJoinedSpace(
                                    shareId: id,
                                    name: name,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _joinSpaceDialog(context),
                          child: const Text('Join a shared place'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
