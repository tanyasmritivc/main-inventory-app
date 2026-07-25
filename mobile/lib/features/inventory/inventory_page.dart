import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/low_stock_prefs.dart';
import '../../core/pro_status.dart';
import '../../core/upgrade_sheet.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/skeleton.dart';
import '../chat/chat_page.dart';
import '../sharing/share_space_sheet.dart';
import 'bin_label_sheet.dart';
import 'item_detail_sheet.dart';
import 'item_editor_sheet.dart';
import 'item_sort.dart';
import '../scan/upload_photo_flow.dart';
import '../checkout/checkout_page.dart';
import '../shopping/shopping_list_page.dart';
import '../sharing/shared_inventory_page.dart';
import '../sharing/space_members_page.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.api,
    required this.refreshToken,
    this.initialQuery,
  });

  final ApiClient api;
  final int refreshToken;
  final String? initialQuery;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _LocationItemsPage extends StatefulWidget {
  const _LocationItemsPage({
    required this.api,
    required this.location,
    required this.items,
    required this.thresholds,
    required this.allItems,
  });

  final ApiClient api;
  final String location;
  final List<InventoryItem> items;
  final Map<String, int> thresholds;
  final List<InventoryItem> allItems;

  @override
  State<_LocationItemsPage> createState() => _LocationItemsPageState();
}

class _LocationItemsPageState extends State<_LocationItemsPage> {
  late List<InventoryItem> _items;
  late Map<String, int> _thresholds;
  bool _changed = false;
  bool _isEditingNotes = false;
  late final TextEditingController _notesController;
  bool _isSuggestingPurchaseSource = false;
  late final TextEditingController _purchaseSourceController;
  late final TextEditingController _thresholdSheetController;
  late final TextEditingController _joinCodeCtrl;
  late final TextEditingController _checkoutNameCtrl;
  late final TextEditingController _checkoutNotesCtrl;
  Timer? _purchaseSourceDebounce;
  Timer? _thresholdDebounce;
  String _selectedCategory = 'All';
  final ScrollController _listScrollController = ScrollController();
  final Map<String, GlobalKey> _categoryKeys = {};
  String _spaceSearchQuery = '';
  late final TextEditingController _spaceSearchController;
  ItemSortOption _sortOption = ItemSortOption.nameAZ;

  @override
  void dispose() {
    _notesController.dispose();
    _purchaseSourceController.dispose();
    _thresholdSheetController.dispose();
    _joinCodeCtrl.dispose();
    _checkoutNameCtrl.dispose();
    _checkoutNotesCtrl.dispose();
    _purchaseSourceDebounce?.cancel();
    _thresholdDebounce?.cancel();
    _listScrollController.dispose();
    _spaceSearchController.dispose();
    super.dispose();
  }

  void _rebuildCategoryKeys() {
    final groups = <String, List<InventoryItem>>{};
    for (final item in _items) {
      final cat = item.category.trim().isEmpty ? 'Uncategorized' : item.category.trim();
      groups.putIfAbsent(cat, () => []).add(item);
    }
    for (final cat in groups.keys) {
      _categoryKeys.putIfAbsent(cat, () => GlobalKey());
    }
  }

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _purchaseSourceController = TextEditingController();
    _thresholdSheetController = TextEditingController();
    _joinCodeCtrl = TextEditingController();
    _checkoutNameCtrl = TextEditingController();
    _checkoutNotesCtrl = TextEditingController();
    _spaceSearchController = TextEditingController();
    loadSortPref().then((v) { if (mounted) setState(() => _sortOption = v); });
    _items = List<InventoryItem>.from(widget.items)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _thresholds = Map<String, int>.from(widget.thresholds);
    _rebuildCategoryKeys();
  }

  int _totalCount() {
    return _items.fold<int>(0, (acc, it) => acc + (it.quantity <= 0 ? 0 : it.quantity));
  }

  int _lowCount() {
    var n = 0;
    for (final it in _items) {
      final thr = _thresholds[it.itemId];
      if ((thr != null && thr > 0 && it.quantity <= thr) || it.quantity <= 0) n++;
    }
    return n;
  }

  Future<void> _editItem(InventoryItem item) async {
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
      await LowStockPrefs.setThreshold(
        itemId: item.itemId,
        threshold: updates.threshold,
      );

      final nextThresholds = Map<String, int>.from(_thresholds);
      if (updates.threshold == null || updates.threshold! <= 0) {
        nextThresholds.remove(item.itemId);
      } else {
        nextThresholds[item.itemId] = updates.threshold!;
      }

      if (!mounted) return;
      setState(() {
        _thresholds = nextThresholds;
        final idx = _items.indexWhere((e) => e.itemId == item.itemId);
        if (idx != -1) {
          _items[idx] = updated;
        }
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory updated')),
      );
    } on dio.DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection issue. Please try again.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
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
      await LowStockPrefs.setThreshold(itemId: item.itemId, threshold: null);
      if (!mounted) return;
      setState(() {
        _items = _items.where((e) => e.itemId != item.itemId).toList();
        final next = Map<String, int>.from(_thresholds);
        next.remove(item.itemId);
        _thresholds = next;
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted')),
      );
    } on dio.DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection issue. Please try again.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    }
  }

  Widget _buildItemRow(InventoryItem item) {
    final threshold = _thresholds[item.itemId];
    final isLow = threshold != null && threshold > 0 && item.quantity <= threshold;
    return Dismissible(
      key: ValueKey(item.itemId),
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
          await _editItem(item);
          return false;
        }
        if (direction == DismissDirection.endToStart) {
          await _deleteItem(item);
          return false;
        }
        return false;
      },
      child: InkWell(
        onTap: () => _editItem(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.category,
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
                'Qty ${item.quantity}',
                style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 13),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showProductInfo(context, item),
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
      ),
    );
  }

  Future<void> _joinSpaceDialog() async {
    _joinCodeCtrl.clear();
    String? error;
    await showDialog(
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

  List<String> _sortedCategoryPills() {
    final loc = widget.location.trim().isEmpty ? 'Unsorted' : widget.location.trim();
    final catSet = <String>{};
    for (final it in widget.allItems) {
      final itLoc = it.location.trim().isEmpty ? 'Unsorted' : it.location.trim();
      if (itLoc.toLowerCase() != loc.toLowerCase()) continue;
      final c = it.category.trim().isEmpty ? 'Uncategorized' : it.category.trim();
      catSet.add(c);
    }
    final sorted = catSet.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...sorted];
  }

  bool _matchesSpaceSearch(InventoryItem item) {
    final q = _spaceSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return item.name.toLowerCase().contains(q) ||
        (item.brand?.toLowerCase().contains(q) ?? false) ||
        item.category.toLowerCase().contains(q);
  }

  void _onCategoryPillTapped(String cat) {
    setState(() => _selectedCategory = cat);
    _listScrollController.jumpTo(0);
  }

  Future<void> _addItem() async {
    final created = await showModalBottomSheet<ItemEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => ItemEditorSheet(initialLocation: widget.location),
    );
    if (created == null) return;
    try {
      final out = await widget.api.addItem(item: created.add);
      await LowStockPrefs.setThreshold(
        itemId: out.itemId,
        threshold: created.threshold,
      );
      _changed = true;
      final result = await widget.api.searchItems(query: '');
      if (!mounted) return;
      final loc = widget.location.trim().isEmpty ? 'Unsorted' : widget.location.trim();
      final locationItems = result.items
          .where((i) {
            final l = i.location.trim().isEmpty ? 'Unsorted' : i.location.trim();
            return l.toLowerCase() == loc.toLowerCase();
          })
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _items = locationItems;
        _rebuildCategoryKeys();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item added')),
      );
    } on SessionExpiredException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please sign in again.')),
      );
    } on dio.DioException catch (e) {
      if (!mounted) return;
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
            const SnackBar(content: Text('Something went wrong. Please try again.')),
          );
        }
        return;
      }
      if (e.response?.statusCode == 403) {
        // Any 403 = free tier limit or auth issue → show upgrade
        if (!ProStatus.isPro) {
          showUpgradeSheet(
            context,
            widget.api,
            reason: 'Upgrade to Pro for unlimited items, spaces and AI scans.',
          );
        } else {
          debugPrint('FINDEZ: Pro user got 403 — backend bug');
          unawaited(ProStatus.refresh(widget.api));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Something went wrong. Please try again.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Connection issue. Please try again.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _showUpgradePrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface2(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Color(0xFFF59E0B), size: 32),
              const SizedBox(height: 12),
              const Text('You\'ve reached your free limit', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Upgrade to FindEZ Pro for unlimited items, spaces, and AI scans.', style: TextStyle(color: Color(0x73FFFFFF), fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(99)),
                  child: const Text('Upgrade to Pro', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: const Text('Maybe later', style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductInfo(BuildContext context, InventoryItem item) {
    final existingThr = _thresholds[item.itemId];
    showItemDetailSheet(
      context,
      item: item,
      api: widget.api,
      permission: 'edit',
      initialThreshold: existingThr,
      spaceName: widget.location,
    );
  }


  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0x73FFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
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
    );
  }

  Widget _divider() {
    return Container(
      height: 0.5,
      color: const Color(0x14FFFFFF),
      margin: const EdgeInsets.symmetric(horizontal: 18),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _saveNotes(InventoryItem item, StateSetter setSheetState) async {
    final notes = _notesController.text.trim();
    try {
      await widget.api.updateItem(
        request: UpdateItemRequest(itemId: item.itemId, notes: notes),
      );
      final idx = _items.indexWhere((e) => e.itemId == item.itemId);
      if (idx != -1 && mounted) setState(() => _changed = true);
      setSheetState(() => _isEditingNotes = false);
    } catch (_) {
      // fail silently, keep editing mode
    }
  }

  Future<void> _showCheckoutDialog(BuildContext context, InventoryItem item, StateSetter setSheetState) async {
    _checkoutNameCtrl.clear();
    _checkoutNotesCtrl.clear();
    DateTime? dueBack;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface2(context),
          title: Text(
            'Check Out ${item.name}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _checkoutNameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Who is taking this?',
                  hintStyle: TextStyle(color: Color(0x4DFFFFFF)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0x14FFFFFF))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _checkoutNotesCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Notes (optional)',
                  hintStyle: TextStyle(color: Color(0x4DFFFFFF)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0x14FFFFFF))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    builder: (context, child) => Theme(
                      data: ThemeData.dark(),
                      child: child!,
                    ),
                  );
                  if (picked != null) setDialogState(() => dueBack = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x14FFFFFF)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: Color(0x73FFFFFF), size: 14),
                      const SizedBox(width: 8),
                      Text(
                        dueBack == null
                            ? 'Set due date (optional)'
                            : 'Due: ${dueBack!.day}/${dueBack!.month}/${dueBack!.year}',
                        style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0x73FFFFFF))),
            ),
            TextButton(
              onPressed: () async {
                if (_checkoutNameCtrl.text.trim().isEmpty) return;
                try {
                  await widget.api.checkoutItem(
                    itemId: item.itemId,
                    checkedOutBy: _checkoutNameCtrl.text.trim(),
                    spaceName: widget.location,
                    dueBackAt: dueBack?.toIso8601String(),
                    notes: _checkoutNotesCtrl.text.trim().isEmpty ? null : _checkoutNotesCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  setSheetState(() {});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${item.name} checked out to ${_checkoutNameCtrl.text.trim()}')),
                    );
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to check out. Try again.')),
                    );
                  }
                }
              },
              child: const Text('Check Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _schedulePurchaseSourceSave(InventoryItem item) {
    _purchaseSourceDebounce?.cancel();
    _purchaseSourceDebounce = Timer(const Duration(milliseconds: 600), () {
      _savePurchaseSourceSilent(item);
    });
  }

  Future<void> _savePurchaseSourceSilent(InventoryItem item) async {
    final source = _purchaseSourceController.text.trim();
    try {
      await widget.api.updateItem(
        request: UpdateItemRequest(itemId: item.itemId, purchaseSource: source.isEmpty ? null : source),
      );
      final idx = _items.indexWhere((e) => e.itemId == item.itemId);
      if (idx != -1 && mounted) setState(() => _changed = true);
    } catch (_) {}
  }

  Future<void> _suggestPurchaseSource(InventoryItem item, StateSetter setSheetState) async {
    final itemName = Uri.encodeComponent(item.name);
    final links = [
      {'name': 'Amazon', 'url': 'https://www.amazon.com/s?k=$itemName', 'icon': Icons.shopping_bag_outlined},
      {'name': 'Google Shopping', 'url': 'https://www.google.com/search?tbm=shop&q=$itemName', 'icon': Icons.search},
      {'name': 'eBay', 'url': 'https://www.ebay.com/sch/i.html?_nkw=$itemName', 'icon': Icons.store_outlined},
      {'name': 'Walmart', 'url': 'https://www.walmart.com/search?q=$itemName', 'icon': Icons.local_grocery_store_outlined},
      {'name': 'Target', 'url': 'https://www.target.com/s?searchTerm=$itemName', 'icon': Icons.shopping_cart_outlined},
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface2(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Where to buy "${item.name}"',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text('Tap to open in browser', style: TextStyle(color: Color(0x73FFFFFF), fontSize: 12)),
            ),
            ...links.map((link) => ListTile(
              leading: Icon(link['icon'] as IconData, color: Colors.white70, size: 20),
              title: Text(link['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 15)),
              trailing: const Icon(Icons.open_in_new, color: Color(0x4DFFFFFF), size: 16),
              onTap: () async {
                final uri = Uri.parse(link['url'] as String);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _scheduleThresholdSave(InventoryItem item) {
    _thresholdDebounce?.cancel();
    _thresholdDebounce = Timer(const Duration(milliseconds: 600), () {
      _saveThresholdSilent(item);
    });
  }

  Future<void> _saveThresholdSilent(InventoryItem item) async {
    final rawThreshold = int.tryParse(_thresholdSheetController.text.trim());
    final threshold = (rawThreshold != null && rawThreshold > 0) ? rawThreshold : null;
    try {
      await LowStockPrefs.setThreshold(itemId: item.itemId, threshold: threshold);
      if (mounted) {
        setState(() {
          final next = Map<String, int>.from(_thresholds);
          if (threshold == null) {
            next.remove(item.itemId);
          } else {
            next[item.itemId] = threshold;
          }
          _thresholds = next;
          _changed = true;
        });
      }
    } catch (_) {}
  }

  void _loadItemDocuments(StateSetter setSheetState, List<DocumentEntry> docs, String itemId) {
    widget.api.getDocuments(itemId: itemId).then((loaded) {
      if (mounted) setSheetState(() { docs.clear(); docs.addAll(loaded); });
    }).catchError((_) {});
  }

  Future<void> _pickAndUploadDocument(
    BuildContext context,
    InventoryItem item,
    StateSetter setSheetState,
    List<DocumentEntry> docs,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface2(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.white),
              title: const Text('Choose Photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
              title: const Text('Choose PDF', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    List<int>? bytes;
    String? filename;

    if (choice == 'photo') {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (x == null) return;
      bytes = await x.readAsBytes();
      filename = x.name;
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      if (picked.bytes == null) return;
      bytes = picked.bytes!.toList();
      filename = picked.name;
    }

    if (bytes == null || filename == null) return;
    try {
      final file = dio.MultipartFile.fromBytes(bytes, filename: filename);
      await widget.api.uploadDocument(file: file, itemId: item.itemId);
      _loadItemDocuments(setSheetState, docs, item.itemId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed. Please try again.')),
      );
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
          final loc = widget.location.trim().isEmpty
              ? 'Unsorted'
              : widget.location.trim();
          final locationItems = reload.items
              .where((i) {
                final l = i.location.trim().isEmpty ? 'Unsorted' : i.location.trim();
                return l.toLowerCase() == loc.toLowerCase();
              })
              .toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          if (!mounted) return;
          setState(() {
            _items = locationItems;
            _rebuildCategoryKeys();
          });
        } catch (_) {}
      },
    );
  }

  Future<void> _scanBarcode() async {
    String? barcode;
    try {
      barcode = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const _InventoryBarcodeScannerPage()),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to scan. Please try again.')),
      );
      return;
    }
    if (barcode == null || barcode.trim().isEmpty) return;

    BarcodeLookupResult lookup;
    try {
      lookup = await widget.api.barcodeLookup(barcode: barcode.trim());
    } catch (_) {
      lookup = BarcodeLookupResult();
    }
    if (!mounted) return;

    final request = await showModalBottomSheet<AddItemRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BarcodeConfirmSheet(
        barcode: barcode!,
        lookup: lookup,
        location: widget.location,
      ),
    );
    if (request == null) return;

    try {
      final out = await widget.api.addItem(item: request);
      await LowStockPrefs.setThreshold(itemId: out.itemId, threshold: null);
      _changed = true;
      final reload = await widget.api.searchItems(query: '');
      final loc = widget.location.trim().isEmpty ? 'Unsorted' : widget.location.trim();
      final locationItems = reload.items
          .where((i) {
            final l = i.location.trim().isEmpty ? 'Unsorted' : i.location.trim();
            return l.toLowerCase() == loc.toLowerCase();
          })
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _items = locationItems;
        _rebuildCategoryKeys();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item added')),
      );
    } on SessionExpiredException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please sign in again.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add item. Try again.')),
      );
    }
  }

  Widget _buildGroupedList() {
    final groups = <String, List<InventoryItem>>{};
    for (final item in _items) {
      final cat = item.category.trim().isEmpty ? 'Uncategorized' : item.category.trim();
      groups.putIfAbsent(cat, () => []).add(item);
    }
    final sortedCats = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final cat in sortedCats) {
      sortInventoryItems(groups[cat]!, _sortOption);
    }

    final displayedCats = _selectedCategory == 'All'
        ? sortedCats
        : sortedCats.where((c) => c == _selectedCategory).toList();

    final filteredGroups = <String, List<InventoryItem>>{};
    for (final cat in displayedCats) {
      final matches = (groups[cat] ?? []).where(_matchesSpaceSearch).toList();
      if (matches.isNotEmpty) filteredGroups[cat] = matches;
    }
    final filteredCats =
        displayedCats.where((c) => filteredGroups.containsKey(c)).toList();

    if (filteredCats.isEmpty && _spaceSearchQuery.trim().isNotEmpty) {
      return const Center(
        child: Text(
          'No items match your search',
          style: TextStyle(color: Color(0x4DFFFFFF)),
        ),
      );
    }

    return ListView(
      controller: _listScrollController,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final cat in filteredCats) ...[
          Padding(
            key: _categoryKeys[cat],
            padding: const EdgeInsets.only(left: 32, top: 20, bottom: 6),
            child: Text(
              cat.toUpperCase(),
              style: const TextStyle(
                color: Color(0x4DFFFFFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
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
                      color: Color(0x14FFFFFF),
                    ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        result;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        appBar: AppBar(
          title: Text(widget.location),
          centerTitle: true,
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.image_outlined, color: Color(0x73FFFFFF)),
              onPressed: _uploadImage,
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Color(0x73FFFFFF)),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => DraggableScrollableSheet(
                  initialChildSize: 0.65,
                  maxChildSize: 0.92,
                  minChildSize: 0.4,
                  builder: (_, __) => ShareSpaceSheet(
                    spaceName: widget.location,
                    api: widget.api,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      api: widget.api,
                      initialMessage: 'What do I have in ${widget.location}?',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0x73FFFFFF)),
            ),
          ],
          backgroundColor: AppTheme.bg(context),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Container(
          color: AppTheme.bg(context),
          child: CustomScrollView(
            slivers: [
              // Stats bar + action toolbar — scrolls away
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          _StatChip(
                            icon: Icons.inventory_2_outlined,
                            label: '${_totalCount()} ${_totalCount() == 1 ? 'item' : 'items'}',
                            color: Colors.white60,
                          ),
                          const SizedBox(width: 8),
                          if (_lowCount() > 0)
                            _StatChip(
                              icon: Icons.warning_amber_outlined,
                              label: '${_lowCount()} low stock',
                              color: const Color(0xFFFBBF24),
                            ),
                        ],
                      ),
                    ),
                    // Action toolbar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: _uploadImage,
                                  icon: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white60),
                                  label: const Text('Upload Photo', style: TextStyle(fontSize: 11, color: Colors.white60)),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    backgroundColor: const Color(0x0AFFFFFF),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: _scanBarcode,
                                  icon: const Icon(Icons.qr_code_scanner, size: 16, color: Colors.white60),
                                  label: const Text('Scan Barcode', style: TextStyle(fontSize: 11, color: Colors.white60)),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    backgroundColor: const Color(0x0AFFFFFF),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () => showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => DraggableScrollableSheet(
                                      initialChildSize: 0.65,
                                      maxChildSize: 0.92,
                                      minChildSize: 0.4,
                                      builder: (_, __) => ShareSpaceSheet(
                                        spaceName: widget.location,
                                        api: widget.api,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.share_outlined, size: 16, color: Colors.white60),
                                  label: const Text('Share Space', style: TextStyle(fontSize: 11, color: Colors.white60)),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    backgroundColor: const Color(0x0AFFFFFF),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: _joinSpaceDialog,
                                  icon: const Icon(Icons.person_add_outlined, size: 16, color: Colors.white60),
                                  label: const Text('Join Space', style: TextStyle(fontSize: 11, color: Colors.white60)),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    backgroundColor: const Color(0x0AFFFFFF),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => BinLabelSheet(
                                spaceName: widget.location,
                                items: _items,
                              ),
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0x0AFFFFFF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0x14FFFFFF)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.qr_code_2, size: 16, color: Colors.white60),
                                  SizedBox(width: 6),
                                  Text(
                                    'Print Bin Label',
                                    style: TextStyle(fontSize: 11, color: Colors.white60),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              try {
                                final shares = await widget.api.getMyShares();
                                dynamic match;
                                for (final s in shares) {
                                  if ((s['share_name'] ?? '').toString().toLowerCase() == widget.location.toLowerCase()) {
                                    match = s;
                                    break;
                                  }
                                }
                                if (match != null && mounted) {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => SpaceMembersPage(
                                      shareId: match['share_id'].toString(),
                                      spaceName: widget.location,
                                      api: widget.api,
                                    ),
                                  ));
                                  return;
                                }
                              } catch (_) {}
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('This space isn\'t shared yet')),
                                );
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0x0AFFFFFF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0x14FFFFFF)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline, size: 16, color: Colors.white60),
                                  SizedBox(width: 6),
                                  Text(
                                    'Members',
                                    style: TextStyle(fontSize: 11, color: Colors.white60),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Search bar + category pills — pinned
              if (_items.isNotEmpty)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SearchPinDelegate(
                    height: 108,
                    child: Container(
                      color: Colors.black,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Search bar + sort button
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
                                        border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                                      ),
                                      child: TextField(
                                        controller: _spaceSearchController,
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        decoration: InputDecoration(
                                          hintText: 'Search in this space...',
                                          hintStyle: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 14),
                                          prefixIcon: const Icon(Icons.search, color: Color(0x4DFFFFFF), size: 20),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          filled: false,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 13),
                                          suffixIcon: _spaceSearchQuery.isNotEmpty
                                              ? GestureDetector(
                                                  onTap: () {
                                                    _spaceSearchController.clear();
                                                    setState(() => _spaceSearchQuery = '');
                                                    FocusScope.of(context).unfocus();
                                                  },
                                                  child: const Icon(Icons.close, color: Color(0x4DFFFFFF), size: 16),
                                                )
                                              : null,
                                        ),
                                        onChanged: (v) => setState(() => _spaceSearchQuery = v),
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
                                        border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
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
                          // Category filter pills
                          SizedBox(
                            height: 52,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              physics: const BouncingScrollPhysics(),
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemCount: _sortedCategoryPills().length,
                              itemBuilder: (_, i) {
                                final pills = _sortedCategoryPills();
                                final label = pills[i];
                                final isActive = _selectedCategory == label;
                                return GestureDetector(
                                  onTap: () => _onCategoryPillTapped(label),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.white : const Color(0x0AFFFFFF),
                                      borderRadius: BorderRadius.circular(99),
                                      border: isActive
                                          ? null
                                          : Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: isActive ? Colors.black : const Color(0x73FFFFFF),
                                        fontSize: 13,
                                        fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Empty state or items list
              if (_items.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_box_outlined, color: Color(0x4DFFFFFF), size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'This space is empty',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add your first item to save this space.',
                          style: TextStyle(color: Color(0x73FFFFFF), fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () => _addItem(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'Add Item',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: _buildGroupedList(),
                ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'fab_location',
          onPressed: _addItem,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _InventoryPageState extends State<InventoryPage> with WidgetsBindingObserver {
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
  bool _joinedLoading = false;
  List<Map<String, dynamic>> _myShares = [];

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
    unawaited(Future.wait([_loadItems(), _loadMyShares(), _loadJoinedShares()]));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(Future.wait([_loadItems(), _loadMyShares(), _loadJoinedShares()]));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_items.isEmpty && !_loading) {
      unawaited(Future.wait([_loadItems(), _loadMyShares(), _loadJoinedShares()]));
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

  int _lowStockCountForItems(List<InventoryItem> items, Map<String, int> thresholds) {
    var n = 0;
    for (final it in items) {
      final thr = thresholds[it.itemId];
      if ((thr != null && thr > 0 && it.quantity <= thr) || it.quantity <= 0) n++;
    }
    return n;
  }

  Future<void> _openLocation({required String location, required Map<String, int> thresholds}) async {
    if (!mounted) return;
    final loc = location.trim().isEmpty ? 'Unsorted' : location.trim();

    // If this space has an active share owned by the current user, open the
    // full workspace view instead of the simple location detail view.
    Map<String, dynamic>? matchedShare;
    for (final s in _myShares) {
      if ((s['share_name'] ?? '').toString().trim().toLowerCase() == loc.toLowerCase()) {
        matchedShare = s;
        break;
      }
    }
    if (matchedShare != null) {
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

    final source = _baseItemsForSelectedCategory();
    final items = source.where((it) {
      final l = it.location.trim().isEmpty ? 'Unsorted' : it.location.trim();
      return l.toLowerCase() == loc.toLowerCase();
    }).toList();

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _LocationItemsPage(
          api: widget.api,
          location: loc,
          items: items,
          thresholds: thresholds,
          allItems: _items,
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

  int _lowStockCount() {
    var n = 0;
    for (final it in _items) {
      final thr = _thresholds.value[it.itemId];
      if ((thr != null && thr > 0 && it.quantity <= thr) || it.quantity <= 0) n++;
    }
    return n;
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    final t0 = DateTime.now().millisecondsSinceEpoch;
    debugPrint('[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems start');
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      debugPrint('[Inventory][${DateTime.now().millisecondsSinceEpoch}] calling searchItems...');
      final result = await widget.api.searchItems(query: '').timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('searchItems timed out after 20s'),
      );
      debugPrint('[Inventory][${DateTime.now().millisecondsSinceEpoch}] searchItems returned ${result.items.length} items (${DateTime.now().millisecondsSinceEpoch - t0}ms)');
      if (!mounted) return;
      setState(() {
        _items = result.items;
      });
      LowStockPrefs.loadAll().then((value) {
        if (!mounted) return;
        _thresholds.value = value;
      });
      _applyLocalSearch(_query.value);
    } on SessionExpiredException {
      debugPrint('[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems: SessionExpiredException');
      if (!mounted) return;
      setState(() => _error = 'Session expired. Please sign in again.');
    } on TimeoutException catch (e) {
      debugPrint('[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems: TimeoutException: $e');
      if (!mounted) return;
      setState(() => _error = 'connection');
    } on dio.DioException catch (e) {
      debugPrint('[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems: DioException: ${e.response?.statusCode}');
      if (!mounted) return;
      if (e.response?.statusCode == 429) {
        setState(() => _loading = false);
        return;
      }
      setState(() => _error = 'connection');
    } catch (e) {
      debugPrint('[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems: catch: $e');
      if (!mounted) return;
      setState(() => _error = 'connection');
    } finally {
      debugPrint('[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadItems finally (total ${DateTime.now().millisecondsSinceEpoch - t0}ms)');
      if (mounted) setState(() => _loading = false);
    }
  }


  Future<void> _loadJoinedShares() async {
    if (!mounted) return;
    debugPrint('[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadJoinedShares start');
    setState(() => _joinedLoading = true);
    try {
      final shares = await widget.api.getJoinedShares();
      debugPrint('[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadJoinedShares returned ${shares.length} shares');
      if (!mounted) return;
      final cast = shares.cast<Map<String, dynamic>>();
      setState(() => _joinedShares = cast);
    } catch (e) {
      debugPrint('[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadJoinedShares error: $e');
      if (mounted) setState(() => _joinedLoading = false);
    } finally {
      if (mounted) setState(() => _joinedLoading = false);
    }
  }

  Future<void> _loadMyShares() async {
    debugPrint('[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadMyShares start');
    try {
      final shares = await widget.api.getMyShares();
      debugPrint('[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadMyShares returned ${shares.length} shares');
      if (!mounted) return;
      setState(() => _myShares = shares.cast<Map<String, dynamic>>());
    } catch (e) {
      debugPrint('[Inventory][${DateTime.now().millisecondsSinceEpoch}] _loadMyShares error: $e');
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

  Future<void> _addItem() async {
    final created = await showModalBottomSheet<ItemEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => ItemEditorSheet(
        availableLocations: {
          ..._items.map((i) => i.location.trim().isEmpty ? 'Unsorted' : i.location.trim()),
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
      ).showSnackBar(const SnackBar(content: Text('Item added')));
      await _loadItems();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      debugPrint('FINDEZ addItem error: ${e.response?.statusCode} | ${e.response?.data} | ${e.message}');
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
            const SnackBar(content: Text('Something went wrong. Please try again.')),
          );
        }
        return;
      }
      if (e.response?.statusCode == 403) {
        // Any 403 = free tier limit or auth issue → show upgrade
        if (!ProStatus.isPro) {
          showUpgradeSheet(
            context,
            widget.api,
            reason: 'Upgrade to Pro for unlimited items, spaces and AI scans.',
          );
        } else {
          debugPrint('FINDEZ: Pro user got 403 — backend bug');
          unawaited(ProStatus.refresh(widget.api));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Something went wrong. Please try again.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection issue. Please try again.')),
        );
      }
    }
  }

  void _showUpgradePrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface2(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Color(0xFFF59E0B), size: 32),
              const SizedBox(height: 12),
              const Text('You\'ve reached your free limit', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Upgrade to FindEZ Pro for unlimited items, spaces, and AI scans.', style: TextStyle(color: Color(0x73FFFFFF), fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(99)),
                  child: const Text('Upgrade to Pro', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: const Text('Maybe later', style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editItem(InventoryItem item) async {
    final currentThreshold = _thresholds.value[item.itemId];
    final updates = await showModalBottomSheet<ItemEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) =>
          ItemEditorSheet(item: item, initialThreshold: currentThreshold),
    );
    if (updates == null) return;

    try {
      await widget.api.updateItem(request: updates.update);
      await LowStockPrefs.setThreshold(
        itemId: item.itemId,
        threshold: updates.threshold,
      );
      final next = Map<String, int>.from(_thresholds.value);
      if (updates.threshold == null || updates.threshold! <= 0) {
        next.remove(item.itemId);
      } else {
        next[item.itemId] = updates.threshold!;
      }
      _thresholds.value = next;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved')));
      await _loadItems();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 429) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection issue. Please try again.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection issue. Please try again.')),
        );
      }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted')));
      await _loadItems();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 429) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection issue. Please try again.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection issue. Please try again.')),
        );
      }
    }
  }

  IconData _spaceIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('garage') || n.contains('shop') || n.contains('workshop')) return Icons.garage_outlined;
    if (n.contains('robot') || n.contains('bot')) return Icons.precision_manufacturing_outlined;
    if (n.contains('electric') || n.contains('elec') || n.contains('wire') || n.contains('battery')) return Icons.electrical_services_outlined;
    if (n.contains('motor') || n.contains('drive')) return Icons.settings_outlined;
    if (n.contains('tool')) return Icons.build_outlined;
    if (n.contains('screw') || n.contains('bolt') || n.contains('fastener') || n.contains('hardware')) return Icons.hardware_outlined;
    if (n.contains('kit') || n.contains('box') || n.contains('bin') || n.contains('storage')) return Icons.inventory_2_outlined;
    if (n.contains('med') || n.contains('health')) return Icons.medical_services_outlined;
    if (n.contains('office') || n.contains('desk')) return Icons.desk_outlined;
    if (n.contains('sensor') || n.contains('camera')) return Icons.sensors_outlined;
    if (n.contains('pneumatic') || n.contains('air')) return Icons.air_outlined;
    if (n.contains('pit') || n.contains('competition') || n.contains('comp')) return Icons.emoji_events_outlined;
    if (n.contains('unsorted') || n.contains('misc')) return Icons.category_outlined;
    return Icons.folder_outlined;
  }

  Color _spaceColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('garage') || n.contains('shop') || n.contains('workshop')) return const Color(0xFFFF9F0A);
    if (n.contains('robot') || n.contains('bot')) return const Color(0xFF0A84FF);
    if (n.contains('electric') || n.contains('elec') || n.contains('wire') || n.contains('battery')) return const Color(0xFFFFD60A);
    if (n.contains('motor') || n.contains('drive')) return const Color(0xFF5E5CE6);
    if (n.contains('tool')) return const Color(0xFFFF6B35);
    if (n.contains('screw') || n.contains('bolt') || n.contains('fastener') || n.contains('hardware')) return const Color(0xFF636366);
    if (n.contains('kit') || n.contains('box') || n.contains('bin') || n.contains('storage')) return const Color(0xFF30D158);
    if (n.contains('med') || n.contains('health')) return const Color(0xFFFF375F);
    if (n.contains('office') || n.contains('desk')) return const Color(0xFF32ADE6);
    if (n.contains('sensor') || n.contains('camera')) return const Color(0xFFBF5AF2);
    if (n.contains('pneumatic') || n.contains('air')) return const Color(0xFF5AC8F5);
    if (n.contains('pit') || n.contains('competition') || n.contains('comp')) return const Color(0xFFFFD60A);
    if (n.contains('unsorted') || n.contains('misc')) return const Color(0xFF636366);
    const colors = [
      Color(0xFF0A84FF),
      Color(0xFF5E5CE6),
      Color(0xFFBF5AF2),
      Color(0xFFFF375F),
      Color(0xFFFF9F0A),
      Color(0xFF30D158),
      Color(0xFF32ADE6),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_outlined, color: Color(0x4DFFFFFF), size: 48),
          const SizedBox(height: 16),
          const Text('Could not load inventory', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Pull down to retry', style: TextStyle(color: Color(0x73FFFFFF), fontSize: 13)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _loadItems,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0x0AFFFFFF),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0x14FFFFFF)),
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpacesGrid(Map<String, int> thresholds) {
    final groups = _groupByLocation(_baseItemsForSelectedCategory());
    // Union: item locations + names of spaces the user has created a share for
    final ownedShareNames = _myShares
        .map((s) => (s['share_name'] ?? '').toString().trim())
        .where((n) => n.isNotEmpty)
        .toSet();
    final allSpaces = {...groups.keys, ...ownedShareNames}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
        if (index == allSpaces.length) {
          return GestureDetector(
            onTap: () => _createSpace(context),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x14FFFFFF)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Color(0x4DFFFFFF), size: 28),
                  SizedBox(height: 8),
                  Text('New Space', style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 14)),
                ],
              ),
            ),
          );
        }
        final loc = allSpaces[index];
        final items = groups[loc] ?? const <InventoryItem>[];
        final lowStock = items.where((it) => it.quantity <= 1).length;
        return GestureDetector(
          onTap: () => unawaited(_openLocation(location: loc, thresholds: thresholds)),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x0DFFFFFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: lowStock > 0
                    ? const Color(0x33FBBF24)
                    : _spaceColor(loc).withOpacity(0.15),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _spaceColor(loc).withOpacity(lowStock > 0 ? 0.08 : 0.04),
                            Colors.transparent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _spaceColor(loc).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _spaceIcon(loc),
                                color: _spaceColor(loc),
                                size: 18,
                              ),
                            ),
                            const Spacer(),
                            if (lowStock > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0x1AFBBF24),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$lowStock low',
                                  style: const TextStyle(
                                    color: Color(0xFFFBBF24),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          loc,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                          style: const TextStyle(
                            color: Color(0x60FFFFFF),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => DraggableScrollableSheet(
                                  initialChildSize: 0.65,
                                  maxChildSize: 0.92,
                                  minChildSize: 0.4,
                                  builder: (_, __) => ShareSpaceSheet(
                                    spaceName: loc,
                                    api: widget.api,
                                  ),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0x0AFFFFFF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.share_outlined, color: Color(0x60FFFFFF), size: 14),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _showSpaceMenu(context, loc, items),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0x0AFFFFFF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.more_horiz, color: Color(0x60FFFFFF), size: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
              childCount: allSpaces.length + 1,
            ),
          ),
        ),
        if (_joinedShares.isNotEmpty) ...<Widget>[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'JOINED SPACES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0x4DFFFFFF),
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final share = _joinedShares[i];
                final ts = (share['team_shares'] as Map<String, dynamic>?) ?? {};
                final name = (ts['share_name'] ?? 'Shared Space') as String;
                final permission = (ts['permission'] ?? 'view') as String;
                final shareId = (ts['share_id'] ?? share['share_id']) as String?;
                return GestureDetector(
                  onTap: () => unawaited(_openSharedSpace(share)),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0x0AFFFFFF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x14FFFFFF)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      permission == 'edit' ? 'Can edit' : 'View only',
                                      style: const TextStyle(
                                        color: Color(0x73FFFFFF),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Color(0x4DFFFFFF),
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0x33F59E0B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Shared',
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: _joinedShares.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ],
    );
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
            onPressed: () => Navigator.pop(context, _createSpaceCtrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (!mounted) return;
    await _openLocation(location: name, thresholds: _thresholds.value);
  }

  Future<void> _joinSpaceDialog(BuildContext context) async {
    _joinCodeCtrl.clear();
    String? error;
    await showDialog(
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
                    await _loadItems();
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

  Future<void> _showSpaceMenu(
    BuildContext context,
    String loc,
    List<InventoryItem> items,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.white),
              title: const Text('Rename', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFFF453A)),
              title: const Text('Delete Space', style: TextStyle(color: Color(0xFFFF453A))),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'rename' && mounted) await _renameSpace(context, loc, items);
    if (action == 'delete' && mounted) await _deleteSpace(context, loc, items);
  }

  Future<void> _renameSpace(
    BuildContext context,
    String oldName,
    List<InventoryItem> items,
  ) async {
    _renameSpaceCtrl.text = oldName;
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface2(context),
        title: const Text('Rename Space', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _renameSpaceCtrl,
          autofocus: true,
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
            onPressed: () => Navigator.pop(context, _renameSpaceCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;
    for (final item in items) {
      try {
        await widget.api.updateItem(
          request: UpdateItemRequest(itemId: item.itemId, location: newName),
        );
      } catch (_) {}
    }
    if (mounted) await _loadItems();
  }

  Future<void> _deleteSpace(
    BuildContext context,
    String loc,
    List<InventoryItem> items,
  ) async {
    if (items.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.surface2(context),
          title: const Text('Delete Space?', style: TextStyle(color: Colors.white)),
          content: Text(
            'This will delete all ${items.length} item(s) in "$loc".',
            style: const TextStyle(color: Color(0x73FFFFFF)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Color(0xFFFF453A))),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      for (final item in items) {
        try { await widget.api.deleteItem(itemId: item.itemId); } catch (_) {}
      }
    }
    if (mounted) await _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'My Inventory',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_outlined, color: Colors.white70, size: 22),
                if (_lowStockCount() > 0)
                  Positioned(
                    top: -4, right: -4,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${_lowStockCount() > 9 ? '9+' : _lowStockCount()}',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ShoppingListPage(api: widget.api)),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70, size: 22),
            color: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (value) {
              if (value == 'checkout') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutPage(api: widget.api)));
              } else if (value == 'join') {
                _joinSpaceDialog(context);
              } else if (value == 'refresh') {
                _loadItems();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'checkout',
                child: Row(children: [
                  Icon(Icons.swap_horiz_outlined, color: Colors.white70, size: 18),
                  SizedBox(width: 12),
                  Text('Check-Out Tracker', style: TextStyle(color: Colors.white, fontSize: 14)),
                ]),
              ),
              const PopupMenuItem(
                value: 'join',
                child: Row(children: [
                  Icon(Icons.person_add_outlined, color: Colors.white70, size: 18),
                  SizedBox(width: 12),
                  Text('Join a Space', style: TextStyle(color: Colors.white, fontSize: 14)),
                ]),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(children: [
                  Icon(Icons.refresh_outlined, color: Colors.white70, size: 18),
                  SizedBox(width: 12),
                  Text('Refresh', style: TextStyle(color: Colors.white, fontSize: 14)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _search,
                onChanged: _applyLocalSearch,
                decoration: const InputDecoration(
                  hintText: 'Search your stuff…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              if (_lowStockCount() > 0)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ShoppingListPage(api: widget.api)),
                  ),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x0AEF4444),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x33EF4444)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_cart_outlined, color: Color(0xFFEF4444), size: 16),
                        const SizedBox(width: 10),
                        Text(
                          '${_lowStockCount()} items need restocking',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'View list →',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: _loading && _items.isEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            itemCount: 8,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) =>
                                const SkeletonListTile(),
                          ),
                        ),
                      ),
                    )
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
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          if (searching)
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                                              child: Text(
                                                'Searching…',
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: Colors.white.withValues(alpha: 0.55),
                                                ),
                                              ),
                                            ),
                                          Expanded(
                                            child: ValueListenableBuilder<List<InventoryItem>>(
                                              valueListenable: _rows,
                                              builder: (context, rows, _) {
                                                if (rows.isEmpty) {
                                                  return Center(
                                                    child: Text(
                                                      'No results.',
                                                      style: TextStyle(
                                                        color: Colors.white.withValues(alpha: 0.65),
                                                      ),
                                                    ),
                                                  );
                                                }

                                                return _SearchResultsList(
                                                  rows: rows,
                                                  thresholds: thresholds,
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'fab_inventory',
            onPressed: _addItem,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.rows,
    required this.thresholds,
    required this.onEdit,
    required this.onDelete,
  });

  final List<InventoryItem> rows;
  final Map<String, int> thresholds;
  final Future<void> Function(InventoryItem item) onEdit;
  final Future<void> Function(InventoryItem item) onDelete;

  @override
  Widget build(BuildContext context) {
    final hasImages = rows.any((e) => (e.imageUrl ?? '').trim().isNotEmpty);
    if (!hasImages) {
      return ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = rows[index];
          final threshold = thresholds[item.itemId];
          final isLow = (threshold != null && threshold > 0 && item.quantity <= threshold);
          return Dismissible(
            key: ValueKey(item.itemId),
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 16),
              color: AppColors.swipe,
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              title: Text(item.name),
              subtitle: Text(
                '${item.category} · ${item.location}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.60)),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLow) ...[
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.70),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'Qty ${item.quantity}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                  ),
                ],
              ),
              onTap: () => onEdit(item),
            ),
          );
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.98,
      ),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final item = rows[index];
        final threshold = thresholds[item.itemId];
        final isLow = (threshold != null && threshold > 0 && item.quantity <= threshold);
        return _ItemGridCard(
          item: item,
          isLow: isLow,
          onEdit: () => onEdit(item),
          onDelete: () => onDelete(item),
        );
      },
    );
  }
}

class _ItemGridCard extends StatelessWidget {
  const _ItemGridCard({
    required this.item,
    required this.isLow,
    required this.onEdit,
    required this.onDelete,
  });

  final InventoryItem item;
  final bool isLow;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final url = (item.imageUrl ?? '').trim();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onEdit,
      onLongPress: onDelete,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: url.isEmpty
                        ? Container(
                            color: Colors.white.withValues(alpha: 0.04),
                            child: Icon(
                              Icons.image_outlined,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          )
                        : Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.white.withValues(alpha: 0.04),
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    'Qty ${item.quantity}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                  ),
                ),
              ),
              if (isLow)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.92),
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

// ─── Pinned header delegate for search + pills ───────────────────────────────

class _SearchPinDelegate extends SliverPersistentHeaderDelegate {
  const _SearchPinDelegate({required this.child, this.height = 100});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  bool shouldRebuild(_SearchPinDelegate old) =>
      old.child != child || old.height != height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      child;
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

// ─── Review extracted items before saving ────────────────────────────────────

class _ReviewExtractedSheet extends StatefulWidget {
  const _ReviewExtractedSheet({
    required this.items,
    required this.spaceName,
  });

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
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
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
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Review ${_items.length} extracted item${_items.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Location: ${widget.spaceName}',
              style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 13),
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
              separatorBuilder: (_, __) =>
                  const Divider(color: Color(0x14FFFFFF), height: 1),
              itemBuilder: (_, i) {
                final it = _items[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          it.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          it.category,
                          style: const TextStyle(
                            color: Color(0x73FFFFFF),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '×${it.quantity}',
                        style: const TextStyle(
                          color: Color(0x73FFFFFF),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _items.removeAt(i)),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Color(0x4DFFFFFF),
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
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0x73FFFFFF)),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text('Save All (${_items.length})'),
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
        hintStyle: const TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
        filled: true,
        fillColor: const Color(0x0AFFFFFF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x14FFFFFF), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x14FFFFFF), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x40FFFFFF), width: 0.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
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
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add Scanned Item',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _inputDec('Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _category,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _inputDec('Category'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _inputDec('Quantity'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _location,
            readOnly: true,
            style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 15),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0x73FFFFFF),
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
