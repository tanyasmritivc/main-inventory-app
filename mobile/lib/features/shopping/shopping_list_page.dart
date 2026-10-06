import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/inventory_cache.dart';
import '../../core/restock_plan.dart';
import '../../core/ui/app_text.dart';

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
      description:
          'How many ${item.displayName} did you order? Stock changes only after you record arrival.',
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
          '${item.displayName}\nLast saved stock: ${item.quantity}. ${entry.orderQuantity == null ? '' : 'Ordered: ${entry.orderQuantity}. '}'
          'Count what is actually on hand, including this delivery. Saving replaces the stock count; it does not add units twice.',
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
          'Stop planning purchases and low-stock alerts for ${item.displayName}. The inventory item and its stock count stay unchanged.',
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
                  AppText(
                    '${buying.length} to buy | ${ordered.length} on order',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const AppText(
                    'Order what you need. Record arrival only after checking the stock on hand.',
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    'Purchase planning is saved for your account on this device. Stock counts sync with inventory.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  if (!widget.canEditStock)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: AppText(
                        'View-only Space: ask an editor to update stock after delivery.',
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (buying.isEmpty)
                    const AppText('Nothing to buy right now.'),
                  if (buying.isNotEmpty) ...[
                    const AppText(
                      'To buy',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    for (final item in buying) _card(item, onOrder: false),
                  ],
                  if (ordered.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const AppText(
                      'On order',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
                      child: AppText(
                        'Save an inventory item first. Then add the items you want to buy or track.',
                      ),
                    ),
                  if (_items.isNotEmpty &&
                      buying.isEmpty &&
                      ordered.isEmpty &&
                      tracked.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: AppText(
                        'A single belonging is not automatically low stock. Add an item you actually need to purchase, or set its low-stock threshold in item details.',
                      ),
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
                  child: AppText(
                    item.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove ${item.displayName} from planner',
                  onPressed: _busy ? null : () => _remove(item),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            AppText('${item.quantity} on hand | ${item.location}'),
            const SizedBox(height: 6),
            AppText(
              onOrder
                  ? (e.receiptTotal != null
                        ? 'Stock confirmation pending: ${e.receiptTotal} total'
                        : e.orderQuantity == null
                        ? 'Ordered previously. Quantity was not recorded.'
                        : '${e.orderQuantity} ordered')
                  : '${e.quantityToBuy(item.quantity)} to buy',
            ),
            if (e.minimum != null)
              AppText(
                'Low-stock alert at ${e.minimum}. Buy enough to get above that level.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: onOrder
                  ? [
                      FilledButton(
                        onPressed: _busy || !widget.canEditStock
                            ? null
                            : () => _receive(item),
                        child: const AppText('Record arrival'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _save(
                                () => RestockPrefs.cancelOrder(
                                  item.itemId,
                                  account: _account,
                                ),
                              ),
                        child: const AppText('Back to to-buy'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _order(item),
                        child: const AppText('Edit order'),
                      ),
                    ]
                  : [
                      FilledButton(
                        onPressed: _busy ? null : () => _order(item),
                        child: const AppText('Mark ordered'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _editBuy(item),
                        child: const AppText('Edit quantity'),
                      ),
                      if (widget.canEditStock)
                        TextButton(
                          onPressed: _busy ? null : () => _receive(item),
                          child: const AppText('Already received'),
                        ),
                    ],
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
