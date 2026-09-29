import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/inventory_cache.dart';

Future<T?> _optionalRead<T>(Future<T> Function() read) async {
  try {
    return await read();
  } catch (_) {
    return null;
  }
}

Future<void> showItemDetailSheet(
  BuildContext context, {
  required InventoryItem item,
  required ApiClient api,
  String permission = 'edit',
  int? initialThreshold,
  String spaceName = '',
  ValueChanged<int?>? onThresholdChanged,
  VoidCallback? onDeleted,
}) async {
  final deleted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTokens.of(context).bg,
    showDragHandle: true,
    builder: (_) => _ObjectSheet(
      item: item,
      api: api,
      canEdit: permission == 'edit',
      spaceName: spaceName,
      onThresholdChanged: onThresholdChanged,
    ),
  );
  if (deleted == true) onDeleted?.call();
}

class _ObjectData {
  const _ObjectData(
    this.item,
    this.history,
    this.relationships,
    this.documents,
    this.checkouts,
    this.catalog,
    this.compatibility,
  );

  final InventoryItem item;
  final List<Map<String, dynamic>>? history;
  final List<Map<String, dynamic>>? relationships;
  final List<DocumentEntry>? documents;
  final List<Map<String, dynamic>>? checkouts;
  final VerifiedCatalogPart? catalog;
  final CatalogCompatibilityResult? compatibility;

  String? get sourceFrameUrl {
    for (final event in history ?? const <Map<String, dynamic>>[]) {
      if (event['event_type'] == 'photo') {
        final url = event['image_url']?.toString();
        if (url != null && url.isNotEmpty) return url;
      }
    }
    return null;
  }
}

class _ObjectSheet extends StatefulWidget {
  const _ObjectSheet({
    required this.item,
    required this.api,
    required this.canEdit,
    required this.spaceName,
    this.onThresholdChanged,
  });

  final InventoryItem item;
  final ApiClient api;
  final bool canEdit;
  final String spaceName;
  final ValueChanged<int?>? onThresholdChanged;

  @override
  State<_ObjectSheet> createState() => _ObjectSheetState();
}

class _ObjectSheetState extends State<_ObjectSheet> {
  late Future<_ObjectData> _future;
  InventoryItem? _currentItem;
  final _borrower = TextEditingController();
  final _checkoutNote = TextEditingController();
  bool _saving = false;

  Future<void> _delete(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this object?'),
        content: Text('${item.name} will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete object'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final deleted = await widget.api.deleteItem(itemId: item.itemId);
      if (!deleted) throw StateError('The object was not deleted.');
      InventoryCache.removeItem(item.itemId);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showError('Could not delete the object. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _borrower.dispose();
    _checkoutNote.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<_ObjectData> _load() async {
    final item =
        await _optionalRead(() => widget.api.itemDetail(widget.item.itemId)) ??
        _currentItem ??
        widget.item;
    final values = await Future.wait<dynamic>([
      _optionalRead(() => widget.api.itemHistory(widget.item.itemId)),
      _optionalRead(() => widget.api.itemRelationships(widget.item.itemId)),
      _optionalRead(() => widget.api.getDocuments(itemId: widget.item.itemId)),
      _optionalRead(
        () => widget.api.getItemCheckouts(itemId: widget.item.itemId),
      ),
    ]);
    VerifiedCatalogPart? catalog;
    CatalogCompatibilityResult? compatibility;
    if ((item.catalogId ?? '').isNotEmpty) {
      final catalogValues = await Future.wait<dynamic>([
        widget.api
            .getVerifiedCatalogPart(item.catalogId!)
            .then<VerifiedCatalogPart?>((part) => part)
            .catchError((_) => null),
        widget.api
            .getCompatibleCatalogParts(item.catalogId!)
            .then<CatalogCompatibilityResult?>((parts) => parts)
            .catchError((_) => null),
      ]);
      catalog = catalogValues[0] as VerifiedCatalogPart?;
      compatibility = catalogValues[1] as CatalogCompatibilityResult?;
    }
    return _ObjectData(
      item,
      values[0] as List<Map<String, dynamic>>?,
      values[1] as List<Map<String, dynamic>>?,
      values[2] as List<DocumentEntry>?,
      values[3] as List<Map<String, dynamic>>?,
      catalog,
      compatibility,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit(InventoryItem item) async {
    final updated = await Navigator.push<InventoryItem>(
      context,
      MaterialPageRoute(
        builder: (_) => _EditObjectPage(item: item, api: widget.api),
      ),
    );
    if (updated == null || !mounted) return;
    _currentItem = updated;
    if (item.reorderPointAvailable) {
      widget.onThresholdChanged?.call(updated.reorderPoint);
    }
    _refresh();
  }

  Future<void> _attachPhoto(InventoryItem item) async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (photo == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.api.uploadItemPhoto(
        itemId: item.itemId,
        bytes: await photo.readAsBytes(),
        filename: photo.name,
      );
      if (!mounted) return;
      _currentItem = updated;
      _refresh();
    } catch (error) {
      _showError(describeError(error).$1);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _lend(InventoryItem item) async {
    _borrower.clear();
    _checkoutNote.clear();
    final quantity = TextEditingController(text: '1');
    DateTime? due;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Lend object'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _borrower,
                  decoration: const InputDecoration(labelText: 'Who has it?'),
                ),
                TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'How many?'),
                ),
                TextField(
                  controller: _checkoutNote,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: dialogContext,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate:
                          due ?? DateTime.now().add(const Duration(days: 7)),
                    );
                    if (date != null) update(() => due = date);
                  },
                  child: Text(
                    due == null ? 'Set due date' : 'Due ${_date(due!)}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final count = int.tryParse(quantity.text.trim());
                if (_borrower.text.trim().isEmpty ||
                    count == null ||
                    count < 1 ||
                    count > item.quantity) {
                  _showError('Enter a person and an available count.');
                  return;
                }
                try {
                  await widget.api.checkoutItem(
                    itemId: item.itemId,
                    checkedOutBy: _borrower.text.trim(),
                    spaceName: widget.spaceName.isEmpty
                        ? item.location
                        : widget.spaceName,
                    dueBackAt: due?.toIso8601String(),
                    notes: _checkoutNote.text.trim().isEmpty
                        ? null
                        : _checkoutNote.text.trim(),
                    checkoutQuantity: count,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (_) {
                  _showError('Could not lend this object. Try again.');
                }
              },
              child: const Text('Lend'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    quantity.dispose();
    if (saved == true && mounted) _refresh();
  }

  Future<void> _uploadDocument() async {
    final chosen = await FilePicker.platform.pickFiles(withData: true);
    if (chosen == null || chosen.files.isEmpty) return;
    final file = chosen.files.first;
    if (file.bytes == null) {
      _showError('Could not read that file.');
      return;
    }
    try {
      await widget.api.uploadDocument(
        file: dio.MultipartFile.fromBytes(file.bytes!, filename: file.name),
        itemId: widget.item.itemId,
      );
      if (mounted) _refresh();
    } catch (_) {
      _showError('Could not attach the document. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: FutureBuilder<_ObjectData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load this object.'),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              );
            }
            final data = snapshot.data!;
            final item = data.item;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  color: t.ink,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              if ((item.partNumber ?? '').isNotEmpty)
                                Text(
                                  item.partNumber!,
                                  style: TextStyle(
                                    color: t.text2,
                                    fontFamily: 'IBMPlexMono',
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (widget.canEdit)
                          TextButton(
                            onPressed: () => _edit(item),
                            child: const Text('Edit'),
                          ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if ((item.imageUrl ?? '').isNotEmpty) ...[
                          _Photo(
                            url: item.imageUrl,
                            empty: 'Photo unavailable',
                            height: 230,
                          ),
                          if (widget.canEdit)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () => _attachPhoto(item),
                                icon: const Icon(Icons.photo_outlined),
                                label: const Text('Change photo'),
                              ),
                            ),
                        ] else if (widget.canEdit)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _attachPhoto(item),
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                              label: const Text('Add photo'),
                            ),
                          ),
                        if (data.sourceFrameUrl != null) ...[
                          const SizedBox(height: 8),
                          _Photo(
                            url: data.sourceFrameUrl,
                            empty: 'Source frame unavailable',
                            height: 105,
                            label: 'Source frame',
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          inventoryPath(item).isEmpty
                              ? 'No place assigned'
                              : inventoryPath(item),
                          style: TextStyle(color: t.text2, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        _Section(
                          title: 'Stock',
                          rows: [
                            _RowData('In stock', '${item.quantity}'),
                            if (item.reorderPoint != null &&
                                item.reorderPoint! > 0)
                              _RowData('Reorder at', '${item.reorderPoint}'),
                            if (item.reorderPoint != null &&
                                item.quantity < item.reorderPoint!)
                              _RowData(
                                'Stock status',
                                'Running low',
                                warning: true,
                              ),
                          ],
                        ),
                        _Section(
                          title: 'Details',
                          rows: [
                            if ((item.partNumber ?? '').isNotEmpty)
                              _RowData('Part number', item.partNumber!),
                            if ((item.barcode ?? '').isNotEmpty)
                              _RowData('Barcode', item.barcode!),
                            if (item.category.isNotEmpty)
                              _RowData('Kind', item.category),
                            if ((item.namedBy ?? '').isNotEmpty)
                              _RowData(
                                'Named by',
                                '${item.namedBy!.replaceAll('_', ' ')}'
                                    '${item.confidence == null ? '' : ', ${item.confidence!.toStringAsFixed(2)}'}',
                              ),
                            if (item.tags?.isNotEmpty == true)
                              _RowData('Tags', item.tags!.join(', ')),
                          ],
                        ),
                        if (item.catalogId != null) ...[
                          _Section(
                            title: 'Verified catalog',
                            rows: [
                              if (data.catalog != null) ...[
                                _RowData('Manufacturer', data.catalog!.brand),
                                _RowData(
                                  'Part number',
                                  data.catalog!.partNumber,
                                ),
                                if ((data.catalog!.description ?? '')
                                    .isNotEmpty)
                                  _RowData(
                                    'Description',
                                    data.catalog!.description!,
                                  ),
                                for (final entry
                                    in data.catalog!.specifications.entries)
                                  _RowData(
                                    entry.key.replaceAll('_', ' '),
                                    entry.value.toString(),
                                  ),
                                if ((data.catalog!.productUrl ?? '').isNotEmpty)
                                  _RowData(
                                    'Product page',
                                    'Open',
                                    onTap: () => launchUrl(
                                      Uri.parse(data.catalog!.productUrl!),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                          _Section(
                            title: 'Compatible parts',
                            rows: [
                              for (final match
                                  in data.compatibility?.matches ??
                                      const <CompatibleCatalogPart>[])
                                _RowData(
                                  match.name,
                                  match.partNumber,
                                  onTap: match.productUrl == null
                                      ? null
                                      : () => launchUrl(
                                          Uri.parse(match.productUrl!),
                                        ),
                                ),
                            ],
                          ),
                        ],
                        _Section(
                          title: 'Purchase',
                          rows: [
                            if ((item.purchaseSource ?? '').isNotEmpty)
                              _RowData('Bought from', item.purchaseSource!),
                          ],
                        ),
                        _Section(
                          title: 'Note',
                          rows: [
                            if ((item.notes ?? '').isNotEmpty)
                              _RowData('', item.notes!),
                          ],
                        ),
                        if (data.relationships != null)
                          _Section(
                            title: 'Related',
                            rows: [
                              for (final relation in data.relationships!)
                                _RowData(
                                  (relation['other_item'] as Map?)?['name']
                                          ?.toString() ??
                                      (relation['project_kit'] as Map?)?['name']
                                          ?.toString() ??
                                      'Linked record',
                                  (relation['kind'] ?? '')
                                      .toString()
                                      .replaceAll('_', ' '),
                                  onTap: () => _openRelationship(relation),
                                ),
                            ],
                          ),
                        if (data.history != null)
                          _Section(
                            title: 'History',
                            rows: [
                              for (final event in data.history!)
                                _RowData(
                                  _historyTitle(event),
                                  _historyDetail(event),
                                ),
                            ],
                          ),
                        if (data.documents != null)
                          _Section(
                            title: 'Documents',
                            rows: [
                              for (final document in data.documents!)
                                _RowData(
                                  document.displayName ?? document.filename,
                                  _date(document.createdAt),
                                  onTap: document.url == null
                                      ? null
                                      : () =>
                                            launchUrl(Uri.parse(document.url!)),
                                ),
                            ],
                            action: widget.canEdit
                                ? TextButton(
                                    onPressed: _uploadDocument,
                                    child: const Text('Add document'),
                                  )
                                : null,
                          ),
                        if (data.checkouts != null)
                          _Section(
                            title: 'Loans',
                            rows: [
                              for (final checkout in data.checkouts!.where(
                                (entry) => entry['returned_at'] == null,
                              ))
                                _RowData(
                                  '${checkout['checked_out_by'] ?? 'Borrower'}'
                                  '${(checkout['due_back_at'] ?? '').toString().isEmpty ? '' : ', due ${_dateFrom(checkout['due_back_at'])}'}',
                                  widget.canEdit ? 'Return' : 'Lent out',
                                  onTap: widget.canEdit
                                      ? () => _return(checkout)
                                      : null,
                                ),
                            ],
                            action: widget.canEdit && item.quantity > 0
                                ? TextButton(
                                    onPressed: () => _lend(item),
                                    child: const Text('Lend'),
                                  )
                                : null,
                          ),
                        if (widget.canEdit) ...[
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: _saving ? null : () => _delete(item),
                            child: Text(
                              'Delete object',
                              style: TextStyle(color: t.danger),
                            ),
                          ),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openRelationship(Map<String, dynamic> relation) async {
    final other = relation['other_item'];
    if (other is! Map || other['item_id'] == null) return;
    try {
      final item = await widget.api.itemDetail(other['item_id'].toString());
      if (mounted) {
        await showItemDetailSheet(
          context,
          item: item,
          api: widget.api,
          permission: widget.canEdit ? 'edit' : 'view',
        );
      }
    } catch (_) {
      _showError('Could not open that object.');
    }
  }

  Future<void> _return(Map<String, dynamic> checkout) async {
    final id =
        checkout['id']?.toString() ?? checkout['checkout_id']?.toString();
    if (id == null) return;
    setState(() => _saving = true);
    try {
      await widget.api.returnItem(checkoutId: id);
      if (mounted) _refresh();
    } catch (_) {
      _showError('Could not record the return. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _EditObjectPage extends StatefulWidget {
  const _EditObjectPage({required this.item, required this.api});

  final InventoryItem item;
  final ApiClient api;

  @override
  State<_EditObjectPage> createState() => _EditObjectPageState();
}

class _EditObjectPageState extends State<_EditObjectPage> {
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _quantity;
  late final TextEditingController _reorder;
  late final TextEditingController _supplier;
  late final TextEditingController _note;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item.name);
    _barcode = TextEditingController(text: item.barcode ?? '');
    _quantity = TextEditingController(text: item.quantity.toString());
    _reorder = TextEditingController(text: item.reorderPoint?.toString() ?? '');
    _supplier = TextEditingController(text: item.purchaseSource ?? '');
    _note = TextEditingController(text: item.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _quantity.dispose();
    _reorder.dispose();
    _supplier.dispose();
    _note.dispose();
    super.dispose();
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _save() async {
    if (_saving) return;
    final count = int.tryParse(_quantity.text.trim());
    final threshold = !widget.item.reorderPointAvailable
        ? null
        : _reorder.text.trim().isEmpty
        ? 0
        : int.tryParse(_reorder.text.trim());
    if (_name.text.trim().isEmpty ||
        count == null ||
        count < 0 ||
        (widget.item.reorderPointAvailable &&
            (threshold == null || threshold < 0))) {
      _message('Enter a name and valid stock numbers.');
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await widget.api.updateItem(
        request: UpdateItemRequest(
          itemId: widget.item.itemId,
          name: _name.text.trim(),
          barcode: _barcode.text.trim(),
          quantity: count,
          reorderPoint: threshold,
          purchaseSource: _supplier.text.trim(),
          notes: _note.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (error) {
      if (mounted) _message(describeError(error).$1);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textInputAction: maxLines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Edit object'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving' : 'Save'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              _field('Name', _name),
              _field('Barcode', _barcode),
              _field('In stock', _quantity, keyboardType: TextInputType.number),
              if (widget.item.reorderPointAvailable)
                _field(
                  'Reorder at',
                  _reorder,
                  keyboardType: TextInputType.number,
                ),
              _field('Bought from', _supplier),
              _field('Note', _note, maxLines: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({
    required this.url,
    required this.empty,
    required this.height,
    this.label,
  });

  final String? url;
  final String empty;
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: height,
        color: t.card,
        child: (url ?? '').isEmpty
            ? Center(
                child: Text(empty, style: TextStyle(color: t.text2)),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    url!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Text(
                        'Photo unavailable',
                        style: TextStyle(color: t.text2),
                      ),
                    ),
                  ),
                  if (label != null)
                    Positioned(
                      left: 12,
                      bottom: 10,
                      child: Text(
                        label!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _RowData {
  const _RowData(this.label, this.value, {this.warning = false, this.onTap});
  final String label;
  final String value;
  final bool warning;
  final VoidCallback? onTap;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows, this.action});
  final String title;
  final List<_RowData> rows;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty && action == null) return const SizedBox.shrink();
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: t.text2,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: t.card,
                child: Column(
                  children: [
                    for (var index = 0; index < rows.length; index++) ...[
                      if (index > 0)
                        Divider(
                          height: 1,
                          color: t.separator,
                          indent: 16,
                          endIndent: 16,
                        ),
                      InkWell(
                        onTap: rows[index].onTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              if (rows[index].label.isNotEmpty) ...[
                                Expanded(
                                  child: Text(
                                    rows[index].label,
                                    style: TextStyle(
                                      color: t.ink,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Flexible(
                                child: Text(
                                  rows[index].value,
                                  textAlign: rows[index].label.isEmpty
                                      ? TextAlign.left
                                      : TextAlign.right,
                                  style: TextStyle(
                                    color: rows[index].warning
                                        ? t.warn
                                        : t.text2,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String inventoryPath(InventoryItem item) {
  final parts =
      [
            item.workspaceName,
            item.spaceName ?? item.location,
            item.binName,
            item.container,
          ]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty);
  return parts.join(' / ');
}

String _historyTitle(Map<String, dynamic> event) {
  final after = event['quantity_after'];
  final before = event['quantity_before'];
  if (after != null && before != null) return 'Count $before to $after';
  return (event['event_type'] ?? 'Change').toString().replaceAll('_', ' ');
}

String _historyDetail(Map<String, dynamic> event) {
  final parts = <String>[
    if (event['cause'] != null) event['cause'].toString(),
    if (event['actor_display_name'] != null)
      event['actor_display_name'].toString(),
    if (event['created_at'] != null) _dateFrom(event['created_at']),
  ];
  return parts.join(' · ');
}

String _dateFrom(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed == null ? 'Date unavailable' : _date(parsed.toLocal());
}

String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
