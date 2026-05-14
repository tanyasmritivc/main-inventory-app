import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/low_stock_prefs.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/skeleton.dart';
import '../chat/chat_page.dart';
import '../sharing/share_space_sheet.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.api,
    required this.refreshToken,
    this.initialQuery,
  });

  final ApiClient api;
  final int refreshToken;
  final String? initialQuery;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _LocationItemsPage extends StatefulWidget {
  const _LocationItemsPage({
    required this.api,
    required this.location,
    required this.items,
    required this.thresholds,
    required this.allItems,
  });

  final ApiClient api;
  final String location;
  final List<InventoryItem> items;
  final Map<String, int> thresholds;
  final List<InventoryItem> allItems;

  @override
  State<_LocationItemsPage> createState() => _LocationItemsPageState();
}

class _LocationItemsPageState extends State<_LocationItemsPage> {
  late List<InventoryItem> _items;
  late Map<String, int> _thresholds;
  bool _changed = false;
  bool _isEditingNotes = false;
  final TextEditingController _notesController = TextEditingController();
  bool _isSuggestingPurchaseSource = false;
  final TextEditingController _purchaseSourceController = TextEditingController();
  final TextEditingController _thresholdSheetController = TextEditingController();
  Timer? _purchaseSourceDebounce;
  Timer? _thresholdDebounce;
  String _selectedCategory = 'All';
  final ScrollController _listScrollController = ScrollController();
  final Map<String, GlobalKey> _categoryKeys = {};
  String _spaceSearchQuery = '';
  final TextEditingController _spaceSearchController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    _purchaseSourceController.dispose();
    _thresholdSheetController.dispose();
    _purchaseSourceDebounce?.cancel();
    _thresholdDebounce?.cancel();
    _listScrollController.dispose();
    _spaceSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _items = List<InventoryItem>.from(widget.items)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _thresholds = Map<String, int>.from(widget.thresholds);
  }

  int _totalCount() {
    return _items.fold<int>(0, (acc, it) => acc + (it.quantity <= 0 ? 0 : it.quantity));
  }

  int _lowCount() {
    var n = 0;
    for (final it in _items) {
      final thr = _thresholds[it.itemId];
      if (thr == null || thr <= 0) continue;
      if (it.quantity <= thr) n++;
    }
    return n;
  }

  Future<void> _editItem(InventoryItem item) async {
    final currentThreshold = _thresholds[item.itemId];
    final updates = await showModalBottomSheet<_ItemEditorResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _ItemEditorSheet(item: item, initialThreshold: currentThreshold),
    );
    if (updates == null) return;

    try {
      final updated = await widget.api.updateItem(request: updates.update);
      await LowStockPrefs.setThreshold(
        itemId: item.itemId,
        threshold: updates.threshold,
      );

      final nextThresholds = Map<String, int>.from(_thresholds);
      if (updates.threshold == null || updates.threshold! <= 0) {
        nextThresholds.remove(item.itemId);
      } else {
        nextThresholds[item.itemId] = updates.threshold!;
      }

      if (!mounted) return;
      setState(() {
        _thresholds = nextThresholds;
        final idx = _items.indexWhere((e) => e.itemId == item.itemId);
        if (idx != -1) {
          _items[idx] = updated;
        }
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory updated')),
      );
    } on dio.DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection issue. Please try again.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    }
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text(item.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.deleteItem(itemId: item.itemId);
      await LowStockPrefs.setThreshold(itemId: item.itemId, threshold: null);
      if (!mounted) return;
      setState(() {
        _items = _items.where((e) => e.itemId != item.itemId).toList();
        final next = Map<String, int>.from(_thresholds);
        next.remove(item.itemId);
        _thresholds = next;
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted')),
      );
    } on dio.DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection issue. Please try again.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    }
  }

  Widget _buildItemRow(InventoryItem item) {
    final threshold = _thresholds[item.itemId];
    final isLow = threshold != null && threshold > 0 && item.quantity <= threshold;
    return Dismissible(
      key: ValueKey(item.itemId),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        color: AppColors.swipe,
        child: const Icon(Icons.edit_outlined),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: const Color(0x1AFF3B30),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _editItem(item);
          return false;
        }
        if (direction == DismissDirection.endToStart) {
          await _deleteItem(item);
          return false;
        }
        return false;
      },
      child: InkWell(
        onTap: () => _editItem(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.category,
                      style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (isLow) ...[
                const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
                const SizedBox(width: 8),
              ],
              Text(
                'Qty ${item.quantity}',
                style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 13),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showProductInfo(context, item),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                  ),
                  child: const Icon(Icons.info_outline, color: Color(0x4DFFFFFF), size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinSpaceDialog() async {
    final ctrl = TextEditingController();
    String? error;
    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (_, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text('Join a Space', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  letterSpacing: 4,
                ),
                decoration: const InputDecoration(
                  hintText: '6-character code',
                  hintStyle: TextStyle(color: Color(0x4DFFFFFF)),
                  counterStyle: TextStyle(color: Color(0x4DFFFFFF)),
                ),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Color(0xFFFF453A), fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final code = ctrl.text.trim().toUpperCase();
                if (code.length != 6) {
                  setDlgState(() => error = 'Enter a 6-character code.');
                  return;
                }
                try {
                  await widget.api.joinShare(code);
                  if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Joined! Check Joined Spaces to view.'),
                      ),
                    );
                  }
                } catch (e) {
                  setDlgState(() => error = e.toString());
                }
              },
              child: const Text('Join'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  List<String> _sortedCategoryPills() {
    final loc = widget.location.trim().isEmpty ? 'Unsorted' : widget.location.trim();
    final catSet = <String>{};
    for (final it in widget.allItems) {
      final itLoc = it.location.trim().isEmpty ? 'Unsorted' : it.location.trim();
      if (itLoc.toLowerCase() != loc.toLowerCase()) continue;
      final c = it.category.trim().isEmpty ? 'Uncategorized' : it.category.trim();
      catSet.add(c);
    }
    final sorted = catSet.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...sorted];
  }

  bool _matchesSpaceSearch(InventoryItem item) {
    final q = _spaceSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return item.name.toLowerCase().contains(q) ||
        (item.brand?.toLowerCase().contains(q) ?? false) ||
        item.category.toLowerCase().contains(q);
  }

  void _onCategoryPillTapped(String cat) {
    setState(() => _selectedCategory = cat);
    _listScrollController.jumpTo(0);
  }

  void _showProductInfo(BuildContext context, InventoryItem item) {
    _isEditingNotes = false;
    _notesController.text = item.notes ?? '';
    _purchaseSourceDebounce?.cancel();
    _thresholdDebounce?.cancel();
    _isSuggestingPurchaseSource = false;
    _purchaseSourceController.text = item.purchaseSource ?? '';
    final existingThr = _thresholds[item.itemId];
    _thresholdSheetController.text = (existingThr != null && existingThr > 0) ? existingThr.toString() : '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final localDocs = <DocumentEntry>[];
        var docsInitialized = false;
        return StatefulBuilder(
          builder: (_, setSheetState) {
            if (!docsInitialized) {
              docsInitialized = true;
              _loadItemDocuments(setSheetState, localDocs, item.itemId);
            }
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0A0A0A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(top: BorderSide(color: Color(0x14FFFFFF), width: 0.5)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 32,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(top: 12, bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        item.category,
                        style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Info rows
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0x0AFFFFFF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                        ),
                        child: Column(
                          children: [
                            _infoRow('Category', item.category),
                            _divider(),
                            _infoRow('Location', item.location),
                            _divider(),
                            _infoRow('Quantity', '${item.quantity}'),
                            if (item.brand != null && item.brand!.isNotEmpty) ...[
                              _divider(),
                              _infoRow('Brand', item.brand!),
                            ],
                            if (item.barcode != null && item.barcode!.isNotEmpty) ...[
                              _divider(),
                              _infoRow('Barcode', item.barcode!),
                            ],
                            if (item.partNumber != null && item.partNumber!.isNotEmpty) ...[
                              _divider(),
                              _infoRow('Part number', item.partNumber!),
                            ],
                            if (item.subcategory != null && item.subcategory!.isNotEmpty) ...[
                              _divider(),
                              _infoRow('Subcategory', item.subcategory!),
                            ],
                            _divider(),
                            _infoRow('Date added', _formatDate(item.createdAt)),
                            if (item.confidence != null) ...[
                              _divider(),
                              _infoRow(
                                'AI confidence',
                                '${(item.confidence! * 100).toStringAsFixed(0)}%',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Notes section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Text(
                                'NOTES',
                                style: TextStyle(
                                  color: Color(0x4DFFFFFF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const Spacer(),
                              _isEditingNotes
                                ? GestureDetector(
                                    onTap: () => _saveNotes(item, setSheetState),
                                    child: const Text(
                                      'Save',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  )
                                : GestureDetector(
                                    onTap: () => setSheetState(() => _isEditingNotes = true),
                                    child: const Text(
                                      'Edit',
                                      style: TextStyle(color: Color(0x73FFFFFF), fontSize: 13),
                                    ),
                                  ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 80),
                            decoration: BoxDecoration(
                              color: const Color(0x0AFFFFFF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: _isEditingNotes
                              ? TextField(
                                  controller: _notesController,
                                  maxLines: null,
                                  autofocus: true,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Add notes about this item...',
                                    hintStyle: TextStyle(
                                      color: Color(0x33FFFFFF),
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : Text(
                                  _notesController.text.isNotEmpty
                                    ? _notesController.text
                                    : 'Tap Edit to add notes...',
                                  style: TextStyle(
                                    color: _notesController.text.isNotEmpty
                                      ? const Color(0x73FFFFFF)
                                      : const Color(0x33FFFFFF),
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                    // Documents section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Text(
                                'DOCUMENTS',
                                style: TextStyle(
                                  color: Color(0x4DFFFFFF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => _pickAndUploadDocument(
                                  sheetContext,
                                  item,
                                  setSheetState,
                                  localDocs,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x0AFFFFFF),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: const Color(0x14FFFFFF),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add, color: Color(0x73FFFFFF), size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Add',
                                        style: TextStyle(
                                          color: Color(0x73FFFFFF),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (localDocs.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: const Color(0x0AFFFFFF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0x14FFFFFF),
                                  width: 0.5,
                                ),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    color: Color(0x20FFFFFF),
                                    size: 28,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No documents yet',
                                    style: TextStyle(
                                      color: Color(0x33FFFFFF),
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Add receipts, manuals, or warranties',
                                    style: TextStyle(
                                      color: Color(0x20FFFFFF),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0x0AFFFFFF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0x14FFFFFF),
                                  width: 0.5,
                                ),
                              ),
                              child: Column(
                                children: localDocs.asMap().entries.map((entry) {
                                  final doc = entry.value;
                                  final isLast = entry.key == localDocs.length - 1;
                                  return Column(
                                    children: [
                                      ListTile(
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                        leading: Icon(
                                          (doc.mimeType?.contains('pdf') == true)
                                            ? Icons.picture_as_pdf_outlined
                                            : Icons.image_outlined,
                                          color: const Color(0x73FFFFFF),
                                          size: 20,
                                        ),
                                        title: Text(
                                          doc.displayName ?? doc.filename,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          color: Color(0x33FFFFFF),
                                          size: 12,
                                        ),
                                        onTap: () {
                                          if (doc.url != null) {
                                            unawaited(launchUrl(Uri.parse(doc.url!)));
                                          }
                                        },
                                      ),
                                      if (!isLast)
                                        Container(
                                          height: 0.5,
                                          color: const Color(0x14FFFFFF),
                                          margin: const EdgeInsets.symmetric(horizontal: 16),
                                        ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Tags
                    if (item.tags != null && item.tags!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'TAGS',
                          style: TextStyle(
                            color: Color(0x4DFFFFFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: item.tags!.map((tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0x0AFFFFFF),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 13),
                            ),
                          )).toList(),
                        ),
                      ),
                    ],
                    // Where to Buy section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Text(
                                'WHERE TO BUY',
                                style: TextStyle(
                                  color: Color(0x4DFFFFFF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const Spacer(),
                              if (_isSuggestingPurchaseSource)
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Color(0x73FFFFFF),
                                  ),
                                )
                              else
                                GestureDetector(
                                  onTap: () => _suggestPurchaseSource(item, setSheetState),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0x0AFFFFFF),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                                    ),
                                    child: const Text(
                                      'Suggest',
                                      style: TextStyle(color: Color(0x73FFFFFF), fontSize: 12),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0x0AFFFFFF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            child: TextField(
                              controller: _purchaseSourceController,
                              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'e.g. Amazon, Home Depot, supplier URL',
                                hintStyle: TextStyle(color: Color(0x33FFFFFF), fontSize: 14),
                              ),
                              onChanged: (_) => _schedulePurchaseSourceSave(item),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // QR Code section — only for items without a barcode
                    if (item.barcode == null || item.barcode!.trim().isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          const Text(
                            'ITEM QR CODE',
                            style: TextStyle(
                              color: Color(0x4DFFFFFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: QrImageView(
                              data: item.itemId,
                              version: QrVersions.auto,
                              size: 120,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.white,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Center(
                            child: Text(
                              'Scan to identify this item',
                              style: TextStyle(color: Color(0x33FFFFFF), fontSize: 11),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: GestureDetector(
                              onTap: () => SharePlus.instance.share(
                                ShareParams(
                                  text: 'FindEZ item ID: ${item.itemId}',
                                  subject: 'FindEZ Item QR',
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0x0AFFFFFF),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.share_outlined, color: Color(0x73FFFFFF), size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      'Share QR',
                                      style: TextStyle(color: Color(0x73FFFFFF), fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Alert threshold section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          const Text(
                            'ALERT ME WHEN BELOW',
                            style: TextStyle(
                              color: Color(0x4DFFFFFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0x0AFFFFFF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            child: TextField(
                              controller: _thresholdSheetController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Quantity threshold',
                                hintStyle: TextStyle(color: Color(0x33FFFFFF), fontSize: 14),
                              ),
                              onChanged: (_) => _scheduleThresholdSave(item),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Close
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(sheetContext),
                        child: Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0x0AFFFFFF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                          ),
                          child: const Center(
                            child: Text(
                              'Close',
                              style: TextStyle(
                                color: Color(0x73FFFFFF),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0x73FFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 0.5,
      color: const Color(0x14FFFFFF),
      margin: const EdgeInsets.symmetric(horizontal: 18),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _saveNotes(InventoryItem item, StateSetter setSheetState) async {
    final notes = _notesController.text.trim();
    try {
      await widget.api.updateItem(
        request: UpdateItemRequest(itemId: item.itemId, notes: notes),
      );
      final idx = _items.indexWhere((e) => e.itemId == item.itemId);
      if (idx != -1 && mounted) setState(() => _changed = true);
      setSheetState(() => _isEditingNotes = false);
    } catch (_) {
      // fail silently, keep editing mode
    }
  }

  void _schedulePurchaseSourceSave(InventoryItem item) {
    _purchaseSourceDebounce?.cancel();
    _purchaseSourceDebounce = Timer(const Duration(milliseconds: 600), () {
      _savePurchaseSourceSilent(item);
    });
  }

  Future<void> _savePurchaseSourceSilent(InventoryItem item) async {
    final source = _purchaseSourceController.text.trim();
    try {
      await widget.api.updateItem(
        request: UpdateItemRequest(itemId: item.itemId, purchaseSource: source.isEmpty ? null : source),
      );
      final idx = _items.indexWhere((e) => e.itemId == item.itemId);
      if (idx != -1 && mounted) setState(() => _changed = true);
    } catch (_) {}
  }

  Future<void> _suggestPurchaseSource(InventoryItem item, StateSetter setSheetState) async {
    setSheetState(() => _isSuggestingPurchaseSource = true);
    try {
      final prompt =
          'What is the best place to buy ${item.name}? '
          'Reply with ONLY the store name, nothing else.';
      final result = await widget.api.aiCommand(message: prompt);
      final suggestion = result.assistantMessage.trim();
      if (suggestion.isNotEmpty && mounted) {
        _purchaseSourceController.text = suggestion;
        _schedulePurchaseSourceSave(item);
      }
    } catch (_) {
      // fail silently
    } finally {
      if (mounted) setSheetState(() => _isSuggestingPurchaseSource = false);
    }
  }

  void _scheduleThresholdSave(InventoryItem item) {
    _thresholdDebounce?.cancel();
    _thresholdDebounce = Timer(const Duration(milliseconds: 600), () {
      _saveThresholdSilent(item);
    });
  }

  Future<void> _saveThresholdSilent(InventoryItem item) async {
    final rawThreshold = int.tryParse(_thresholdSheetController.text.trim());
    final threshold = (rawThreshold != null && rawThreshold > 0) ? rawThreshold : null;
    try {
      await LowStockPrefs.setThreshold(itemId: item.itemId, threshold: threshold);
      if (mounted) {
        setState(() {
          final next = Map<String, int>.from(_thresholds);
          if (threshold == null) {
            next.remove(item.itemId);
          } else {
            next[item.itemId] = threshold;
          }
          _thresholds = next;
          _changed = true;
        });
      }
    } catch (_) {}
  }

  void _loadItemDocuments(StateSetter setSheetState, List<DocumentEntry> docs, String itemId) {
    widget.api.getDocuments(itemId: itemId).then((loaded) {
      if (mounted) setSheetState(() { docs.clear(); docs.addAll(loaded); });
    }).catchError((_) {});
  }

  Future<void> _pickAndUploadDocument(
    BuildContext context,
    InventoryItem item,
    StateSetter setSheetState,
    List<DocumentEntry> docs,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) return;
    try {
      final file = dio.MultipartFile.fromBytes(bytes.toList(), filename: picked.name);
      await widget.api.uploadDocument(file: file, itemId: item.itemId);
      _loadItemDocuments(setSheetState, docs, item.itemId);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed. Please try again.')),
      );
    }
  }

  Future<void> _uploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Extracting items from image…')),
    );
    try {
      final extracted = await widget.api.extractInventoryFromImage(
        bytes: bytes.toList(),
        filename: picked.name,
      );
      if (extracted.items.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No items found in image.')),
        );
        return;
      }
      for (final item in extracted.items) {
        item.location = widget.location;
      }
      final created = await widget.api.bulkCreateInventory(
        items: extracted.items,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...created.inserted];
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${created.inserted.length} items.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to extract items. Try again.')),
      );
    }
  }

  Widget _buildGroupedList() {
    final groups = <String, List<InventoryItem>>{};
    for (final item in _items) {
      final cat = item.category.trim().isEmpty ? 'Uncategorized' : item.category.trim();
      groups.putIfAbsent(cat, () => []).add(item);
    }
    final sortedCats = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final cat in sortedCats) {
      groups[cat]!.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    for (final cat in sortedCats) {
      _categoryKeys.putIfAbsent(cat, () => GlobalKey());
    }

    final displayedCats = _selectedCategory == 'All'
        ? sortedCats
        : sortedCats.where((c) => c == _selectedCategory).toList();

    final filteredGroups = <String, List<InventoryItem>>{};
    for (final cat in displayedCats) {
      final matches = (groups[cat] ?? []).where(_matchesSpaceSearch).toList();
      if (matches.isNotEmpty) filteredGroups[cat] = matches;
    }
    final filteredCats =
        displayedCats.where((c) => filteredGroups.containsKey(c)).toList();

    if (filteredCats.isEmpty && _spaceSearchQuery.trim().isNotEmpty) {
      return const Center(
        child: Text(
          'No items match your search',
          style: TextStyle(color: Color(0x4DFFFFFF)),
        ),
      );
    }

    return ListView(
      controller: _listScrollController,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final cat in filteredCats) ...[
          Padding(
            key: _categoryKeys[cat],
            padding: const EdgeInsets.only(left: 32, top: 20, bottom: 6),
            child: Text(
              cat.toUpperCase(),
              style: const TextStyle(
                color: Color(0x4DFFFFFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              children: [
                for (int i = 0; i < filteredGroups[cat]!.length; i++) ...[
                  _buildItemRow(filteredGroups[cat]![i]),
                  if (i < filteredGroups[cat]!.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 16,
                      endIndent: 16,
                      color: Color(0x14FFFFFF),
                    ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        result;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(widget.location),
          centerTitle: true,
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.image_outlined, color: Color(0x73FFFFFF)),
              onPressed: _uploadImage,
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Color(0x73FFFFFF)),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => DraggableScrollableSheet(
                  initialChildSize: 0.65,
                  maxChildSize: 0.92,
                  minChildSize: 0.4,
                  builder: (_, __) => ShareSpaceSheet(
                    spaceName: widget.location,
                    api: widget.api,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      api: widget.api,
                      initialMessage: 'What do I have in ${widget.location}?',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0x73FFFFFF)),
            ),
          ],
          backgroundColor: Colors.black,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Container(
          color: Colors.black,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0x0AFFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                ),
                child: Text(
                  '${_totalCount()} items · ${_lowCount()} low stock',
                  style: const TextStyle(
                    color: Color(0x73FFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              // Action toolbar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      TextButton.icon(
                        onPressed: _uploadImage,
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('Upload Photo', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white60,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const VerticalDivider(width: 1, color: Colors.white12, indent: 8, endIndent: 8),
                      TextButton.icon(
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => DraggableScrollableSheet(
                            initialChildSize: 0.65,
                            maxChildSize: 0.92,
                            minChildSize: 0.4,
                            builder: (_, __) => ShareSpaceSheet(
                              spaceName: widget.location,
                              api: widget.api,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Share Space', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white60,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const VerticalDivider(width: 1, color: Colors.white12, indent: 8, endIndent: 8),
                      TextButton.icon(
                        onPressed: _joinSpaceDialog,
                        icon: const Icon(Icons.person_add_outlined, size: 18),
                        label: const Text('Join Space', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white60,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Space search bar
              if (_items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: SizedBox(
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Color(0x4DFFFFFF), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _spaceSearchController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Search in this space...',
                                hintStyle: TextStyle(
                                    color: Color(0x33FFFFFF), fontSize: 14),
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (v) =>
                                  setState(() => _spaceSearchQuery = v),
                            ),
                          ),
                          if (_spaceSearchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _spaceSearchController.clear();
                                setState(() => _spaceSearchQuery = '');
                                FocusScope.of(context).unfocus();
                              },
                              child: const Icon(Icons.close,
                                  color: Color(0x4DFFFFFF), size: 16),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Category filter pills
              if (_items.isNotEmpty)
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    physics: const BouncingScrollPhysics(),
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: _sortedCategoryPills().length,
                    itemBuilder: (_, i) {
                      final pills = _sortedCategoryPills();
                      final label = pills[i];
                      final isActive = _selectedCategory == label;
                      return GestureDetector(
                        onTap: () => _onCategoryPillTapped(label),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.white : const Color(0x0AFFFFFF),
                            borderRadius: BorderRadius.circular(99),
                            border: isActive
                              ? null
                              : Border.all(color: const Color(0x14FFFFFF), width: 0.5),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: isActive ? Colors.black : const Color(0x73FFFFFF),
                              fontSize: 13,
                              fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Expanded(
                child: _items.isEmpty
                    ? const Center(
                        child: Text(
                          'No items here yet.',
                          style: TextStyle(color: Color(0x4DFFFFFF)),
                        ),
                      )
                    : _buildGroupedList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryPageState extends State<InventoryPage> {
  late final TextEditingController _search;
  final ValueNotifier<String> _query = ValueNotifier('');
  final ValueNotifier<List<InventoryItem>> _rows = ValueNotifier(const []);
  final ValueNotifier<bool> _aiSearching = ValueNotifier(false);
  final ValueNotifier<Map<String, int>> _thresholds = ValueNotifier(const {});

  final ValueNotifier<String> _category = ValueNotifier('All');

  bool _loading = true;
  String? _error;
  final Set<String> _localSpaces = {};

  List<InventoryItem> _items = const [];

  Timer? _debounce;
  String? _lastAiExpandedFor;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();

    final initial = (widget.initialQuery ?? '').trim();
    if (initial.isNotEmpty) {
      _search.text = initial;
      _query.value = initial;
    }
    _loadItems();
  }

  Map<String, List<InventoryItem>> _groupByLocation(List<InventoryItem> items) {
    final groups = <String, List<InventoryItem>>{};
    for (final it in items) {
      final loc = it.location.trim().isEmpty ? 'Unsorted' : it.location.trim();
      (groups[loc] ??= <InventoryItem>[]).add(it);
    }
    return groups;
  }

  int _lowStockCountForItems(List<InventoryItem> items, Map<String, int> thresholds) {
    var n = 0;
    for (final it in items) {
      final thr = thresholds[it.itemId];
      if (thr == null || thr <= 0) continue;
      if (it.quantity <= thr) n++;
    }
    return n;
  }

  Future<void> _openLocation({required String location, required Map<String, int> thresholds}) async {
    if (!mounted) return;
    final loc = location.trim().isEmpty ? 'Unsorted' : location.trim();
    final source = _baseItemsForSelectedCategory();
    final items = source.where((it) {
      final l = it.location.trim().isEmpty ? 'Unsorted' : it.location.trim();
      return l.toLowerCase() == loc.toLowerCase();
    }).toList();

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _LocationItemsPage(
          api: widget.api,
          location: loc,
          items: items,
          thresholds: thresholds,
          allItems: _items,
        ),
      ),
    );
    if (changed == true) {
      await _loadItems();
    }
  }

  @override
  void didUpdateWidget(covariant InventoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadItems();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _query.dispose();
    _rows.dispose();
    _aiSearching.dispose();
    _thresholds.dispose();
    _category.dispose();
    super.dispose();
  }

  List<InventoryItem> _baseItemsForSelectedCategory() {
    final selected = _category.value;
    if (selected == 'All') return _items;
    final target = selected.trim().toLowerCase();
    return _items
        .where((it) => it.category.trim().toLowerCase() == target)
        .toList();
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null || uid.isEmpty) {
        if (!mounted) return;
        setState(() => _error = 'Please sign in again.');
        return;
      }
      final resp = await supabase
          .from('items')
          .select('*')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(1000);

      final rows = (resp as List<dynamic>).cast<Map<String, dynamic>>();
      final items = rows.map(InventoryItem.fromJson).toList();

      if (!mounted) return;
      setState(() {
        _items = items;
      });
      LowStockPrefs.loadAll().then((value) {
        if (!mounted) return;
        _thresholds.value = value;
      });
      _applyLocalSearch(_query.value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  bool _containsToken(String haystack, String token) {
    if (haystack.isEmpty || token.isEmpty) return false;
    return haystack.toLowerCase().contains(token.toLowerCase());
  }

  int _scoreForToken(
    InventoryItem it,
    String token, {
    required String fullQuery,
  }) {
    final name = it.name;
    final category = it.category;
    final location = it.location;
    final notes = (it.notes ?? '');

    final nameLower = name.toLowerCase();
    final tokenLower = token.toLowerCase();
    final fullLower = fullQuery.toLowerCase();

    var score = 0;

    if (nameLower == fullLower) return 10000;
    if (nameLower.startsWith(fullLower) && fullLower.isNotEmpty) score += 7000;

    if (nameLower == tokenLower) score += 4500;
    if (nameLower.startsWith(tokenLower)) score += 2200;
    if (nameLower.contains(tokenLower)) score += 1500;

    if (_containsToken(category, token)) score += 900;

    final tags = it.tags ?? const <String>[];
    for (final t in tags) {
      if (_containsToken(t, token)) {
        score += 750;
        break;
      }
    }

    if (_containsToken(location, token)) score += 600;
    if (_containsToken(notes, token)) score += 450;
    if (_containsToken(it.purchaseSource ?? '', token)) score += 350;
    if (_containsToken(it.barcode ?? '', token)) score += 250;

    return score;
  }

  List<InventoryItem> _smartLocalSearch(
    String rawQuery, {
    List<String> extraTerms = const [],
  }) {
    final base = _baseItemsForSelectedCategory();
    final q = rawQuery.trim();
    if (q.isEmpty) return base;

    final tokens = <String>{
      ...q
          .split(RegExp(r'\s+'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty),
      ...extraTerms.map((t) => t.trim()).where((t) => t.isNotEmpty),
    }.toList();

    final scored = <({InventoryItem item, int score})>[];
    for (final it in base) {
      var s = 0;
      for (final tok in tokens) {
        s += _scoreForToken(it, tok, fullQuery: q);
      }
      if (s > 0) scored.add((item: it, score: s));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.item.createdAt.compareTo(a.item.createdAt);
    });
    return scored.map((e) => e.item).toList();
  }

  Future<List<String>> _expandQueryWithAi(String query) async {
    final msg =
        'Expand this inventory search query into up to 8 related search terms (synonyms, categories, related items). '
        'Return ONLY JSON like {"terms":["term1","term2"]}. Query: "$query"';

    final out = await widget.api.aiCommand(message: msg);
    final text = out.assistantMessage.trim();
    if (text.isEmpty) return const [];

    try {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final jsonStr = text.substring(start, end + 1);
        final obj = (json.decode(jsonStr) as Map).cast<String, dynamic>();
        final terms = obj['terms'];
        if (terms is List) {
          return terms
              .map((e) => e.toString())
              .where((t) => t.trim().isNotEmpty)
              .take(8)
              .toList();
        }
      }
    } catch (_) {
      // fall through
    }

    return text
        .replaceAll(RegExp(r'[^a-zA-Z0-9,\n\s-]'), '')
        .split(RegExp(r'[,\n]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .take(8)
        .toList();
  }

  void _applyLocalSearch(String v) {
    final q = v.trim();
    _query.value = q;
    _aiSearching.value = false;
    _rows.value = _smartLocalSearch(q);

    _debounce?.cancel();
    if (q.isEmpty) {
      _lastAiExpandedFor = null;
      return;
    }

    if (_rows.value.length >= 4) return;
    if (_lastAiExpandedFor == q) return;

    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final active = _query.value;
      if (active != q || active.isEmpty) return;
      if (_rows.value.length >= 4) return;

      _aiSearching.value = true;
      try {
        final terms = await _expandQueryWithAi(active);
        if (!mounted) return;
        if (_query.value != active) return;
        _lastAiExpandedFor = active;
        _rows.value = _smartLocalSearch(active, extraTerms: terms);
      } on dio.DioException {
        // ignore; keep local results
      } catch (_) {
        // ignore; keep local results
      } finally {
        if (mounted && _query.value == active) _aiSearching.value = false;
      }
    });
  }

  Future<void> _addItem() async {
    final created = await showModalBottomSheet<_ItemEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => const _ItemEditorSheet(),
    );
    if (created == null) return;

    try {
      final out = await widget.api.addItem(item: created.add);
      await LowStockPrefs.setThreshold(
        itemId: out.itemId,
        threshold: created.threshold,
      );
      final next = Map<String, int>.from(_thresholds.value);
      if (created.threshold == null || created.threshold! <= 0) {
        next.remove(out.itemId);
      } else {
        next[out.itemId] = created.threshold!;
      }
      _thresholds.value = next;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item added')));
      await _loadItems();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 429) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection issue. Please try again.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection issue. Please try again.')),
        );
      }
    }
  }

  Future<void> _editItem(InventoryItem item) async {
    final currentThreshold = _thresholds.value[item.itemId];
    final updates = await showModalBottomSheet<_ItemEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) =>
          _ItemEditorSheet(item: item, initialThreshold: currentThreshold),
    );
    if (updates == null) return;

    try {
      await widget.api.updateItem(request: updates.update);
      await LowStockPrefs.setThreshold(
        itemId: item.itemId,
        threshold: updates.threshold,
      );
      final next = Map<String, int>.from(_thresholds.value);
      if (updates.threshold == null || updates.threshold! <= 0) {
        next.remove(item.itemId);
      } else {
        next[item.itemId] = updates.threshold!;
      }
      _thresholds.value = next;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved')));
      await _loadItems();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 429) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection issue. Please try again.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection issue. Please try again.')),
        );
      }
    }
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text(item.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.deleteItem(itemId: item.itemId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted')));
      await _loadItems();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 429) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection issue. Please try again.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection issue. Please try again.')),
        );
      }
    }
  }

  Widget _buildSpacesGrid(Map<String, int> thresholds) {
    final groups = _groupByLocation(_baseItemsForSelectedCategory());
    final allSpaces = <String>{...groups.keys, ..._localSpaces}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: allSpaces.length + 1,
      itemBuilder: (context, index) {
        if (index == allSpaces.length) {
          return GestureDetector(
            onTap: () => _createSpace(context),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x14FFFFFF)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Color(0x4DFFFFFF), size: 28),
                  SizedBox(height: 8),
                  Text('New Space', style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 14)),
                ],
              ),
            ),
          );
        }
        final loc = allSpaces[index];
        final items = groups[loc] ?? const <InventoryItem>[];
        final lowStock = items.where((it) => it.quantity <= 1).length;
        return GestureDetector(
          onTap: () => unawaited(_openLocation(location: loc, thresholds: thresholds)),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x14FFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${items.length} items',
                        style: const TextStyle(color: Color(0x8AFFFFFF), fontSize: 13),
                      ),
                      if (lowStock > 0) ...[                        const SizedBox(height: 2),
                        Text(
                          '$lowStock low stock',
                          style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => DraggableScrollableSheet(
                          initialChildSize: 0.65,
                          maxChildSize: 0.92,
                          minChildSize: 0.4,
                          builder: (_, __) => ShareSpaceSheet(
                            spaceName: loc,
                            api: widget.api,
                          ),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.share_outlined, color: Color(0x73FFFFFF), size: 18),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _showSpaceMenu(context, loc, items),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.more_vert, color: Color(0x73FFFFFF), size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createSpace(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('New Space', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Space name',
            hintStyle: TextStyle(color: Color(0x4DFFFFFF)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    setState(() => _localSpaces.add(name));
    if (!mounted) return;
    await _openLocation(location: name, thresholds: _thresholds.value);
  }

  Future<void> _joinSpaceDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    String? error;
    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (_, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text('Join a Space', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  letterSpacing: 4,
                ),
                decoration: const InputDecoration(
                  hintText: '6-character code',
                  hintStyle: TextStyle(color: Color(0x4DFFFFFF)),
                  counterStyle: TextStyle(color: Color(0x4DFFFFFF)),
                ),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Color(0xFFFF453A), fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final code = ctrl.text.trim().toUpperCase();
                if (code.length != 6) {
                  setDlgState(() => error = 'Enter a 6-character code.');
                  return;
                }
                try {
                  await widget.api.joinShare(code);
                  if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Joined! Check Joined Spaces to view.'),
                      ),
                    );
                  }
                } catch (e) {
                  setDlgState(() => error = e.toString());
                }
              },
              child: const Text('Join'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  Future<void> _showSpaceMenu(
    BuildContext context,
    String loc,
    List<InventoryItem> items,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.white),
              title: const Text('Rename', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFFF453A)),
              title: const Text('Delete Space', style: TextStyle(color: Color(0xFFFF453A))),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'rename' && mounted) await _renameSpace(context, loc, items);
    if (action == 'delete' && mounted) await _deleteSpace(context, loc, items);
  }

  Future<void> _renameSpace(
    BuildContext context,
    String oldName,
    List<InventoryItem> items,
  ) async {
    final ctrl = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Rename Space', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintStyle: TextStyle(color: Color(0x4DFFFFFF)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newName == null || newName.isEmpty || newName == oldName) return;
    for (final item in items) {
      try {
        await widget.api.updateItem(
          request: UpdateItemRequest(itemId: item.itemId, location: newName),
        );
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _localSpaces.remove(oldName);
        if (items.isEmpty) _localSpaces.add(newName);
      });
      await _loadItems();
    }
  }

  Future<void> _deleteSpace(
    BuildContext context,
    String loc,
    List<InventoryItem> items,
  ) async {
    if (items.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text('Delete Space?', style: TextStyle(color: Colors.white)),
          content: Text(
            'This will delete all ${items.length} item(s) in "$loc".',
            style: const TextStyle(color: Color(0x73FFFFFF)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Color(0xFFFF453A))),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      for (final item in items) {
        try { await widget.api.deleteItem(itemId: item.itemId); } catch (_) {}
      }
    }
    if (mounted) {
      setState(() => _localSpaces.remove(loc));
      await _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('My Inventory'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _joinSpaceDialog(context),
            icon: const Icon(Icons.group_add_outlined, color: Color(0x73FFFFFF)),
          ),
          IconButton(
            onPressed: () => _createSpace(context),
            icon: const Icon(Icons.add, color: Color(0x73FFFFFF)),
          ),
          IconButton(
            onPressed: _loadItems,
            icon: const Icon(Icons.refresh, color: Color(0x73FFFFFF)),
          ),
          IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      api: widget.api,
                      initialMessage: _query.value.trim().isEmpty ? null : _query.value.trim(),
                      onInventoryMutated: _loadItems,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0x73FFFFFF)),
            ),
        ],
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _search,
                onChanged: _applyLocalSearch,
                decoration: const InputDecoration(
                  hintText: 'Search your stuff…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            itemCount: 8,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) =>
                                const SkeletonListTile(),
                          ),
                        ),
                      ),
                    )
                  : (_error != null)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Couldn’t load your inventory.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Try again in a moment.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.70),
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.55),
                                      height: 1.35,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ValueListenableBuilder<Map<String, int>>(
                      valueListenable: _thresholds,
                            builder: (context, thresholds, _) {
                              return ValueListenableBuilder<String>(
                                valueListenable: _query,
                                builder: (context, q, _) {
                                  final query = q.trim();
                                  if (query.isEmpty) {
                                    return _buildSpacesGrid(thresholds);
                                  }

                                  return ValueListenableBuilder<bool>(
                                    valueListenable: _aiSearching,
                                    builder: (context, searching, _) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          if (searching)
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                                              child: Text(
                                                'Searching…',
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: Colors.white.withValues(alpha: 0.55),
                                                ),
                                              ),
                                            ),
                                          Expanded(
                                            child: ValueListenableBuilder<List<InventoryItem>>(
                                              valueListenable: _rows,
                                              builder: (context, rows, _) {
                                                if (rows.isEmpty) {
                                                  return Center(
                                                    child: Text(
                                                      'No results.',
                                                      style: TextStyle(
                                                        color: Colors.white.withValues(alpha: 0.65),
                                                      ),
                                                    ),
                                                  );
                                                }

                                                return _SearchResultsList(
                                                  rows: rows,
                                                  thresholds: thresholds,
                                                  onEdit: _editItem,
                                                  onDelete: _deleteItem,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
              ),
          ],
        ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'fab_inventory',
            onPressed: _addItem,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.rows,
    required this.thresholds,
    required this.onEdit,
    required this.onDelete,
  });

  final List<InventoryItem> rows;
  final Map<String, int> thresholds;
  final Future<void> Function(InventoryItem item) onEdit;
  final Future<void> Function(InventoryItem item) onDelete;

  @override
  Widget build(BuildContext context) {
    final hasImages = rows.any((e) => (e.imageUrl ?? '').trim().isNotEmpty);
    if (!hasImages) {
      return ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = rows[index];
          final threshold = thresholds[item.itemId];
          final isLow = (threshold != null && threshold > 0 && item.quantity <= threshold);
          return Dismissible(
            key: ValueKey(item.itemId),
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 16),
              color: AppColors.swipe,
              child: const Icon(Icons.edit_outlined),
            ),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.15),
              child: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                await onEdit(item);
                return false;
              }
              if (direction == DismissDirection.endToStart) {
                await onDelete(item);
                return false;
              }
              return false;
            },
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              title: Text(item.name),
              subtitle: Text(
                '${item.category} · ${item.location}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.60)),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLow) ...[
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.70),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'Qty ${item.quantity}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                  ),
                ],
              ),
              onTap: () => onEdit(item),
            ),
          );
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.98,
      ),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final item = rows[index];
        final threshold = thresholds[item.itemId];
        final isLow = (threshold != null && threshold > 0 && item.quantity <= threshold);
        return _ItemGridCard(
          item: item,
          isLow: isLow,
          onEdit: () => onEdit(item),
          onDelete: () => onDelete(item),
        );
      },
    );
  }
}

class _ItemGridCard extends StatelessWidget {
  const _ItemGridCard({
    required this.item,
    required this.isLow,
    required this.onEdit,
    required this.onDelete,
  });

  final InventoryItem item;
  final bool isLow;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final url = (item.imageUrl ?? '').trim();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onEdit,
      onLongPress: onDelete,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: url.isEmpty
                        ? Container(
                            color: Colors.white.withValues(alpha: 0.04),
                            child: Icon(
                              Icons.image_outlined,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          )
                        : Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.white.withValues(alpha: 0.04),
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    'Qty ${item.quantity}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                  ),
                ),
              ),
              if (isLow)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemEditorResult {
  const _ItemEditorResult({
    required this.add,
    required this.update,
    required this.threshold,
  });

  final AddItemRequest add;
  final UpdateItemRequest update;
  final int? threshold;
}

class _ItemEditorSheet extends StatefulWidget {
  const _ItemEditorSheet({this.item, this.initialThreshold});

  final InventoryItem? item;
  final int? initialThreshold;

  @override
  State<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<_ItemEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _location;
  late final TextEditingController _quantity;
  late final TextEditingController _threshold;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name ?? '');
    _category = TextEditingController(text: widget.item?.category ?? '');
    _location = TextEditingController(text: widget.item?.location ?? '');
    _quantity = TextEditingController(
      text: (widget.item?.quantity ?? 1).toString(),
    );
    _threshold = TextEditingController(
      text: (widget.initialThreshold ?? '').toString(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _location.dispose();
    _quantity.dispose();
    _threshold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.item == null ? 'Add item' : 'Edit item',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Name',
              hintStyle: TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
              filled: true,
              fillColor: Color(0x0AFFFFFF),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x40FFFFFF), width: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _category,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Category',
              hintStyle: TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
              filled: true,
              fillColor: Color(0x0AFFFFFF),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x40FFFFFF), width: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _location,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Location',
              hintStyle: TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
              filled: true,
              fillColor: Color(0x0AFFFFFF),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x40FFFFFF), width: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Quantity',
              hintStyle: TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
              filled: true,
              fillColor: Color(0x0AFFFFFF),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: Color(0x40FFFFFF), width: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(_quantity.text.trim()) ?? 0;
                final rawThreshold = int.tryParse(_threshold.text.trim());
                final threshold = (rawThreshold != null && rawThreshold > 0)
                    ? rawThreshold
                    : null;
                final location = _location.text.trim().isEmpty
                    ? 'Unsorted'
                    : _location.text.trim();
                if (widget.item == null) {
                  Navigator.of(context).pop(
                    _ItemEditorResult(
                      threshold: threshold,
                      add: AddItemRequest(
                        name: _name.text.trim(),
                        category: _category.text.trim(),
                        quantity: qty,
                        location: location,
                      ),
                      update: UpdateItemRequest(itemId: ''),
                    ),
                  );
                } else {
                  Navigator.of(context).pop(
                    _ItemEditorResult(
                      threshold: threshold,
                      add: AddItemRequest(
                        name: '',
                        category: '',
                        quantity: 0,
                        location: '',
                      ),
                      update: UpdateItemRequest(
                        itemId: widget.item!.itemId,
                        name: _name.text.trim(),
                        category: _category.text.trim(),
                        quantity: qty,
                        location: location,
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0x73FFFFFF),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
