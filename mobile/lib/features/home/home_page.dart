import '../../core/app_theme.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/inventory_cache.dart';
import '../../core/low_stock_prefs.dart';
import '../inventory/item_detail_sheet.dart';
import 'home_overview.dart';
import 'package:mobile/core/ui/app_text.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    required this.onOpenAsk,
    required this.onOpenReview,
    required this.onOpenCheckouts,
    required this.onOpenSpace,
    this.refreshToken = 0,
  });
  final ApiClient api;
  final ValueChanged<String> onOpenAsk;
  final VoidCallback onOpenReview, onOpenCheckouts;
  final Future<void> Function(Map<String, dynamic>) onOpenSpace;
  final int refreshToken;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<InventoryItem> _items = const [];
  List<Map<String, dynamic>> _spaces = const [];
  Map<String, int>? _thresholds;
  List<Map<String, dynamic>>? _checkouts;
  int? _pendingReviews;
  bool _inventoryAvailable = false;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _items = InventoryCache.items;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (!mounted) return;
    setState(() => _error = null);
    var failed = false;
    Future<T?> read<T>(Future<T> request) async {
      try {
        return await request;
      } catch (_) {
        failed = true;
        return null;
      }
    }

    final results = await Future.wait<Object?>([
      read(widget.api.searchItems(query: '')),
      read(widget.api.listSpaces()),
      read(widget.api.getReviewItems(limit: 1)),
      read(widget.api.getActiveCheckouts()),
      read(LowStockPrefs.loadAll()),
    ]);
    if (!mounted || generation != _loadGeneration) return;
    final inventory = results[0] as SearchItemsResult?;
    if (inventory != null) InventoryCache.setItems(inventory.items);
    setState(() {
      _items = inventory?.items ?? _items;
      if (inventory != null) _inventoryAvailable = true;
      _spaces = results[1] as List<Map<String, dynamic>>? ?? _spaces;
      _pendingReviews =
          (results[2] as ReviewQueueResult?)?.pendingCount ?? _pendingReviews;
      _checkouts = results[3] as List<Map<String, dynamic>>? ?? _checkouts;
      _thresholds = results[4] as Map<String, int>? ?? _thresholds;
      _error = failed
          ? 'Some details could not refresh. Pull down to try again.'
          : null;
    });
  }

  List<InventoryItem> get _lowStock => _items.where((item) {
    final threshold = _thresholds?[item.itemId];
    return threshold != null &&
        threshold > 0 &&
        item.quantity > 0 &&
        item.quantity <= threshold;
  }).toList();
  List<InventoryItem> get _outOfStock =>
      _items.where((item) => item.quantity <= 0).toList();
  int? get _lentOutCount {
    if (_checkouts == null || !_inventoryAvailable) return null;
    final ownedIds = _items.map((item) => item.itemId).toSet();
    return _checkouts!
        .where((checkout) => ownedIds.contains(checkout['item_id']))
        .map((checkout) => checkout['item_id'])
        .toSet()
        .length;
  }

  Future<void> _openItem(InventoryItem item) async {
    await showItemDetailSheet(
      context,
      api: widget.api,
      item: item,
      spaceName: item.location,
      initialThreshold: _thresholds?[item.itemId],
    );
    if (mounted) unawaited(_load());
  }

  Future<void> _openAttention(String title, List<InventoryItem> items) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _AttentionItemsPage(
          title: title,
          api: widget.api,
          items: items,
          thresholds: _thresholds ?? const {},
        ),
      ),
    );
    if (mounted) unawaited(_load());
  }

  Future<void> _chooseSpace() async {
    final space = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.adaptive(context, HomeColors.surface),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: AppText(
                'Spaces',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final space in _spaces)
                    ListTile(
                      title: AppText((space['name'] ?? '').toString()),
                      onTap: () => Navigator.pop(context, space),
                    ),
                  if (_spaces.isEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: AppText(
                        'No Spaces yet',
                        style: TextStyle(
                          color: AppTheme.foreground(
                            context,
                            HomeColors.secondary,
                          ),
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
    if (space != null && mounted) await widget.onOpenSpace(space);
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: HomeOverview(
      items: _items,
      spaces: _spaces,
      pendingReviews: _pendingReviews,
      lowStock: _thresholds == null || !_inventoryAvailable
          ? null
          : _lowStock.length,
      outOfStock: !_inventoryAvailable ? null : _outOfStock.length,
      lentOut: _lentOutCount,
      error: _error,
      onAsk: widget.onOpenAsk,
      onChooseSpace: _chooseSpace,
      onOpenReview: widget.onOpenReview,
      onOpenLowStock: () => _openAttention('Running low', _lowStock),
      onOpenOutOfStock: () => _openAttention('Out of stock', _outOfStock),
      onOpenCheckouts: widget.onOpenCheckouts,
      onOpenItem: _openItem,
      onOpenSpace: widget.onOpenSpace,
    ),
  );
}

class _AttentionItemsPage extends StatefulWidget {
  const _AttentionItemsPage({
    required this.title,
    required this.api,
    required this.items,
    required this.thresholds,
  });
  final String title;
  final ApiClient api;
  final List<InventoryItem> items;
  final Map<String, int> thresholds;
  @override
  State<_AttentionItemsPage> createState() => _AttentionItemsPageState();
}

class _AttentionItemsPageState extends State<_AttentionItemsPage> {
  late final List<InventoryItem> _items = List.of(widget.items);
  late final Map<String, int> _thresholds = Map.of(widget.thresholds);
  bool _matches(InventoryItem item) => widget.title == 'Out of stock'
      ? item.quantity <= 0
      : item.quantity > 0 && item.quantity <= (_thresholds[item.itemId] ?? 0);
  void _updateItem(InventoryItem updated) {
    if (!mounted) return;
    setState(() {
      final index = _items.indexWhere((item) => item.itemId == updated.itemId);
      if (index < 0) return;
      if (_matches(updated)) {
        _items[index] = updated;
      } else {
        _items.removeAt(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.adaptive(context, HomeColors.background),
    appBar: AppBar(title: AppText(widget.title)),
    body: _items.isEmpty
        ? Center(
            child: AppText(
              'No items',
              style: TextStyle(
                color: AppTheme.foreground(context, HomeColors.secondary),
              ),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return ListTile(
                leading: (item.imageUrl ?? '').trim().isEmpty
                    ? null
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.imageUrl!,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                title: AppText(item.displayName),
                subtitle: AppText(item.location),
                trailing: AppText('${item.quantity}'),
                onTap: () => showItemDetailSheet(
                  context,
                  item: item,
                  api: widget.api,
                  spaceName: item.location,
                  initialThreshold: _thresholds[item.itemId],
                  onItemUpdated: _updateItem,
                  onThresholdChanged: (threshold) {
                    if (threshold == null) {
                      _thresholds.remove(item.itemId);
                    } else {
                      _thresholds[item.itemId] = threshold;
                    }
                    final current = _items.where(
                      (entry) => entry.itemId == item.itemId,
                    );
                    if (current.isNotEmpty) _updateItem(current.first);
                  },
                ),
              );
            },
          ),
  );
}
