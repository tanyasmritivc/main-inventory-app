import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/inventory_cache.dart';

class ConfirmScanSheet extends StatefulWidget {
  const ConfirmScanSheet({
    super.key,
    required this.items,
    required this.defaultLocation,
  });

  final List<ExtractedInventoryItem> items;
  final String defaultLocation;

  @override
  State<ConfirmScanSheet> createState() => _ConfirmScanSheetState();
}

class _ConfirmScanSheetState extends State<ConfirmScanSheet> {
  late final List<TextEditingController> _names;
  late final List<TextEditingController> _places;
  late final List<TextEditingController> _brands;
  late final List<TextEditingController> _parts;
  late final List<TextEditingController> _barcodes;
  late final List<TextEditingController> _categories;
  late final List<int> _quantities;

  @override
  void initState() {
    super.initState();
    _names = widget.items
        .map((item) => TextEditingController(text: item.name))
        .toList();
    _brands = widget.items
        .map((item) => TextEditingController(text: item.brand ?? ''))
        .toList();
    _parts = widget.items
        .map((item) => TextEditingController(text: item.partNumber ?? ''))
        .toList();
    _barcodes = widget.items
        .map((item) => TextEditingController(text: item.barcode ?? ''))
        .toList();
    _categories = widget.items
        .map((item) => TextEditingController(text: item.category))
        .toList();
    _places = widget.items.map((item) {
      final extracted = (item.location ?? '').trim();
      return TextEditingController(
        text: extracted.isEmpty || extracted.toLowerCase() == 'unsorted'
            ? widget.defaultLocation
            : extracted,
      );
    }).toList();
    _quantities = widget.items
        .map((item) => item.quantity.clamp(1, 9999))
        .toList();
  }

  @override
  void dispose() {
    for (final controller in [
      ..._names,
      ..._places,
      ..._brands,
      ..._parts,
      ..._barcodes,
      ..._categories,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  InventoryItem? _match(int index) {
    final query = _names[index].text.trim().toLowerCase();
    if (query.isEmpty) return null;
    for (final item in InventoryCache.items) {
      if (item.name.toLowerCase() == query) return item;
    }
    return null;
  }

  Future<void> _chooseMatch(int index) async {
    final selected = await showModalBottomSheet<InventoryItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ExistingItemPicker(
        items: InventoryCache.items,
        query: _names[index].text,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _names[index].text = selected.name);
  }

  List<ExtractedInventoryItem> _result() =>
      List.generate(widget.items.length, (index) {
        final original = widget.items[index];
        String? optional(TextEditingController controller) {
          final value = controller.text.trim();
          return value.isEmpty ? null : value;
        }

        return ExtractedInventoryItem(
          name: _names[index].text.trim(),
          category: optional(_categories[index]) ?? 'Other',
          quantity: _quantities[index],
          subcategory: original.subcategory,
          brand: optional(_brands[index]),
          partNumber: optional(_parts[index]),
          barcode: optional(_barcodes[index]),
          tags: original.tags,
          confidence: original.confidence,
          imageUrl: original.imageUrl,
          sourceFrameUrl: original.sourceFrameUrl,
          notes: original.notes,
          location: optional(_places[index]) ?? 'Unsorted',
          catalogMatch: original.catalogMatch,
          scanEvidence: original.scanEvidence,
        );
      });

  void _confirm() {
    if (_names.any((controller) => controller.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name each object before saving.')),
      );
      return;
    }
    Navigator.pop(context, _result());
  }

  Future<void> _openSource(String? rawUrl) async {
    final uri = Uri.tryParse(rawUrl ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the manufacturer page.')),
      );
    }
  }

  Widget _field(String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _image(String? url, String label) {
    final t = AppTokens.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: t.text2, fontSize: 12)),
          const SizedBox(height: 6),
          AspectRatio(
            aspectRatio: 1.2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radius),
              child: url == null || url.isEmpty
                  ? ColoredBox(
                      color: t.raised,
                      child: Center(
                        child: Text(
                          'No image',
                          style: TextStyle(color: t.text2),
                        ),
                      ),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: t.raised,
                        child: Center(
                          child: Text(
                            'Image unavailable',
                            style: TextStyle(color: t.text2),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _evidence(ExtractedInventoryItem item) {
    final t = AppTokens.of(context);
    final evidence = item.scanEvidence;
    final facts = <String>[
      if (item.confidence != null)
        'Identity ${(item.confidence! * 100).round()}%',
      if (evidence?.detectionConfidence != null)
        'Detection ${(evidence!.detectionConfidence! * 100).round()}%',
      if (evidence?.hasDimensions == true)
        'Measured ${evidence!.lengthMm} x ${evidence.widthMm} mm',
      if (evidence?.barcodeSymbology?.isNotEmpty == true)
        'Barcode ${evidence!.barcodeSymbology}',
    ];
    if (facts.isEmpty &&
        evidence?.identificationReasoning == null &&
        evidence?.ocrText == null) {
      return const SizedBox.shrink();
    }
    return Material(
      color: t.card,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text('What it read', style: TextStyle(color: t.ink)),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final fact in facts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(fact, style: TextStyle(color: t.text2)),
                  ),
                if (evidence?.identificationReasoning?.isNotEmpty == true)
                  Text(
                    evidence!.identificationReasoning!,
                    style: TextStyle(color: t.text2),
                  ),
                if (evidence?.ocrText?.isNotEmpty == true)
                  Text(
                    'Text read: ${evidence!.ocrText}',
                    style: TextStyle(color: t.text2),
                  ),
                if (evidence?.measurementAssumption?.isNotEmpty == true)
                  Text(
                    evidence!.measurementAssumption!,
                    style: TextStyle(color: t.warn),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _objectCard(int index) {
    final t = AppTokens.of(context);
    final original = widget.items[index];
    final match = _match(index);
    final catalog = original.catalogMatch;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: t.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          side: BorderSide(color: t.separator),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Object ${index + 1}',
                      style: TextStyle(color: t.ink, fontSize: 18),
                    ),
                  ),
                  if (catalog?.verified == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: t.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Match',
                        style: TextStyle(color: t.onAccent, fontSize: 12),
                      ),
                    ),
                  if (original.scanEvidence?.needsReview == true)
                    Text(
                      'Review',
                      style: TextStyle(color: t.warn, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _image(original.sourceFrameUrl, 'Source photo'),
                  const SizedBox(width: 8),
                  _image(original.imageUrl, 'Object crop'),
                ],
              ),
              const SizedBox(height: 14),
              _field('Name', _names[index]),
              TextButton(
                onPressed: () => _chooseMatch(index),
                child: Text(
                  match == null
                      ? 'Match to an existing object'
                      : 'Matches ${match.name}',
                ),
              ),
              _field('Place', _places[index]),
              Row(
                children: [
                  Text('Count', style: TextStyle(color: t.ink)),
                  const Spacer(),
                  TextButton(
                    onPressed: _quantities[index] > 1
                        ? () => setState(() => _quantities[index]--)
                        : null,
                    child: const Text('Less'),
                  ),
                  Text('${_quantities[index]}', style: TextStyle(color: t.ink)),
                  TextButton(
                    onPressed: () => setState(() => _quantities[index]++),
                    child: const Text('More'),
                  ),
                ],
              ),
              Material(
                color: t.card,
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('More details'),
                  children: [
                    _field('Category', _categories[index]),
                    _field('Manufacturer', _brands[index]),
                    _field('Part or model number', _parts[index]),
                    _field('Barcode', _barcodes[index]),
                    if (catalog?.productUrl?.isNotEmpty == true)
                      TextButton(
                        onPressed: () => _openSource(catalog?.productUrl),
                        child: const Text('View manufacturer source'),
                      ),
                  ],
                ),
              ),
              _evidence(original),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final count = widget.items.length;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.94,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review what was found',
                    style: TextStyle(color: t.ink, fontSize: 25),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check each object before saving.',
                    style: TextStyle(color: t.text2),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                itemCount: count,
                itemBuilder: (_, index) => _objectCard(index),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: count == 0 ? null : _confirm,
                    child: Text(
                      'Save $count ${count == 1 ? 'object' : 'objects'}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExistingItemPicker extends StatefulWidget {
  const _ExistingItemPicker({required this.items, required this.query});

  final List<InventoryItem> items;
  final String query;

  @override
  State<_ExistingItemPicker> createState() => _ExistingItemPickerState();
}

class _ExistingItemPickerState extends State<_ExistingItemPicker> {
  late final TextEditingController _search = TextEditingController(
    text: widget.query,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final query = _search.text.trim().toLowerCase();
    final matches = widget.items
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Search existing objects',
                ),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text(
                        'No matching objects.',
                        style: TextStyle(color: t.text2),
                      ),
                    )
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(matches[index].name),
                        subtitle: Text(matches[index].category),
                        onTap: () => Navigator.pop(context, matches[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
