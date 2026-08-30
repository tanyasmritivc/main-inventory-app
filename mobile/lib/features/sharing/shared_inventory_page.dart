import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/low_stock_prefs.dart';
import '../../core/ui/app_colors.dart';
import '../inventory/bin_label_sheet.dart';
import '../inventory/item_detail_sheet.dart';
import '../inventory/item_editor_sheet.dart';
import '../inventory/item_sort.dart';
import '../scan/import_sheet_page.dart';
import '../scan/bom_readiness_page.dart';
import '../scan/project_kits_page.dart';
import '../scan/upload_photo_flow.dart';
import '../scan/space_barcode_flow.dart';
import 'share_space_sheet.dart';

class SharedInventoryPage extends StatefulWidget {
  const SharedInventoryPage({
    super.key,
    required this.shareId,
    required this.shareName,
    required this.permission,
    required this.api,
  });

  final String shareId;
  final String shareName;
  final String permission;
  final ApiClient api;

  @override
  State<SharedInventoryPage> createState() => _SharedInventoryPageState();
}

class _SharedInventoryPageState extends State<SharedInventoryPage>
    with TickerProviderStateMixin {
  // ── Tab ─────────────────────────────────────────────────────────────────
  late final TabController _tabController;
  int _currentTab = 0;

  // ── FAB ──────────────────────────────────────────────────────────────────
  bool _fabOpen = false;
  late final AnimationController _fabController;

  // ── Items ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _items = [];
  Map<String, int> _thresholds = {};
  bool _loading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  ItemSortOption _sortOption = ItemSortOption.nameAZ;

  // ── Members ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _members = [];
  bool _membersLoaded = false;
  bool _membersLoading = false;
  String? _membersError;
  String? _currentUserId;
  bool _isOwner = false;
  String? _removingMemberId;

  // ── Checkouts ────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _activeCheckouts = [];
  List<Map<String, dynamic>> _returnedCheckouts = [];
  bool _checkoutsLoaded = false;
  bool _checkoutsLoading = false;

  // ── Activity ─────────────────────────────────────────────────────────────
  List<ActivityEntry> _activity = [];
  bool _activityLoaded = false;
  bool _activityLoading = false;

  // ── Shopping ─────────────────────────────────────────────────────────────
  List<_SpaceShoppingItem> _shoppingItems = [];
  final Set<String> _shoppingChecked = {};

  // ── Checkout dialog ──────────────────────────────────────────────────────
  final TextEditingController _joinCodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
        _onTabActivated(_tabController.index);
      }
    });
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    loadSortPref().then((v) { if (mounted) setState(() => _sortOption = v); });
    _load();
    _loadMembers();
  }

  @override
  void dispose() {
    _fabController.dispose();
    _tabController.dispose();
    _searchCtrl.dispose();
    _joinCodeCtrl.dispose();
    super.dispose();
  }

  void _onTabActivated(int tab) {
    if (tab == 2 && !_checkoutsLoaded) _loadCheckouts();
    if (tab == 3 && !_activityLoaded) _loadActivity();
  }

  // ── Data loaders ─────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.getShareInventory(widget.shareId),
        LowStockPrefs.loadAll(),
      ]);
      final raw = results[0] as List<dynamic>;
      final thresholds = results[1] as Map<String, int>;
      if (!mounted) return;
      setState(() {
        _items = raw.cast<Map<String, dynamic>>();
        _thresholds = thresholds;
        _shoppingItems = _computeShoppingItems(_items, thresholds);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t load this shared space.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_SpaceShoppingItem> _computeShoppingItems(
    List<Map<String, dynamic>> items,
    Map<String, int> thresholds,
  ) {
    final result = <_SpaceShoppingItem>[];
    for (final item in items) {
      final itemId = (item['item_id'] ?? '').toString();
      final qty = (item['quantity'] is num)
          ? (item['quantity'] as num).toInt()
          : int.tryParse((item['quantity'] ?? '0').toString()) ?? 0;
      final threshold = thresholds[itemId];
      final isLow = threshold != null && threshold > 0 && qty <= threshold;
      final isZero = qty <= 0;
      if (isLow || isZero) {
        final needed =
            threshold != null && threshold > 0 ? (threshold * 2) - qty : 5;
        result.add(_SpaceShoppingItem(
          item: item,
          suggestedQty: needed.clamp(1, 999),
          reason: isZero
              ? 'Out of stock'
              : 'Low stock ($qty left, need $threshold+)',
        ));
      }
    }
    result.sort((a, b) {
      final aq = (a.item['quantity'] is num)
          ? (a.item['quantity'] as num).toInt()
          : 0;
      final bq = (b.item['quantity'] is num)
          ? (b.item['quantity'] as num).toInt()
          : 0;
      if (aq <= 0 && bq > 0) return -1;
      if (bq <= 0 && aq > 0) return 1;
      return 0;
    });
    return result;
  }

  Future<void> _loadMembers() async {
    if (!mounted) return;
    setState(() => _membersLoading = true);
    try {
      final members =
          await widget.api.getShareMembers(shareId: widget.shareId);
      if (!mounted) return;
      bool isOwner = false;
      for (final m in members) {
        if ((m['user_id'] ?? '').toString() == _currentUserId &&
            (m['role'] ?? '').toString() == 'owner') {
          isOwner = true;
          break;
        }
      }
      setState(() {
        _members = members;
        _isOwner = isOwner;
        _membersLoaded = true;
        _membersError = null;
      });
    } catch (_) {
      if (mounted) setState(() => _membersError = 'Could not load members.');
    } finally {
      if (mounted) setState(() => _membersLoading = false);
    }
  }

  Future<void> _loadCheckouts() async {
    if (!mounted) return;
    setState(() => _checkoutsLoading = true);
    try {
      final result =
          await widget.api.getSpaceCheckouts(shareId: widget.shareId);
      if (!mounted) return;
      setState(() {
        _activeCheckouts = result.active;
        _returnedCheckouts = result.returned;
        _checkoutsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _checkoutsLoaded = true);
    } finally {
      if (mounted) setState(() => _checkoutsLoading = false);
    }
  }

  Future<void> _loadActivity() async {
    if (!mounted) return;
    setState(() => _activityLoading = true);
    try {
      final activity =
          await widget.api.getShareActivity(location: widget.shareName);
      if (!mounted) return;
      setState(() {
        _activity = activity;
        _activityLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _activityLoaded = true);
    } finally {
      if (mounted) setState(() => _activityLoading = false);
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _importSpreadsheet() async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ImportSheetPage(
          api: widget.api,
          location: widget.shareName,
          shareId: widget.shareId,
        ),
      ),
    );
    if (imported == true) await _load();
  }

  void _openBuildReadiness() => Navigator.of(context).push<void>(MaterialPageRoute(
    builder: (_) => BomReadinessPage(api: widget.api, location: widget.shareName, shareId: widget.shareId),
  ));

  void _openProjectKits() => Navigator.of(context).push<void>(MaterialPageRoute(
    builder: (_) => ProjectKitsPage(api: widget.api, location: widget.shareName, shareId: widget.shareId),
  ));

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final memberId = (member['member_id'] ?? '').toString();
    final name = (member['display_name'] ?? member['email'] ?? 'this member')
        .toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface2(ctx),
        title: const Text('Remove member?',
            style: TextStyle(color: Colors.white)),
        content: Text('Remove $name from this space?',
            style: const TextStyle(color: Color(0x73FFFFFF))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove',
                  style: TextStyle(color: Color(0xFFFF453A)))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _removingMemberId = memberId);
    try {
      await widget.api
          .removeMember(shareId: widget.shareId, memberId: memberId);
      if (!mounted) return;
      setState(
          () => _members.removeWhere((m) => m['member_id'].toString() == memberId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to remove member.')));
      }
    } finally {
      if (mounted) setState(() => _removingMemberId = null);
    }
  }

  Future<void> _joinSpaceDialog() async {
    _joinCodeCtrl.clear();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (_, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.surface2(context),
          title: const Text('Join a Space', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _joinCodeCtrl,
                autofocus: true,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 4),
                decoration: const InputDecoration(
                  hintText: '6-character code',
                  hintStyle: TextStyle(color: Color(0x4DFFFFFF)),
                  counterStyle: TextStyle(color: Color(0x4DFFFFFF)),
                ),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Color(0xFFFF453A), fontSize: 12)),
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
                      const SnackBar(content: Text('Joined! Check Joined Spaces to view.')),
                    );
                  }
                } catch (_) {
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

  Future<void> _returnCheckout(String checkoutId, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface2(ctx),
        title: const Text('Return item?',
            style: TextStyle(color: Colors.white)),
        content: Text('Mark "$itemName" as returned?',
            style: const TextStyle(color: Color(0x73FFFFFF))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Return',
                  style: TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await widget.api.returnItem(checkoutId: checkoutId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$itemName returned')));
        _loadCheckouts();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to return item.')));
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _colorForName(String name) {
    const colors = [
      Color(0xFF0A84FF), Color(0xFF30D158), Color(0xFFFF9F0A),
      Color(0xFFFF375F), Color(0xFFBF5AF2), Color(0xFF5E5CE6),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  Color _avatarColorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF2C2C2E);
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF2C2C2E);
    }
  }

  IconData _activityIcon(String summary) {
    final s = summary.toLowerCase();
    if (s.contains('checked out')) return Icons.logout_outlined;
    if (s.contains('returned')) return Icons.login_outlined;
    if (s.contains('added')) return Icons.add_circle_outline;
    if (s.contains('deleted') || s.contains('removed')) {
      return Icons.remove_circle_outline;
    }
    if (s.contains('updated') || s.contains('edited') ||
        s.contains('changed')) {
      return Icons.edit_outlined;
    }
    return Icons.history_outlined;
  }

  bool _isOverdue(String? dueBackAt) {
    if (dueBackAt == null) return false;
    final dt = DateTime.tryParse(dueBackAt);
    if (dt == null) return false;
    return DateTime.now().isAfter(dt.toLocal());
  }

  // ── Items tab helpers (preserved from original) ──────────────────────────

  Future<void> _addItem() async {
    final created = await showModalBottomSheet<AddItemRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SharedAddItemSheet(initialLocation: widget.shareName),
    );
    if (created == null) return;
    try {
      await widget.api.addItem(item: created);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Item added')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to add item')));
      }
    }
  }



  Future<void> _showItemDetail(Map<String, dynamic> item) async {
    // Convert the shared-space Map to a typed InventoryItem so we can open
    // the same comprehensive detail sheet used in personal spaces.
    // Note: GET /sharing/{shareId}/inventory may omit `tags` — if so the
    // Tags section simply won't render (backend gap, not faked here).
    final invItem = InventoryItem.fromJson(item);
    final threshold = (await LowStockPrefs.loadAll())[invItem.itemId];
    if (!mounted) return;
    await showItemDetailSheet(
      context,
      item: invItem,
      api: widget.api,
      permission: widget.permission,
      initialThreshold: threshold,
      spaceName: widget.shareName,
    );
    if (!mounted) return;
    // Refresh in case notes or qty changed during the detail view.
    _load();
  }

  Future<void> _editItemRow(Map<String, dynamic> item) async {
    final invItem = InventoryItem.fromJson(item);
    final currentThreshold = _thresholds[invItem.itemId];
    final result = await showModalBottomSheet<ItemEditorResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          ItemEditorSheet(item: invItem, initialThreshold: currentThreshold),
    );
    if (result == null) return;
    try {
      await widget.api.updateItem(request: result.update);
      await LowStockPrefs.setThreshold(itemId: invItem.itemId, threshold: result.threshold);
      if (!mounted) return;
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update item.')),
      );
    }
  }

  Future<void> _deleteItemRow(InventoryItem item) async {
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
      await LowStockPrefs.setThreshold(itemId: item.itemId, threshold: null);
      if (!mounted) return;
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete item.')),
      );
    }
  }

  Future<void> _uploadPhoto() async {
    await runUploadPhotoFlow(
      context: context,
      api: widget.api,
      preselectedSpace: widget.shareName,
      onItemsSaved: () async {
        await _load();
      },
    );
  }

  Future<void> _scanBarcode() async {
    await runSpaceBarcodeFlow(
      context: context,
      api: widget.api,
      preselectedSpace: widget.shareName,
      onItemsSaved: _load,
    );
  }

  List<String> _sortedCategoryPills() {
    final cats = <String>{};
    for (final it in _items) {
      final c = (it['category'] ?? '').toString().trim();
      cats.add(c.isEmpty ? 'Uncategorized' : c);
    }
    return ['All', ...cats.toList()..sort()];
  }

  bool _matchesSearch(Map<String, dynamic> item) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return (item['name'] ?? '').toString().toLowerCase().contains(q) ||
        (item['category'] ?? '').toString().toLowerCase().contains(q);
  }

  Widget _buildPinnedHeader() {
    final pills = _sortedCategoryPills();
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0x14FFFFFF), width: 0.5),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search in this space...',
                          hintStyle: const TextStyle(
                              color: Color(0x4DFFFFFF), fontSize: 14),
                          prefixIcon: const Icon(Icons.search,
                              color: Color(0x4DFFFFFF), size: 20),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 13),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                    FocusScope.of(context).unfocus();
                                  },
                                  child: const Icon(Icons.close,
                                      color: Color(0x4DFFFFFF), size: 16),
                                )
                              : null,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => showItemSortSheet(context, _sortOption, (opt) async {
                      await saveSortPref(opt);
                      if (mounted) setState(() => _sortOption = opt);
                    }),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0x14FFFFFF), width: 0.5),
                      ),
                      child: Icon(
                        Icons.sort,
                        color: _sortOption != ItemSortOption.nameAZ
                            ? Colors.white
                            : const Color(0x4DFFFFFF),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: 60,
              child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              physics: const BouncingScrollPhysics(),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: pills.length,
              itemBuilder: (_, i) {
                final label = pills[i];
                final isActive = _selectedCategory == label;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(99),
                      border: isActive
                          ? null
                          : Border.all(
                              color: const Color(0x14FFFFFF), width: 0.5),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isActive
                            ? Colors.black
                            : const Color(0x73FFFFFF),
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final invItem = InventoryItem.fromJson(item);
    final threshold = _thresholds[invItem.itemId];
    final isLow = threshold != null && threshold > 0 && invItem.quantity <= threshold;
    final canEdit = widget.permission == 'edit';

    final rowChild = InkWell(
      onTap: canEdit
          ? () => _editItemRow(item)
          : () => _showItemDetail(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invItem.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    invItem.category,
                    style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 13),
                  ),
                ],
              ),
            ),
            if (isLow) ...[
              const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
              const SizedBox(width: 8),
            ],
            Text(
              'Qty ${invItem.quantity}',
              style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 13),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _showItemDetail(item),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0x0AFFFFFF),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                ),
                child: const Icon(Icons.info_outline, color: Color(0x4DFFFFFF), size: 14),
              ),
            ),
          ],
        ),
      ),
    );

    if (!canEdit) return rowChild;

    return Dismissible(
      key: ValueKey(invItem.itemId),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        color: AppColors.swipe,
        child: const Icon(Icons.edit_outlined),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: const Color(0x1AFF3B30),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _editItemRow(item);
          return false;
        }
        if (direction == DismissDirection.endToStart) {
          await _deleteItemRow(invItem);
          return false;
        }
        return false;
      },
      child: rowChild,
    );
  }

  Widget _buildGroupedItemsSliver() {
    if (_items.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text('No items in this shared space.',
              style: TextStyle(color: Color(0x4DFFFFFF))),
        ),
      );
    }
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      final cat = (item['category'] ?? '').toString().trim();
      groups.putIfAbsent(cat.isEmpty ? 'Uncategorized' : cat, () => []).add(item);
    }
    final sortedCats = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final displayedCats = _selectedCategory == 'All'
        ? sortedCats
        : sortedCats.where((c) => c == _selectedCategory).toList();
    final filteredGroups = <String, List<Map<String, dynamic>>>{};
    for (final cat in displayedCats) {
      final matches = (groups[cat] ?? []).where(_matchesSearch).toList();
      sortRawItems(matches, _sortOption);
      if (matches.isNotEmpty) filteredGroups[cat] = matches;
    }
    final filteredCats =
        displayedCats.where(filteredGroups.containsKey).toList();
    if (filteredCats.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text('No items match your search',
              style: TextStyle(color: Color(0x4DFFFFFF))),
        ),
      );
    }
    final children = <Widget>[];
    for (final cat in filteredCats) {
      children.add(Padding(
        padding: const EdgeInsets.only(left: 32, top: 20, bottom: 6),
        child: Text(cat.toUpperCase(),
            style: const TextStyle(
                color: Color(0x4DFFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5)),
      ));
      children.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < filteredGroups[cat]!.length; i++) ...[
              _buildItemRow(filteredGroups[cat]![i]),
              if (i < filteredGroups[cat]!.length - 1)
                const Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 16,
                    endIndent: 16,
                    color: Color(0x14FFFFFF)),
            ],
          ],
        ),
      ));
    }
    children.add(const SizedBox(height: 80));
    return SliverList(delegate: SliverChildListDelegate(children));
  }

  // ── FAB ──────────────────────────────────────────────────────────────────

  void _toggleFab() {
    setState(() => _fabOpen = !_fabOpen);
    if (_fabOpen) {
      _fabController.forward();
    } else {
      _fabController.reverse();
    }
  }

  Widget _buildSpeedDial() {
    final items = [
      if (widget.permission == 'edit') ...[
        const _SharedFabItem(icon: Icons.edit_outlined, label: 'Add Item'),
        const _SharedFabItem(icon: Icons.camera_alt_outlined, label: 'Upload Photo'),
        const _SharedFabItem(icon: Icons.qr_code_scanner, label: 'Scan Barcode'),
      ],
      const _SharedFabItem(icon: Icons.construction_outlined, label: 'Import & Build'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IgnorePointer(
          ignoring: !_fabOpen,
          child: AnimatedBuilder(
            animation: _fabController,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final delay = i / items.length;
                  final end = (i + 1) / items.length;
                  final anim = CurvedAnimation(
                    parent: _fabController,
                    curve: Interval(delay, end.clamp(0.0, 1.0), curve: Curves.easeOut),
                  );
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
                          .animate(anim),
                      child: _buildFabItemTile(item),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _toggleFab,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.22),
                  Colors.white.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.1),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _fabController,
                    builder: (context, _) => Transform.rotate(
                      angle: _fabController.value * 0.785398,
                      child: const Icon(Icons.add, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFabItemTile(_SharedFabItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 4),
      child: GestureDetector(
        onTap: () => _onFabItemTap(item.label),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, color: Colors.white, size: 16),
                  const SizedBox(width: 10),
                  Text(
                    item.label,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onFabItemTap(String label) {
    setState(() => _fabOpen = false);
    _fabController.reverse();
    switch (label) {
      case 'Add Item':
        _addItem();
      case 'Upload Photo':
        _uploadPhoto();
      case 'Import & Build':
        _showImportBuildMenu();
      case 'Import Spreadsheet':
        _importSpreadsheet();
      case 'Build Readiness':
        _openBuildReadiness();
      case 'Project Kits':
        _openProjectKits();
      case 'Scan Barcode':
        _scanBarcode();
      case 'Share Space':
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => DraggableScrollableSheet(
            initialChildSize: 0.65,
            maxChildSize: 0.92,
            minChildSize: 0.4,
            builder: (_, _) => ShareSpaceSheet(
              spaceName: widget.shareName,
              api: widget.api,
            ),
          ),
        );
      case 'Join Space':
        _joinSpaceDialog();
      case 'Print Bin Label':
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BinLabelSheet(
            spaceName: widget.shareName,
            items: _items.map((m) => InventoryItem.fromJson(m)).toList(),
          ),
        );
      case 'Members':
        _tabController.animateTo(1);
    }
  }

  void _showImportBuildMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 12),
            const ListTile(title: Text('Import & Build', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)), subtitle: Text('Bring in inventory or check a project', style: TextStyle(color: Colors.white54))),
            if (widget.permission == 'edit')
              ListTile(leading: const Icon(Icons.table_chart_outlined, color: Color(0xFF4DA3FF)), title: const Text('Import Spreadsheet'), onTap: () { Navigator.pop(sheetContext); _importSpreadsheet(); }),
            ListTile(leading: const Icon(Icons.fact_check_outlined, color: Color(0xFF4DA3FF)), title: const Text('Build Readiness'), onTap: () { Navigator.pop(sheetContext); _openBuildReadiness(); }),
            ListTile(leading: const Icon(Icons.inventory_2_outlined, color: Color(0xFF4DA3FF)), title: const Text('Project Kits'), onTap: () { Navigator.pop(sheetContext); _openProjectKits(); }),
          ]),
        ),
      ),
    );
  }

  // ── Tab content builders ─────────────────────────────────────────────────

  Widget _buildItemsTab() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2));
    }
    return CustomScrollView(
      slivers: [
        if (widget.permission == 'view')
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0x0AFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x14FFFFFF)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.visibility_outlined,
                        color: Color(0x73FFFFFF), size: 16),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "You're viewing a shared inventory. Contact the owner to make changes.",
                        style: TextStyle(
                            color: Color(0x73FFFFFF), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_items.isNotEmpty)
          SliverPersistentHeader(
            pinned: true,
            delegate: _SharedSearchPinDelegate(
                height: 124, child: _buildPinnedHeader()),
          ),
        _buildGroupedItemsSliver(),
      ],
    );
  }

  Widget _buildMembersTab() {
    if (_membersLoading && !_membersLoaded) {
      return const Center(
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2));
    }
    if (_membersError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_membersError!,
                style: const TextStyle(color: Color(0x73FFFFFF))),
            const SizedBox(height: 12),
            TextButton(
                onPressed: _loadMembers, child: const Text('Retry')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMembers,
      color: Colors.white,
      backgroundColor: const Color(0xFF1C1C1E),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _members.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${_members.length} MEMBER${_members.length != 1 ? 'S' : ''}',
                style: const TextStyle(
                    color: Color(0x4DFFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4),
              ),
            );
          }
          return _buildMemberRow(_members[i - 1]);
        },
      ),
    );
  }

  Widget _buildMemberRow(Map<String, dynamic> member) {
    final memberId = (member['member_id'] ?? '').toString();
    final userId = (member['user_id'] ?? '').toString();
    final name =
        (member['display_name'] ?? member['email'] ?? 'Unknown').toString();
    final role = (member['role'] ?? 'member').toString();
    final joinedAt = member['joined_at']?.toString();
    final avatarHex = member['avatar_color']?.toString();
    final isMe = userId == _currentUserId;
    final isOwnerRow = role == 'owner';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatarColor = avatarHex != null && avatarHex.isNotEmpty
        ? _avatarColorFromHex(avatarHex)
        : _colorForName(name);
    final isRemoving = _removingMemberId == memberId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: avatarColor,
                borderRadius: BorderRadius.circular(20)),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '$name (you)' : name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOwnerRow
                            ? const Color(0x1AFBBF24)
                            : const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOwnerRow ? 'Owner' : 'Member',
                        style: TextStyle(
                          color: isOwnerRow
                              ? const Color(0xFFFBBF24)
                              : const Color(0x73FFFFFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (joinedAt != null) ...[
                      const SizedBox(width: 8),
                      Text('Joined ${_timeAgo(joinedAt)}',
                          style: const TextStyle(
                              color: Color(0x4DFFFFFF), fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_isOwner && !isOwnerRow && !isMe)
            isRemoving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white38, strokeWidth: 2),
                  )
                : GestureDetector(
                    onTap: () => _removeMember(member),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x0AFF453A),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: const Color(0x33FF453A)),
                      ),
                      child: const Text('Remove',
                          style: TextStyle(
                              color: Color(0xFFFF453A),
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _buildCheckoutsTab() {
    if (_checkoutsLoading && !_checkoutsLoaded) {
      return const Center(
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2));
    }

    final hasAny =
        _activeCheckouts.isNotEmpty || _returnedCheckouts.isNotEmpty;

    if (!hasAny) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline,
                color: Color(0xFF30D158), size: 48),
            const SizedBox(height: 12),
            const Text('Nothing checked out',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Items checked out from this space appear here.',
              style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (widget.permission == 'edit') ...[
              const SizedBox(height: 20),
              const Text(
                'Tap an item in the Items tab to check it out.',
                style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCheckouts,
      color: Colors.white,
      backgroundColor: const Color(0xFF1C1C1E),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_activeCheckouts.isNotEmpty) ...[
            _checkoutSectionHeader(
              '${_activeCheckouts.length} ITEM${_activeCheckouts.length != 1 ? 'S' : ''} CHECKED OUT',
            ),
            ..._activeCheckouts
                .map((c) => _buildCheckoutCard(c, isReturned: false)),
            const SizedBox(height: 8),
          ],
          if (_returnedCheckouts.isNotEmpty) ...[
            if (_activeCheckouts.isNotEmpty) const SizedBox(height: 8),
            _checkoutSectionHeader('RECENTLY RETURNED'),
            ..._returnedCheckouts
                .map((c) => _buildCheckoutCard(c, isReturned: true)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _checkoutSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
            color: Color(0x4DFFFFFF),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4),
      ),
    );
  }

  Widget _buildCheckoutCard(
    Map<String, dynamic> checkout, {
    bool isReturned = false,
  }) {
    final itemData = checkout['items'] as Map<String, dynamic>? ?? {};
    final itemName = itemData['name'] as String? ??
        (checkout['item_name'] as String? ?? 'Unknown item');
    final checkedOutBy = (checkout['checked_out_by'] as String?) ?? '';
    final checkedOutAt = checkout['checked_out_at'] as String?;
    final dueBackAt = checkout['due_back_at'] as String?;
    final returnedAt = checkout['returned_at'] as String?;
    final checkoutId = (checkout['checkout_id'] as String?) ?? '';
    final overdue = !isReturned && _isOverdue(dueBackAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isReturned
            ? const Color(0x06FFFFFF)
            : overdue
                ? const Color(0x0AEF4444)
                : const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: overdue
                ? const Color(0x33EF4444)
                : const Color(0x14FFFFFF),
            width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: isReturned
                    ? _colorForName(checkedOutBy).withValues(alpha: 0.4)
                    : _colorForName(checkedOutBy),
                borderRadius: BorderRadius.circular(18)),
            child: Center(
              child: Text(
                checkedOutBy.isNotEmpty
                    ? checkedOutBy[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    color: isReturned
                        ? const Color(0x99FFFFFF)
                        : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: TextStyle(
                      color: isReturned
                          ? const Color(0x99FFFFFF)
                          : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'By $checkedOutBy · ${_timeAgo(checkedOutAt)}',
                  style: const TextStyle(
                      color: Color(0x4DFFFFFF), fontSize: 12),
                ),
                if (isReturned && returnedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Returned ${_timeAgo(returnedAt)}',
                    style: const TextStyle(
                      color: Color(0xFF30D158),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else if (!isReturned && dueBackAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    overdue
                        ? '⚠ Overdue — due ${_timeAgo(dueBackAt)}'
                        : 'Due ${_timeAgo(dueBackAt)}',
                    style: TextStyle(
                      color: overdue
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFFBBF24),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isReturned &&
              widget.permission == 'edit' &&
              checkoutId.isNotEmpty)
            GestureDetector(
              onTap: () => _returnCheckout(checkoutId, itemName),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x0AFFFFFF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x14FFFFFF)),
                ),
                child: const Text('Return',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    if (_activityLoading && !_activityLoaded) {
      return const Center(
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2));
    }
    if (_activity.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_outlined,
                color: Color(0x4DFFFFFF), size: 48),
            SizedBox(height: 12),
            Text('No recent activity',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text('Changes to items in this space appear here.',
                style: TextStyle(
                    color: Color(0x4DFFFFFF), fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadActivity,
      color: Colors.white,
      backgroundColor: const Color(0xFF1C1C1E),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _activity.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('RECENT ACTIVITY',
                  style: TextStyle(
                      color: Color(0x4DFFFFFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4)),
            );
          }
          return _buildActivityRow(_activity[i - 1]);
        },
      ),
    );
  }

  Widget _buildActivityRow(ActivityEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_activityIcon(entry.summary),
                color: const Color(0x73FFFFFF), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.summary,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.4)),
                const SizedBox(height: 4),
                Text(
                  _timeAgo(entry.createdAt.toIso8601String()),
                  style: const TextStyle(
                      color: Color(0x4DFFFFFF), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingTab() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2));
    }
    if (_shoppingItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                color: Color(0xFF30D158), size: 48),
            SizedBox(height: 12),
            Text('All stocked up!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text(
              'No items are low on stock in this space.\nSet thresholds on items to track them.',
              style: TextStyle(
                  color: Color(0x4DFFFFFF), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    final unchecked = _shoppingItems
        .where((i) => !_shoppingChecked
            .contains((i.item['item_id'] ?? '').toString()))
        .toList();
    final checked = _shoppingItems
        .where((i) => _shoppingChecked
            .contains((i.item['item_id'] ?? '').toString()))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: unchecked.isEmpty
                ? const Color(0x0A30D158)
                : const Color(0x0AEF4444),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: unchecked.isEmpty
                    ? const Color(0x3330D158)
                    : const Color(0x33EF4444)),
          ),
          child: Row(
            children: [
              Icon(
                unchecked.isEmpty
                    ? Icons.check_circle_outline
                    : Icons.shopping_cart_outlined,
                color: unchecked.isEmpty
                    ? const Color(0xFF30D158)
                    : const Color(0xFFEF4444),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  unchecked.isEmpty
                      ? 'All items ordered!'
                      : '${unchecked.length} items need restocking',
                  style: TextStyle(
                    color: unchecked.isEmpty
                        ? const Color(0xFF30D158)
                        : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (unchecked.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    final text = _buildShoppingShareText(unchecked);
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Shopping list copied to clipboard')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(99)),
                    child: const Text('Share',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (unchecked.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('NEEDS RESTOCKING',
                style: TextStyle(
                    color: Color(0x4DFFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4)),
          ),
          ...unchecked.map((si) => _SpaceShoppingItemCard(
                shoppingItem: si,
                isChecked: false,
                onTap: () => setState(() => _shoppingChecked
                    .add((si.item['item_id'] ?? '').toString())),
                onQtyChanged: (qty) =>
                    setState(() => si.suggestedQty = qty),
              )),
        ],
        if (checked.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('ORDERED',
                style: TextStyle(
                    color: Color(0x4DFFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4)),
          ),
          ...checked.map((si) => _SpaceShoppingItemCard(
                shoppingItem: si,
                isChecked: true,
                onTap: () => setState(() => _shoppingChecked
                    .remove((si.item['item_id'] ?? '').toString())),
                onQtyChanged: (qty) =>
                    setState(() => si.suggestedQty = qty),
              )),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  String _buildShoppingShareText(List<_SpaceShoppingItem> items) {
    final buf = StringBuffer();
    buf.writeln('🛒 ${widget.shareName} — Shopping List');
    for (final si in items) {
      final name = (si.item['name'] ?? '').toString();
      final part = si.item['part_number']?.toString();
      final brand = si.item['brand']?.toString();
      buf.writeln(
          '  • $name${part != null ? ' [#$part]' : ''}${brand != null ? ' — $brand' : ''}');
      buf.writeln('    Qty: ${si.suggestedQty}  |  ${si.reason}');
    }
    return buf.toString();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: _currentTab == 0 ? _buildSpeedDial() : null,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.shareName,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w500),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              children: [
                _badge(
                  _isOwner ? 'Owner' : 'Member',
                  textColor: const Color(0x73FFFFFF),
                  bgColor: const Color(0x14FFFFFF),
                ),
                const SizedBox(width: 6),
                _badge(
                  widget.permission == 'edit' ? 'Can edit' : 'View only',
                  textColor: widget.permission == 'edit'
                      ? const Color(0xFF30D158)
                      : const Color(0x73FFFFFF),
                  bgColor: widget.permission == 'edit'
                      ? const Color(0x1A30D158)
                      : const Color(0x14FFFFFF),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Color(0xB3FFFFFF)),
            color: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: _onFabItemTap,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'Share Space', child: ListTile(leading: Icon(Icons.share_outlined), title: Text('Share Space'))),
              PopupMenuItem(value: 'Join Space', child: ListTile(leading: Icon(Icons.person_add_outlined), title: Text('Join Space'))),
              PopupMenuItem(value: 'Print Bin Label', child: ListTile(leading: Icon(Icons.qr_code_2), title: Text('Print Bin Label'))),
              PopupMenuItem(value: 'Members', child: ListTile(leading: Icon(Icons.people_outline), title: Text('Members'))),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          indicatorWeight: 1.5,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0x4DFFFFFF),
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          unselectedLabelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          dividerColor: const Color(0x14FFFFFF),
          tabs: [
            Tab(
                text: _items.isNotEmpty
                    ? 'Items (${_items.length})'
                    : 'Items'),
            Tab(
                text: _members.isNotEmpty
                    ? 'Members (${_members.length})'
                    : 'Members'),
            const Tab(text: 'Checked Out'),
            const Tab(text: 'Activity'),
            Tab(
                text: _shoppingItems.isNotEmpty
                    ? 'Shopping (${_shoppingItems.length})'
                    : 'Shopping'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildItemsTab(),
              _buildMembersTab(),
              _buildCheckoutsTab(),
              _buildActivityTab(),
              _buildShoppingTab(),
            ],
          ),
          AnimatedOpacity(
            opacity: _fabOpen ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_fabOpen,
              child: GestureDetector(
                onTap: () {
                  setState(() => _fabOpen = false);
                  _fabController.reverse();
                },
                child: Container(color: Colors.black.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text,
      {required Color textColor, required Color bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: TextStyle(
              color: textColor, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

// ── Shopping item model (space-scoped, Map-backed) ───────────────────────────

class _SpaceShoppingItem {
  final Map<String, dynamic> item;
  int suggestedQty;
  final String reason;
  _SpaceShoppingItem(
      {required this.item, required this.suggestedQty, required this.reason});
}

// ── Shopping item card ────────────────────────────────────────────────────────

class _SpaceShoppingItemCard extends StatelessWidget {
  const _SpaceShoppingItemCard({
    required this.shoppingItem,
    required this.isChecked,
    required this.onTap,
    required this.onQtyChanged,
  });

  final _SpaceShoppingItem shoppingItem;
  final bool isChecked;
  final VoidCallback onTap;
  final ValueChanged<int> onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final item = shoppingItem.item;
    final qty = (item['quantity'] is num)
        ? (item['quantity'] as num).toInt()
        : int.tryParse((item['quantity'] ?? '0').toString()) ?? 0;
    final name = (item['name'] ?? '').toString();
    final location = (item['location'] ?? '').toString();
    final partNumber = item['part_number']?.toString();
    final isOut = qty <= 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isChecked
              ? const Color(0x06FFFFFF)
              : const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isChecked
                ? const Color(0x0AFFFFFF)
                : isOut
                    ? const Color(0x33EF4444)
                    : const Color(0x33FBBF24),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isChecked
                    ? const Color(0xFF30D158)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isChecked
                      ? const Color(0xFF30D158)
                      : const Color(0x40FFFFFF),
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color:
                          isChecked ? const Color(0x60FFFFFF) : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration:
                          isChecked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOut
                              ? const Color(0x1AEF4444)
                              : const Color(0x1AFBBF24),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isOut ? 'OUT OF STOCK' : '$qty left',
                          style: TextStyle(
                            color: isOut
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFFBBF24),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(location,
                            style: const TextStyle(
                                color: Color(0x4DFFFFFF), fontSize: 11)),
                      ],
                      if (partNumber != null) ...[
                        const SizedBox(width: 6),
                        Text('#$partNumber',
                            style: const TextStyle(
                                color: Color(0x4DFFFFFF), fontSize: 11)),
                      ],
                    ],
                  ),
                  if (!isChecked) ...[
                    const SizedBox(height: 4),
                    Text(shoppingItem.reason,
                        style: const TextStyle(
                            color: Color(0x4DFFFFFF), fontSize: 11)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!isChecked)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (shoppingItem.suggestedQty > 1) {
                        onQtyChanged(shoppingItem.suggestedQty - 1);
                      }
                    },
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.remove,
                          color: Colors.white70, size: 14),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${shoppingItem.suggestedQty}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onQtyChanged(shoppingItem.suggestedQty + 1),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.add,
                          color: Colors.white70, size: 14),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Barcode scanner page ─────────────────────────────────────────────────────

class _SharedBarcodeScannerPage extends StatefulWidget {
  const _SharedBarcodeScannerPage();

  @override
  State<_SharedBarcodeScannerPage> createState() =>
      _SharedBarcodeScannerPageState();
}

class _SharedBarcodeScannerPageState
    extends State<_SharedBarcodeScannerPage> {
  MobileScannerController? _controller;
  bool _returned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
        formats: const <BarcodeFormat>[BarcodeFormat.all]);
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.black,
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

class _SharedSearchPinDelegate extends SliverPersistentHeaderDelegate {
  const _SharedSearchPinDelegate({required this.child, this.height = 100});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  bool shouldRebuild(_SharedSearchPinDelegate old) =>
      old.child != child || old.height != height;
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;
}

// ── Add item sheet ────────────────────────────────────────────────────────────

class _SharedAddItemSheet extends StatefulWidget {
  const _SharedAddItemSheet({
    required this.initialLocation,
  });
  final String initialLocation;

  @override
  State<_SharedAddItemSheet> createState() => _SharedAddItemSheetState();
}

class _SharedAddItemSheetState extends State<_SharedAddItemSheet> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _quantity;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _category = TextEditingController();
    _quantity = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _quantity.dispose();
    super.dispose();
  }

  InputDecoration _field(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
        filled: true,
        fillColor: const Color(0x0AFFFFFF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide:
              BorderSide(color: Color(0x14FFFFFF), width: 0.5),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide:
              BorderSide(color: Color(0x14FFFFFF), width: 0.5),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide:
              BorderSide(color: Color(0x40FFFFFF), width: 0.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border:
            Border(top: BorderSide(color: Color(0x14FFFFFF), width: 0.5)),
      ),
      padding:
          EdgeInsets.only(left: 16, right: 16, bottom: bottom + 24),
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
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Add item',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextField(
              controller: _name,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: _field('Name')),
          const SizedBox(height: 10),
          TextField(
              controller: _category,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: _field('Category')),
          const SizedBox(height: 10),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _field('Quantity'),
          ),
          const SizedBox(height: 10),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0x14FFFFFF), width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Text(widget.initialLocation,
                style: const TextStyle(
                    color: Color(0x4DFFFFFF), fontSize: 15)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                final qty =
                    int.tryParse(_quantity.text.trim()) ?? 1;
                Navigator.of(context).pop(AddItemRequest(
                  name: _name.text.trim(),
                  category: _category.text.trim(),
                  quantity: qty,
                  location: widget.initialLocation,
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Save',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(
                      color: Color(0x73FFFFFF), fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item detail sheet ─────────────────────────────────────────────────────────

// Retained as a legacy fallback while shared items use showItemDetailSheet.
// ignore: unused_element
class _SharedItemDetailContent extends StatelessWidget {
  const _SharedItemDetailContent({
    required this.item,
    required this.permission,
  });

  final Map<String, dynamic> item;
  final String permission;

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0x73FFFFFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w400)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400),
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      height: 0.5,
      color: const Color(0x14FFFFFF),
      margin: const EdgeInsets.symmetric(horizontal: 18));

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name = (item['name'] ?? '').toString();
    final category = (item['category'] ?? '').toString();
    final location = (item['location'] ?? '').toString();
    final qty = (item['quantity'] is num)
        ? (item['quantity'] as num).toInt()
        : int.tryParse((item['quantity'] ?? '0').toString()) ?? 0;
    final brand = item['brand']?.toString() ?? '';
    final partNumber = item['part_number']?.toString() ?? '';
    final subcategory = item['subcategory']?.toString() ?? '';
    final barcode = item['barcode']?.toString() ?? '';
    final purchaseSource = item['purchase_source']?.toString() ?? '';
    final notes = item['notes']?.toString() ?? '';
    final confidence = (item['confidence'] is num)
        ? (item['confidence'] as num).toDouble()
        : double.tryParse((item['confidence'] ?? '').toString());
    final createdAt =
        DateTime.tryParse((item['created_at'] ?? '').toString()) ??
            DateTime.now();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        border:
            Border(top: BorderSide(color: Color(0x14FFFFFF), width: 0.5)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(99)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5)),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(category,
                  style: const TextStyle(
                      color: Color(0x4DFFFFFF), fontSize: 14)),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0x0AFFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                ),
                child: Column(
                  children: [
                    _infoRow('Category', category),
                    _divider(),
                    _infoRow('Location', location),
                    _divider(),
                    _infoRow('Quantity', '$qty'),
                    if (brand.isNotEmpty) ...[
                      _divider(),
                      _infoRow('Brand', brand)
                    ],
                    if (barcode.isNotEmpty) ...[
                      _divider(),
                      _infoRow('Barcode', barcode)
                    ],
                    if (partNumber.isNotEmpty) ...[
                      _divider(),
                      _infoRow('Part Number', partNumber)
                    ],
                    if (subcategory.isNotEmpty) ...[
                      _divider(),
                      _infoRow('Subcategory', subcategory)
                    ],
                    if (purchaseSource.isNotEmpty) ...[
                      _divider(),
                      _infoRow('Purchase Source', purchaseSource)
                    ],
                    _divider(),
                    _infoRow('Date added', _formatDate(createdAt)),
                    if (confidence != null) ...[
                      _divider(),
                      _infoRow('AI confidence',
                          '${(confidence * 100).toStringAsFixed(0)}%'),
                    ],
                  ],
                ),
              ),
            ),
            if (notes.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('NOTES',
                        style: TextStyle(
                            color: Color(0x4DFFFFFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 60),
                      decoration: BoxDecoration(
                        color: const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0x14FFFFFF), width: 0.5),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Text(notes,
                          style: const TextStyle(
                              color: Color(0x73FFFFFF),
                              fontSize: 14,
                              height: 1.5)),
                    ),
                  ],
                ),
              ),
            ],
            if (permission == 'edit') ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop('edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0x14FFFFFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Edit',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop('checkout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0x0A0A84FF),
                      foregroundColor: const Color(0xFF0A84FF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Check Out',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop('delete'),
                  child: const Text('Delete item',
                      style: TextStyle(
                          color: Color(0xFFFF453A), fontSize: 14)),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Edit item sheet ───────────────────────────────────────────────────────────

class _SharedEditItemSheet extends StatefulWidget {
  const _SharedEditItemSheet({
    required this.item,
    required this.api,
    required this.onSaved,
  });

  final Map<String, dynamic> item;
  final ApiClient api;
  final VoidCallback onSaved;

  @override
  State<_SharedEditItemSheet> createState() => _SharedEditItemSheetState();
}

class _SharedEditItemSheetState extends State<_SharedEditItemSheet> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _location;
  late final TextEditingController _quantity;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _name = TextEditingController(text: (it['name'] ?? '').toString());
    _category =
        TextEditingController(text: (it['category'] ?? '').toString());
    _location =
        TextEditingController(text: (it['location'] ?? '').toString());
    _quantity =
        TextEditingController(text: (it['quantity'] ?? 1).toString());
    _notes = TextEditingController(text: (it['notes'] ?? '').toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _location.dispose();
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  InputDecoration _field(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
        filled: true,
        fillColor: const Color(0x0AFFFFFF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide:
                BorderSide(color: Color(0x14FFFFFF), width: 0.5)),
        enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide:
                BorderSide(color: Color(0x14FFFFFF), width: 0.5)),
        focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide:
                BorderSide(color: Color(0x40FFFFFF), width: 0.5)),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        border:
            Border(top: BorderSide(color: Color(0x14FFFFFF), width: 0.5)),
      ),
      padding:
          EdgeInsets.only(left: 16, right: 16, bottom: bottom + 24),
      child: SingleChildScrollView(
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
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 4),
            const Text('Edit item',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextField(
                controller: _name,
                style:
                    const TextStyle(color: Colors.white, fontSize: 15),
                decoration: _field('Name *')),
            const SizedBox(height: 10),
            TextField(
                controller: _category,
                style:
                    const TextStyle(color: Colors.white, fontSize: 15),
                decoration: _field('Category *')),
            const SizedBox(height: 10),
            TextField(
                controller: _location,
                style:
                    const TextStyle(color: Colors.white, fontSize: 15),
                decoration: _field('Location')),
            const SizedBox(height: 10),
            TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: _field('Quantity'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: _field('Notes'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        if (_name.text.trim().isEmpty ||
                            _category.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Name and category are required')),
                          );
                          return;
                        }
                        setState(() => _saving = true);
                        try {
                          await widget.api.updateItem(
                            request: UpdateItemRequest(
                              itemId: (widget.item['item_id'] ?? '')
                                  .toString(),
                              name: _name.text.trim(),
                              category: _category.text.trim(),
                              location: _location.text.trim().isEmpty
                                  ? null
                                  : _location.text.trim(),
                              quantity:
                                  int.tryParse(_quantity.text.trim()),
                              notes: _notes.text.trim().isEmpty
                                  ? null
                                  : _notes.text.trim(),
                            ),
                          );
                          if (!mounted) return;
                          Navigator.of(this.context).pop();
                          widget.onSaved();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text(describeError(e).$1)));
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Text('Save',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
              ),
            ),
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: Color(0x73FFFFFF), fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedFabItem {
  const _SharedFabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
