import 'package:mobile/core/private_image.dart';
import 'package:mobile/core/ui/glass_control.dart';
import '../../core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/inventory_cache.dart';
import 'scan_evidence_panel.dart';
import 'package:mobile/core/ui/app_text.dart';

TextStyle _kLabelStyle(BuildContext context) => TextStyle(
  color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
  fontSize: 11,
  fontWeight: FontWeight.w400,
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
    this.existingItems,
  });

  final List<ExtractedInventoryItem> items;

  /// The space the user selected before opening this sheet; used as the
  /// initial value for each item's Location field so the user sees their
  /// chosen space rather than the AI-extracted default ("Unsorted").
  final String defaultLocation;
  final List<InventoryItem>? existingItems;

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
  late final List<bool> _quantityConfirmed;
  late final List<TextEditingController> _quantityCtrl;
  late final List<TextEditingController> _unitCtrl;
  late final List<InventoryItem> _existing =
      widget.existingItems ?? InventoryCache.items;

  @override
  void initState() {
    super.initState();
    _nameCtrl = widget.items
        .map((it) => TextEditingController(text: it.name))
        .toList();
    _brandCtrl = widget.items
        .map((it) => TextEditingController(text: it.brand ?? ''))
        .toList();
    _partNumberCtrl = widget.items
        .map((it) => TextEditingController(text: it.partNumber ?? ''))
        .toList();
    _categoryCtrl = widget.items
        .map((it) => TextEditingController(text: it.category))
        .toList();
    _locCtrl = widget.items
        .map(
          (it) => TextEditingController(
            text: widget.defaultLocation.trim().isNotEmpty
                ? widget.defaultLocation
                : (it.location ?? 'Unsorted'),
          ),
        )
        .toList();
    _nameFocus = List.generate(widget.items.length, (_) => FocusNode());
    _qty = widget.items.map((it) => it.quantity.clamp(0, 100000)).toList();
    _quantityConfirmed = widget.items
        .map((it) => it.scanEvidence?.quantityMissing != true)
        .toList();
    _unitCtrl = widget.items
        .map(
          (item) => TextEditingController(
            text: item.scanEvidence?.quantityUnit ?? 'item',
          ),
        )
        .toList();
    _quantityCtrl = widget.items
        .asMap()
        .entries
        .map(
          (entry) => TextEditingController(
            text: _quantityConfirmed[entry.key] ? '${_qty[entry.key]}' : '',
          ),
        )
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
    for (final c in [
      ..._brandCtrl,
      ..._partNumberCtrl,
      ..._categoryCtrl,
      ..._quantityCtrl,
      ..._unitCtrl,
    ]) {
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

  bool _needsReview(int i) {
    final original = widget.items[i];
    final name = _nameCtrl[i].text.trim();
    final unknownName = RegExp(
      r'^(unknown|unidentified|unrecognized)( item| object)?$',
      caseSensitive: false,
    ).hasMatch(name);
    final weakUneditedIdentity =
        (original.scanEvidence?.identityConfidence ?? 1) < 0.5 &&
        name == original.name.trim();
    return !_quantityConfirmed[i] || unknownName || weakUneditedIdentity;
  }

  String? _savedNotes(int i) {
    final orig = widget.items[i];
    final notes = [
      if (!_quantityConfirmed[i]) 'Quantity has not been counted yet.',
      if (_unitCtrl[i].text.trim().isNotEmpty)
        'Quantity unit: ${_unitCtrl[i].text.trim()}.',
      if (orig.notes?.isNotEmpty == true) orig.notes!,
    ].join(' ');
    return notes.isEmpty
        ? null
        : notes.substring(0, notes.length.clamp(0, 2000));
  }

  List<ExtractedInventoryItem> _buildResult() {
    return List.generate(widget.items.length, (i) {
      final orig = widget.items[i];
      return ExtractedInventoryItem(
        name: _nameCtrl[i].text.trim(),
        category: _categoryCtrl[i].text.trim().isEmpty
            ? 'Other'
            : _categoryCtrl[i].text.trim(),
        quantity: _qty[i],
        subcategory: orig.subcategory,
        brand: _brandCtrl[i].text.trim().isEmpty
            ? null
            : _brandCtrl[i].text.trim(),
        partNumber: _partNumberCtrl[i].text.trim().isEmpty
            ? null
            : _partNumberCtrl[i].text.trim(),
        barcode: orig.barcode,
        tags: orig.tags,
        confidence: orig.confidence,
        imageUrl: orig.imageUrl,
        sourceFrameUrl: orig.sourceFrameUrl,
        notes: _savedNotes(i),
        location: _locCtrl[i].text.trim().isEmpty
            ? 'Unsorted'
            : _locCtrl[i].text.trim(),
        catalogMatch: orig.catalogMatch,
        scanEvidence: orig.scanEvidence == null
            ? null
            : ScanEvidence.fromJson({
                ...(_quantityConfirmed[i]
                        ? orig.scanEvidence!.confirmedQuantity()
                        : orig.scanEvidence!)
                    .toJson(),
                'needs_review': _needsReview(i),
                'quantity_unit': _unitCtrl[i].text.trim(),
              }),
        reviewId: orig.reviewId,
        reviewStatus: orig.reviewStatus,
        reviewToken: orig.reviewToken,
      );
    });
  }

  Widget _detailField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(label, style: _kLabelStyle(context)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.adaptive(context, const Color(0xFF171717)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.next,
              style: AppTypography.bodyStyleOf(
                context,
                TextStyle(
                  color: AppTheme.foreground(context, Colors.white),
                  fontSize: 13,
                ),
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppTypography.bodyStyleOf(
                  context,
                  TextStyle(
                    color: AppTheme.foreground(context, Color(0x33FFFFFF)),
                    fontSize: 13,
                  ),
                ),
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
    if (uri == null ||
        uri.scheme != 'https' ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Could not open the manufacturer page.'),
        ),
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
        color: AppTheme.adaptive(context, const Color(0xFF171717)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((widget.items[i].imageUrl ?? '').trim().isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: PrivateImage(
                  widget.items[i].imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppTheme.adaptive(context, const Color(0xFF202020)),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppTheme.foreground(context, Color(0x55FFFFFF)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          // Row 1: label + "Can't read?" pill
          Row(
            children: [
              AppText('ITEM NAME', style: _kLabelStyle(context)),
              if (isVerified) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.adaptive(context, const Color(0x1A30D158)),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: AppTheme.adaptive(
                        context,
                        const Color(0x5530D158),
                      ),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: AppTheme.foreground(context, Color(0xFF30D158)),
                        size: 13,
                      ),
                      SizedBox(width: 4),
                      AppText(
                        'Verified',
                        style: TextStyle(
                          color: AppTheme.foreground(
                            context,
                            Color(0xFF30D158),
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.adaptive(context, const Color(0xFF171717)),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: AppTheme.adaptive(
                        context,
                        const Color(0x14FFFFFF),
                      ),
                      width: 0.5,
                    ),
                  ),
                  child: AppText(
                    "Can't read?",
                    style: TextStyle(
                      color: AppTheme.foreground(context, Color(0x73FFFFFF)),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Name text field
          Container(
            decoration: BoxDecoration(
              color: AppTheme.adaptive(context, const Color(0xFF171717)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _nameCtrl[i],
              focusNode: _nameFocus[i],
              textInputAction: TextInputAction.next,
              style: AppTypography.bodyStyleOf(
                context,
                TextStyle(
                  color: AppTheme.foreground(context, Colors.white),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Item name',
                hintStyle: AppTypography.bodyStyleOf(
                  context,
                  TextStyle(
                    color: AppTheme.foreground(context, Color(0x33FFFFFF)),
                    fontSize: 14,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          // Reuse a name without claiming an item link or stock update.
          GestureDetector(
            onTap: () => _pickExisting(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.adaptive(context, const Color(0xFF171717)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppText(
                      match != null
                          ? 'Similar saved name: ${match.name}'
                          : 'Use a saved item name',
                      style: TextStyle(
                        color: match != null
                            ? AppTheme.foreground(
                                context,
                                const Color(0x73FFFFFF),
                              )
                            : AppTheme.foreground(
                                context,
                                const Color(0x33FFFFFF),
                              ),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.foreground(context, Color(0x33FFFFFF)),
                    size: 16,
                  ),
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
          Row(
            children: [
              _detailField('CATEGORY', _categoryCtrl[i], 'Robot Parts'),
            ],
          ),
          if (isVerified) ...[
            const SizedBox(height: 12),
            AppText(
              specificationSummary == null || specificationSummary.isEmpty
                  ? 'Matched against the manufacturer catalog.'
                  : 'Manufacturer specifications: $specificationSummary',
              style: TextStyle(
                color: AppTheme.foreground(context, Color(0x9930D158)),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            if (compatibility.isNotEmpty) ...[
              const SizedBox(height: 10),
              AppText('VERIFIED COMPATIBILITY', style: _kLabelStyle(context)),
              const SizedBox(height: 7),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: compatibility
                    .map(
                      (value) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.adaptive(
                            context,
                            const Color(0x1230D158),
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.adaptive(
                              context,
                              const Color(0x3330D158),
                            ),
                            width: 0.5,
                          ),
                        ),
                        child: AppText(
                          value,
                          style: TextStyle(
                            color: AppTheme.foreground(
                              context,
                              Color(0xCC30D158),
                            ),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (catalog?.productUrl?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _openManufacturerPage(catalog?.productUrl),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      color: AppTheme.foreground(context, Color(0xFF30D158)),
                      size: 14,
                    ),
                    SizedBox(width: 5),
                    AppText(
                      'View manufacturer source',
                      style: TextStyle(
                        color: AppTheme.foreground(context, Color(0xFF30D158)),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          AppText('QUANTITY', style: _kLabelStyle(context)),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('quantity-$i'),
            controller: _quantityCtrl[i],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              helperMaxLines: 3,
              helperText: widget.items[i].scanEvidence?.quantityMissing == true
                  ? "Not counted from the photo. Leave blank to save in this Space's Review section."
                  : widget.items[i].scanEvidence?.quantityNote ??
                        'You can edit this quantity now or later.',
              errorText:
                  _quantityCtrl[i].text.isNotEmpty &&
                      (int.tryParse(_quantityCtrl[i].text) == null ||
                          (int.tryParse(_quantityCtrl[i].text) ?? 0) > 100000)
                  ? 'Enter a number from 0 to 100000.'
                  : null,
            ),
            onChanged: (value) => setState(() {
              final n = int.tryParse(value);
              _quantityConfirmed[i] = n != null && n >= 0 && n <= 100000;
              if (n != null && n >= 0 && n <= 100000) {
                _qty[i] = n;
              }
            }),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('quantity-unit-$i'),
            controller: _unitCtrl[i],
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Counted unit',
              hintText: 'e.g. tablet, blister strip, screw',
              counterText: '',
            ),
          ),
          if (widget.items[i].scanEvidence != null) ...[
            const SizedBox(height: 14),
            ScanEvidencePanel(
              evidence: widget.items[i].scanEvidence!,
              barcode: widget.items[i].barcode,
              allowEditLater: true,
            ),
          ],
          const SizedBox(height: 16),
          // LOCATION label
          AppText('LOCATION', style: _kLabelStyle(context)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.adaptive(context, const Color(0xFF171717)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _locCtrl[i],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              style: AppTypography.bodyStyleOf(
                context,
                TextStyle(
                  color: AppTheme.foreground(context, Colors.white),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Unsorted',
                hintStyle: AppTypography.bodyStyleOf(
                  context,
                  TextStyle(
                    color: AppTheme.foreground(context, Color(0x33FFFFFF)),
                    fontSize: 14,
                  ),
                ),
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
        decoration: BoxDecoration(
          color: AppTheme.adaptive(context, Color(0xFF0A0A0A)),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border(
            top: BorderSide(
              color: AppTheme.adaptive(context, Color(0x14FFFFFF)),
              width: 0.5,
            ),
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
                    color: AppTheme.adaptive(context, const Color(0x33FFFFFF)),
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
                children: [
                  AppText(
                    'Confirm Items',
                    style: TextStyle(
                      color: AppTheme.foreground(context, Colors.white),
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    'Save to this Space. Unknown items go to its Review section.',
                    style: TextStyle(
                      color: AppTheme.foreground(context, Color(0x73FFFFFF)),
                      fontSize: 13,
                    ),
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
                16,
                12,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppTheme.adaptive(context, Color(0x14FFFFFF)),
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      List.generate(n, _needsReview).any((review) => review)
                          ? 'Unknown items will be saved in ${widget.defaultLocation} / Review. Edit them there later.'
                          : 'You can edit these items after saving.',
                    ),
                  ),
                  GestureDetector(
                    onTap:
                        _quantityCtrl.every((c) {
                              final n = int.tryParse(c.text);
                              return c.text.isEmpty ||
                                  (n != null && n >= 0 && n <= 100000);
                            }) &&
                            _nameCtrl.every((c) => c.text.trim().isNotEmpty)
                        ? () => Navigator.of(context).pop(_buildResult())
                        : null,
                    child: GlassControl(
                      radius: 99,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Center(
                          child: AppText(
                            'Save to Space',
                            style: TextStyle(
                              color: AppTheme.textPrimary(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(null),
                    child: Center(
                      child: AppText(
                        'Cancel',
                        style: TextStyle(
                          color: AppTheme.foreground(
                            context,
                            Color(0x73FFFFFF),
                          ),
                          fontSize: 15,
                        ),
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
        decoration: BoxDecoration(
          color: AppTheme.adaptive(context, Color(0xFF0A0A0A)),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border(
            top: BorderSide(
              color: AppTheme.adaptive(context, Color(0x14FFFFFF)),
              width: 0.5,
            ),
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
                    color: AppTheme.adaptive(context, const Color(0x33FFFFFF)),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.adaptive(context, const Color(0xFF171717)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                    width: 0.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: TextField(
                  controller: _search,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  style: AppTypography.bodyStyleOf(
                    context,
                    TextStyle(
                      color: AppTheme.foreground(context, Colors.white),
                      fontSize: 14,
                    ),
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search saved names',
                    hintStyle: AppTypography.bodyStyleOf(
                      context,
                      TextStyle(
                        color: AppTheme.foreground(context, Color(0x33FFFFFF)),
                        fontSize: 14,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppTheme.foreground(context, Color(0x33FFFFFF)),
                      size: 18,
                    ),
                  ),
                  onChanged: _filter,
                ),
              ),
            ),
            Flexible(
              child: _filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: AppText(
                          'No items found',
                          style: TextStyle(
                            color: AppTheme.foreground(
                              context,
                              Color(0x4DFFFFFF),
                            ),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: AppTheme.adaptive(context, Color(0x14FFFFFF)),
                        indent: 16,
                        endIndent: 16,
                      ),
                      itemBuilder: (_, i) {
                        final item = _filtered[i];
                        return GestureDetector(
                          onTap: () => Navigator.of(context).pop(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: AppText(
                                    item.name,
                                    style: TextStyle(
                                      color: AppTheme.foreground(
                                        context,
                                        Colors.white,
                                      ),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                AppText(
                                  item.category,
                                  style: TextStyle(
                                    color: AppTheme.foreground(
                                      context,
                                      Color(0x4DFFFFFF),
                                    ),
                                    fontSize: 12,
                                  ),
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
