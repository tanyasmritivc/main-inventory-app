import 'package:image_picker/image_picker.dart';
import 'space_v2/space_style.dart';
import 'space_v2/space_widgets.dart';
import 'space_v2/space_quick_view.dart';
import 'space_v2/space_ask.dart';
import '../chat/inventory_chat_button.dart';
import '../../core/account_refresh.dart';
import '../../core/ui/native_menu_button.dart';
import '../review/review_queue_page.dart';
import '../workspaces/resource_removal.dart';
import 'package:mobile/core/private_image.dart';
import '../notifications/notification_bell.dart';
import 'package:mobile/core/ui/glass_control.dart';
import 'dart:async';
import '../profile/account_button.dart';
import 'dart:convert';
import 'dart:ui';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/inventory_cache.dart';
import '../../core/low_stock_prefs.dart';
import '../../core/restock_plan.dart';
import '../../core/ui/restock_status.dart';
import '../../core/low_stock_notifications.dart';
import '../../core/pro_status.dart';
import '../../core/upgrade_sheet.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/content_loading.dart';
import '../../core/ui/glass_fab.dart';
import '../sharing/share_space_sheet.dart';
import 'bin_label_sheet.dart';
import 'item_detail_sheet.dart';
import 'item_editor_sheet.dart';
import 'item_sort.dart';
import 'space_icon_picker.dart';
import '../scan/upload_photo_flow.dart';
import '../scan/space_barcode_flow.dart';
import '../scan/import_sheet_page.dart';
import '../scan/bom_readiness_page.dart';
import '../scan/project_kits_page.dart';
import '../checkout/checkout_page.dart';
import '../shopping/shopping_list_page.dart';
import '../sharing/shared_inventory_page.dart';
import '../sharing/space_members_page.dart';
import '../showcase/tutorial_controller.dart';
import 'package:mobile/core/ui/app_text.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.api,
    required this.refreshToken,
    this.initialQuery,
    this.showAppBar = true,
    this.onRegisterJoinSpace,
    this.onRegisterOpenAssistDestination,
    this.onSpaceDeleted,
  });

  final ApiClient api;
  final int refreshToken;
  final String? initialQuery;
  final bool showAppBar;
  final ValueChanged<String>? onSpaceDeleted;
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
  late final AccountRefresh _accountRefresh;
  late String _location;
  String? _syncError;
  bool _removed = false;
  late List<InventoryItem> _items;
  late Map<String, int> _thresholds;
  bool _changed = false;
  late final TextEditingController _joinCodeCtrl;
  String _selectedCategory = 'All';
  final ScrollController _listScrollController = ScrollController();
  final Map<String, GlobalKey> _categoryKeys = {};
  String _spaceSearchQuery = '';
  Set<String>? _answerIds;
  bool _onlyLowQuantity = false;
  late final TextEditingController _spaceSearchController;
  ItemSortOption _sortOption = ItemSortOption.nameAZ;

  @override
  void dispose() {
    _accountRefresh.dispose();
    _joinCodeCtrl.dispose();
    _listScrollController.dispose();
    _spaceSearchController.dispose();
    super.dispose();
  }

  void _rebuildCategoryKeys() {
    final groups = <String, List<InventoryItem>>{};
    for (final item in _items) {
      final cat = item.category.trim().isEmpty
          ? 'Uncategorized'
          : item.category.trim();
      groups.putIfAbsent(cat, () => []).add(item);
    }
    for (final cat in groups.keys) {
      _categoryKeys.putIfAbsent(cat, () => GlobalKey());
    }
  }

  @override
  void initState() {
    super.initState();
    _location = widget.location;
    _accountRefresh = AccountRefresh(
      refresh: _refreshSpace,
      isActive: () => mounted && (ModalRoute.of(context)?.isCurrent ?? true),
    );
    _joinCodeCtrl = TextEditingController();
    _spaceSearchController = TextEditingController();
    loadSortPref().then((v) {
      if (mounted) setState(() => _sortOption = v);
    });
    _items = List<InventoryItem>.from(widget.items)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _thresholds = Map<String, int>.from(widget.thresholds);
    _rebuildCategoryKeys();
  }

  Future<void> _refreshSpace() async {
    try {
      final spaces = await widget.api.listSpaces();
      if (!mounted) return;
      final matches = spaces.where(
        (space) => widget.spaceId != null
            ? (space['id'] ?? space['space_id']) == widget.spaceId
            : space['name'] == _location,
      );
      if (matches.isEmpty && widget.spaceId != null) {
        setState(() {
          _removed = true;
          _items = [];
        });
        return;
      }
      final name = matches.firstOrNull?['name']?.toString() ?? _location;
      final result = await widget.api.searchItems(query: '');
      if (!mounted) return;
      setState(() {
        _location = name;
        _syncError = null;
        _items = result.items
            .where(
              (item) => widget.spaceId != null
                  ? item.spaceId == widget.spaceId
                  : item.location == name,
            )
            .toList();
        _rebuildCategoryKeys();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _syncError = describeError(error).$1;
        if (error is dio.DioException &&
            [401, 403, 404, 410].contains(error.response?.statusCode)) {
          _removed = true;
          _items = [];
        }
      });
    }
  }

  int _totalCount() {
    return _items.fold<int>(
      0,
      (acc, it) => acc + (it.quantity <= 0 ? 0 : it.quantity),
    );
  }

  int _lowCount() {
    var n = 0;
    for (final it in _items) {
      final thr = it.reorderEnabled
          ? it.reorderThreshold
          : _thresholds[it.itemId];
      if ((thr != null && thr >= 0 && it.quantity <= thr) || it.quantity <= 0) {
        n++;
      }
    }
    return n;
  }

  Future<void> _editItem(InventoryItem item) async {
    await _quickView(item);
  }

  Future<void> _deleteItem(InventoryItem item) async {
    if (!widget.api.canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('You have view-only access to this inventory.'),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      useRootNavigator: false,
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Delete item?'),
        content: AppText(item.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.deleteItem(itemId: item.itemId);
      await LowStockPrefs.setThreshold(itemId: item.itemId, threshold: null);
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
      ).showSnackBar(const SnackBar(content: AppText('Item deleted')));
    } on dio.DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(describeError(e).$1)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(describeError(e).$1)));
    }
  }

  Widget _buildItemRow(InventoryItem item, {bool divider = true}) {
    return Dismissible(
      key: ValueKey(item.itemId),
      direction: widget.readOnly
          ? DismissDirection.none
          : DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        color: AppTheme.adaptive(context, AppColors.swipe),
        child: const Icon(Icons.edit_outlined),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppTheme.adaptive(context, const Color(0x1AFF3B30)),
        child: Icon(
          Icons.delete_outline,
          color: AppTheme.foreground(context, AppColors.danger),
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _editItem(item);
          return false;
        }
        if (direction == DismissDirection.endToStart) {
          await _deleteItem(item);
          return false;
        }
        return false;
      },
      child: SpaceItemRow(
        item: item,
        divider: divider,
        onTap: () => _quickView(item),
        low: spaceItemIsLow(item, _thresholds[item.itemId]),
      ),
    );
  }

  Future<void> _joinSpaceDialog() async {
    _joinCodeCtrl.clear();
    String? error;
    await showDialog(
      useRootNavigator: false,
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (_, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.surface2(context),
          title: AppText(
            'Join a Space',
            style: TextStyle(color: AppTheme.foreground(context, Colors.white)),
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
                style: AppTypography.bodyStyleOf(
                  context,
                  TextStyle(
                    color: AppTheme.foreground(context, Colors.white),
                    fontSize: 20,
                    letterSpacing: 4,
                  ),
                ),
                decoration: InputDecoration(
                  hintText: '6-character code',
                  hintStyle: AppTypography.bodyStyleOf(
                    context,
                    TextStyle(
                      color: AppTheme.foreground(
                        context,
                        const Color(0x4DFFFFFF),
                      ),
                    ),
                  ),
                  counterStyle: AppTypography.bodyStyleOf(
                    context,
                    TextStyle(
                      color: AppTheme.foreground(
                        context,
                        const Color(0x4DFFFFFF),
                      ),
                    ),
                  ),
                ),
              ),
              if (error != null)
                AppText(
                  error!,
                  style: TextStyle(
                    color: AppTheme.foreground(
                      context,
                      const Color(0xFFFF453A),
                    ),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const AppText('Cancel'),
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
                        content: AppText(
                          'Joined! Check Joined Spaces to view.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  setDlgState(() => error = 'Invalid code or already joined.');
                }
              },
              child: const AppText('Join'),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _sortedCategoryPills() {
    final catSet = <String>{};
    for (final it in _items) {
      final c = it.category.trim().isEmpty
          ? 'Uncategorized'
          : it.category.trim();
      catSet.add(c);
    }
    final sorted = catSet.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...sorted];
  }

  bool _matchesSpaceSearch(InventoryItem item) {
    if (_onlyLowQuantity &&
        item.quantity >
            ((item.reorderEnabled
                    ? item.reorderThreshold
                    : _thresholds[item.itemId]) ??
                0)) {
      return false;
    }
    return item.searchScore(_spaceSearchQuery) > 0;
  }

  void _onCategoryPillTapped(String cat) {
    setState(() => _selectedCategory = cat);
    if (_listScrollController.hasClients) _listScrollController.jumpTo(0);
  }

  void _showProductInfo(BuildContext context, InventoryItem item) {
    final existingThr = _thresholds[item.itemId];
    showItemDetailSheet(
      context,
      item: item,
      api: widget.api,
      permission: widget.readOnly ? 'view' : 'edit',
      initialThreshold: existingThr,
      spaceName: _location,
      onItemUpdated: _acceptUpdated,
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
    );
  }

  Future<void> _uploadImage({
    BuildContext? sourceContext,
    ImageSource? source,
  }) async {
    await runUploadPhotoFlow(
      context: sourceContext ?? context,
      source: source,
      api: widget.api,
      preselectedSpace: _location,
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
            _rebuildCategoryKeys();
          });
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: AppText('Items saved, but the list could not refresh.'),
            ),
          );
        }
      },
    );
  }

  Future<void> _importSpreadsheet({BuildContext? sourceContext}) async {
    final imported = await Navigator.of(sourceContext ?? context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ImportSheetPage(
          api: widget.api,
          location: _location,
          openPicker: true,
        ),
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
        _rebuildCategoryKeys();
      });
    } catch (error) {
      debugPrint('[Inventory] refresh after spreadsheet import failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Import finished, but the list could not refresh.'),
        ),
      );
    }
  }

  void _openBuildReadiness() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => BomReadinessPage(api: widget.api, location: _location),
    ),
  );

  void _openProjectKits() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ProjectKitsPage(api: widget.api, location: _location),
    ),
  );

  Future<void> _scanBarcode({BuildContext? sourceContext}) async {
    await runSpaceBarcodeFlow(
      context: sourceContext ?? context,
      api: widget.api,
      preselectedSpace: _location,
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
          _rebuildCategoryKeys();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_removed) {
      return Scaffold(
        appBar: AppBar(title: const AppText('Space unavailable')),
        body: const Center(
          child: AppText('This Space was deleted or is no longer available.'),
        ),
      );
    }
    final inventory = widget.api.inventoryContext;
    final filtered = _items
        .where(
          (item) =>
              _matchesSpaceSearch(item) &&
              (_selectedCategory == 'All' ||
                  (item.category.trim().isEmpty
                          ? 'Uncategorized'
                          : item.category.trim()) ==
                      _selectedCategory) &&
              (_answerIds == null || _answerIds!.contains(item.itemId)),
        )
        .toList();
    sortInventoryItems(filtered, _sortOption);
    final categories = _sortedCategoryPills();
    return AppTypography(
      child: Builder(
        builder: (context) => Theme(
          data: SpaceStyle.theme(context),
          child: Builder(
            builder: (context) => Scaffold(
              backgroundColor: SpaceStyle.of(context).bg,
              body: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        CustomScrollView(
                          controller: _listScrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          slivers: [
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: SpaceCollapsingHeader(
                                topInset: MediaQuery.paddingOf(context).top,
                                // Keep the complete editable line visible at larger
                                // system text sizes, including its vertical padding.
                                searchExtent: _items.isEmpty
                                    ? 0
                                    : (MediaQuery.textScalerOf(context).scale(
                                                    AppTypography.bodySizeOf(
                                                      context,
                                                    ),
                                                  ) *
                                                  1.35 +
                                              46)
                                          .ceilToDouble()
                                          .clamp(68.0, double.infinity),
                                summaryExtent: spaceSummaryHeight(
                                  context,
                                  _items.length,
                                  _totalCount(),
                                  _lowCount() > 0,
                                ),
                                navigation: AnimatedBuilder(
                                  animation: _listScrollController,
                                  builder: (_, _) {
                                    return Container(
                                      height: 56,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Row(
                                        children: [
                                          SpaceCircle(
                                            label: 'Back',
                                            icon: Icons.chevron_left,
                                            onTap: () => Navigator.of(
                                              context,
                                            ).pop(_changed),
                                          ),
                                          const SizedBox(width: 52),
                                          Expanded(
                                            child: Opacity(
                                              key: const ValueKey(
                                                'space-title-fade',
                                              ),
                                              opacity:
                                                  (1 -
                                                          (_listScrollController
                                                                      .hasClients
                                                                  ? _listScrollController
                                                                        .offset
                                                                  : 0) /
                                                              100)
                                                      .clamp(0.0, 1.0),
                                              child: AppText(
                                                _location,
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: SpaceStyle.of(
                                                  context,
                                                ).text(17),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: SpaceStyle.of(
                                              context,
                                            ).card(22),
                                            child: NotificationBell(
                                              api: widget.api,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          PopupMenuButton<String>(
                                            tooltip: 'More',
                                            color: SpaceStyle.of(context).menu,
                                            constraints:
                                                const BoxConstraints.tightFor(
                                                  width: 230,
                                                ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              side: BorderSide(
                                                color: SpaceStyle.of(
                                                  context,
                                                ).line2,
                                              ),
                                            ),
                                            onSelected: _onFabItemTap,
                                            itemBuilder: (_) => [
                                              if (!widget.readOnly &&
                                                  widget.api.canEdit)
                                                _spaceMenu(
                                                  'Import Spreadsheet',
                                                  Icons.table_chart_outlined,
                                                ),
                                              if (!widget.readOnly &&
                                                  widget.api.canEdit &&
                                                  (inventory == null ||
                                                      inventory.isPersonal))
                                                _spaceMenu(
                                                  'Share Space',
                                                  Icons.ios_share,
                                                ),
                                              if (inventory == null)
                                                _spaceMenu(
                                                  'Join Space',
                                                  Icons.person_add_outlined,
                                                ),
                                              _spaceMenu(
                                                'Print Bin Label',
                                                Icons.qr_code,
                                              ),
                                              if (inventory == null ||
                                                  inventory.isPersonal)
                                                _spaceMenu(
                                                  'Members',
                                                  Icons.people_outline,
                                                ),
                                            ],
                                            child: Container(
                                              width: 44,
                                              height: 44,
                                              decoration: SpaceStyle.of(
                                                context,
                                              ).card(22),
                                              child: const Icon(
                                                Icons.more_horiz,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                summary: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    6,
                                    20,
                                    0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: AppText(
                                          '${spaceCount(_items.length)} items · ${spaceCount(_totalCount())} units',
                                          key: const ValueKey(
                                            'space-unit-count',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: SpaceStyle.of(context).text(
                                            15,
                                            SpaceStyle.of(context).tx2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: SpaceStatusCard(
                                              icon:
                                                  Icons.photo_library_outlined,
                                              title: 'Review',
                                              subtitle: 'Items to finish',
                                              onTap: _openReview,
                                              onLongPress: _openReview,
                                            ),
                                          ),
                                          if (_lowCount() > 0)
                                            const SizedBox(width: 8),
                                          if (_lowCount() > 0)
                                            Expanded(
                                              child: SpaceStatusCard(
                                                icon:
                                                    Icons.inventory_2_outlined,
                                                title: 'Low quantity',
                                                subtitle:
                                                    '${_lowCount()} ${_lowCount() == 1 ? 'item' : 'items'}',
                                                active: _onlyLowQuantity,
                                                onTap: () => setState(() {
                                                  _onlyLowQuantity =
                                                      !_onlyLowQuantity;
                                                  _answerIds = null;
                                                }),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                search: _items.isEmpty
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          20,
                                          14,
                                          20,
                                          10,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                decoration: SpaceStyle.of(
                                                  context,
                                                ).card(22),
                                                child: Row(
                                                  children: [
                                                    const SizedBox(width: 14),
                                                    Icon(
                                                      Icons.search,
                                                      size: 18,
                                                      color: SpaceStyle.of(
                                                        context,
                                                      ).tx2,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: TextField(
                                                        controller:
                                                            _spaceSearchController,
                                                        style: SpaceStyle.of(
                                                          context,
                                                        ).text(15.5),
                                                        textInputAction:
                                                            TextInputAction
                                                                .search,
                                                        decoration: InputDecoration(
                                                          hintText:
                                                              'Search ${spaceCount(_items.length)} items',
                                                          hintStyle:
                                                              SpaceStyle.of(
                                                                context,
                                                              ).text(
                                                                15.5,
                                                                SpaceStyle.of(
                                                                  context,
                                                                ).tx3,
                                                              ),
                                                          border:
                                                              InputBorder.none,
                                                          enabledBorder:
                                                              InputBorder.none,
                                                          focusedBorder:
                                                              InputBorder.none,
                                                          filled: false,
                                                          contentPadding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 10,
                                                              ),
                                                          isDense: true,
                                                        ),
                                                        onChanged: (value) =>
                                                            setState(() {
                                                              _spaceSearchQuery =
                                                                  value;
                                                              _answerIds = null;
                                                            }),
                                                        onSubmitted: (_) =>
                                                            FocusScope.of(
                                                              context,
                                                            ).unfocus(),
                                                      ),
                                                    ),
                                                    if (_spaceSearchQuery
                                                        .isNotEmpty)
                                                      IconButton(
                                                        tooltip: 'Clear search',
                                                        icon: Icon(
                                                          Icons.cancel,
                                                          size: 20,
                                                          color: SpaceStyle.of(
                                                            context,
                                                          ).tx2,
                                                        ),
                                                        onPressed: () => setState(
                                                          () {
                                                            _spaceSearchController
                                                                .clear();
                                                            _spaceSearchQuery =
                                                                '';
                                                          },
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SpaceCircle(
                                              label: 'Sort',
                                              icon: Icons.swap_vert,
                                              onTap: _openSort,
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                            if (_syncError != null)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: AppText(
                                    _syncError!,
                                    style: SpaceStyle.of(
                                      context,
                                    ).text(13, SpaceStyle.of(context).amber),
                                  ),
                                ),
                              ),
                            if (_items.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    4,
                                    20,
                                    6,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child:
                                            _onlyLowQuantity ||
                                                _answerIds != null
                                            ? Align(
                                                alignment: Alignment.centerLeft,
                                                child: InputChip(
                                                  label: AppText(
                                                    _onlyLowQuantity
                                                        ? 'Low quantity'
                                                        : 'Ask results',
                                                  ),
                                                  backgroundColor:
                                                      SpaceStyle.of(
                                                        context,
                                                      ).white,
                                                  labelStyle:
                                                      SpaceStyle.of(
                                                        context,
                                                      ).text(
                                                        12.5,
                                                        SpaceStyle.of(
                                                          context,
                                                        ).bg,
                                                      ),
                                                  deleteIconColor:
                                                      SpaceStyle.of(context).bg,
                                                  onDeleted: () => setState(() {
                                                    _onlyLowQuantity = false;
                                                    _answerIds = null;
                                                  }),
                                                ),
                                              )
                                            : AppText(
                                                '${spaceCount(filtered.length)} ${_spaceSearchQuery.isEmpty ? 'items' : 'results'}',
                                                style: SpaceStyle.of(context)
                                                    .text(
                                                      12.5,
                                                      SpaceStyle.of(
                                                        context,
                                                      ).tx3,
                                                    ),
                                              ),
                                      ),
                                      Expanded(
                                        child: AppText(
                                          itemSortLabel(_sortOption),
                                          textAlign: TextAlign.right,
                                          style: SpaceStyle.of(context).text(
                                            12.5,
                                            SpaceStyle.of(context).tx3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (categories.length > 2)
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 52,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    itemCount: categories.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (_, i) => ChoiceChip(
                                      label: AppText(categories[i]),
                                      selected:
                                          categories[i] == _selectedCategory,
                                      showCheckmark: false,
                                      selectedColor: SpaceStyle.of(
                                        context,
                                      ).white,
                                      backgroundColor: SpaceStyle.of(
                                        context,
                                      ).s1,
                                      labelStyle: SpaceStyle.of(context).text(
                                        13,
                                        categories[i] == _selectedCategory
                                            ? SpaceStyle.of(context).bg
                                            : SpaceStyle.of(context).tx2,
                                      ),
                                      onSelected: (_) =>
                                          _onCategoryPillTapped(categories[i]),
                                    ),
                                  ),
                                ),
                              ),
                            if (filtered.isEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    52,
                                    24,
                                    24,
                                  ),
                                  child: Column(
                                    children: [
                                      AppText(
                                        _items.isEmpty
                                            ? 'This space is empty'
                                            : _spaceSearchQuery.isNotEmpty
                                            ? 'No “$_spaceSearchQuery” in $_location'
                                            : 'No items match this filter',
                                        style: SpaceStyle.of(context).text(17),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      AppText(
                                        _items.isEmpty
                                            ? 'Tap + to add your first item.'
                                            : 'Try another search, or ask FindEZ to look across this inventory.',
                                        style: SpaceStyle.of(
                                          context,
                                        ).text(15, SpaceStyle.of(context).tx2),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (inventory != null &&
                                          _items.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 16,
                                          ),
                                          child: OutlinedButton(
                                            onPressed: () => _openAsk(
                                              initial: _spaceSearchQuery,
                                            ),
                                            child: const AppText('Ask FindEZ'),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                sliver: SliverList.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (_, index) => _buildItemRow(
                                    filtered[index],
                                    divider: index < filtered.length - 1,
                                  ),
                                ),
                              ),
                            if (filtered.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    20,
                                    154,
                                  ),
                                  child: AppText(
                                    'Showing ${spaceCount(filtered.length)} of ${spaceCount(filtered.length)}',
                                    textAlign: TextAlign.center,
                                    style: SpaceStyle.of(
                                      context,
                                    ).text(12.5, SpaceStyle.of(context).tx3),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (MediaQuery.viewInsetsOf(context).bottom == 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IgnorePointer(
                                  child: Container(
                                    height: 45,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          SpaceStyle.of(context).bg,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  color: SpaceStyle.of(context).bg,
                                  padding: EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    MediaQuery.paddingOf(context).bottom + 18,
                                  ),
                                  child: Row(
                                    children: [
                                      if (inventory != null)
                                        Expanded(
                                          child: Material(
                                            color: SpaceStyle.of(context).s1,
                                            shape: StadiumBorder(
                                              side: BorderSide(
                                                color: SpaceStyle.of(
                                                  context,
                                                ).line2,
                                              ),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: InkWell(
                                              onTap: _openAsk,
                                              child: SizedBox(
                                                height: 58,
                                                child: Row(
                                                  children: [
                                                    const SizedBox(width: 10),
                                                    Container(
                                                      width: 38,
                                                      height: 38,
                                                      decoration: BoxDecoration(
                                                        color: SpaceStyle.of(
                                                          context,
                                                        ).white,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            9,
                                                          ),
                                                      child: Image.asset(
                                                        'assets/brand/findez-mark-black.png',
                                                        color: SpaceStyle.of(
                                                          context,
                                                        ).bg,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: AppText(
                                                        'Ask about $_location',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            SpaceStyle.of(
                                                              context,
                                                            ).text(
                                                              16,
                                                              SpaceStyle.of(
                                                                context,
                                                              ).tx2,
                                                            ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      tooltip:
                                                          'Ask about $_location with voice',
                                                      onPressed: () =>
                                                          _openAsk(voice: true),
                                                      icon: Icon(
                                                        Icons.mic_none,
                                                        color: SpaceStyle.of(
                                                          context,
                                                        ).tx2,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (!widget.readOnly &&
                                          widget.api.canEdit) ...[
                                        if (inventory != null)
                                          const SizedBox(width: 8)
                                        else
                                          const Spacer(),
                                        SpaceCircle(
                                          key: TutorialController
                                              .spaceDetailFabKey,
                                          label: 'Add items',
                                          icon: Icons.add,
                                          size: 58,
                                          white: true,
                                          onTap: _openAdd,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _spaceMenu(String title, IconData icon) =>
      PopupMenuItem(
        value: title,
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: AppText(title, style: SpaceStyle.of(context).text(15.5)),
            ),
            Icon(icon, size: 20),
          ],
        ),
      );

  void _openReview() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ReviewQueuePage(
        api: widget.api,
        location: _location,
        onInventoryMutated: () => _changed = true,
      ),
    ),
  );

  void _openSort() => showSpaceSheet<void>(
    context,
    builder: (ctx) => SpaceSheetList(
      title: 'Sort by',
      children: [
        for (final option in ItemSortOption.values)
          SpaceAction(
            icon: Icons.sort,
            title: itemSortLabel(option),
            selected: option == _sortOption,
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _sortOption = option);
              unawaited(saveSortPref(option));
            },
          ),
      ],
    ),
  );

  GlobalKey get _addAnchor => TutorialController.spaceDetailFabKey;
  Future<void> _openAdd({
    BuildContext? sourceContext,
    GlobalKey? anchor,
  }) async {
    final activeContext = sourceContext ?? context;
    final box =
        (anchor ?? _addAnchor).currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final screen = MediaQuery.sizeOf(activeContext);
    final choice = await showMenu<String>(
      context: activeContext,
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy - 260,
        screen.width - origin.dx - box.size.width,
        screen.height - origin.dy,
      ),
      popUpAnimationStyle: AnimationStyle.noAnimation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      items: [
        const PopupMenuItem(value: 'camera', child: AppText('Take photo')),
        const PopupMenuItem(value: 'library', child: AppText('Photo library')),
        const PopupMenuItem(
          value: 'spreadsheet',
          child: AppText('Import spreadsheet'),
        ),
        if (sourceContext == null && widget.api.inventoryContext != null)
          const PopupMenuItem(value: 'type', child: AppText('Type it in')),
        const PopupMenuItem(value: 'barcode', child: AppText('Scan barcode')),
      ],
    );
    if (!mounted || !activeContext.mounted || choice == null) return;
    switch (choice) {
      case 'camera':
        await _uploadImage(
          sourceContext: activeContext,
          source: ImageSource.camera,
        );
      case 'library':
        await _uploadImage(
          sourceContext: activeContext,
          source: ImageSource.gallery,
        );
      case 'spreadsheet':
        await _importSpreadsheet(sourceContext: activeContext);
      case 'barcode':
        await _scanBarcode(sourceContext: activeContext);
      case 'type':
        await _openAsk(draft: 'Add ');
    }
  }

  void _acceptUpdated(InventoryItem updated) {
    if (!mounted) return;
    setState(() {
      final index = _items.indexWhere((item) => item.itemId == updated.itemId);
      if (index >= 0) {
        final stillHere = widget.spaceId == null
            ? updated.location == _location
            : updated.spaceId == widget.spaceId;
        if (stillHere) {
          _items[index] = updated;
        } else {
          _items.removeAt(index);
        }
      }
      _changed = true;
    });
  }

  Future<void> _quickView(InventoryItem item) => showSpaceQuickView(
    context,
    item: item,
    api: widget.api,
    readOnly: widget.readOnly,
    threshold: _thresholds[item.itemId],
    onThresholdChanged: (threshold) {
      if (!mounted) return;
      setState(() {
        if (threshold == null) {
          _thresholds.remove(item.itemId);
        } else {
          _thresholds[item.itemId] = threshold;
        }
      });
    },
    onUpdated: _acceptUpdated,
    onEdit: (item) => _showProductInfo(context, item),
    onAsk: widget.api.inventoryContext == null
        ? null
        : (question) => _openAsk(initial: question),
  );

  Future<void> _openAsk({
    String? initial,
    String? draft,
    bool voice = false,
  }) async {
    if (widget.api.inventoryContext == null) return;
    await showSpaceAsk(
      context,
      api: widget.api,
      space: _location,
      spaceId: widget.spaceId,
      items: _items,
      thresholds: _thresholds,
      readOnly: widget.readOnly,
      initialMessage: initial,
      initialDraft: draft,
      startVoice: voice,
      onUpdated: _acceptUpdated,
      onThresholdChanged: (id, threshold) {
        if (!mounted) return;
        setState(() {
          if (threshold == null) {
            _thresholds.remove(id);
          } else {
            _thresholds[id] = threshold;
          }
        });
      },
      onAdd: (ctx, anchor) => _openAdd(sourceContext: ctx, anchor: anchor),
      onInventoryMutated: () {
        _changed = true;
        unawaited(_refreshSpace());
      },
      onShowItems: (ids) => setState(() {
        _answerIds = ids;
        _onlyLowQuantity = false;
        _selectedCategory = 'All';
        _spaceSearchQuery = '';
        _spaceSearchController.clear();
      }),
      onShowLow: () => setState(() {
        _onlyLowQuantity = true;
        _answerIds = null;
        _selectedCategory = 'All';
        _spaceSearchQuery = '';
        _spaceSearchController.clear();
      }),
    );
  }

  void _onFabItemTap(String label) {
    switch (label) {
      case 'Scan Photo':
        unawaited(_uploadImage());
      case 'Import Spreadsheet':
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
            builder: (_, _) => ShareSpaceSheet(
              spaceName: _location,
              teamId: widget.api.teamId,
              api: widget.api,
            ),
          ),
        );
      case 'Join Space':
        unawaited(_joinSpaceDialog());
      case 'Print Bin Label':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BinLabelSheet(spaceName: _location, items: _items),
        );
      case 'Members':
        unawaited(() async {
          try {
            final shares = await widget.api.getMyShares();
            dynamic match;
            for (final s in shares) {
              if ((s['share_name'] ?? '').toString().toLowerCase() ==
                  _location.toLowerCase()) {
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
                    spaceName: _location,
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
                  content: AppText('Couldn’t load space members. Try again.'),
                ),
              );
            }
            return;
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: AppText("This space isn't shared yet")),
            );
          }
        }());
    }
  }
}

class _InventoryPageState extends State<InventoryPage>
    with WidgetsBindingObserver {
  late final AccountRefresh _accountRefresh;
  late final TextEditingController _search;
  final ValueNotifier<String> _query = ValueNotifier('');
  final ValueNotifier<List<InventoryItem>> _rows = ValueNotifier(const []);
  final ValueNotifier<bool> _aiSearching = ValueNotifier(false);
  final ValueNotifier<Map<String, int>> _thresholds = ValueNotifier(const {});
  RestockPlan _restockPlan = const RestockPlan({});
  bool _restockReady = false;
  bool _restockFailed = false;

  final ValueNotifier<String> _category = ValueNotifier('All');

  bool _loading = true;
  bool _hasLoadedItems = false;
  String? _itemsOwner;
  Future<void>? _itemsLoad;
  int _itemsReadGeneration = 0;
  bool _openingLocation = false;
  String? _error;
  List<InventoryItem> _items = const [];
  List<Map<String, dynamic>> _joinedShares = [];
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
    _accountRefresh = AccountRefresh(
      refresh: () async {
        await Future.wait([
          _loadItems(),
          _loadSpaces(),
          _loadMyShares(),
          _loadJoinedShares(),
        ]);
      },
      isActive: () =>
          mounted && (ModalRoute.of(context)?.isCurrent ?? true) && (!_loading),
    );
    WidgetsBinding.instance.addObserver(this);
    RestockPrefs.changes.addListener(_restockChanged);
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
      thresholds: await LowStockPrefs.loadAll(),
      spaceId: hint['space_id']?.toString(),
    );
  }

  Future<void> _leaveJoinedSpace({
    required String shareId,
    required String name,
  }) async {
    final confirmed = await showDialog<bool>(
      useRootNavigator: false,
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Leave Space?'),
        content: AppText(
          'You will lose access to “$name”. The owner’s Space and items will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: AppText(
              'Leave Space',
              style: TextStyle(
                color: AppTheme.foreground(context, AppColors.danger),
              ),
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
      ).showSnackBar(SnackBar(content: AppText('Left “$name”')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedItems && !_loading && _itemsLoad == null) {
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

  Map<String, List<InventoryItem>> _groupByLocation(List<InventoryItem> items) {
    final groups = <String, List<InventoryItem>>{};
    for (final it in items) {
      final loc = it.location.trim().isEmpty ? 'Unsorted' : it.location.trim();
      (groups[loc] ??= <InventoryItem>[]).add(it);
    }
    return groups;
  }

  Future<void> _openLocation({
    required String location,
    required Map<String, int> thresholds,
    String? spaceId,
  }) async {
    if (!mounted || _openingLocation) return;
    _openingLocation = true;
    final owner = Supabase.instance.client.auth.currentUser?.id;
    try {
      // Registration makes navigation available before the cold inventory read
      // finishes. Never snapshot that uninitialized list into a Space route.
      if (_itemsLoad != null ||
          !_hasLoadedItems ||
          _itemsOwner != owner ||
          _error != null) {
        await _loadItems();
      }
      if (!mounted || Supabase.instance.client.auth.currentUser?.id != owner) {
        return;
      }
      if (_error != null || !_hasLoadedItems || _itemsOwner != owner) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Could not load this Space. Please try again.'),
          ),
        );
        return;
      }
      await _showLocation(
        location: location,
        thresholds: thresholds,
        spaceId: spaceId,
      );
    } finally {
      _openingLocation = false;
    }
  }

  Future<void> _showLocation({
    required String location,
    required Map<String, int> thresholds,
    String? spaceId,
  }) async {
    if (!mounted) return;
    final loc = location.trim().isEmpty ? 'Unsorted' : location.trim();

    // If this space has an active share owned by the current user, open the
    // full workspace view instead of the simple location detail view.
    Map<String, dynamic>? matchedShare;
    for (final s in _myShares) {
      if ((s['share_name'] ?? '').toString().trim().toLowerCase() ==
          loc.toLowerCase()) {
        matchedShare = s;
        break;
      }
    }
    if (matchedShare != null && spaceId == null) {
      final shareId = (matchedShare['share_id'] ?? '').toString();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SharedInventoryPage(
            shareId: shareId,
            shareName: loc,
            permission: 'edit',
            api: widget.api,
          ),
        ),
      );
      await _loadItems();
      return;
    }

    final String? resolvedSpaceId =
        spaceId ??
        ((loc == 'Unsorted')
            ? null
            : (_spaces.firstWhere(
                    (s) =>
                        (s['name'] as String? ?? '').toLowerCase() ==
                        loc.toLowerCase(),
                    orElse: () => const <String, dynamic>{},
                  )['id']
                  as String?));
    // A Home Space opens its complete inventory, independent of Find's filter.
    final source = spaceId == null ? _baseItemsForSelectedCategory() : _items;
    final items = source.where((it) => it.spaceId == resolvedSpaceId).toList();

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LocationItemsPage(
          api: widget.api,
          location: loc,
          items: items,
          thresholds: thresholds,
          allItems: _items,
          spaceId: resolvedSpaceId,
          readOnly: !widget.api.canEdit,
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
    _accountRefresh.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _search.dispose();
    _createSpaceCtrl.dispose();
    _joinCodeCtrl.dispose();
    _renameSpaceCtrl.dispose();
    _query.dispose();
    _rows.dispose();
    _aiSearching.dispose();
    RestockPrefs.changes.removeListener(_restockChanged);
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

  int _lowStockCount() => _items
      .where((i) => _restockPlan.needsBuying(i.itemId, i.quantity))
      .length;
  int _onOrderCount() =>
      _items.where((i) => _restockPlan.onOrder(i.itemId)).length;
  void _restockChanged() => unawaited(_refreshRestock());
  Future<void> _refreshRestock() async {
    final account = RestockPrefs.accountKey;
    try {
      final plan = await RestockPrefs.load();
      if (!mounted || account != RestockPrefs.accountKey) return;
      setState(() {
        _restockPlan = plan;
        _restockReady = true;
        _restockFailed = false;
      });
      _thresholds.value = plan.thresholds;
      unawaited(
        LowStockNotifications.evaluate(
          _items
              .map(
                (item) => LowStockCandidate(
                  itemId: item.itemId,
                  name: item.name,
                  quantity: item.quantity,
                  threshold: plan.thresholds[item.itemId] ?? -1,
                  spaceName: item.location,
                ),
              )
              .toList(),
        ).catchError((Object error) {
          if (!mounted || account != RestockPrefs.accountKey) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: AppText(
                'Could not refresh restock notifications. Your purchase plan is saved.',
              ),
            ),
          );
        }),
      );
    } catch (_) {
      if (!mounted || account != RestockPrefs.accountKey) return;
      setState(() {
        _restockReady = false;
        _restockFailed = true;
      });
    }
  }

  Future<void> _openRestock() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ShoppingListPage(api: widget.api)),
    );
    if (mounted) await _loadItems();
  }

  Future<void> _loadItems() {
    final running = _itemsLoad;
    if (running != null) return running;
    late final Future<void> request;
    request = _fetchItems().whenComplete(() {
      if (identical(_itemsLoad, request)) _itemsLoad = null;
    });
    _itemsLoad = request;
    return request;
  }

  Future<void> _fetchItems() async {
    if (!mounted) return;
    final generation = ++_itemsReadGeneration;
    final owner = Supabase.instance.client.auth.currentUser?.id;
    bool current() =>
        mounted &&
        generation == _itemsReadGeneration &&
        Supabase.instance.client.auth.currentUser?.id == owner;
    final t0 = DateTime.now().millisecondsSinceEpoch;
    debugPrint(
      '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems start',
    );
    setState(() {
      _loading = !_hasLoadedItems;
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
      if (!current()) {
        return;
      }
      setState(() {
        _items = result.items;
        _hasLoadedItems = true;
        _itemsOwner = owner;
      });
      await _refreshRestock();
      if (!current()) {
        return;
      }
      _applyLocalSearch(_query.value);
    } on SessionExpiredException {
      debugPrint(
        '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems: SessionExpiredException',
      );
      if (!current()) return;
      setState(() => _error = 'Session expired. Please sign in again.');
    } on TimeoutException catch (e) {
      debugPrint(
        '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems: TimeoutException: $e',
      );
      if (!current()) return;
      setState(() => _error = 'connection');
    } on dio.DioException catch (e) {
      debugPrint(
        '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems: DioException: ${e.response?.statusCode}',
      );
      if (!current()) return;
      if ([401, 403, 404, 410].contains(e.response?.statusCode)) {
        setState(() {
          _items = [];
          _spaces = [];
          _error = 'This inventory is no longer available.';
        });
        _rows.value = const [];
        return;
      }
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
      if (!current()) return;
      setState(() => _error = 'connection');
    } finally {
      debugPrint(
        '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems finally (total ${DateTime.now().millisecondsSinceEpoch - t0}ms)',
      );
      if (current()) setState(() => _loading = false);
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
    if (widget.api.inventoryContext != null) return;
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
    } catch (e) {
      debugPrint(
        '[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadJoinedShares error: ${describeError(e).$1}',
      );
      if (mounted) setState(() => _joinedSharesError = describeError(e).$1);
    }
  }

  Future<void> _loadMyShares() async {
    if (widget.api.inventoryContext != null &&
        !widget.api.inventoryContext!.isPersonal) {
      return;
    }
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

  List<InventoryItem> _smartLocalSearch(
    String rawQuery, {
    List<String> extraTerms = const [],
  }) {
    final base = _baseItemsForSelectedCategory();
    final q = rawQuery.trim();
    if (q.isEmpty) return base;

    final scored = <({InventoryItem item, int score})>[];
    for (final it in base) {
      var score = it.searchScore(q);
      if (score == 0) {
        for (final alternative in extraTerms) {
          final candidate = it.searchScore(alternative);
          if (candidate > 0) score = 1;
        }
      }
      if (score > 0) scored.add((item: it, score: score));
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

  Future<void> _addItem() async {
    if (!widget.api.canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('You have view-only access to this inventory.'),
        ),
      );
      return;
    }
    final created = await showModalBottomSheet<ItemEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => ItemEditorSheet(
        availableLocations: {
          ..._items.map(
            (i) => i.location.trim().isEmpty ? 'Unsorted' : i.location.trim(),
          ),
          ..._myShares
              .map((s) => (s['share_name'] ?? '').toString().trim())
              .where((n) => n.isNotEmpty),
        }.toList()..sort(),
      ),
    );
    if (created == null) return;

    try {
      final out = await widget.api.addItem(item: created.add);
      await LowStockPrefs.setThreshold(
        itemId: out.itemId,
        threshold: created.threshold,
      );
      final next = Map<String, int>.from(_thresholds.value);
      if (created.threshold == null || created.threshold! <= 0) {
        next.remove(out.itemId);
      } else {
        next[out.itemId] = created.threshold!;
      }
      _thresholds.value = next;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('Item added')));
      await _loadItems();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      debugPrint(
        'FINDEZ addItem error: ${e.response?.statusCode} | ${e.response?.data} | ${e.message}',
      );
      if (e.response?.statusCode == 429) {
        if (!ProStatus.isPro) {
          final detail = e.response?.data?['detail'];
          final message = detail is Map
              ? detail['message'] as String?
              : 'You\'ve reached your free limit.';
          showUpgradeSheet(
            context,
            widget.api,
            reason: message ?? 'You\'ve reached your free limit.',
          );
        } else {
          debugPrint('FINDEZ: Pro user got 429 — backend bug');
          unawaited(ProStatus.refresh(widget.api));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: AppText('Something went wrong. Please try again.'),
            ),
          );
        }
        return;
      }
      if (e.response?.statusCode == 403 &&
          widget.api.inventoryContext != null &&
          describeError(e).$2 != ErrorKind.planLimit) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(describeError(e).$1)));
        return;
      }
      if (e.response?.statusCode == 403) {
        // Legacy unscoped item-limit behavior.
        if (!ProStatus.isPro) {
          showUpgradeSheet(
            context,
            widget.api,
            reason: 'You\'ve reached the free item limit.',
          );
        } else {
          debugPrint('FINDEZ: Pro user got 403 — backend bug');
          unawaited(ProStatus.refresh(widget.api));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: AppText('Something went wrong. Please try again.'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Connection issue. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _editItem(InventoryItem item) async {
    await showItemDetailSheet(
      context,
      item: item,
      api: widget.api,
      permission: widget.api.canEdit ? 'edit' : 'view',
      spaceName: item.location,
      initialThreshold: _thresholds.value[item.itemId],
    );
    if (mounted) await _loadItems();
  }

  Future<void> _deleteItem(InventoryItem item) async {
    if (!widget.api.canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('You have view-only access to this inventory.'),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      useRootNavigator: false,
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Delete item?'),
        content: AppText(item.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.deleteItem(itemId: item.itemId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('Deleted')));
      await _loadItems();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 429) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Connection issue. Please try again.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Connection issue. Please try again.'),
          ),
        );
      }
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_outlined,
            color: AppTheme.foreground(context, const Color(0x4DFFFFFF)),
            size: 48,
          ),
          const SizedBox(height: 16),
          AppText(
            'Could not load inventory',
            style: TextStyle(
              color: AppTheme.foreground(context, Colors.white),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          AppText(
            'Pull down to retry',
            style: TextStyle(
              color: AppTheme.foreground(context, const Color(0x73FFFFFF)),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _loadItems,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.adaptive(context, const Color(0xFF171717)),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                ),
              ),
              child: AppText(
                'Retry',
                style: TextStyle(
                  color: AppTheme.foreground(context, Colors.white),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpacesGrid(Map<String, int> thresholds) {
    final groups = _groupByLocation(_baseItemsForSelectedCategory());
    // Keep the approved default card height, but let accessibility text grow it.
    final minimumCardHeight = (MediaQuery.sizeOf(context).width - 64) / 3.35;
    final allSpaces = [..._spaces]
      ..sort(
        (a, b) => (a['name'] as String).toLowerCase().compareTo(
          (b['name'] as String).toLowerCase(),
        ),
      );
    return CustomScrollView(
      slivers: [
        if (allSpaces.isEmpty)
          SliverToBoxAdapter(
            child: _spacesError
                ? GestureDetector(
                    onTap: () => unawaited(_loadSpaces()),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.adaptive(context, AppColors.surface),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.adaptive(context, AppColors.border),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.wifi_off_outlined,
                            color: AppTheme.foreground(
                              context,
                              const Color(0x73FFFFFF),
                            ),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppText(
                              'Could not load spaces. Tap to retry.',
                              style: TextStyle(
                                color: AppTheme.foreground(
                                  context,
                                  const Color(0x73FFFFFF),
                                ),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.adaptive(context, AppColors.surface),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.adaptive(context, AppColors.border),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_box_outlined,
                          color: AppTheme.foreground(
                            context,
                            const Color(0xFFF2F2F7),
                          ),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppText(
                            'Create your first space to start organizing your inventory.',
                            style: TextStyle(
                              color: AppTheme.foreground(
                                context,
                                Colors.white70,
                              ),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 132),
          sliver: SliverList.separated(
            itemCount: allSpaces.length + (widget.api.canEdit ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == allSpaces.length) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _createSpace(context);
                  },
                  child: Container(
                    constraints: BoxConstraints(minHeight: minimumCardHeight),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: AppTheme.adaptive(context, AppColors.surface),
                      border: Border.all(
                        color: AppTheme.adaptive(context, AppColors.border),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          color: AppTheme.foreground(
                            context,
                            const Color(0xFFF2F2F7),
                          ),
                          size: 28,
                        ),
                        const SizedBox(height: 10),
                        AppText(
                          'New Space',
                          style: TextStyle(
                            color: AppTheme.foreground(context, Colors.white),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final space = allSpaces[index];
              final loc = space['name'] as String;
              final spaceId = space['id'] as String;
              final items = groups[loc] ?? const <InventoryItem>[];
              final lowStock = items
                  .where(
                    (it) => _restockPlan.needsBuying(it.itemId, it.quantity),
                  )
                  .length;
              final onOrder = items
                  .where((it) => _restockPlan.onOrder(it.itemId))
                  .length;
              return GestureDetector(
                key: index == 0 ? TutorialController.firstSpaceCardKey : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  unawaited(
                    _openLocation(location: loc, thresholds: thresholds),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: AppTheme.adaptive(context, AppColors.surface),
                        border: Border.all(
                          color: AppTheme.adaptive(context, AppColors.border),
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 1,
                              color: AppTheme.border(context),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: minimumCardHeight - 24,
                              ),
                              child: Row(
                                children: [
                                  SpaceIconButton(
                                    key: ValueKey('space-icon-button-$spaceId'),
                                    spaceId: spaceId,
                                    spaceName: loc,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AppText(
                                          loc,
                                          style: TextStyle(
                                            color: AppTheme.foreground(
                                              context,
                                              Colors.white,
                                            ),
                                            fontSize: 16,
                                            height: 1.2,
                                            fontWeight: FontWeight.w400,
                                            letterSpacing: -0.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 5),
                                        Wrap(
                                          children: [
                                            AppText(
                                              '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                                              style: TextStyle(
                                                color: AppTheme.foreground(
                                                  context,
                                                  Colors.white,
                                                ),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                            if (onOrder > 0)
                                              AppText(
                                                '  |  $onOrder on order',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      RestockStatusColors.onOrder(
                                                        context,
                                                      ),
                                                ),
                                              ),
                                            if (lowStock > 0) ...[
                                              AppText(
                                                '  ·  ',
                                                style: TextStyle(
                                                  color: AppTheme.foreground(
                                                    context,
                                                    const Color(0x40FFFFFF),
                                                  ),
                                                ),
                                              ),
                                              AppText(
                                                '$lowStock to buy',
                                                style: TextStyle(
                                                  color:
                                                      RestockStatusColors.toBuy(
                                                        context,
                                                      ),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (widget.api.canEdit &&
                                      (widget.api.inventoryContext == null ||
                                          widget
                                              .api
                                              .inventoryContext!
                                              .isPersonal))
                                    IconButton(
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) =>
                                              DraggableScrollableSheet(
                                                initialChildSize: 0.65,
                                                maxChildSize: 0.92,
                                                minChildSize: 0.4,
                                                builder: (_, _) =>
                                                    ShareSpaceSheet(
                                                      spaceName: loc,
                                                      api: widget.api,
                                                    ),
                                              ),
                                        );
                                      },
                                      tooltip: 'Share space',
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 32,
                                            height: 32,
                                          ),
                                      icon: Icon(
                                        Icons.person_add_alt_1_rounded,
                                        color: AppTheme.foreground(
                                          context,
                                          const Color(0x99FFFFFF),
                                        ),
                                        size: 18,
                                      ),
                                    ),
                                  if (widget.api.canEdit)
                                    IconButton(
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        _showSpaceMenu(context, loc, spaceId);
                                      },
                                      tooltip: 'Space options',
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 32,
                                            height: 32,
                                          ),
                                      icon: Icon(
                                        Icons.more_horiz,
                                        color: AppTheme.foreground(
                                          context,
                                          const Color(0x60FFFFFF),
                                        ),
                                        size: 19,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_joinedSharesError != null && _joinedShares.isEmpty)
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () => unawaited(_loadJoinedShares()),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.adaptive(context, AppColors.surface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.adaptive(context, AppColors.border),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.refresh,
                      color: AppTheme.foreground(
                        context,
                        const Color(0x4DFFFFFF),
                      ),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppText(
                        "Couldn't load joined spaces — tap to retry",
                        style: TextStyle(
                          color: AppTheme.foreground(
                            context,
                            Colors.white.withValues(alpha: 0.35),
                          ),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_joinedShares.isNotEmpty) ...<Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: AppText(
                'JOINED SPACES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.foreground(context, const Color(0x4DFFFFFF)),
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, i) {
              final share = _joinedShares[i];
              final ts = (share['team_shares'] as Map<String, dynamic>?) ?? {};
              final name = (ts['share_name'] ?? 'Shared Space') as String;
              final permission = (ts['permission'] ?? 'view') as String;
              final shareId = (ts['share_id'] ?? share['share_id']).toString();
              return GestureDetector(
                onTap: () => unawaited(_openSharedSpace(share)),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.adaptive(context, AppColors.surface),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTheme.adaptive(context, AppColors.border),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            SpaceIconButton(
                              key: ValueKey('share-icon-button-$shareId'),
                              namespace: 'share',
                              spaceId: shareId == 'null' ? '' : shareId,
                              spaceName: name,
                              fallbackIcon:
                                  CupertinoIcons.folder_badge_person_crop,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    name,
                                    style: TextStyle(
                                      color: AppTheme.foreground(
                                        context,
                                        Colors.white,
                                      ),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  AppText(
                                    permission == 'edit'
                                        ? 'Can edit'
                                        : 'View only',
                                    style: TextStyle(
                                      color: AppTheme.foreground(
                                        context,
                                        const Color(0x73FFFFFF),
                                      ),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppMenuButton(
                              label: 'Space options',
                              onSelected: (value) {
                                if (value == 'share') {
                                  showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => SizedBox(
                                      height:
                                          MediaQuery.sizeOf(context).height *
                                          .72,
                                      child: ShareSpaceSheet(
                                        spaceName: name,
                                        shareId: shareId,
                                        api: widget.api,
                                      ),
                                    ),
                                  );
                                }
                                if (value == 'leave') {
                                  unawaited(
                                    _leaveJoinedSpace(
                                      shareId: shareId,
                                      name: name,
                                    ),
                                  );
                                }
                              },
                              items: const [
                                AppMenuItem(
                                  'share',
                                  'Share invitation link',
                                  'square.and.arrow.up',
                                ),
                                AppMenuItem(
                                  'leave',
                                  'Leave Space',
                                  'rectangle.portrait.and.arrow.right',
                                  destructive: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 52,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.adaptive(
                              context,
                              AppColors.surface2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: AppText(
                            'Shared',
                            style: TextStyle(
                              color: AppTheme.foreground(
                                context,
                                AppColors.muted,
                              ),
                              fontSize: 9,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }, childCount: _joinedShares.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ],
    );
  }

  Future<void> _createSpace(BuildContext context) async {
    _createSpaceCtrl.clear();
    final name = await showDialog<String>(
      useRootNavigator: false,
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface2(context),
        title: AppText(
          'New Space',
          style: TextStyle(color: AppTheme.foreground(context, Colors.white)),
        ),
        content: TextField(
          controller: _createSpaceCtrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: AppTypography.bodyStyleOf(
            context,
            TextStyle(color: AppTheme.foreground(context, Colors.white)),
          ),
          decoration: InputDecoration(
            hintText: 'Space name',
            hintStyle: AppTypography.bodyStyleOf(
              context,
              TextStyle(
                color: AppTheme.foreground(context, const Color(0x4DFFFFFF)),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _createSpaceCtrl.text.trim()),
            child: const AppText('Create'),
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
      if (status == 402 ||
          (status == 403 &&
              (widget.api.inventoryContext == null ||
                  describeError(e).$2 == ErrorKind.planLimit))) {
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
              content: AppText('Something went wrong. Please try again.'),
            ),
          );
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Couldn’t create the space. Try again.'),
        ),
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
      useRootNavigator: false,
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (_, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.adaptive(context, AppColors.surface2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.adaptive(context, AppColors.border),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Join a Space',
                      style: TextStyle(
                        color: AppTheme.foreground(context, Colors.white),
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _joinCodeCtrl,
                      autofocus: true,
                      maxLength: 6,
                      textCapitalization: TextCapitalization.characters,
                      style: AppTypography.bodyStyleOf(
                        context,
                        TextStyle(
                          color: AppTheme.foreground(context, Colors.white),
                          fontSize: 20,
                          letterSpacing: 4,
                        ),
                      ),
                      decoration: InputDecoration(
                        hintText: '6-character code',
                        hintStyle: AppTypography.bodyStyleOf(
                          context,
                          TextStyle(
                            color: AppTheme.foreground(
                              context,
                              const Color(0x4DFFFFFF),
                            ),
                          ),
                        ),
                        counterStyle: AppTypography.bodyStyleOf(
                          context,
                          TextStyle(
                            color: AppTheme.foreground(
                              context,
                              const Color(0x4DFFFFFF),
                            ),
                          ),
                        ),
                        filled: true,
                        fillColor: AppTheme.adaptive(
                          context,
                          AppColors.surface,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(12),
                          ),
                          borderSide: BorderSide(
                            color: AppTheme.adaptive(context, AppColors.border),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(12),
                          ),
                          borderSide: BorderSide(
                            color: AppTheme.adaptive(context, AppColors.border),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(12),
                          ),
                          borderSide: BorderSide(
                            color: AppTheme.adaptive(
                              context,
                              const Color(0xFFF2F2F7),
                            ),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 6),
                      AppText(
                        error!,
                        style: TextStyle(
                          color: AppTheme.foreground(
                            context,
                            const Color(0xFFFF453A),
                          ),
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
                          child: AppText(
                            'Cancel',
                            style: TextStyle(
                              color: AppTheme.foreground(
                                context,
                                Colors.white.withValues(alpha: 0.50),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            final code = _joinCodeCtrl.text
                                .trim()
                                .toUpperCase();
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
                                    content: AppText(
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
                          child: const AppText('Join'),
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
    );
  }

  Future<void> _showSpaceMenu(
    BuildContext context,
    String loc,
    String spaceId,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppTheme.adaptive(context, const Color(0xFF1C1C1E)),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.adaptive(context, const Color(0x33FFFFFF)),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.edit_outlined,
                  color: AppTheme.foreground(context, Colors.white),
                ),
                title: AppText(
                  'Rename',
                  style: TextStyle(
                    color: AppTheme.foreground(context, Colors.white),
                  ),
                ),
                onTap: () => Navigator.pop(context, 'rename'),
              ),
              if (widget.api.canDeleteSpace)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: AppTheme.foreground(
                      context,
                      const Color(0xFFFF453A),
                    ),
                  ),
                  title: AppText(
                    'Delete Space',
                    style: TextStyle(
                      color: AppTheme.foreground(
                        context,
                        const Color(0xFFFF453A),
                      ),
                    ),
                  ),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || !context.mounted) return;
    if (action == 'rename') {
      await _renameSpace(context, loc, spaceId);
    } else if (action == 'delete') {
      await _deleteSpace(context, loc, spaceId);
    }
  }

  Future<void> _renameSpace(
    BuildContext context,
    String oldName,
    String spaceId,
  ) async {
    _renameSpaceCtrl.text = oldName;
    final newName = await showDialog<String>(
      useRootNavigator: false,
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface2(context),
        title: AppText(
          'Rename Space',
          style: TextStyle(color: AppTheme.foreground(context, Colors.white)),
        ),
        content: TextField(
          controller: _renameSpaceCtrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: AppTypography.bodyStyleOf(
            context,
            TextStyle(color: AppTheme.foreground(context, Colors.white)),
          ),
          decoration: InputDecoration(
            hintStyle: AppTypography.bodyStyleOf(
              context,
              TextStyle(
                color: AppTheme.foreground(context, const Color(0x4DFFFFFF)),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _renameSpaceCtrl.text.trim()),
            child: const AppText('Save'),
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
            content: AppText('Couldn’t rename the space. Try again.'),
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
            content: const AppText(
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
    if (!widget.api.canDeleteSpace) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            'Only inventory owners and admins can delete a Space.',
          ),
        ),
      );
      return;
    }
    final owner = Supabase.instance.client.auth.currentUser?.id;
    final changed = await confirmResourceRemoval(
      context,
      widget.api,
      kind: 'space',
      id: spaceId,
      name: loc,
    );
    if (!changed ||
        !mounted ||
        Supabase.instance.client.auth.currentUser?.id != owner) {
      return;
    }
    _itemsReadGeneration++;
    _itemsLoad = null;
    InventoryCache.removeSpace(spaceId, contextKey: widget.api.cacheKey);
    widget.onSpaceDeleted?.call(spaceId);
    if (mounted) {
      await _loadSpaces();
      await _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    final restockColor = !_restockReady
        ? AppTheme.textSecondary(context)
        : _lowStockCount() > 0
        ? RestockStatusColors.toBuy(context)
        : RestockStatusColors.onOrder(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              title: AppText(
                'My Inventory',
                style: TextStyle(
                  color: AppTheme.foreground(context, Colors.white),
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.5,
                ),
              ),
              actions: [
                IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        color: AppTheme.foreground(context, Colors.white70),
                        size: 22,
                      ),
                      if (_lowStockCount() > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: AppTheme.action,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: AppText(
                                '${_lowStockCount() > 9 ? '9+' : _lowStockCount()}',
                                style: const TextStyle(
                                  color: AppTheme.onAction,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  tooltip: 'Restock planner',
                  onPressed: _openRestock,
                ),
                AppMenuButton(
                  label: 'Inventory options',
                  onSelected: (value) {
                    if (value == 'checkout') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CheckoutPage(api: widget.api),
                        ),
                      );
                    } else if (value == 'join') {
                      _joinSpaceDialog(context);
                    } else if (value == 'refresh') {
                      _loadItems();
                    }
                  },
                  items: const [
                    AppMenuItem(
                      'checkout',
                      'Check-Out Tracker',
                      'arrow.left.arrow.right',
                    ),
                    AppMenuItem('join', 'Join Space', 'person.badge.plus'),
                    AppMenuItem('refresh', 'Refresh', 'arrow.clockwise'),
                  ],
                ),
                AccountButton(api: widget.api),
              ],
            )
          : null,
      body: Container(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.5,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          key: TutorialController.inventorySearchKey,
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          onChanged: _applyLocalSearch,
                          onSubmitted: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          decoration: const InputDecoration(
                            hintText: 'Search inventory',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                          style: AppTypography.bodyStyleOf(context),
                        ),
                        const SizedBox(height: 12),
                        if (_restockFailed ||
                            _lowStockCount() > 0 ||
                            _onOrderCount() > 0)
                          GestureDetector(
                            onTap: _openRestock,
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: restockColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: restockColor.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _restockReady &&
                                            _lowStockCount() == 0 &&
                                            _onOrderCount() > 0
                                        ? Icons.local_shipping_outlined
                                        : Icons.shopping_cart_outlined,
                                    color: restockColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: !_restockReady
                                        ? const AppText(
                                            'Restock planner could not refresh. Tap to retry.',
                                            style: TextStyle(fontSize: 13),
                                          )
                                        : RestockSummary(
                                            toBuy: _lowStockCount(),
                                            onOrder: _onOrderCount(),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: restockColor,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _loading && _items.isEmpty
                      ? const ContentLoading(label: 'Loading inventory...')
                      : (_error != null && _items.isEmpty)
                      ? _buildErrorState()
                      : ValueListenableBuilder<Map<String, int>>(
                          valueListenable: _thresholds,
                          builder: (context, thresholds, _) {
                            return ValueListenableBuilder<String>(
                              valueListenable: _query,
                              builder: (context, q, _) {
                                final query = q.trim();
                                if (query.isEmpty) {
                                  return _buildSpacesGrid(thresholds);
                                }

                                return ValueListenableBuilder<bool>(
                                  valueListenable: _aiSearching,
                                  builder: (context, searching, _) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (searching)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              10,
                                              6,
                                              10,
                                              10,
                                            ),
                                            child: AppText(
                                              'Searching…',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: AppTheme.adaptive(
                                                      context,
                                                      Colors.white.withValues(
                                                        alpha: 0.55,
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        Expanded(
                                          child:
                                              ValueListenableBuilder<
                                                List<InventoryItem>
                                              >(
                                                valueListenable: _rows,
                                                builder: (context, rows, _) {
                                                  if (rows.isEmpty) {
                                                    return Center(
                                                      child: AppText(
                                                        'No results.',
                                                        style: TextStyle(
                                                          color:
                                                              AppTheme.foreground(
                                                                context,
                                                                Colors.white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.65,
                                                                    ),
                                                              ),
                                                        ),
                                                      ),
                                                    );
                                                  }

                                                  return _SearchResultsList(
                                                    rows: rows,
                                                    thresholds: thresholds,
                                                    readOnly:
                                                        !widget.api.canEdit,
                                                    onEdit: _editItem,
                                                    onDelete: _deleteItem,
                                                  );
                                                },
                                              ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: InventoryChatButton(
        api: widget.api,
        primary: !widget.api.canEdit
            ? null
            : Padding(
                padding: EdgeInsets.only(bottom: widget.showAppBar ? 94 : 0),
                child: GlassFab(heroTag: 'fab_inventory', onPressed: _addItem),
              ),
      ),
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    this.readOnly = false,
    required this.rows,
    required this.thresholds,
    required this.onEdit,
    required this.onDelete,
  });

  final List<InventoryItem> rows;
  final bool readOnly;
  final Map<String, int> thresholds;
  final Future<void> Function(InventoryItem item) onEdit;
  final Future<void> Function(InventoryItem item) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = rows[index];
        final threshold = thresholds[item.itemId];
        final isLow =
            (threshold != null && threshold >= 0 && item.quantity <= threshold);
        final imageUrl = (item.imageUrl ?? '').trim();
        return Dismissible(
          direction: readOnly
              ? DismissDirection.none
              : DismissDirection.horizontal,
          key: ValueKey(item.itemId),
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 16),
            color: AppTheme.adaptive(context, AppColors.swipe),
            child: const Icon(Icons.edit_outlined),
          ),
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.15),
            child: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              await onEdit(item);
              return false;
            }
            if (direction == DismissDirection.endToStart) {
              await onDelete(item);
              return false;
            }
            return false;
          },
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            leading: imageUrl.isEmpty
                ? null
                : ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: PrivateImage(
                      imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
            title: AppText(item.displayName),
            subtitle: AppText(
              [
                if (item.displayDescription != null) item.displayDescription!,
                item.category,
                item.location,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.foreground(
                  context,
                  Colors.white.withValues(alpha: 0.60),
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLow) ...[
                  Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: AppTheme.foreground(
                      context,
                      Colors.white.withValues(alpha: 0.70),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                AppText(
                  'Qty ${item.quantity}',
                  style: TextStyle(
                    fontFamily: 'CupertinoSystemText',
                    color: AppTheme.foreground(
                      context,
                      Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
            onTap: () => onEdit(item),
          ),
        );
      },
    );
  }
}

// ─── Barcode scanner page (reused inside LocationItemsPage) ──────────────────

class _InventoryBarcodeScannerPage extends StatefulWidget {
  const _InventoryBarcodeScannerPage();

  @override
  State<_InventoryBarcodeScannerPage> createState() =>
      _InventoryBarcodeScannerPageState();
}

class _InventoryBarcodeScannerPageState
    extends State<_InventoryBarcodeScannerPage> {
  MobileScannerController? _controller;
  bool _returned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const <BarcodeFormat>[BarcodeFormat.all],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: AppTheme.adaptive(context, Colors.black),
      appBar: AppBar(
        title: const AppText('Scan Barcode'),
        backgroundColor: AppTheme.adaptive(context, Colors.black),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: controller == null
          ? const SizedBox.shrink()
          : MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (_returned) return;
                final codes = capture.barcodes;
                if (codes.isEmpty) return;
                final raw = codes.first.rawValue;
                if (raw == null || raw.trim().isEmpty) return;
                _returned = true;
                Navigator.of(context).pop(raw.trim());
              },
            ),
    );
  }
}

// ─── Review extracted items before saving ────────────────────────────────────

class _ReviewExtractedSheet extends StatefulWidget {
  const _ReviewExtractedSheet({required this.items, required this.spaceName});

  final List<ExtractedInventoryItem> items;
  final String spaceName;

  @override
  State<_ReviewExtractedSheet> createState() => _ReviewExtractedSheetState();
}

class _ReviewExtractedSheetState extends State<_ReviewExtractedSheet> {
  late List<ExtractedInventoryItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List<ExtractedInventoryItem>.from(widget.items);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.adaptive(context, const Color(0xFF0A0A0A)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(
            color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.adaptive(context, const Color(0x33FFFFFF)),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppText(
              'Review ${_items.length} extracted item${_items.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: AppTheme.foreground(context, Colors.white),
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppText(
              'Location: ${widget.spaceName}',
              style: TextStyle(
                color: AppTheme.foreground(context, const Color(0x73FFFFFF)),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _items.length,
              separatorBuilder: (_, _) => Divider(
                color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                height: 1,
              ),
              itemBuilder: (_, i) {
                final it = _items[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: AppText(
                          it.name,
                          style: TextStyle(
                            color: AppTheme.foreground(context, Colors.white),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppText(
                          it.category,
                          style: TextStyle(
                            color: AppTheme.foreground(
                              context,
                              const Color(0x73FFFFFF),
                            ),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppText(
                        '×${it.quantity}',
                        style: TextStyle(
                          color: AppTheme.foreground(
                            context,
                            const Color(0x73FFFFFF),
                          ),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _items.removeAt(i)),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppTheme.foreground(
                            context,
                            const Color(0x4DFFFFFF),
                          ),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: AppText(
                      'Cancel',
                      style: TextStyle(
                        color: AppTheme.foreground(
                          context,
                          const Color(0x73FFFFFF),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _items.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_items),
                    style: GlassControl.buttonStyle(
                      context,
                      radius: 14,
                      base: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    child: AppText('Save All (${_items.length})'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Barcode confirm sheet ────────────────────────────────────────────────────

class _BarcodeConfirmSheet extends StatefulWidget {
  const _BarcodeConfirmSheet({
    required this.barcode,
    required this.lookup,
    required this.location,
  });

  final String barcode;
  final BarcodeLookupResult lookup;
  final String location;

  @override
  State<_BarcodeConfirmSheet> createState() => _BarcodeConfirmSheetState();
}

class _BarcodeConfirmSheetState extends State<_BarcodeConfirmSheet> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _quantity;
  late final TextEditingController _location;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.lookup.name ?? '');
    _category = TextEditingController(text: widget.lookup.category ?? '');
    _quantity = TextEditingController(text: '1');
    _location = TextEditingController(text: widget.location);
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _quantity.dispose();
    _location.dispose();
    super.dispose();
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: AppTypography.bodyStyleOf(
      context,
      TextStyle(
        color: AppTheme.foreground(context, const Color(0x33FFFFFF)),
        fontSize: 15,
      ),
    ),
    filled: true,
    fillColor: AppTheme.adaptive(context, const Color(0xFF171717)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
        width: 0.5,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
        width: 0.5,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: AppTheme.adaptive(context, const Color(0x40FFFFFF)),
        width: 0.5,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.adaptive(context, const Color(0xFF0A0A0A)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(
            color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.adaptive(context, const Color(0x33FFFFFF)),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 4),
          AppText(
            'Add Scanned Item',
            style: TextStyle(
              color: AppTheme.foreground(context, Colors.white),
              fontSize: 17,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.next,
            style: AppTypography.bodyStyleOf(
              context,
              TextStyle(
                color: AppTheme.foreground(context, Colors.white),
                fontSize: 15,
              ),
            ),
            decoration: _inputDec('Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _category,
            textInputAction: TextInputAction.next,
            style: AppTypography.bodyStyleOf(
              context,
              TextStyle(
                color: AppTheme.foreground(context, Colors.white),
                fontSize: 15,
              ),
            ),
            decoration: _inputDec('Category'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: AppTypography.bodyStyleOf(
              context,
              TextStyle(
                color: AppTheme.foreground(context, Colors.white),
                fontSize: 15,
              ),
            ),
            decoration: _inputDec('Quantity'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _location,
            readOnly: true,
            style: AppTypography.bodyStyleOf(
              context,
              TextStyle(
                color: AppTheme.foreground(context, const Color(0x4DFFFFFF)),
                fontSize: 15,
              ),
            ),
            decoration: _inputDec('Location'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(_quantity.text.trim()) ?? 1;
                Navigator.of(context).pop(
                  AddItemRequest(
                    name: _name.text.trim(),
                    category: _category.text.trim(),
                    quantity: qty,
                    location: widget.location,
                    barcode: widget.barcode,
                  ),
                );
              },
              style: GlassControl.buttonStyle(
                context,
                radius: 14,
                base: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              child: const AppText(
                'Save',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: AppText(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.foreground(context, const Color(0x73FFFFFF)),
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
