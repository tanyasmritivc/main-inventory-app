import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/ui/photo_source_sheet.dart';
import '../item_photo_viewer.dart';
import '../../../core/api_client.dart';
import '../../../core/api_error.dart';
import '../../../core/inventory_cache.dart';
import '../../../core/low_stock_prefs.dart';
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
  ValueChanged<int?>? onThresholdChanged,
}) => showSpaceSheet<void>(
  context,
  builder: (_) => SpaceQuickView(
    item: item,
    api: api,
    readOnly: readOnly,
    threshold: threshold,
    onThresholdChanged: onThresholdChanged,
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
    this.onThresholdChanged,
  });
  final InventoryItem item;
  final ApiClient api;
  final bool readOnly;
  final int? threshold;
  final ValueChanged<int?>? onThresholdChanged;
  final ValueChanged<InventoryItem> onUpdated, onEdit;
  final ValueChanged<String>? onAsk;
  @override
  State<SpaceQuickView> createState() => _SpaceQuickViewState();
}

class _SpaceQuickViewState extends State<SpaceQuickView> {
  late InventoryItem _item = widget.item;
  late int? _threshold = widget.threshold;
  bool _saving = false;
  String? _error, _receipt;
  Timer? _savedTimer;
  final _fieldController = TextEditingController();
  String? _editingField, _fieldError;
  bool get _canEdit => !widget.readOnly && widget.api.canEdit;
  @override
  void dispose() {
    _savedTimer?.cancel();
    _fieldController.dispose();
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

  bool _openingPhoto = false;
  Future<void> _photo() async {
    if (_openingPhoto || _saving || _editingField != null) return;
    _openingPhoto = true;
    try {
      await _performPhoto();
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error).$1);
    } finally {
      _openingPhoto = false;
    }
  }

  Future<void> _performPhoto() async {
    final url = (_item.imageUrl ?? '').trim();
    if (url.isNotEmpty) {
      await Navigator.of(context).push<void>(
        PageRouteBuilder(
          transitionDuration: Duration(
            milliseconds: SpaceStyle.reduced(context) ? 180 : 350,
          ),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, _, _) => ItemPhotoViewer(
            photos: [
              ItemPhoto(
                photoId: 'primary',
                imageUrl: url,
                isPrimary: true,
                createdAt: _item.createdAt,
              ),
            ],
            initialIndex: 0,
          ),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
      return;
    }
    if (!_canEdit || _saving) return;
    final camera = await showPhotoSourceSheet(context, showCancel: false);
    if (camera == null || !mounted) return;
    final image = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 88,
    );
    if (image == null || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      widget.api.assertCurrentContext();
      final result = await widget.api.addItemPhoto(
        itemId: _item.itemId,
        bytes: await image.readAsBytes(),
        filename: image.name,
      );
      widget.api.assertCurrentContext();
      InventoryCache.updateItem(result.item, contextKey: widget.api.cacheKey);
      widget.onUpdated(result.item);
      if (mounted) {
        setState(() {
          _item = result.item;
          _receipt = 'Photo added';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error).$1);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _beginField(String key, String value) {
    if (!_canEdit || _saving || _editingField != null) return;
    if (key == 'location') {
      unawaited(_move());
      return;
    }
    setState(() {
      _editingField = key;
      _fieldController.text = value;
      _fieldError = null;
    });
  }

  Future<void> _saveField() async {
    final key = _editingField;
    if (key == null || _saving) return;
    final value = _fieldController.text.trim();
    final quantity = int.tryParse(value);
    if ((['name', 'category'].contains(key) && value.isEmpty) ||
        (key == 'quantity' &&
            (quantity == null || quantity < 0 || quantity > 100000))) {
      setState(
        () => _fieldError = key == 'quantity'
            ? 'Enter a whole number from 0 to 100000.'
            : 'Enter a value.',
      );
      return;
    }
    if (key == 'threshold') {
      if (value.isNotEmpty &&
          (quantity == null || quantity < 0 || quantity > 100000)) {
        setState(
          () => _fieldError =
              'Enter a whole number from 0 to 100000, or clear it.',
        );
        return;
      }
      setState(() => _saving = true);
      try {
        widget.api.assertCurrentContext();
        await LowStockPrefs.setThreshold(
          itemId: _item.itemId,
          threshold: value.isEmpty ? null : quantity,
        );
        widget.api.assertCurrentContext();
        if (!mounted) return;
        setState(() {
          _threshold = value.isEmpty ? null : quantity;
          _editingField = null;
          _receipt = 'Saved';
        });
        widget.onThresholdChanged?.call(_threshold);
      } catch (error) {
        if (mounted) setState(() => _fieldError = describeError(error).$1);
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }
    final saved = await _save(
      UpdateItemRequest(
        itemId: _item.itemId,
        name: key == 'name' ? value : null,
        partNumber: key == 'part_number' ? value : null,
        category: key == 'category' ? value : null,
        quantity: key == 'quantity' ? quantity : null,
        brand: key == 'brand' ? value : null,
        barcode: key == 'barcode' ? value : null,
        subcategory: key == 'subcategory' ? value : null,
        tags: key == 'tags'
            ? value
                  .split(',')
                  .map((v) => v.trim())
                  .where((v) => v.isNotEmpty)
                  .toList()
            : null,
        notes: key == 'notes' ? value : null,
        purchaseSource: key == 'purchase_source' ? value : null,
      ),
      (_) => 'Saved',
    );
    if (mounted) {
      setState(() {
        if (saved) {
          _editingField = null;
        } else {
          _fieldError = _error;
        }
      });
    }
  }

  bool _confirmingDismiss = false;
  Future<void> _requestDismiss() async {
    if (_confirmingDismiss || _saving) return;
    if (_editingField == null) {
      Navigator.maybePop(context);
      return;
    }
    _confirmingDismiss = true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save your changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    _confirmingDismiss = false;
    if (!mounted || choice == null) return;
    if (choice == 'save') {
      await _saveField();
    } else {
      setState(() => _editingField = null);
    }
    if (!mounted || _editingField != null) return;
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.maybePop(context);
  }

  Widget _field(String label, String value, [String? key]) {
    if (_editingField == key && key != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: ValueKey('space-item-field-$key'),
              controller: _fieldController,
              autofocus: true,
              enabled: !_saving,
              style: SpaceStyle.text(15),
              keyboardType: key == 'quantity' || key == 'threshold'
                  ? TextInputType.number
                  : TextInputType.text,
              maxLines: key == 'notes' ? 4 : 1,
              maxLength: key == 'notes'
                  ? 5000
                  : key == 'tags'
                  ? 1000
                  : 200,
              decoration: InputDecoration(
                labelText: label,
                errorText: _fieldError,
              ),
              onSubmitted: (_) => _saveField(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _editingField = null),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _saving ? null : _saveField,
                  child: Text(_saving ? 'Saving...' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    final row = _Field(label, value.isEmpty ? 'Not set' : value);
    if (!_canEdit || key == null) return row;
    return Semantics(
      button: true,
      label: 'Edit $label',
      key: ValueKey('space-edit-$key'),
      child: InkWell(
        onTap: _saving ? null : () => _beginField(key, value),
        child: row,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final low = spaceItemIsLow(_item, _threshold);
    final fields = itemDetailFields(_item, canEdit: _canEdit);
    return PopScope(
      canPop: !_saving && _editingField == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestDismiss());
      },
      child: SingleChildScrollView(
        key: const ValueKey('space-quick-view'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SpaceHandle(),
              Semantics(
                button: (_item.imageUrl ?? '').isNotEmpty || _canEdit,
                label: (_item.imageUrl ?? '').isNotEmpty
                    ? 'View full item photo'
                    : 'Add item photo',
                child: InkWell(
                  key: const ValueKey('space-item-photo'),
                  onTap: _saving || _editingField != null ? null : _photo,
                  borderRadius: BorderRadius.circular(26),
                  child: Stack(
                    children: [
                      SpaceThumbnail(
                        item: _item,
                        size: double.infinity,
                        height: 190,
                        radius: 26,
                      ),
                      if ((_item.imageUrl ?? '').isEmpty && _canEdit)
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xCC252527),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Add photo',
                              style: SpaceStyle.text(13),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 18, 6, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _item.displayName,
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
                        onTap:
                            _saving ||
                                _editingField != null ||
                                _item.quantity <= 0
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
                        onTap:
                            _saving ||
                                _editingField != null ||
                                _item.quantity >= 100000
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    for (final (index, field) in fields.indexed) ...[
                      if (index > 0)
                        const Divider(height: 1, color: SpaceStyle.line),
                      _field(field.label, field.value, field.editKey),
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
                Text(
                  'Price, expiry and reordering',
                  style: SpaceStyle.text(15),
                ),
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
              _field('Notes', _item.notes ?? '', 'notes'),
              _field(
                'Where to buy',
                _item.purchaseSource ?? '',
                'purchase_source',
              ),
              if (_canEdit || _threshold != null)
                _field(
                  'Alert me at or below',
                  _threshold?.toString() ?? '',
                  'threshold',
                ),
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
                      _saving || _editingField != null ? null : _move,
                    ),
                  if (widget.onAsk != null)
                    _pill(
                      'Ask',
                      Icons.auto_awesome_outlined,
                      _saving || _editingField != null
                          ? null
                          : () {
                              Navigator.pop(context);
                              widget.onAsk!(
                                'How many ${_item.name} do we have?',
                              );
                            },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String title, IconData icon, VoidCallback? onTap) =>
      FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(100, 52),
          backgroundColor: const Color(0xFFD4D4D8),
          foregroundColor: SpaceStyle.bg,
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
