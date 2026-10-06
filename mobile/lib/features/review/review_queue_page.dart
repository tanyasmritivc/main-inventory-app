import '../../core/app_theme.dart';
import 'dart:async';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../scan/scan_evidence_panel.dart';
import 'package:mobile/core/ui/app_text.dart';

class ReviewQueuePage extends StatefulWidget {
  const ReviewQueuePage({
    super.key,
    required this.api,
    this.onInventoryMutated,
  });

  final ApiClient api;
  final VoidCallback? onInventoryMutated;

  @override
  State<ReviewQueuePage> createState() => _ReviewQueuePageState();
}

class _ReviewQueuePageState extends State<ReviewQueuePage> {
  bool _loading = true;
  String? _error;
  List<ReviewItem> _items = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.getReviewItems();
      if (!mounted) return;
      setState(() => _items = result.items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeError(error).$1);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(ReviewItem item) async {
    final outcome = await showModalBottomSheet<_ReviewOutcome>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReviewDetailSheet(api: widget.api, item: item),
    );
    if (!mounted || outcome == null) return;
    setState(
      () => _items = _items.where((entry) => entry.id != item.id).toList(),
    );
    if (outcome == _ReviewOutcome.resolved) {
      widget.onInventoryMutated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Item confirmed and added to Find.')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('Capture dismissed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.adaptive(context, Colors.black),
      appBar: AppBar(
        title: const AppText('Review'),
        backgroundColor: AppTheme.adaptive(context, Colors.black),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 240),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 130),
          Icon(
            Icons.cloud_off_outlined,
            size: 42,
            color: AppTheme.foreground(context, Colors.white54),
          ),
          const SizedBox(height: 14),
          AppText(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const AppText('Try again')),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: 130),
          Icon(
            Icons.check_circle_outline_rounded,
            size: 46,
            color: AppTheme.foreground(context, Color(0xFF30D158)),
          ),
          SizedBox(height: 16),
          AppText(
            'Nothing needs review',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          AppText(
            'When a photo is uncertain, it will wait here instead of becoming incorrect inventory.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.foreground(context, Colors.white60),
              height: 1.45,
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
      itemCount: _items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
            child: AppText(
              '${_items.length} ${_items.length == 1 ? 'capture needs' : 'captures need'} a quick decision. Nothing here is in inventory yet.',
              style: TextStyle(
                color: AppTheme.foreground(context, Colors.white60),
                height: 1.4,
              ),
            ),
          );
        }
        final item = _items[index - 1];
        final image = (item.imageUrl ?? '').trim();
        return Material(
          color: AppTheme.adaptive(context, const Color(0xFF171717)),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _open(item),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (image.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.network(
                        image,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 5),
                        AppText(
                          item.scanEvidence?.reviewReasons.firstOrNull ??
                              'Confirm this item before saving.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.foreground(context, Colors.white60),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.foreground(context, Colors.white38),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _ReviewOutcome { resolved, dismissed }

class _ReviewDetailSheet extends StatefulWidget {
  const _ReviewDetailSheet({required this.api, required this.item});

  final ApiClient api;
  final ReviewItem item;

  @override
  State<_ReviewDetailSheet> createState() => _ReviewDetailSheetState();
}

class _ReviewDetailSheetState extends State<_ReviewDetailSheet> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _location;
  late final TextEditingController _brand;
  late final TextEditingController _partNumber;
  late int _quantity;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item.name);
    _category = TextEditingController(text: widget.item.category);
    _location = TextEditingController(text: widget.item.location ?? '');
    _brand = TextEditingController(text: widget.item.brand ?? '');
    _partNumber = TextEditingController(text: widget.item.partNumber ?? '');
    _quantity = widget.item.quantity.clamp(0, 100000);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _category,
      _location,
      _brand,
      _partNumber,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  ExtractedInventoryItem _draft() => ExtractedInventoryItem(
    name: _name.text.trim(),
    category: _category.text.trim(),
    quantity: _quantity,
    subcategory: widget.item.subcategory,
    brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
    partNumber: _partNumber.text.trim().isEmpty
        ? null
        : _partNumber.text.trim(),
    barcode: widget.item.barcode,
    tags: widget.item.tags,
    confidence: widget.item.confidence,
    imageUrl: widget.item.imageUrl,
    sourceFrameUrl: widget.item.sourceFrameUrl,
    notes: widget.item.notes,
    location: _location.text.trim(),
    catalogMatch: widget.item.catalogMatch,
    scanEvidence: widget.item.scanEvidence,
    reviewId: widget.item.id,
    reviewStatus: widget.item.status,
  );

  Future<void> _resolve() async {
    if (_name.text.trim().isEmpty ||
        _category.text.trim().isEmpty ||
        _location.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Name, category, and location are required.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.resolveReviewItem(
        reviewId: widget.item.id,
        item: _draft(),
      );
      if (mounted) Navigator.of(context).pop(_ReviewOutcome.resolved);
    } on dio.DioException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _dismiss() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Dismiss this capture?'),
        content: const AppText(
          'It will be removed from Review and will not be added to inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Dismiss'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.api.dismissReviewItem(reviewId: widget.item.id);
      if (mounted) Navigator.of(context).pop(_ReviewOutcome.dismissed);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = (widget.item.imageUrl ?? '').trim();
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.94,
      ),
      decoration: BoxDecoration(
        color: AppTheme.adaptive(context, Color(0xFF090909)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.adaptive(context, Colors.white24),
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Review capture',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 3),
                      AppText(
                        'Correct anything uncertain, then add it to Find.',
                        style: TextStyle(
                          color: AppTheme.foreground(context, Colors.white60),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              children: [
                if (image.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      image,
                      height: 210,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (widget.item.scanEvidence != null) ...[
                  ScanEvidencePanel(
                    evidence: widget.item.scanEvidence!,
                    barcode: widget.item.barcode,
                    initiallyExpanded: true,
                  ),
                  const SizedBox(height: 16),
                ],
                _field('Item name', _name),
                _field('Category', _category),
                Row(
                  children: [
                    Expanded(child: _field('Brand', _brand)),
                    const SizedBox(width: 10),
                    Expanded(child: _field('Part / model #', _partNumber)),
                  ],
                ),
                _field('Location', _location),
                AppText(
                  'QUANTITY',
                  style: TextStyle(
                    color: AppTheme.foreground(context, Colors.white38),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _saving || _quantity == 0
                          ? null
                          : () => setState(() => _quantity--),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: AppText(
                        '$_quantity',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _saving || _quantity >= 100000
                          ? null
                          : () => setState(() => _quantity++),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _saving ? null : _resolve,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const AppText('Confirm and add to Find'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving ? null : _dismiss,
                  child: const AppText('Dismiss capture'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: label),
        style: AppTypography.bodyStyleOf(context),
      ),
    );
  }
}
