import 'dart:async';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/account_preferences.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/low_stock_prefs.dart';
import '../../core/pro_status.dart';
import '../../core/upgrade_sheet.dart';
import '../inventory/item_detail_sheet.dart';
import '../inventory/world_views.dart';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({required this.api, super.key});
  final ApiClient api;

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  static const _checkedKey = 'shopping_list_checked';
  List<InventoryItem> _items = const [];
  Map<String, int> _thresholds = const {};
  final Set<String> _ordered = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadOrdered());
  }

  Future<void> _loadOrdered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(accountPreferenceKey(_checkedKey));
      if (!mounted) return;
      setState(() => _ordered.addAll(saved ?? const []));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  Future<void> _toggleOrdered(InventoryItem item) async {
    final before = Set<String>.from(_ordered);
    setState(() {
      if (!_ordered.add(item.itemId)) _ordered.remove(item.itemId);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setStringList(
        accountPreferenceKey(_checkedKey),
        _ordered.toList(),
      );
      if (!saved) throw StateError('Could not save the shopping list.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ordered
          ..clear()
          ..addAll(before);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.searchItems(query: '');
      final thresholds = await LowStockPrefs.loadAll(widget.api);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _thresholds = thresholds;
      });
    } on dio.DioException catch (error) {
      if (!mounted) return;
      if (error.response?.statusCode == 429 && !ProStatus.isPro) {
        showUpgradeSheet(
          context,
          widget.api,
          reason: 'You have reached the free limit.',
        );
      }
      setState(() => _error = describeError(error).$1);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeError(error).$1);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _point(InventoryItem item) =>
      _thresholds[item.itemId] ?? item.reorderPoint;

  bool _needsRestock(InventoryItem item) {
    final point = _point(item);
    return item.quantity <= 0 ||
        (point != null && point > 0 && item.quantity < point);
  }

  int _shortfall(InventoryItem item) {
    final point = _point(item);
    if (point == null || point <= 0) return 1;
    return (point - item.quantity).clamp(1, 999);
  }

  Future<void> _copyList(List<InventoryItem> needed) async {
    final text = needed
        .map(
          (item) =>
              '${_shortfall(item)} × ${item.displayName}  ·  ${item.location}',
        )
        .join('\n');
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Shopping list copied.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  Future<void> _actions(InventoryItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Open object'),
              onTap: () => Navigator.pop(context, 'open'),
            ),
            if (_needsRestock(item))
              ListTile(
                title: Text(
                  _ordered.contains(item.itemId)
                      ? 'Move back to shopping list'
                      : 'Mark as ordered',
                ),
                onTap: () => Navigator.pop(context, 'ordered'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'ordered') {
      await _toggleOrdered(item);
      return;
    }
    if (action == 'open') {
      showItemDetailSheet(context, item: item, api: widget.api);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final needed = _items
        .where((item) => _needsRestock(item) && !_ordered.contains(item.itemId))
        .toList();
    final ordered = _items
        .where((item) => _needsRestock(item) && _ordered.contains(item.itemId))
        .toList();
    final stocked = _items.where((item) => !_needsRestock(item)).toList();
    needed.sort((a, b) => a.quantity.compareTo(b.quantity));
    final rows = <(String?, InventoryItem?)>[
      if (needed.isNotEmpty) (null, null),
      for (final item in needed) ('needed', item),
      if (ordered.isNotEmpty) ('ordered-header', null),
      for (final item in ordered) ('ordered', item),
      if (stocked.isNotEmpty) ('stocked-header', null),
      for (final item in stocked) ('stocked', item),
    ];
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            WorldHeader(
              title: 'Supplies',
              onBack: () => Navigator.pop(context),
              actions: [
                if (needed.isNotEmpty)
                  TextButton(
                    onPressed: () => _copyList(needed),
                    child: const Text('Copy list'),
                  ),
              ],
            ),
            if (!_loading && _error == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${needed.length} need restocking',
                    style: TextStyle(
                      color: t.warn,
                      fontSize: 15,
                      fontFamily: 'IBMPlexMono',
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: TextStyle(color: t.text2)),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _items.isEmpty
                          ? ListView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'No objects yet. Capture something to track supplies.',
                                    style: TextStyle(
                                      color: t.text2,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                100,
                              ),
                              itemCount: rows.length,
                              itemBuilder: (context, index) {
                                final row = rows[index];
                                if (row.$2 == null) {
                                  final title = row.$1 == 'ordered-header'
                                      ? 'Ordered'
                                      : row.$1 == 'stocked-header'
                                      ? 'Stocked'
                                      : 'Need restocking';
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      0,
                                      18,
                                      0,
                                      8,
                                    ),
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        color: t.text2,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                }
                                final item = row.$2!;
                                final point = _point(item);
                                final subtitle = row.$1 == 'ordered'
                                    ? 'Ordered  ·  ${item.location}'
                                    : point != null && point > 0
                                    ? '${item.location}  ·  reorder below $point'
                                    : '${item.location}  ·  no reorder point';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 1),
                                  child: Material(
                                    color: t.card,
                                    child: WorldRow(
                                      title: item.displayName,
                                      subtitle: subtitle,
                                      count: '${item.quantity}',
                                      warning: row.$1 == 'needed',
                                      onTap: () => showItemDetailSheet(
                                        context,
                                        item: item,
                                        api: widget.api,
                                      ),
                                      onLongPress: () => _actions(item),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
