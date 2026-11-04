import '../../../core/private_image.dart';
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
  final _editFocus = FocusNode();
  final _editAnchor = GlobalKey();
  final _scroll = ScrollController();
  final _gallery = PageController();
  List<ItemPhoto> _photos = [];
  int _photoIndex = 0, _galleryEpoch = 0;
  String? _galleryError;

  @override
  void initState() {
    super.initState();
    _photos = _fallbackPhotos();
    unawaited(_loadPhotos());
  }

  List<ItemPhoto> _fallbackPhotos() => (_item.imageUrl ?? '').trim().isEmpty
      ? []
      : [
          ItemPhoto(
            photoId: 'primary',
            imageUrl: _item.imageUrl!,
            isPrimary: true,
            createdAt: _item.createdAt,
          ),
        ];
  Future<void> _loadPhotos() async {
    final epoch = ++_galleryEpoch;
    try {
      widget.api.assertCurrentContext();
      final photos = await widget.api.getItemPhotos(itemId: _item.itemId);
      widget.api.assertCurrentContext();
      if (!mounted || epoch != _galleryEpoch) return;
      setState(() {
        _photos = photos.isEmpty ? _fallbackPhotos() : photos;
        _galleryError = null;
        _photoIndex = 0;
      });
    } catch (error) {
      if (mounted && epoch == _galleryEpoch) {
        setState(() => _galleryError = 'Could not load all photos.');
      }
    }
  }

  void _revealEditor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _editAnchor.currentContext;
      if (!mounted || anchor == null) return;
      Scrollable.ensureVisible(
        anchor,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: .5,
      );
    });
  }

  String? _editingField, _fieldError;
  bool get _canEdit => !widget.readOnly && widget.api.canEdit;
  @override
  void dispose() {
    _savedTimer?.cancel();
    _fieldController.dispose();
    _editFocus.dispose();
    _scroll.dispose();
    _gallery.dispose();
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
    setState(() => _openingPhoto = true);
    try {
      await _performPhoto();
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error).$1);
    } finally {
      if (mounted) setState(() => _openingPhoto = false);
    }
  }

  Future<void> _performPhoto() async {
    if (_photos.isEmpty) {
      await _addPhotos();
      return;
    }
    await Navigator.of(context).push<void>(
      PageRouteBuilder(
        transitionDuration: Duration(
          milliseconds: SpaceStyle.reduced(context) ? 180 : 350,
        ),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, _, _) => ItemPhotoViewer(
          photos: List.of(_photos),
          initialIndex: _photoIndex,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _addPhotos() async {
    if (!_canEdit || _saving || _editingField != null) return;
    final camera = await showPhotoSourceSheet(context, showCancel: false);
    if (camera == null || !mounted) return;
    final picker = ImagePicker();
    final images = camera
        ? [
            await picker.pickImage(
              source: ImageSource.camera,
              maxWidth: 2048,
              maxHeight: 2048,
              imageQuality: 88,
            ),
          ].whereType<XFile>().toList()
        : await picker.pickMultiImage(
            maxWidth: 2048,
            maxHeight: 2048,
            imageQuality: 88,
          );
    if (images.isEmpty || !mounted) return;
    ++_galleryEpoch;
    setState(() {
      _saving = true;
      _error = null;
    });
    var added = 0;
    try {
      for (final image in images) {
        widget.api.assertCurrentContext();
        final result = await widget.api.addItemPhoto(
          itemId: _item.itemId,
          bytes: await image.readAsBytes(),
          filename: image.name,
        );
        widget.api.assertCurrentContext();
        InventoryCache.updateItem(result.item, contextKey: widget.api.cacheKey);
        widget.onUpdated(result.item);
        if (!mounted) return;
        added++;
        setState(() {
          _item = result.item;
          _photos = result.photos.isEmpty ? _fallbackPhotos() : result.photos;
          _photoIndex = 0;
          _galleryError = null;
          _receipt = added == 1 ? 'Photo added' : '$added photos added';
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _gallery.hasClients) _gallery.jumpToPage(0);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              '${added == 0 ? '' : '$added ${added == 1 ? 'photo' : 'photos'} added. '}${describeError(error).$1}',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _photoGallery() => Column(
    children: [
      SizedBox(
        height: 190,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: _photos.isEmpty
              ? InkWell(
                  key: const ValueKey('space-item-photo'),
                  onTap: _saving || _editingField != null ? null : _photo,
                  child: SpaceThumbnail(
                    item: _item,
                    size: double.infinity,
                    height: 190,
                    radius: 26,
                  ),
                )
              : PageView.builder(
                  controller: _gallery,
                  itemCount: _photos.length,
                  onPageChanged: (index) => setState(() => _photoIndex = index),
                  itemBuilder: (_, index) => Semantics(
                    label: 'View full item photo ${index + 1}',
                    button: true,
                    child: InkWell(
                      key: index == _photoIndex
                          ? const ValueKey('space-item-photo')
                          : null,
                      onTap: _saving || _editingField != null ? null : _photo,
                      child: PrivateImage(
                        _photos[index].imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Center(child: Text('Photo unavailable')),
                      ),
                    ),
                  ),
                ),
        ),
      ),
      const SizedBox(height: 6),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_photos.length > 1) ...[
            IconButton(
              tooltip: 'Previous item photo',
              onPressed: _photoIndex > 0
                  ? () => _gallery.previousPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    )
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${_photoIndex + 1} of ${_photos.length}',
              style: SpaceStyle.of(context).text(13),
            ),
            IconButton(
              tooltip: 'Next item photo',
              onPressed: _photoIndex + 1 < _photos.length
                  ? () => _gallery.nextPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    )
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
          if (_canEdit)
            TextButton.icon(
              onPressed: _saving || _openingPhoto || _editingField != null
                  ? null
                  : () async {
                      if (_openingPhoto) return;
                      setState(() => _openingPhoto = true);
                      try {
                        await _addPhotos();
                      } catch (error) {
                        if (mounted) {
                          setState(() => _error = describeError(error).$1);
                        }
                      } finally {
                        if (mounted) setState(() => _openingPhoto = false);
                      }
                    },
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_saving ? 'Adding...' : 'Add photos'),
            ),
          if (_galleryError != null)
            TextButton(
              onPressed: _loadPhotos,
              child: Text('$_galleryError Retry'),
            ),
        ],
      ),
    ],
  );

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
    _revealEditor();
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
          _editFocus.unfocus();
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
          _editFocus.unfocus();
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
        key: _editAnchor,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: ValueKey('space-item-field-$key'),
              controller: _fieldController,
              focusNode: _editFocus,
              scrollPadding: const EdgeInsets.only(bottom: 96, top: 24),
              autofocus: true,
              enabled: !_saving,
              style: SpaceStyle.of(context).text(15),
              keyboardType: key == 'quantity' || key == 'threshold'
                  ? TextInputType.number
                  : TextInputType.text,
              maxLines: key == 'notes' ? 4 : 1,
              maxLength: key == 'notes'
                  ? 5000
                  : key == 'tags'
                  ? 1000
                  : key == 'quantity' || key == 'threshold'
                  ? 6
                  : 200,
              decoration: InputDecoration(
                labelText: label,
                counterText: '',
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
                      : () {
                          _editFocus.unfocus();
                          setState(() => _editingField = null);
                        },
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
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        key: const ValueKey('space-quick-view'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SpaceHandle(),
              _photoGallery(),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 18, 6, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _item.displayName,
                      style: SpaceStyle.of(
                        context,
                      ).text(24).copyWith(height: 1.15, letterSpacing: -.6),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      spaceItemSubtitle(_item),
                      style: SpaceStyle.of(
                        context,
                      ).text(15, SpaceStyle.of(context).tx2),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: SpaceStyle.of(context).card(),
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            low ? 'Quantity · Low' : 'Quantity',
                            style: SpaceStyle.of(context).text(
                              12.5,
                              low
                                  ? SpaceStyle.of(context).amber
                                  : SpaceStyle.of(context).tx2,
                            ),
                          ),
                          Text(
                            '${_item.quantity}',
                            style: SpaceStyle.of(context).text(32),
                          ),
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
                      style: SpaceStyle.of(context).text(
                        14,
                        _error == null
                            ? SpaceStyle.of(context).tx2
                            : SpaceStyle.of(context).amber,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Container(
                decoration: SpaceStyle.of(context).card(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    for (final (index, field) in fields.indexed) ...[
                      if (index > 0)
                        Divider(height: 1, color: SpaceStyle.of(context).line),
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
                  style: SpaceStyle.of(context).text(15),
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
                      style: SpaceStyle.of(context).text(14.5),
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
              if (_editingField == null) const SizedBox(height: 14),
              if (_editingField == null)
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
        style:
            FilledButton.styleFrom(
              minimumSize: const Size(100, 52),
              backgroundColor: SpaceStyle.of(context).button,
              foregroundColor: SpaceStyle.of(context).tx,
              disabledBackgroundColor: SpaceStyle.of(context).button,
              disabledForegroundColor: SpaceStyle.of(context).tx3,
              shape: const StadiumBorder(),
              elevation: 0,
              textStyle: SpaceStyle.of(context).text(15),
            ).copyWith(
              backgroundBuilder: (_, _, child) =>
                  child ?? const SizedBox.shrink(),
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
      Text(
        label,
        style: SpaceStyle.of(context).text(14.5, SpaceStyle.of(context).tx2),
      ),
      Text(
        value,
        textAlign: TextAlign.right,
        style: SpaceStyle.of(context).text(14.5),
      ),
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
