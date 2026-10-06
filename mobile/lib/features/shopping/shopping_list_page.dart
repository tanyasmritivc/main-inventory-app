import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/inventory_cache.dart';
import '../../core/restock_plan.dart';
import '../../core/ui/app_text.dart';
import '../../core/ui/restock_status.dart';

/// Retains the existing destination while replacing disconnected checkmarks.
class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({
    required this.api,
    super.key,
    this.shareId,
    this.spaceName,
    this.canEditStock = true,
    this.embedded = false,
    this.onChanged,
  });
  final ApiClient api;
  final String? shareId, spaceName;
  final bool canEditStock, embedded;
  final VoidCallback? onChanged;
  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  late final String _account;
  RestockPlan _plan = const RestockPlan({});
  List<InventoryItem> _items = const [];
  bool _loading = true, _busy = false;
  String? _error;
  int _generation = 0;
  final Map<String, int> _buyDrafts = {},
      _orderDrafts = {},
      _receiptDrafts = {};
  bool get _current => mounted && RestockPrefs.accountKey == _account;

  @override
  void initState() {
    super.initState();
    _account = RestockPrefs.accountKey;
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (!_current) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final inventory = widget.shareId != null
          ? (await widget.api.getShareInventory(widget.shareId!))
                .whereType<Map<String, dynamic>>()
                .map(InventoryItem.fromJson)
                .toList()
          : (await widget.api.searchItems(query: '')).items;
      final plan = await RestockPrefs.load();
      if (!_current || generation != _generation) return;
      setState(() {
        _items = inventory;
        _plan = plan;
      });
    } catch (error) {
      if (_current && generation == _generation) {
        setState(
          () => _error = friendlyApiError(
            error,
            fallback: 'Could not refresh the restock planner. Try again.',
          ),
        );
      }
    } finally {
      if (_current && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool> _save(Future<void> Function() write) async {
    if (!_current || _busy) return false;
    setState(() => _busy = true);
    try {
      await write();
      if (!_current) return false;
      final plan = await RestockPrefs.load();
      if (!_current) return false;
      setState(() => _plan = plan);
      widget.onChanged?.call();
      return true;
    } catch (_) {
      if (_current) _notice('Could not save this change. Please try again.');
      return false;
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: AppText(message)));
  Future<void> _order(InventoryItem item) async {
    final entry = _plan.entry(item.itemId);
    final quantity = await _askCount(
      title: 'Mark as ordered',
      description: item.displayName,
      label: 'Quantity ordered',
      initial:
          _orderDrafts[item.itemId] ??
          entry.orderQuantity ??
          entry.quantityToBuy(item.quantity),
      minimum: 1,
      action: 'Save order',
    );
    if (quantity == null || !_current) return;
    _orderDrafts[item.itemId] = quantity;
    if (await _save(
      () => RestockPrefs.order(item.itemId, quantity, account: _account),
    )) {
      _orderDrafts.remove(item.itemId);
    }
  }

  Future<void> _editBuy(InventoryItem item) async {
    final quantity = await _askCount(
      title: 'Plan a purchase',
      description: item.displayName,
      label: 'Quantity to buy',
      initial:
          _buyDrafts[item.itemId] ??
          _plan.entry(item.itemId).quantityToBuy(item.quantity),
      minimum: 1,
      action: 'Save',
    );
    if (quantity == null || !_current) return;
    _buyDrafts[item.itemId] = quantity;
    if (await _save(
      () => RestockPrefs.planPurchase(item.itemId, quantity, account: _account),
    )) {
      _buyDrafts.remove(item.itemId);
    }
  }

  Future<void> _receive(InventoryItem item) async {
    if (!widget.canEditStock || _busy || !_current) return;
    final entry = _plan.entry(item.itemId);
    final total = await _askCount(
      title: 'Record arrival',
      description:
          '${item.displayName}\n${item.quantity} on hand${entry.orderQuantity == null ? '' : ' | ${entry.orderQuantity} ordered'}\nInclude the delivery in your count.',
      label: 'Total now on hand',
      initial: _receiptDrafts[item.itemId] ?? entry.receiptTotal,
      minimum: 0,
      action: 'Save stock count',
    );
    if (total == null || !_current) return;
    setState(() => _busy = true);
    _receiptDrafts[item.itemId] = total;
    var stockSaved = false;
    try {
      // Persist an absolute count first. A lost response retains the same count
      // for explicit retry rather than blindly adding a delivery again.
      await RestockPrefs.prepareReceipt(item.itemId, total, account: _account);
      if (!_current) return;
      final request = UpdateItemRequest(itemId: item.itemId, quantity: total);
      final updated = widget.shareId != null
          ? await widget.api.updateSharedItem(
              shareId: widget.shareId!,
              request: request,
            )
          : await widget.api.updateItem(request: request);
      if (updated.itemId != item.itemId || updated.quantity != total) {
        throw StateError('Stock was not confirmed');
      }
      stockSaved = true;
      if (!_current) return;
      if (widget.shareId == null && widget.api.teamId == null) {
        InventoryCache.updateItem(updated);
      }
      await RestockPrefs.finishReceipt(item.itemId, account: _account);
      if (!_current) return;
      _receiptDrafts.remove(item.itemId);
      _notice('Stock saved: ${updated.quantity} on hand.');
      widget.onChanged?.call();
      await _load();
    } catch (_) {
      if (_current) {
        _notice(
          stockSaved
              ? 'Stock was saved, but the planner could not finish. Reopen Record arrival to confirm the saved count.'
              : 'Stock could not be confirmed. Refresh and check the count before retrying Record arrival.',
        );
        await _load();
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<int?> _askCount({
    required String title,
    required String description,
    required String label,
    int? initial,
    required int minimum,
    required String action,
  }) async {
    return showDialog<int>(
      context: context,
      builder: (_) => _RestockCountDialog(
        title: title,
        description: description,
        label: label,
        initial: initial,
        minimum: minimum,
        action: action,
      ),
    );
  }

  Future<void> _remove(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Remove from restock planner?'),
        content: AppText(
          'Stop tracking ${item.displayName}? The inventory item stays.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !_current) return;
    await _save(() => RestockPrefs.remove(item.itemId, account: _account));
  }

  Future<void> _add() async {
    if (_busy || !_current) return;
    final item = await showModalBottomSheet<InventoryItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _InventoryPicker(items: _items),
    );
    if (item != null && _current) await _editBuy(item);
  }

  Future<void> _copy(List<InventoryItem> buying) async {
    final text = StringBuffer('FindEZ - To buy\n');
    for (final item in buying) {
      text.writeln(
        '${_plan.entry(item.itemId).quantityToBuy(item.quantity)} x ${item.displayName} | ${item.location}',
      );
    }
    try {
      await Clipboard.setData(ClipboardData(text: text.toString()));
      if (_current) _notice('To-buy list copied. On-order items are excluded.');
    } catch (_) {
      if (_current) _notice('Could not copy the list. Try again.');
    }
  }

  Future<void> _showInfo() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              'About restocking',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const AppText(
              'Mark ordered moves a purchase to On order. Record arrival saves the total you count on hand.',
            ),
            const SizedBox(height: 12),
            const AppText(
              'Purchase plans stay on this device for your account. Stock counts sync.',
            ),
            const SizedBox(height: 12),
            const AppText(
              'Set stock alerts in item details. Remove from planner stops tracking without deleting the item.',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const AppText('Done'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!_current) {
      return const Center(
        child: AppText('Account changed. Reopen the restock planner.'),
      );
    }
    final buying = _items
        .where((i) => _plan.needsBuying(i.itemId, i.quantity))
        .toList();
    final ordered = _items.where((i) => _plan.onOrder(i.itemId)).toList();
    final tracked = _items
        .where(
          (i) =>
              _plan.entry(i.itemId).minimum != null &&
              !_plan.needsBuying(i.itemId, i.quantity) &&
              !_plan.onOrder(i.itemId),
        )
        .toList();
    final actions = <Widget>[
      IconButton(
        tooltip: 'Add item to buy',
        onPressed: _busy || _loading || _error != null ? null : _add,
        icon: const Icon(Icons.add),
      ),
      IconButton(
        tooltip: 'Copy to-buy list',
        onPressed: _busy || buying.isEmpty || _error != null
            ? null
            : () => _copy(buying),
        icon: const Icon(Icons.ios_share),
      ),
      IconButton(
        tooltip: 'Refresh restock planner',
        onPressed: _busy || _loading ? null : _load,
        icon: const Icon(Icons.refresh),
      ),
    ];
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (widget.embedded)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [const AppText('Restock planner'), ...actions],
                  ),
                if (_error != null) ...[
                  AppText(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(onPressed: _load, child: const AppText('Retry')),
                ],
                if (_error == null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: RestockSummary(
                          toBuy: buying.length,
                          onOrder: ordered.length,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'About restock planner',
                        onPressed: _showInfo,
                        icon: const Icon(Icons.info_outline),
                      ),
                    ],
                  ),
                  if (!widget.canEditStock)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: AppText('View-only Space'),
                    ),
                  const SizedBox(height: 12),
                  if (buying.isEmpty && ordered.isEmpty && _items.isNotEmpty)
                    const AppText('Nothing to buy.'),
                  if (buying.isNotEmpty) ...[
                    AppText(
                      'To buy',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: RestockStatusColors.toBuy(context),
                      ),
                    ),
                    for (final item in buying) _card(item, onOrder: false),
                  ],
                  if (ordered.isNotEmpty) ...[
                    if (buying.isNotEmpty) const SizedBox(height: 20),
                    AppText(
                      'On order',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: RestockStatusColors.onOrder(context),
                      ),
                    ),
                    for (final item in ordered) _card(item, onOrder: true),
                  ],
                  if (tracked.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const AppText(
                      'Tracked stock',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    for (final item in tracked) _trackedCard(item),
                  ],
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: AppText('Add inventory items to plan a purchase.'),
                    ),
                  if (_items.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _add,
                        icon: const Icon(Icons.add),
                        label: const AppText('Add item to buy'),
                      ),
                    ),
                ],
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          );
    return widget.embedded
        ? body
        : Scaffold(
            backgroundColor: AppTheme.bg(context),
            appBar: AppBar(
              title: const AppText('Restock planner'),
              actions: actions,
            ),
            body: body,
          );
  }

  Widget _card(InventoryItem item, {required bool onOrder}) {
    final e = _plan.entry(item.itemId);
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        item.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AppText(
                        '${item.quantity} on hand | ${item.location}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Options for ${item.displayName}',
                  enabled: !_busy,
                  onSelected: (value) async {
                    switch (value) {
                      case 'edit':
                        if (onOrder) {
                          await _order(item);
                        } else {
                          await _editBuy(item);
                        }
                      case 'buy':
                        await _save(
                          () => RestockPrefs.cancelOrder(
                            item.itemId,
                            account: _account,
                          ),
                        );
                      case 'receive':
                        await _receive(item);
                      case 'remove':
                        await _remove(item);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: AppText(onOrder ? 'Edit order' : 'Edit quantity'),
                    ),
                    if (onOrder)
                      const PopupMenuItem(
                        value: 'buy',
                        child: AppText('Move to To buy'),
                      ),
                    if (!onOrder && widget.canEditStock)
                      const PopupMenuItem(
                        value: 'receive',
                        child: AppText('Already received'),
                      ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: AppText('Remove from planner'),
                    ),
                  ],
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
            if (!onOrder ||
                e.orderQuantity != null ||
                e.receiptTotal != null) ...[
              const SizedBox(height: 6),
              AppText(
                onOrder
                    ? (e.receiptTotal != null
                          ? 'Confirm stock: ${e.receiptTotal}'
                          : '${e.orderQuantity} ordered')
                    : '${e.quantityToBuy(item.quantity)} to buy',
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy || (onOrder && !widget.canEditStock)
                  ? null
                  : () => onOrder ? _receive(item) : _order(item),
              child: AppText(onOrder ? 'Record arrival' : 'Mark ordered'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trackedCard(InventoryItem item) => Card(
    margin: const EdgeInsets.only(top: 10),
    child: ListTile(
      title: AppText(item.displayName),
      subtitle: AppText(
        '${item.quantity} on hand | Alert at ${_plan.entry(item.itemId).minimum}',
      ),
      trailing: IconButton(
        tooltip: 'Stop tracking ${item.displayName}',
        onPressed: _busy ? null : () => _remove(item),
        icon: const Icon(Icons.close),
      ),
    ),
  );
}

class _InventoryPicker extends StatefulWidget {
  const _InventoryPicker({required this.items});
  final List<InventoryItem> items;
  @override
  State<_InventoryPicker> createState() => _InventoryPickerState();
}

class _InventoryPickerState extends State<_InventoryPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final items = widget.items
        .where(
          (i) => '${i.displayName} ${i.name} ${i.location}'
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: AppText(
                  'Choose an inventory item',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  style: AppTypography.bodyStyleOf(context),
                  decoration: const InputDecoration(
                    labelText: 'Search items or Spaces',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final item in items)
                      ListTile(
                        title: AppText(item.displayName),
                        subtitle: AppText(
                          '${item.quantity} on hand | ${item.location}',
                        ),
                        onTap: () => Navigator.pop(context, item),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestockCountDialog extends StatefulWidget {
  const _RestockCountDialog({
    required this.title,
    required this.description,
    required this.label,
    this.initial,
    required this.minimum,
    required this.action,
  });
  final String title, description, label, action;
  final int? initial;
  final int minimum;
  @override
  State<_RestockCountDialog> createState() => _RestockCountDialogState();
}

class _RestockCountDialogState extends State<_RestockCountDialog> {
  late final TextEditingController _controller;
  final _form = GlobalKey<FormState>();
  bool _submitted = false;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial?.toString() ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: AppText(widget.title),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(widget.description),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('restock-count'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTypography.bodyStyleOf(context),
              decoration: InputDecoration(labelText: widget.label),
              validator: (value) {
                final n = int.tryParse(value ?? '');
                return n == null || n < widget.minimum || n > 100000
                    ? 'Enter a whole number from ${widget.minimum} to 100000.'
                    : null;
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const AppText('Cancel'),
      ),
      FilledButton(
        onPressed: _submitted
            ? null
            : () {
                if (_form.currentState!.validate()) {
                  setState(() => _submitted = true);
                  Navigator.pop(context, int.parse(_controller.text));
                }
              },
        child: AppText(widget.action),
      ),
    ],
  );
}
