import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/inventory_cache.dart';

const _kLabelStyle = TextStyle(
  color: Color(0xFF8E8E93),
  fontSize: 11,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.6,
);

/// Bottom sheet that lets the user review and edit AI-detected items
/// before they are saved. Returns [List<ExtractedInventoryItem>] on confirm,
/// or null on cancel.
class ConfirmScanSheet extends StatefulWidget {
  const ConfirmScanSheet({
    super.key,
    required this.items,
    required this.defaultLocation,
  });

  final List<ExtractedInventoryItem> items;
  /// The space the user selected before opening this sheet; used as the
  /// initial value for each item's Location field so the user sees their
  /// chosen space rather than the AI-extracted default ("Unsorted").
  final String defaultLocation;

  @override
  State<ConfirmScanSheet> createState() => _ConfirmScanSheetState();
}

class _ConfirmScanSheetState extends State<ConfirmScanSheet> {
  late final List<TextEditingController> _nameCtrl;
  late final List<TextEditingController> _locCtrl;
  late final List<TextEditingController> _brandCtrl;
  late final List<TextEditingController> _partNumberCtrl;
  late final List<TextEditingController> _categoryCtrl;
  late final List<FocusNode> _nameFocus;
  late final List<int> _qty;
  final List<InventoryItem> _existing = InventoryCache.items;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        widget.items.map((it) => TextEditingController(text: it.name)).toList();
    _brandCtrl = widget.items.map((it) => TextEditingController(text: it.brand ?? '')).toList();
    _partNumberCtrl = widget.items.map((it) => TextEditingController(text: it.partNumber ?? '')).toList();
    _categoryCtrl = widget.items.map((it) => TextEditingController(text: it.category)).toList();
    _locCtrl = widget.items.map((it) {
      final loc = (it.location ?? '').trim();
      // Use the user's chosen space as the default; only fall back to the
      // AI-extracted location if it's a non-trivial, non-default value.
      final isAiDefault = loc.isEmpty || loc.toLowerCase() == 'unsorted';
      return TextEditingController(
        text: isAiDefault ? widget.defaultLocation : loc,
      );
    }).toList();
    _nameFocus = List.generate(widget.items.length, (_) => FocusNode());
    _qty = widget.items
        .map((it) => it.quantity.clamp(1, 9999))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _nameCtrl) {
      c.dispose();
    }
    for (final c in _locCtrl) {
      c.dispose();
    }
    for (final c in [..._brandCtrl, ..._partNumberCtrl, ..._categoryCtrl]) {
      c.dispose();
    }
    for (final f in _nameFocus) {
      f.dispose();
    }
    super.dispose();
  }

  InventoryItem? _autoMatch(int i) {
    final q = _nameCtrl[i].text.toLowerCase().trim();
    if (q.isEmpty) return null;
    final qWords = q.split(RegExp(r'\s+'));
    for (final item in _existing) {
      final n = item.name.toLowerCase();
      // Full-string containment: existing name contains entire query string.
      if (n.contains(q)) return item;
      // Whole-word-sequence match: every word in n appears consecutively in q.
      // This prevents "table" matching "vegetable" via substring.
      final nWords = n.split(RegExp(r'\s+'));
      if (_wordSeqContains(qWords, nWords)) return item;
    }
    return null;
  }

  /// Returns true if [needle] appears as a consecutive whole-word sequence
  /// inside [haystack].
  bool _wordSeqContains(List<String> haystack, List<String> needle) {
    if (needle.isEmpty || needle.length > haystack.length) return false;
    outer:
    for (int i = 0; i <= haystack.length - needle.length; i++) {
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  Future<void> _pickExisting(int i) async {
    final picked = await showModalBottomSheet<InventoryItem>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ExistingItemPicker(
        existingItems: _existing,
        initialQuery: _nameCtrl[i].text,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _nameCtrl[i].text = picked.name);
    }
  }

  List<ExtractedInventoryItem> _buildResult() {
    return List.generate(widget.items.length, (i) {
      final orig = widget.items[i];
      return ExtractedInventoryItem(
        name: _nameCtrl[i].text.trim(),
        category: _categoryCtrl[i].text.trim().isEmpty ? 'Other' : _categoryCtrl[i].text.trim(),
        quantity: _qty[i],
        subcategory: orig.subcategory,
        brand: _brandCtrl[i].text.trim().isEmpty ? null : _brandCtrl[i].text.trim(),
        partNumber: _partNumberCtrl[i].text.trim().isEmpty ? null : _partNumberCtrl[i].text.trim(),
        barcode: orig.barcode,
        tags: orig.tags,
        confidence: orig.confidence,
        notes: orig.notes,
        location: _locCtrl[i].text.trim().isEmpty
            ? 'Unsorted'
            : _locCtrl[i].text.trim(),
        catalogMatch: orig.catalogMatch,
      );
    });
  }

  Widget _detailField(String label, TextEditingController controller, String hint) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _kLabelStyle),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x14000000), width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Colors.black, fontSize: 13),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0x33000000), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _catalogValues(Map<String, dynamic> metadata) {
    final values = <String>[];
    for (final value in metadata.values) {
      if (value is List) {
        values.addAll(value.map((entry) => entry.toString()));
      } else if (value != null && value.toString().trim().isNotEmpty) {
        values.add(value.toString());
      }
    }
    return values;
  }

  Future<void> _openManufacturerPage(String? rawUrl) async {
    final uri = Uri.tryParse(rawUrl ?? '');
    if (uri == null || uri.scheme != 'https' || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the manufacturer page.')),
      );
    }
  }

  Widget _buildCard(int i) {
    final match = _autoMatch(i);
    final catalog = widget.items[i].catalogMatch;
    final isVerified = catalog?.verified == true;
    final specificationSummary = catalog?.specifications.values
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .take(3)
        .join(' • ');
    final compatibility = _catalogValues(catalog?.compatibility ?? const {});
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14000000), width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: label + "Can't read?" pill
          Row(
            children: [
              const Text('ITEM NAME', style: _kLabelStyle),
              if (isVerified) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x1A30D158),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0x5530D158), width: 0.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, color: Color(0xFF30D158), size: 13),
                      SizedBox(width: 4),
                      Text('Verified', style: TextStyle(color: Color(0xFF30D158), fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() => _nameCtrl[i].clear());
                  _nameFocus[i].requestFocus();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(99),
                    border:
                        Border.all(color: const Color(0x14000000), width: 0.5),
                  ),
                  child: const Text(
                    "Can't read?",
                    style: TextStyle(color: Color(0xFF636366), fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Name text field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x14000000), width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _nameCtrl[i],
              focusNode: _nameFocus[i],
              textInputAction: TextInputAction.next,
              style: const TextStyle(
                  color: Colors.black, fontSize: 14, height: 1.5),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Item name',
                hintStyle:
                    TextStyle(color: Color(0x33000000), fontSize: 14),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          // Match to existing row
          GestureDetector(
            onTap: () => _pickExisting(i),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0x14000000), width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      match != null
                          ? 'Match found: ${match.name}'
                          : 'Match to existing item?',
                      style: TextStyle(
                        color: match != null
                            ? const Color(0xFF636366)
                            : const Color(0x33000000),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Color(0x33000000), size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailField('MANUFACTURER', _brandCtrl[i], 'Unknown'),
              const SizedBox(width: 12),
              _detailField('PART / MODEL #', _partNumberCtrl[i], 'Not visible'),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            _detailField('CATEGORY', _categoryCtrl[i], 'Robot Parts'),
          ]),
          if (isVerified) ...[
            const SizedBox(height: 12),
            Text(
              specificationSummary == null || specificationSummary.isEmpty
                  ? 'Matched against the manufacturer catalog.'
                  : 'Manufacturer specifications: $specificationSummary',
              style: const TextStyle(color: Color(0x9930D158), fontSize: 12, height: 1.35),
            ),
            if (compatibility.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('VERIFIED COMPATIBILITY', style: _kLabelStyle),
              const SizedBox(height: 7),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: compatibility.map((value) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x1230D158),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x3330D158), width: 0.5),
                  ),
                  child: Text(value, style: const TextStyle(color: Color(0xCC30D158), fontSize: 11)),
                )).toList(),
              ),
            ],
            if (catalog?.productUrl?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _openManufacturerPage(catalog?.productUrl),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new_rounded, color: Color(0xFF30D158), size: 14),
                    SizedBox(width: 5),
                    Text('View manufacturer source', style: TextStyle(color: Color(0xFF30D158), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          // QUANTITY label
          const Text('QUANTITY', style: _kLabelStyle),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  if (_qty[i] > 1) setState(() => _qty[i]--);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0x14000000), width: 0.5),
                  ),
                  child: const Icon(Icons.remove,
                      color: Color(0xFF636366), size: 18),
                ),
              ),
              const SizedBox(width: 24),
              Text(
                '${_qty[i]}',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () => setState(() => _qty[i]++),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0x14000000), width: 0.5),
                  ),
                  child: const Icon(Icons.add,
                      color: Color(0xFF636366), size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // LOCATION label
          const Text('LOCATION', style: _kLabelStyle),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x14000000), width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _locCtrl[i],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              style: const TextStyle(
                  color: Colors.black, fontSize: 14, height: 1.5),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Unsorted',
                hintStyle:
                    TextStyle(color: Color(0x33000000), fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F8FA),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border(
            top: BorderSide(color: Color(0x14000000), width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x33000000),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Confirm Items',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Review what AI found before saving.',
                    style: TextStyle(color: Color(0xFF636366), fontSize: 13),
                  ),
                ],
              ),
            ),
            // Scrollable item cards
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                itemCount: n,
                itemBuilder: (_, i) => _buildCard(i),
              ),
            ),
            // Fixed bottom bar
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0x14000000), width: 0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).pop(_buildResult()),
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Center(
                        child: Text(
                          'Confirm & Save $n ${n == 1 ? 'Item' : 'Items'}',
                          style: const TextStyle(
                            color: Color(0xFFF4F4F6),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(null),
                    child: const Center(
                      child: Text(
                        'Cancel',
                        style:
                            TextStyle(color: Color(0xFF636366), fontSize: 15),
                      ),
                    ),
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

/// Modal search + list for picking an existing inventory item by name.
class _ExistingItemPicker extends StatefulWidget {
  const _ExistingItemPicker({
    required this.existingItems,
    required this.initialQuery,
  });

  final List<InventoryItem> existingItems;
  final String initialQuery;

  @override
  State<_ExistingItemPicker> createState() => _ExistingItemPickerState();
}

class _ExistingItemPickerState extends State<_ExistingItemPicker> {
  late final TextEditingController _search;
  late List<InventoryItem> _filtered;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery);
    _filter(widget.initialQuery);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      _filtered = lower.isEmpty
          ? widget.existingItems
          : widget.existingItems
              .where((it) => it.name.toLowerCase().contains(lower))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F8FA),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border(
            top: BorderSide(color: Color(0x14000000), width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x33000000),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0x14000000), width: 0.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: TextField(
                  controller: _search,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search existing items…',
                    hintStyle:
                        TextStyle(color: Color(0x33000000), fontSize: 14),
                    prefixIcon: Icon(Icons.search,
                        color: Color(0x33000000), size: 18),
                  ),
                  onChanged: _filter,
                ),
              ),
            ),
            Flexible(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No items found',
                          style: TextStyle(
                              color: Color(0xFF8E8E93), fontSize: 14),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: Color(0x14000000),
                        indent: 16,
                        endIndent: 16,
                      ),
                      itemBuilder: (_, i) {
                        final item = _filtered[i];
                        return GestureDetector(
                          onTap: () => Navigator.of(context).pop(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(
                                        color: Colors.black, fontSize: 14),
                                  ),
                                ),
                                Text(
                                  item.category,
                                  style: const TextStyle(
                                      color: Color(0xFF8E8E93), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
