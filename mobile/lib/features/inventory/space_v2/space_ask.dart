import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/api_error.dart';
import '../../../core/ask_answer.dart';
import '../item_detail_sheet.dart';
import '../../chat/chat_page.dart';
import 'space_chat_widgets.dart';
import 'space_style.dart';
import 'space_widgets.dart';
import 'space_quick_view.dart';
import 'space_move.dart';
import '../../../core/inventory_cache.dart';

Future<void> showSpaceAsk(
  BuildContext context, {
  required ApiClient api,
  required String space,
  required List<InventoryItem> items,
  required Map<String, int> thresholds,
  required bool readOnly,
  required ValueChanged<InventoryItem> onUpdated,
  required void Function(String, int?) onThresholdChanged,
  required VoidCallback onAdd,
  required VoidCallback onInventoryMutated,
  required ValueChanged<Set<String>> onShowItems,
  required VoidCallback onShowLow,
  String? initialMessage,
  String? initialDraft,
  bool startVoice = false,
}) async {
  try {
    api.assertCurrentContext();
    if (api.inventoryContext == null) return;
    await showSpaceSheet<void>(
      context,
      ask: true,
      builder: (_) => _SpaceAsk(
        api: api,
        space: space,
        items: items,
        thresholds: thresholds,
        readOnly: readOnly,
        onUpdated: onUpdated,
        onThresholdChanged: onThresholdChanged,
        onAdd: onAdd,
        onInventoryMutated: onInventoryMutated,
        onShowItems: onShowItems,
        onShowLow: onShowLow,
        initialMessage: initialMessage,
        initialDraft: initialDraft,
        startVoice: startVoice,
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }
}

class _SpaceAsk extends StatefulWidget {
  const _SpaceAsk({
    required this.api,
    required this.space,
    required this.items,
    required this.thresholds,
    required this.readOnly,
    required this.onUpdated,
    required this.onThresholdChanged,
    required this.onAdd,
    required this.onInventoryMutated,
    required this.onShowItems,
    required this.onShowLow,
    this.initialMessage,
    this.initialDraft,
    required this.startVoice,
  });
  final ApiClient api;
  final String space;
  final List<InventoryItem> items;
  final Map<String, int> thresholds;
  final bool readOnly, startVoice;
  final ValueChanged<InventoryItem> onUpdated;
  final void Function(String, int?) onThresholdChanged;
  final VoidCallback onAdd, onInventoryMutated, onShowLow;
  final ValueChanged<Set<String>> onShowItems;
  final String? initialMessage, initialDraft;
  @override
  State<_SpaceAsk> createState() => _SpaceAskState();
}

class _SpaceAskState extends State<_SpaceAsk> {
  late final Map<String, InventoryItem> _items = {
    for (final item in widget.items) item.itemId: item,
  };
  late final _thresholds = Map<String, int>.of(widget.thresholds);
  final _chatKey = GlobalKey();
  ValueChanged<String>? _send;
  final _changedItems = <String>{};
  bool _saving = false;
  String? _writeStatus;

  Future<void> _change(InventoryItem item, {bool move = false}) async {
    if (_saving || widget.readOnly || !widget.api.canEdit) return;
    setState(() {
      _saving = true;
      _writeStatus = null;
    });
    try {
      final location = move
          ? await chooseSpaceLocation(context, widget.api, item)
          : null;
      if (!mounted ||
          (move && (location == null || location == item.location))) {
        return;
      }
      widget.api.assertCurrentContext();
      // Read before a decrement, since a chat answer may be older than stock.
      final current = move
          ? item
          : (await widget.api.searchItems(
              query: item.name,
            )).items.where((i) => i.itemId == item.itemId).firstOrNull;
      if (!mounted) return;
      if (current == null || (!move && current.quantity <= 0)) {
        setState(
          () => _writeStatus = 'This item is no longer available to use.',
        );
        return;
      }
      final updated = await widget.api.updateItem(
        request: UpdateItemRequest(
          itemId: item.itemId,
          location: move ? location : null,
          quantity: move ? null : current.quantity - 1,
        ),
      );
      widget.api.assertCurrentContext();
      InventoryCache.updateItem(updated, contextKey: widget.api.cacheKey);
      _updated(updated);
      if (mounted) {
        setState(
          () => _writeStatus = move
              ? 'Moved to ${updated.location}'
              : 'Saved · ${updated.quantity} left',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _writeStatus = describeError(error).$1);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _updated(InventoryItem item) {
    if (mounted) {
      setState(() {
        _items[item.itemId] = item;
        _changedItems.add(item.itemId);
      });
    }
    widget.onUpdated(item);
  }

  bool _opening = false;
  Future<void> _open(InventoryItem item) async {
    if (_opening) return;
    _opening = true;
    try {
      final result = await widget.api.searchItems(query: item.name);
      widget.api.assertCurrentContext();
      if (!mounted) return;
      final current = result.items
          .where((candidate) => candidate.itemId == item.itemId)
          .firstOrNull;
      if (current == null) {
        setState(() => _writeStatus = 'This item is no longer available.');
        return;
      }
      _updated(current);
      await showSpaceQuickView(
        context,
        item: current,
        api: widget.api,
        readOnly: widget.readOnly,
        threshold: _thresholds[item.itemId],
        onUpdated: _updated,
        onAsk: (question) => _send?.call(question),
        onEdit: (current) => showItemDetailSheet(
          context,
          item: current,
          api: widget.api,
          permission: widget.readOnly ? 'view' : 'edit',
          initialThreshold: _thresholds[item.itemId],
          spaceName: current.location,
          onItemUpdated: _updated,
          onThresholdChanged: (threshold) {
            if (mounted) {
              setState(() {
                if (threshold == null) {
                  _thresholds.remove(item.itemId);
                } else {
                  _thresholds[item.itemId] = threshold;
                }
              });
            }
            widget.onThresholdChanged(item.itemId, threshold);
          },
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _writeStatus = describeError(error).$1);
    } finally {
      _opening = false;
    }
  }

  Widget? _results(AskAnswerContext data) {
    // Preserve the original renderer for unknown/cross-Space results and project
    // requirements. Never manufacture item references from response prose.
    if (data.rows.isEmpty ||
        data.rows.any(
          (row) =>
              !_items.containsKey(row.id) ||
              row.requiredQuantity != null ||
              row.availableQuantity == null,
        )) {
      return null;
    }
    final resultItems = data.rows.map((row) => _items[row.id]!).toList();
    final canShowInList = resultItems.every(
      (item) => item.location == widget.space,
    );
    final visibleItems = canShowInList
        ? resultItems.take(4).toList()
        : resultItems;
    int quantity(int index) => _changedItems.contains(resultItems[index].itemId)
        ? resultItems[index].quantity
        : data.rows[index].availableQuantity!;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: SpaceStyle.card(18),
            child: Column(
              children: [
                for (final (index, item) in visibleItems.indexed)
                  SpaceItemRow(
                    item: item,
                    quantity: _changedItems.contains(item.itemId)
                        ? item.quantity
                        : data.rows[index].availableQuantity,
                    subtitleSuffix: ' · ${item.location}',
                    onTap: () => _open(item),
                    compact: resultItems.length > 1,
                    low: spaceItemIsLow(
                      item,
                      _thresholds[item.itemId],
                      quantity: _changedItems.contains(item.itemId)
                          ? item.quantity
                          : data.rows[index].availableQuantity,
                    ),
                    divider: index < visibleItems.length - 1,
                  ),
              ],
            ),
          ),
          if (resultItems.length == 1 && !widget.readOnly && widget.api.canEdit)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving || quantity(0) <= 0
                          ? null
                          : () => _change(resultItems.first),
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: SpaceStyle.s2,
                        foregroundColor: SpaceStyle.tx,
                      ),
                      child: const Text('− I used one'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving
                          ? null
                          : () => _change(resultItems.first, move: true),
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: SpaceStyle.s2,
                        foregroundColor: SpaceStyle.tx,
                      ),
                      child: const Text('Move'),
                    ),
                  ),
                ],
              ),
            ),
          if (_writeStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _writeStatus!,
                  style: SpaceStyle.text(13, SpaceStyle.tx2),
                ),
              ),
            ),
          if (canShowInList && resultItems.length > 4)
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onShowItems(resultItems.map((i) => i.itemId).toSet());
              },
              child: Text('See all ${resultItems.length} in the list'),
            ),
          if (canShowInList &&
              resultItems.indexed.every(
                (entry) => spaceItemIsLow(
                  entry.$2,
                  _thresholds[entry.$2.itemId],
                  quantity: quantity(entry.$1),
                ),
              ))
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onShowLow();
              },
              child: const Text('Show low quantity in list'),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final question in [
                  'Where is ${resultItems.first.name}?',
                  'What is running low?',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        textStyle: SpaceStyle.text(13.5),
                        foregroundColor: SpaceStyle.tx2,
                        side: const BorderSide(color: SpaceStyle.line2),
                      ),
                      onPressed: () => _send?.call(question),
                      child: Text(question),
                    ),
                  ),
              ],
            ),
          ),
          if (data.rowsTruncated)
            Text(
              'Additional results are not shown here.',
              style: SpaceStyle.text(13, SpaceStyle.tx2),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MediaQuery.removePadding(
    context: context,
    removeTop: true,
    child: Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 12,
      ),
      child: ChatPage(
        key: _chatKey,
        api: widget.api,
        contextual: true,
        inPageView: true,
        initialMessage: widget.initialMessage,
        onInventoryMutated: widget.onInventoryMutated,
        spacePresentation: SpaceChatPresentation(
          space: widget.space,
          scopeLabel: 'Only in ${widget.api.inventoryContext!.name}',
          items: _items.values.toList(),
          onClose: () => Navigator.pop(context),
          onAdd: widget.readOnly || !widget.api.canEdit ? null : widget.onAdd,
          results: _results,
          registerSend: (send) => _send = send,
          initialDraft: widget.initialDraft,
          startVoice: widget.startVoice,
        ),
      ),
    ),
  );
}
