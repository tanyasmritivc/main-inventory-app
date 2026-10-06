import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/low_stock_prefs.dart';
import '../../core/restock_plan.dart';
import '../shopping/shopping_list_page.dart';
import '../../core/low_stock_notifications.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/member_avatar.dart';
import '../inventory/bin_label_sheet.dart';
import '../inventory/item_detail_sheet.dart';
import '../inventory/item_editor_sheet.dart';
import '../inventory/item_sort.dart';
import '../scan/import_sheet_page.dart';
import '../scan/bom_readiness_page.dart';
import '../scan/project_kits_page.dart';
import '../scan/upload_photo_flow.dart';
import '../scan/space_barcode_flow.dart';
import '../showcase/tutorial_controller.dart';
import 'share_space_sheet.dart';
import 'package:mobile/core/ui/app_text.dart';

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
    loadSortPref().then((v) {
      if (mounted) setState(() => _sortOption = v);
    });
    _load();
    _loadMembers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        TutorialController.instance.maybeShowSpaceStep(context: context),
      );
    });
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
    final account = RestockPrefs.accountKey;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.getShareInventory(widget.shareId),
        LowStockPrefs.loadAll(),
      ]);
      final raw = results[0] as List<dynamic>;
      final thresholds = results[1] as Map<String, int>;
      if (!mounted || account != RestockPrefs.accountKey) return;
      setState(() {
        _items = raw.cast<Map<String, dynamic>>();
        _thresholds = thresholds;
      });
      unawaited(
        LowStockNotifications.evaluate(
          _items.map((item) {
            final itemId = (item['item_id'] ?? '').toString();
            final quantity = (item['quantity'] is num)
                ? (item['quantity'] as num).toInt()
                : int.tryParse((item['quantity'] ?? '0').toString()) ?? 0;
            return LowStockCandidate(
              itemId: itemId,
              name: (item['name'] ?? 'Item').toString(),
              quantity: quantity,
              threshold: thresholds[itemId] ?? -1,
              spaceName: widget.shareName,
            );
          }).toList(),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('Couldn’t load this shared space.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMembers() async {
    if (!mounted) return;
    setState(() => _membersLoading = true);
    try {
      final members = await widget.api.getShareMembers(shareId: widget.shareId);
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
      final result = await widget.api.getSpaceCheckouts(
        shareId: widget.shareId,
      );
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
      final activity = await widget.api.getShareActivity(
        location: widget.shareName,
      );
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

  void _openBuildReadiness() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => BomReadinessPage(
        api: widget.api,
        location: widget.shareName,
        shareId: widget.shareId,
      ),
    ),
  );

  void _openProjectKits() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ProjectKitsPage(
        api: widget.api,
        location: widget.shareName,
        shareId: widget.shareId,
      ),
    ),
  );

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final memberId = (member['member_id'] ?? '').toString();
    final name = (member['display_name'] ?? member['email'] ?? 'this member')
        .toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface2(ctx),
        title: AppText(
          'Remove member?',
          style: TextStyle(color: AppTheme.foreground(ctx, Colors.white)),
        ),
        content: AppText(
          'Remove $name from this space?',
          style: TextStyle(color: AppTheme.foreground(ctx, Color(0x73FFFFFF))),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: AppText(
              'Remove',
              style: TextStyle(
                color: AppTheme.foreground(ctx, Color(0xFFFF453A)),
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _removingMemberId = memberId);
    try {
      await widget.api.removeMember(
        shareId: widget.shareId,
        memberId: memberId,
      );
      if (!mounted) return;
      setState(
        () =>
            _members.removeWhere((m) => m['member_id'].toString() == memberId),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('Failed to remove member.')),
        );
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
                      color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                    ),
                  ),
                  counterStyle: AppTypography.bodyStyleOf(
                    context,
                    TextStyle(
                      color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                    ),
                  ),
                ),
              ),
              if (error != null)
                AppText(
                  error!,
                  style: TextStyle(
                    color: AppTheme.foreground(context, Color(0xFFFF453A)),
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
                } catch (_) {
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

  Future<void> _returnCheckout(String checkoutId, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface2(ctx),
        title: AppText(
          'Return item?',
          style: TextStyle(color: AppTheme.foreground(ctx, Colors.white)),
        ),
        content: AppText(
          'Mark "$itemName" as returned?',
          style: TextStyle(color: AppTheme.foreground(ctx, Color(0x73FFFFFF))),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText(
              'Return',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await widget.api.returnItem(checkoutId: checkoutId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText('$itemName returned')));
        _loadCheckouts();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('Failed to return item.')),
        );
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
    final colors = [
      AppTheme.adaptive(context, Color(0xFF6997DD)),
      AppTheme.adaptive(context, Color(0xFF30D158)),
      AppTheme.adaptive(context, Color(0xFFFF9F0A)),
      AppTheme.adaptive(context, Color(0xFFFF375F)),
      AppTheme.adaptive(context, Color(0xFF6997DD)),
      AppTheme.adaptive(context, Color(0xFF6997DD)),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  IconData _activityIcon(String summary) {
    final s = summary.toLowerCase();
    if (s.contains('checked out')) return Icons.logout_outlined;
    if (s.contains('returned')) return Icons.login_outlined;
    if (s.contains('added')) return Icons.add_circle_outline;
    if (s.contains('deleted') || s.contains('removed')) {
      return Icons.remove_circle_outline;
    }
    if (s.contains('updated') ||
        s.contains('edited') ||
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: AppText('Item added')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: AppText('Failed to add item')));
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
      shareId: widget.shareId,
      initialThreshold: threshold,
      spaceName: widget.shareName,
      onThresholdChanged: (nextThreshold) {
        if (!mounted) return;
        setState(() {
          if (nextThreshold == null) {
            _thresholds.remove(invItem.itemId);
          } else {
            _thresholds[invItem.itemId] = nextThreshold;
          }
        });
      },
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
      await LowStockPrefs.setThreshold(
        itemId: invItem.itemId,
        threshold: result.threshold,
      );
      if (!mounted) return;
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Failed to update item.')),
      );
    }
  }

  Future<void> _deleteItemRow(InventoryItem item) async {
    final ok = await showDialog<bool>(
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
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Failed to delete item.')),
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
      color: AppTheme.adaptive(context, Colors.black),
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
                        color: AppTheme.adaptive(
                          context,
                          const Color(0xFF171717),
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.adaptive(
                            context,
                            const Color(0x14FFFFFF),
                          ),
                          width: 0.5,
                        ),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        style: AppTypography.bodyStyleOf(
                          context,
                          TextStyle(
                            color: AppTheme.foreground(context, Colors.white),
                            fontSize: 14,
                          ),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search in this space...',
                          hintStyle: AppTypography.bodyStyleOf(
                            context,
                            TextStyle(
                              color: AppTheme.foreground(
                                context,
                                Color(0x4DFFFFFF),
                              ),
                              fontSize: 14,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppTheme.foreground(
                              context,
                              Color(0x4DFFFFFF),
                            ),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 13,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                    FocusScope.of(context).unfocus();
                                  },
                                  child: Icon(
                                    Icons.close,
                                    color: AppTheme.foreground(
                                      context,
                                      Color(0x4DFFFFFF),
                                    ),
                                    size: 16,
                                  ),
                                )
                              : null,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        showItemSortSheet(context, _sortOption, (opt) async {
                          await saveSortPref(opt);
                          if (mounted) setState(() => _sortOption = opt);
                        }),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.adaptive(
                          context,
                          const Color(0xFF171717),
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.adaptive(
                            context,
                            const Color(0x14FFFFFF),
                          ),
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        Icons.sort,
                        color: _sortOption != ItemSortOption.nameAZ
                            ? AppTheme.foreground(context, Colors.white)
                            : AppTheme.foreground(
                                context,
                                const Color(0x4DFFFFFF),
                              ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.adaptive(context, Colors.white)
                            : AppTheme.adaptive(
                                context,
                                const Color(0xFF171717),
                              ),
                        borderRadius: BorderRadius.circular(99),
                        border: isActive
                            ? null
                            : Border.all(
                                color: AppTheme.adaptive(
                                  context,
                                  const Color(0x14FFFFFF),
                                ),
                                width: 0.5,
                              ),
                      ),
                      child: AppText(
                        label,
                        style: TextStyle(
                          color: isActive
                              ? AppTheme.foreground(context, Colors.black)
                              : AppTheme.foreground(
                                  context,
                                  const Color(0x73FFFFFF),
                                ),
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
    final isLow =
        threshold != null && threshold >= 0 && invItem.quantity <= threshold;
    final canEdit = widget.permission == 'edit';
    final imageUrl = (invItem.imageUrl ?? '').trim();

    final rowChild = InkWell(
      onTap: canEdit ? () => _editItemRow(item) : () => _showItemDetail(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    invItem.displayName,
                    style: TextStyle(
                      color: AppTheme.foreground(context, Colors.white),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AppText(
                    [
                      if (invItem.displayDescription != null)
                        invItem.displayDescription!,
                      invItem.category,
                    ].join(' · '),
                    style: TextStyle(
                      color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isLow) ...[
              Icon(
                Icons.error_outline_rounded,
                size: 16,
                color: AppTheme.foreground(context, AppColors.danger),
              ),
              const SizedBox(width: 8),
            ],
            AppText(
              'Qty ${invItem.quantity}',
              style: TextStyle(
                color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _showItemDetail(item),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.adaptive(context, const Color(0xFF171717)),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                  size: 14,
                ),
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
      return SliverFillRemaining(
        child: Center(
          child: AppText(
            'No items in this shared space.',
            style: TextStyle(
              color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
            ),
          ),
        ),
      );
    }
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      final cat = (item['category'] ?? '').toString().trim();
      groups
          .putIfAbsent(cat.isEmpty ? 'Uncategorized' : cat, () => [])
          .add(item);
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
    final filteredCats = displayedCats
        .where(filteredGroups.containsKey)
        .toList();
    if (filteredCats.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: AppText(
            'No items match your search',
            style: TextStyle(
              color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
            ),
          ),
        ),
      );
    }
    final children = <Widget>[];
    for (final cat in filteredCats) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(left: 32, top: 20, bottom: 6),
          child: AppText(
            cat.toUpperCase(),
            style: TextStyle(
              color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
      );
      children.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.adaptive(context, const Color(0xFF171717)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
              width: 0.5,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < filteredGroups[cat]!.length; i++) ...[
                _buildItemRow(filteredGroups[cat]![i]),
                if (i < filteredGroups[cat]!.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 16,
                    endIndent: 16,
                    color: AppTheme.adaptive(context, Color(0x14FFFFFF)),
                  ),
              ],
            ],
          ),
        ),
      );
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
        const _SharedFabItem(
          icon: Icons.camera_alt_outlined,
          label: 'Upload Photo',
        ),
        const _SharedFabItem(
          icon: Icons.qr_code_scanner,
          label: 'Scan Barcode',
        ),
      ],
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
                    curve: Interval(
                      delay,
                      end.clamp(0.0, 1.0),
                      curve: Curves.easeOut,
                    ),
                  );
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(anim),
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
            key: TutorialController.spaceDetailFabKey,
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface2(context),
              border: Border.all(
                color: AppTheme.adaptive(
                  context,
                  Colors.white.withValues(alpha: 0.3),
                ),
                width: 1,
              ),
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
                      child: Icon(
                        Icons.add,
                        color: AppTheme.foreground(context, Colors.white),
                        size: 28,
                      ),
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
                color: AppTheme.adaptive(
                  context,
                  Colors.white.withValues(alpha: 0.08),
                ),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: AppTheme.adaptive(
                    context,
                    Colors.white.withValues(alpha: 0.15),
                  ),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    color: AppTheme.foreground(context, Colors.white),
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  AppText(
                    item.label,
                    style: TextStyle(
                      color: AppTheme.foreground(context, Colors.white),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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

  void _onFabItemTap(String label) {
    setState(() => _fabOpen = false);
    _fabController.reverse();
    switch (label) {
      case 'Add Item':
        _addItem();
      case 'Upload Photo':
        _uploadPhoto();
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
              shareId: widget.shareId,
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

  Widget _buildProjectsCard() => Material(
    key: TutorialController.projectsCardKey,
    color: AppTheme.adaptive(context, const Color(0xFF102A43)),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _showProjectsMenu,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.adaptive(context, Color(0xFF174A76)),
              child: Icon(
                Icons.inventory_2_outlined,
                color: AppTheme.foreground(context, Color(0xFF64B5FF)),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Projects',
                    style: TextStyle(
                      color: AppTheme.foreground(context, Colors.white),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  AppText(
                    'Check build readiness and track project kits',
                    style: TextStyle(
                      color: AppTheme.foreground(context, Colors.white60),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.foreground(context, Colors.white54),
            ),
          ],
        ),
      ),
    ),
  );

  void _showProjectsMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.adaptive(context, const Color(0xFF1C1C1E)),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.adaptive(sheetContext, Colors.white24),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: AppText(
                  'Projects',
                  style: TextStyle(
                    color: AppTheme.foreground(sheetContext, Colors.white),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: AppText(
                  'Plan a build with the inventory you have',
                  style: TextStyle(
                    color: AppTheme.foreground(sheetContext, Colors.white54),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.fact_check_outlined,
                  color: AppTheme.foreground(sheetContext, Color(0xFF6997DD)),
                ),
                title: const AppText('Build Readiness'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openBuildReadiness();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.inventory_2_outlined,
                  color: AppTheme.foreground(sheetContext, Color(0xFF6997DD)),
                ),
                title: const AppText('Project Kits'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openProjectKits();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab content builders ─────────────────────────────────────────────────

  Widget _buildItemsTab() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppTheme.adaptive(context, Colors.white),
          strokeWidth: 2,
        ),
      );
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
                  color: AppTheme.adaptive(context, const Color(0xFF171717)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      color: AppTheme.foreground(context, Color(0x73FFFFFF)),
                      size: 16,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: AppText(
                        "You're viewing a shared inventory. Contact the owner to make changes.",
                        style: TextStyle(
                          color: AppTheme.foreground(
                            context,
                            Color(0x73FFFFFF),
                          ),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _buildProjectsCard(),
          ),
        ),
        if (_items.isNotEmpty)
          SliverPersistentHeader(
            pinned: true,
            delegate: _SharedSearchPinDelegate(
              height: 124,
              child: _buildPinnedHeader(),
            ),
          ),
        _buildGroupedItemsSliver(),
      ],
    );
  }

  Widget _buildMembersTab() {
    if (_membersLoading && !_membersLoaded) {
      return Center(
        child: CircularProgressIndicator(
          color: AppTheme.adaptive(context, Colors.white),
          strokeWidth: 2,
        ),
      );
    }
    if (_membersError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppText(
              _membersError!,
              style: TextStyle(
                color: AppTheme.foreground(context, Color(0x73FFFFFF)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadMembers, child: const AppText('Retry')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMembers,
      color: AppTheme.adaptive(context, Colors.white),
      backgroundColor: AppTheme.adaptive(context, const Color(0xFF1C1C1E)),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _members.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppText(
                '${_members.length} MEMBER${_members.length != 1 ? 'S' : ''}',
                style: TextStyle(
                  color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
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
    final name = (member['display_name'] ?? member['email'] ?? 'Unknown')
        .toString();
    final role = (member['role'] ?? 'member').toString();
    final joinedAt = member['joined_at']?.toString();
    final avatarHex = member['avatar_color']?.toString();
    final isMe = userId == _currentUserId;
    final isOwnerRow = role == 'owner';
    final isRemoving = _removingMemberId == memberId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.adaptive(context, const Color(0xFF171717)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          MemberAvatar(
            name: name,
            photoUrl: member['avatar_url']?.toString(),
            colorHex: avatarHex,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  isMe ? '$name (you)' : name,
                  style: TextStyle(
                    color: AppTheme.foreground(context, Colors.white),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isOwnerRow
                            ? AppTheme.adaptive(
                                context,
                                const Color(0x1AFBBF24),
                              )
                            : AppTheme.adaptive(
                                context,
                                const Color(0xFF171717),
                              ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: AppText(
                        isOwnerRow ? 'Owner' : 'Member',
                        style: TextStyle(
                          color: isOwnerRow
                              ? AppTheme.foreground(
                                  context,
                                  const Color(0xFFFBBF24),
                                )
                              : AppTheme.foreground(
                                  context,
                                  const Color(0x73FFFFFF),
                                ),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (joinedAt != null) ...[
                      const SizedBox(width: 8),
                      AppText(
                        'Joined ${_timeAgo(joinedAt)}',
                        style: TextStyle(
                          color: AppTheme.foreground(
                            context,
                            Color(0x4DFFFFFF),
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_isOwner && !isOwnerRow && !isMe)
            isRemoving
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppTheme.adaptive(context, Colors.white38),
                      strokeWidth: 2,
                    ),
                  )
                : GestureDetector(
                    onTap: () => _removeMember(member),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.adaptive(
                          context,
                          const Color(0x0AFF453A),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.adaptive(
                            context,
                            const Color(0x33FF453A),
                          ),
                        ),
                      ),
                      child: AppText(
                        'Remove',
                        style: TextStyle(
                          color: AppTheme.foreground(
                            context,
                            Color(0xFFFF453A),
                          ),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _buildCheckoutsTab() {
    if (_checkoutsLoading && !_checkoutsLoaded) {
      return Center(
        child: CircularProgressIndicator(
          color: AppTheme.adaptive(context, Colors.white),
          strokeWidth: 2,
        ),
      );
    }

    final hasAny = _activeCheckouts.isNotEmpty || _returnedCheckouts.isNotEmpty;

    if (!hasAny) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppTheme.foreground(context, Color(0xFF30D158)),
              size: 48,
            ),
            const SizedBox(height: 12),
            AppText(
              'Nothing checked out',
              style: TextStyle(
                color: AppTheme.foreground(context, Colors.white),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            AppText(
              'Items checked out from this space appear here.',
              style: TextStyle(
                color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.permission == 'edit') ...[
              const SizedBox(height: 20),
              AppText(
                'Tap an item in the Items tab to check it out.',
                style: TextStyle(
                  color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCheckouts,
      color: AppTheme.adaptive(context, Colors.white),
      backgroundColor: AppTheme.adaptive(context, const Color(0xFF1C1C1E)),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_activeCheckouts.isNotEmpty) ...[
            _checkoutSectionHeader(
              '${_activeCheckouts.length} ITEM${_activeCheckouts.length != 1 ? 'S' : ''} CHECKED OUT',
            ),
            ..._activeCheckouts.map(
              (c) => _buildCheckoutCard(c, isReturned: false),
            ),
            const SizedBox(height: 8),
          ],
          if (_returnedCheckouts.isNotEmpty) ...[
            if (_activeCheckouts.isNotEmpty) const SizedBox(height: 8),
            _checkoutSectionHeader('RECENTLY RETURNED'),
            ..._returnedCheckouts.map(
              (c) => _buildCheckoutCard(c, isReturned: true),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _checkoutSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppText(
        text,
        style: TextStyle(
          color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildCheckoutCard(
    Map<String, dynamic> checkout, {
    bool isReturned = false,
  }) {
    final itemData = checkout['items'] as Map<String, dynamic>? ?? {};
    final itemName =
        itemData['name'] as String? ??
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
            ? AppTheme.adaptive(context, const Color(0x06FFFFFF))
            : overdue
            ? AppTheme.adaptive(context, const Color(0x0AEF4444))
            : AppTheme.adaptive(context, const Color(0xFF171717)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: overdue
              ? AppTheme.adaptive(context, const Color(0x33EF4444))
              : AppTheme.adaptive(context, const Color(0x14FFFFFF)),
          width: 0.5,
        ),
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
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: AppText(
                checkedOutBy.isNotEmpty ? checkedOutBy[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isReturned
                      ? AppTheme.foreground(context, const Color(0x99FFFFFF))
                      : AppTheme.foreground(context, Colors.white),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  itemName,
                  style: TextStyle(
                    color: isReturned
                        ? AppTheme.foreground(context, const Color(0x99FFFFFF))
                        : AppTheme.foreground(context, Colors.white),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                AppText(
                  'By $checkedOutBy · ${_timeAgo(checkedOutAt)}',
                  style: TextStyle(
                    color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                    fontSize: 12,
                  ),
                ),
                if (isReturned && returnedAt != null) ...[
                  const SizedBox(height: 2),
                  AppText(
                    'Returned ${_timeAgo(returnedAt)}',
                    style: TextStyle(
                      color: AppTheme.foreground(context, Color(0xFF30D158)),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else if (!isReturned && dueBackAt != null) ...[
                  const SizedBox(height: 2),
                  AppText(
                    overdue
                        ? '⚠ Overdue — due ${_timeAgo(dueBackAt)}'
                        : 'Due ${_timeAgo(dueBackAt)}',
                    style: TextStyle(
                      color: overdue
                          ? AppTheme.foreground(
                              context,
                              const Color(0xFFEF4444),
                            )
                          : AppTheme.foreground(
                              context,
                              const Color(0xFFFBBF24),
                            ),
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
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.adaptive(context, const Color(0xFF171717)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                  ),
                ),
                child: AppText(
                  'Return',
                  style: TextStyle(
                    color: AppTheme.foreground(context, Colors.white),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    if (_activityLoading && !_activityLoaded) {
      return Center(
        child: CircularProgressIndicator(
          color: AppTheme.adaptive(context, Colors.white),
          strokeWidth: 2,
        ),
      );
    }
    if (_activity.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_outlined,
              color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
              size: 48,
            ),
            SizedBox(height: 12),
            AppText(
              'No recent activity',
              style: TextStyle(
                color: AppTheme.foreground(context, Colors.white),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            AppText(
              'Changes to items in this space appear here.',
              style: TextStyle(
                color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadActivity,
      color: AppTheme.adaptive(context, Colors.white),
      backgroundColor: AppTheme.adaptive(context, const Color(0xFF1C1C1E)),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _activity.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: AppText(
                'RECENT ACTIVITY',
                style: TextStyle(
                  color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
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
        color: AppTheme.adaptive(context, const Color(0xFF171717)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _activityIcon(entry.summary),
              color: AppTheme.foreground(context, const Color(0x73FFFFFF)),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  entry.summary,
                  style: TextStyle(
                    color: AppTheme.foreground(context, Colors.white),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  _timeAgo(entry.createdAt.toIso8601String()),
                  style: TextStyle(
                    color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingTab() => ShoppingListPage(
    api: widget.api,
    shareId: widget.shareId,
    spaceName: widget.shareName,
    canEditStock: widget.permission == 'edit',
    embedded: true,
    onChanged: () => unawaited(_load()),
  );

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.adaptive(context, Colors.black),
      floatingActionButton: _currentTab == 0 && widget.permission == 'edit'
          ? _buildSpeedDial()
          : null,
      appBar: AppBar(
        backgroundColor: AppTheme.adaptive(context, Colors.black),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: AppTheme.foreground(context, Colors.white),
        ),
        title: AppText(
          widget.shareName,
          style: TextStyle(
            color: AppTheme.foreground(context, Colors.white),
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              children: [
                _badge(
                  _isOwner ? 'Owner' : 'Member',
                  textColor: AppTheme.adaptive(
                    context,
                    const Color(0x73FFFFFF),
                  ),
                  bgColor: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                ),
                const SizedBox(width: 6),
                _badge(
                  widget.permission == 'edit' ? 'Can edit' : 'View only',
                  textColor: widget.permission == 'edit'
                      ? AppTheme.adaptive(context, const Color(0xFF30D158))
                      : AppTheme.adaptive(context, const Color(0x73FFFFFF)),
                  bgColor: widget.permission == 'edit'
                      ? AppTheme.adaptive(context, const Color(0x1A30D158))
                      : AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz,
              color: AppTheme.foreground(context, Color(0xB3FFFFFF)),
            ),
            color: AppTheme.adaptive(context, const Color(0xFF1C1C1E)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: _onFabItemTap,
            itemBuilder: (_) => [
              if (widget.permission == 'edit')
                const PopupMenuItem(
                  value: 'Import Spreadsheet',
                  child: ListTile(
                    leading: Icon(Icons.table_chart_outlined),
                    title: AppText('Import Spreadsheet'),
                  ),
                ),
              const PopupMenuItem(
                value: 'Share Space',
                child: ListTile(
                  leading: Icon(Icons.share_outlined),
                  title: AppText('Share Space'),
                ),
              ),
              const PopupMenuItem(
                value: 'Join Space',
                child: ListTile(
                  leading: Icon(Icons.person_add_outlined),
                  title: AppText('Join Space'),
                ),
              ),
              const PopupMenuItem(
                value: 'Print Bin Label',
                child: ListTile(
                  leading: Icon(Icons.qr_code_2),
                  title: AppText('Print Bin Label'),
                ),
              ),
              const PopupMenuItem(
                value: 'Members',
                child: ListTile(
                  leading: Icon(Icons.people_outline),
                  title: AppText('Members'),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.adaptive(context, Colors.white),
          indicatorWeight: 1.5,
          labelColor: AppTheme.adaptive(context, Colors.white),
          unselectedLabelColor: AppTheme.adaptive(
            context,
            const Color(0x4DFFFFFF),
          ),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          dividerColor: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
          tabs: [
            Tab(text: _items.isNotEmpty ? 'Items (${_items.length})' : 'Items'),
            Tab(
              text: _members.isNotEmpty
                  ? 'Members (${_members.length})'
                  : 'Members',
            ),
            const Tab(text: 'Checked Out'),
            const Tab(text: 'Activity'),
            const Tab(text: 'Restock'),
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
                child: Container(
                  color: AppTheme.adaptive(
                    context,
                    Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(
    String text, {
    required Color textColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: AppText(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w500,
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

class _SharedBarcodeScannerPageState extends State<_SharedBarcodeScannerPage> {
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
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;
}

// ── Add item sheet ────────────────────────────────────────────────────────────

class _SharedAddItemSheet extends StatefulWidget {
  const _SharedAddItemSheet({required this.initialLocation});
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
    hintStyle: AppTypography.bodyStyleOf(
      context,
      TextStyle(
        color: AppTheme.foreground(context, Color(0x33FFFFFF)),
        fontSize: 15,
      ),
    ),
    filled: true,
    fillColor: AppTheme.adaptive(context, const Color(0xFF171717)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(
        color: AppTheme.adaptive(context, Color(0x14FFFFFF)),
        width: 0.5,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(
        color: AppTheme.adaptive(context, Color(0x14FFFFFF)),
        width: 0.5,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(
        color: AppTheme.adaptive(context, Color(0x40FFFFFF)),
        width: 0.5,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.adaptive(context, Color(0xFF111111)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(
            color: AppTheme.adaptive(context, Color(0x14FFFFFF)),
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.only(left: 16, right: 16, bottom: bottom + 24),
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
            'Add item',
            style: TextStyle(
              color: AppTheme.foreground(context, Colors.white),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            style: AppTypography.bodyStyleOf(
              context,
              TextStyle(
                color: AppTheme.foreground(context, Colors.white),
                fontSize: 15,
              ),
            ),
            decoration: _field('Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _category,
            style: AppTypography.bodyStyleOf(
              context,
              TextStyle(
                color: AppTheme.foreground(context, Colors.white),
                fontSize: 15,
              ),
            ),
            decoration: _field('Category'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            style: AppTypography.bodyStyleOf(
              context,
              TextStyle(
                color: AppTheme.foreground(context, Colors.white),
                fontSize: 15,
              ),
            ),
            decoration: _field('Quantity'),
          ),
          const SizedBox(height: 10),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.adaptive(context, const Color(0xFF171717)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: AppText(
              widget.initialLocation,
              style: TextStyle(
                color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(_quantity.text.trim()) ?? 1;
                Navigator.of(context).pop(
                  AddItemRequest(
                    name: _name.text.trim(),
                    category: _category.text.trim(),
                    quantity: qty,
                    location: widget.initialLocation,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.adaptive(context, Colors.white),
                foregroundColor: AppTheme.adaptive(context, Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const AppText(
                'Save',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: AppText(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.foreground(context, Color(0x73FFFFFF)),
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
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            AppText(
              label,
              style: TextStyle(
                color: AppTheme.foreground(context, Color(0x73FFFFFF)),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            Flexible(
              child: AppText(
                value,
                style: TextStyle(
                  color: AppTheme.foreground(context, Colors.white),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Builder(
    builder: (context) => Container(
      height: 0.5,
      color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
      margin: const EdgeInsets.symmetric(horizontal: 18),
    ),
  );

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
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
    final displayName = partNumber.trim().isNotEmpty ? partNumber : name;
    final displayDescription = partNumber.trim().isNotEmpty ? name : '';
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
      decoration: BoxDecoration(
        color: AppTheme.adaptive(context, Color(0xFF111111)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(
            color: AppTheme.adaptive(context, Color(0x14FFFFFF)),
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
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
                  color: AppTheme.adaptive(context, const Color(0x33FFFFFF)),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AppText(
                displayName,
                style: TextStyle(
                  color: AppTheme.foreground(context, Colors.white),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AppText(
                displayDescription.isNotEmpty ? displayDescription : category,
                style: TextStyle(
                  color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.adaptive(context, const Color(0xFF171717)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                    width: 0.5,
                  ),
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
                      _infoRow('Brand', brand),
                    ],
                    if (barcode.isNotEmpty) ...[
                      _divider(),
                      _infoRow('Barcode', barcode),
                    ],
                    if (displayDescription.isNotEmpty) ...[
                      _divider(),
                      _infoRow('Description', displayDescription),
                    ],
                    if (subcategory.isNotEmpty) ...[
                      _divider(),
                      _infoRow('Subcategory', subcategory),
                    ],
                    if (purchaseSource.isNotEmpty) ...[
                      _divider(),
                      _infoRow('Purchase Source', purchaseSource),
                    ],
                    _divider(),
                    _infoRow('Date added', _formatDate(createdAt)),
                    if (confidence != null) ...[
                      _divider(),
                      _infoRow(
                        'AI confidence',
                        '${(confidence * 100).toStringAsFixed(0)}%',
                      ),
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
                    AppText(
                      'NOTES',
                      style: TextStyle(
                        color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 60),
                      decoration: BoxDecoration(
                        color: AppTheme.adaptive(
                          context,
                          const Color(0xFF171717),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.adaptive(
                            context,
                            const Color(0x14FFFFFF),
                          ),
                          width: 0.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: AppText(
                        notes,
                        style: TextStyle(
                          color: AppTheme.foreground(
                            context,
                            Color(0x73FFFFFF),
                          ),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
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
                      backgroundColor: AppTheme.adaptive(
                        context,
                        const Color(0x14FFFFFF),
                      ),
                      foregroundColor: AppTheme.adaptive(context, Colors.white),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const AppText(
                      'Edit',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
                      backgroundColor: AppTheme.adaptive(
                        context,
                        const Color(0x0A6997DD),
                      ),
                      foregroundColor: AppTheme.adaptive(
                        context,
                        const Color(0xFF6997DD),
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const AppText(
                      'Check Out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop('delete'),
                  child: AppText(
                    'Delete item',
                    style: TextStyle(
                      color: AppTheme.foreground(context, Color(0xFFFF453A)),
                      fontSize: 14,
                    ),
                  ),
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
    _category = TextEditingController(text: (it['category'] ?? '').toString());
    _location = TextEditingController(text: (it['location'] ?? '').toString());
    _quantity = TextEditingController(text: (it['quantity'] ?? 1).toString());
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
    hintStyle: AppTypography.bodyStyleOf(
      context,
      TextStyle(
        color: AppTheme.foreground(context, Color(0x33FFFFFF)),
        fontSize: 15,
      ),
    ),
    filled: true,
    fillColor: AppTheme.adaptive(context, const Color(0xFF171717)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(
        color: AppTheme.adaptive(context, Color(0x14FFFFFF)),
        width: 0.5,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(
        color: AppTheme.adaptive(context, Color(0x14FFFFFF)),
        width: 0.5,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(
        color: AppTheme.adaptive(context, Color(0x40FFFFFF)),
        width: 0.5,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.adaptive(context, Color(0xFF111111)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(
            color: AppTheme.adaptive(context, Color(0x14FFFFFF)),
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.only(left: 16, right: 16, bottom: bottom + 24),
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
                  color: AppTheme.adaptive(context, const Color(0x33FFFFFF)),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 4),
            AppText(
              'Edit item',
              style: TextStyle(
                color: AppTheme.foreground(context, Colors.white),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              style: AppTypography.bodyStyleOf(
                context,
                TextStyle(
                  color: AppTheme.foreground(context, Colors.white),
                  fontSize: 15,
                ),
              ),
              decoration: _field('Name *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _category,
              style: AppTypography.bodyStyleOf(
                context,
                TextStyle(
                  color: AppTheme.foreground(context, Colors.white),
                  fontSize: 15,
                ),
              ),
              decoration: _field('Category *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _location,
              style: AppTypography.bodyStyleOf(
                context,
                TextStyle(
                  color: AppTheme.foreground(context, Colors.white),
                  fontSize: 15,
                ),
              ),
              decoration: _field('Location'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              style: AppTypography.bodyStyleOf(
                context,
                TextStyle(
                  color: AppTheme.foreground(context, Colors.white),
                  fontSize: 15,
                ),
              ),
              decoration: _field('Quantity'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              maxLines: 3,
              style: AppTypography.bodyStyleOf(
                context,
                TextStyle(
                  color: AppTheme.foreground(context, Colors.white),
                  fontSize: 15,
                ),
              ),
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
                              content: AppText(
                                'Name and category are required',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() => _saving = true);
                        try {
                          await widget.api.updateItem(
                            request: UpdateItemRequest(
                              itemId: (widget.item['item_id'] ?? '').toString(),
                              name: _name.text.trim(),
                              category: _category.text.trim(),
                              location: _location.text.trim().isEmpty
                                  ? null
                                  : _location.text.trim(),
                              quantity: int.tryParse(_quantity.text.trim()),
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
                            SnackBar(content: AppText(describeError(e).$1)),
                          );
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.adaptive(context, Colors.white),
                  foregroundColor: AppTheme.adaptive(context, Colors.black),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.adaptive(context, Colors.black),
                        ),
                      )
                    : const AppText(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: AppText(
                  'Cancel',
                  style: TextStyle(
                    color: AppTheme.foreground(context, Color(0x73FFFFFF)),
                    fontSize: 15,
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

class _SharedFabItem {
  const _SharedFabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
