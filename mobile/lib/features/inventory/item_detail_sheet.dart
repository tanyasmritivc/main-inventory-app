import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';

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
}) => showModalBottomSheet<void>(
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
  final _borrower = TextEditingController();
  final _checkoutNote = TextEditingController();
  bool _saving = false;

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
    final item = await widget.api.itemDetail(widget.item.itemId);
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
    final name = TextEditingController(text: item.name);
    final barcode = TextEditingController(text: item.barcode ?? '');
    final quantity = TextEditingController(text: item.quantity.toString());
    final reorder = TextEditingController(
      text: item.reorderPoint?.toString() ?? '',
    );
    final note = TextEditingController(text: item.notes ?? '');
    final supplier = TextEditingController(text: item.purchaseSource ?? '');
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit object'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: barcode,
                decoration: const InputDecoration(labelText: 'Barcode'),
              ),
              TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'In stock'),
              ),
              if (item.reorderPointAvailable)
                TextField(
                  controller: reorder,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reorder at'),
                ),
              TextField(
                controller: supplier,
                decoration: const InputDecoration(labelText: 'Bought from'),
              ),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Note'),
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
            onPressed: _saving
                ? null
                : () async {
                    final count = int.tryParse(quantity.text.trim());
                    final threshold = !item.reorderPointAvailable
                        ? null
                        : reorder.text.trim().isEmpty
                        ? 0
                        : int.tryParse(reorder.text.trim());
                    if (name.text.trim().isEmpty ||
                        count == null ||
                        count < 0 ||
                        (item.reorderPointAvailable &&
                            (threshold == null || threshold < 0))) {
                      _showError('Enter a name and valid stock numbers.');
                      return;
                    }
                    try {
                      await widget.api.updateItem(
                        request: UpdateItemRequest(
                          itemId: item.itemId,
                          name: name.text.trim(),
                          barcode: barcode.text.trim(),
                          quantity: count,
                          reorderPoint: threshold,
                          purchaseSource: supplier.text.trim(),
                          notes: note.text.trim(),
                        ),
                      );
                      if (item.reorderPointAvailable) {
                        widget.onThresholdChanged?.call(
                          threshold == 0 ? null : threshold,
                        );
                      }
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (_) {
                      _showError('Could not save the object. Try again.');
                    }
                  },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Dialog TextFields can remain mounted during the closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    barcode.dispose();
    quantity.dispose();
    reorder.dispose();
    note.dispose();
    supplier.dispose();
    if (changed == true && mounted) _refresh();
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
                        _Photo(
                          url: item.imageUrl,
                          empty: 'No object photo yet',
                          height: 230,
                        ),
                        const SizedBox(height: 8),
                        _Photo(
                          url: data.sourceFrameUrl,
                          empty: 'No source frame yet',
                          height: 105,
                          label: 'Source frame',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          inventoryPath(item).isEmpty
                              ? 'No place assigned'
                              : inventoryPath(item),
                          style: TextStyle(color: t.text2, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        _Section(
                          title: 'How many',
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
                          title: 'What it is',
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
                            empty: 'Catalog details unavailable.',
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
                            empty: 'No compatible parts recorded.',
                          ),
                        ],
                        _Section(
                          title: 'What it cost',
                          rows: [
                            if ((item.purchaseSource ?? '').isNotEmpty)
                              _RowData('Bought from', item.purchaseSource!),
                          ],
                          empty: 'No purchase details recorded.',
                        ),
                        _Section(
                          title: 'Note',
                          rows: [
                            if ((item.notes ?? '').isNotEmpty)
                              _RowData('', item.notes!),
                          ],
                          empty: 'No note yet.',
                        ),
                        if (data.relationships != null)
                          _Section(
                            title: 'Connects to',
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
                            empty: 'No connections recorded.',
                          ),
                        if (data.history != null)
                          _Section(
                            title: 'What has happened to it',
                            rows: [
                              for (final event in data.history!)
                                _RowData(
                                  _historyTitle(event),
                                  _historyDetail(event),
                                ),
                            ],
                            empty: 'No history recorded.',
                          ),
                        if (data.documents != null)
                          _Section(
                            title: 'Paper',
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
                            empty: 'No documents attached.',
                            action: widget.canEdit
                                ? TextButton(
                                    onPressed: _uploadDocument,
                                    child: const Text('Add paper'),
                                  )
                                : null,
                          ),
                        if (data.checkouts != null)
                          _Section(
                            title: 'Lent out',
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
                            empty: 'Nothing is lent out.',
                            action: widget.canEdit && item.quantity > 0
                                ? TextButton(
                                    onPressed: () => _lend(item),
                                    child: const Text('Lend'),
                                  )
                                : null,
                          ),
                        const SizedBox(height: 100),
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
  const _Section({
    required this.title,
    required this.rows,
    this.empty,
    this.action,
  });
  final String title;
  final List<_RowData> rows;
  final String? empty;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              color: t.card,
              child: rows.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        empty ?? 'Nothing recorded yet.',
                        style: TextStyle(color: t.text2, fontSize: 15),
                      ),
                    )
                  : Column(
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
