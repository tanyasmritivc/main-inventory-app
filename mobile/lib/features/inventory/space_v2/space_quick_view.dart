import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/api_error.dart';
import '../../../core/inventory_cache.dart';
import '../imported_item_details.dart';
import 'item_detail_fields.dart';
import 'space_style.dart';
import 'space_widgets.dart';
import 'space_move.dart';

Future<void> showSpaceQuickView(
  BuildContext context, {
  required InventoryItem item,
  required ApiClient api,
  required bool readOnly,
  required ValueChanged<InventoryItem> onUpdated,
  required ValueChanged<InventoryItem> onEdit,
  ValueChanged<String>? onAsk,
  int? threshold,
}) => showSpaceSheet<void>(
  context,
  builder: (_) => SpaceQuickView(
    item: item,
    api: api,
    readOnly: readOnly,
    threshold: threshold,
    onUpdated: onUpdated,
    onEdit: onEdit,
    onAsk: onAsk,
  ),
);

class SpaceQuickView extends StatefulWidget {
  const SpaceQuickView({
    super.key,
    required this.item,
    required this.api,
    required this.readOnly,
    required this.onUpdated,
    required this.onEdit,
    this.onAsk,
    this.threshold,
  });
  final InventoryItem item;
  final ApiClient api;
  final bool readOnly;
  final int? threshold;
  final ValueChanged<InventoryItem> onUpdated, onEdit;
  final ValueChanged<String>? onAsk;
  @override
  State<SpaceQuickView> createState() => _SpaceQuickViewState();
}

class _SpaceQuickViewState extends State<SpaceQuickView> {
  late InventoryItem _item = widget.item;
  bool _saving = false;
  String? _error, _receipt;
  Timer? _savedTimer;
  bool get _canEdit => !widget.readOnly && widget.api.canEdit;
  @override
  void dispose() {
    _savedTimer?.cancel();
    super.dispose();
  }

  Future<bool> _save(
    UpdateItemRequest request,
    String Function(InventoryItem) receipt,
  ) async {
    if (_saving || !_canEdit) return false;
    _savedTimer?.cancel();
    setState(() {
      _saving = true;
      _error = null;
      _receipt = null;
    });
    try {
      widget.api.assertCurrentContext();
      final updated = await widget.api.updateItem(request: request);
      widget.api.assertCurrentContext();
      InventoryCache.updateItem(updated, contextKey: widget.api.cacheKey);
      widget.onUpdated(updated);
      if (!mounted) return true;
      setState(() => _item = updated);
      _savedTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _receipt = receipt(updated));
      });
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error).$1);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _move() async {
    if (!_canEdit || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final location = await chooseSpaceLocation(
        context,
        widget.api,
        _item,
        onReady: () {
          if (mounted) setState(() => _saving = false);
        },
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (!mounted || location == null || location == _item.location) return;
      await _save(
        UpdateItemRequest(itemId: _item.itemId, location: location),
        (item) => 'Moved to ${item.location}',
      );
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error).$1);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final low = spaceItemIsLow(_item, widget.threshold);
    final fields = itemDetailFields(_item, canEdit: _canEdit);
    return SingleChildScrollView(
      key: const ValueKey('space-quick-view'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SpaceHandle(),
            Stack(
              children: [
                SpaceThumbnail(
                  item: _item,
                  size: double.infinity,
                  height: 190,
                  radius: 26,
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: SpaceCircle(
                    label: 'Close',
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 18, 6, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _item.name,
                    style: SpaceStyle.text(
                      24,
                    ).copyWith(height: 1.15, letterSpacing: -.6),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    spaceItemSubtitle(_item),
                    style: SpaceStyle.text(15, SpaceStyle.tx2),
                  ),
                ],
              ),
            ),
            Container(
              decoration: SpaceStyle.card(),
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          low ? 'Quantity · Low' : 'Quantity',
                          style: SpaceStyle.text(
                            12.5,
                            low ? SpaceStyle.amber : SpaceStyle.tx2,
                          ),
                        ),
                        Text('${_item.quantity}', style: SpaceStyle.text(32)),
                      ],
                    ),
                  ),
                  if (_canEdit) ...[
                    SpaceCircle(
                      label: 'Use one',
                      icon: Icons.remove,
                      size: 48,
                      onTap: _saving || _item.quantity <= 0
                          ? null
                          : () => _save(
                              UpdateItemRequest(
                                itemId: _item.itemId,
                                quantity: _item.quantity - 1,
                              ),
                              (i) => 'Saved · ${i.quantity} left',
                            ),
                    ),
                    const SizedBox(width: 8),
                    SpaceCircle(
                      label: 'Add one',
                      icon: Icons.add,
                      size: 48,
                      onTap: _saving || _item.quantity >= 100000
                          ? null
                          : () => _save(
                              UpdateItemRequest(
                                itemId: _item.itemId,
                                quantity: _item.quantity + 1,
                              ),
                              (i) => 'Saved · ${i.quantity} left',
                            ),
                    ),
                  ],
                ],
              ),
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_error != null || _receipt != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error ?? _receipt!,
                    style: SpaceStyle.text(
                      14,
                      _error == null ? SpaceStyle.tx2 : SpaceStyle.amber,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Container(
              decoration: SpaceStyle.card(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  for (final (index, field) in fields.indexed) ...[
                    if (index > 0)
                      const Divider(height: 1, color: SpaceStyle.line),
                    _Field(field.label, field.displayValue),
                  ],
                ],
              ),
            ),
            // The exact existing imported-column renderer preserves duplicate labels,
            // empty columns, source formatting, and source order.
            if (_item.importData != null)
              ImportedItemDetails(data: _item.importData!),
            if (_item.unitPrice != null ||
                _item.expiresOn != null ||
                _item.reorderEnabled) ...[
              const SizedBox(height: 16),
              Text('Price, expiry and reordering', style: SpaceStyle.text(15)),
              if (_item.unitPrice != null)
                _Field(
                  'Unit price',
                  '${_item.currency ?? ''} ${_item.unitPrice}',
                ),
              if (_item.expiresOn != null)
                _Field('Expires', '${_item.expiresOn}'),
              if (_item.reorderEnabled)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Request ${_item.reorderQuantity} when quantity reaches ${_item.reorderThreshold}',
                    style: SpaceStyle.text(14.5),
                  ),
                ),
            ],
            _Field(
              'Notes',
              _item.notes?.isNotEmpty == true ? _item.notes! : 'No notes',
            ),
            _Field('Where to buy', _item.purchaseSource ?? ''),
            if (widget.threshold != null)
              _Field('Alert me at or below', '${widget.threshold}'),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_canEdit)
                  _pill(
                    'Move',
                    Icons.drive_file_move_outline,
                    _saving ? null : _move,
                  ),
                _pill(
                  _canEdit ? 'Edit' : 'Details',
                  Icons.edit_outlined,
                  _saving
                      ? null
                      : () {
                          Navigator.pop(context);
                          widget.onEdit(_item);
                        },
                ),
                if (widget.onAsk != null)
                  _pill('Ask', Icons.auto_awesome_outlined, () {
                    Navigator.pop(context);
                    widget.onAsk!('How many ${_item.name} do we have?');
                  }, white: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(
    String title,
    IconData icon,
    VoidCallback? onTap, {
    bool white = false,
  }) => FilledButton.icon(
    style: FilledButton.styleFrom(
      minimumSize: const Size(100, 52),
      backgroundColor: white ? SpaceStyle.white : SpaceStyle.s2,
      foregroundColor: white ? SpaceStyle.bg : SpaceStyle.tx,
      textStyle: SpaceStyle.text(15),
    ),
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(title),
  );
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final children = [
      Text(label, style: SpaceStyle.text(14.5, SpaceStyle.tx2)),
      Text(value, textAlign: TextAlign.right, style: SpaceStyle.text(14.5)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: MediaQuery.textScalerOf(context).scale(14.5) > 24
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children.first),
                const SizedBox(width: 12),
                Expanded(child: children.last),
              ],
            ),
    );
  }
}
