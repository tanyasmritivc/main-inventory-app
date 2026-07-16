import 'dart:async';

import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/low_stock_prefs.dart';

/// Opens the comprehensive item detail bottom sheet.
///
/// [permission] should be `'edit'` or `'view'`. Write actions (checkout,
/// edit notes, add documents) are hidden for `'view'`.
/// [initialThreshold] is the alert threshold from LowStockPrefs.
/// [spaceName] is passed when checking out an item (used as the space label).
Future<void> showItemDetailSheet(
  BuildContext context, {
  required InventoryItem item,
  required ApiClient api,
  String permission = 'edit',
  int? initialThreshold,
  String spaceName = '',
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ItemDetailSheet(
      item: item,
      api: api,
      permission: permission,
      initialThreshold: initialThreshold,
      spaceName: spaceName,
    ),
  );
}

class _ItemDetailSheet extends StatefulWidget {
  const _ItemDetailSheet({
    required this.item,
    required this.api,
    required this.permission,
    required this.spaceName,
    this.initialThreshold,
  });

  final InventoryItem item;
  final ApiClient api;
  final String permission;
  final String spaceName;
  final int? initialThreshold;

  @override
  State<_ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<_ItemDetailSheet> {
  late final TextEditingController _notesCtrl;
  late final TextEditingController _purchaseSourceCtrl;
  late final TextEditingController _thresholdCtrl;

  bool _isEditingNotes = false;
  Timer? _thresholdDebounce;

  List<DocumentEntry> _localDocs = [];

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.item.notes ?? '');
    _purchaseSourceCtrl = TextEditingController(text: widget.item.purchaseSource ?? '');
    _thresholdCtrl = TextEditingController(
      text: (widget.initialThreshold != null && widget.initialThreshold! > 0)
          ? widget.initialThreshold.toString()
          : '',
    );
    _loadDocuments();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _purchaseSourceCtrl.dispose();
    _thresholdCtrl.dispose();
    _thresholdDebounce?.cancel();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────────

  void _loadDocuments() {
    widget.api.getDocuments(itemId: widget.item.itemId).then((docs) {
      if (!mounted) return;
      setState(() => _localDocs = docs);
    }).catchError((_) {});
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _saveNotes() async {
    final notes = _notesCtrl.text.trim();
    try {
      await widget.api.updateItem(
        request: UpdateItemRequest(itemId: widget.item.itemId, notes: notes),
      );
      if (!mounted) return;
      setState(() => _isEditingNotes = false);
    } catch (_) {
      // keep editing mode on failure
    }
  }

  void _scheduleThresholdSave() {
    _thresholdDebounce?.cancel();
    _thresholdDebounce = Timer(const Duration(milliseconds: 600), () async {
      final raw = int.tryParse(_thresholdCtrl.text.trim());
      final threshold = (raw != null && raw > 0) ? raw : null;
      try {
        await LowStockPrefs.setThreshold(
          itemId: widget.item.itemId,
          threshold: threshold,
        );
      } catch (_) {}
    });
  }

  Future<void> _showCheckoutDialog() async {
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime? dueBack;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.surface2(ctx),
          title: Text(
            'Check Out ${widget.item.name}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Who is taking this?',
                  hintStyle: TextStyle(color: Color(0x4DFFFFFF)),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0x14FFFFFF))),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Notes (optional)',
                  hintStyle: TextStyle(color: Color(0x4DFFFFFF)),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0x14FFFFFF))),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38)),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate:
                        DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 30)),
                    builder: (context, child) =>
                        Theme(data: ThemeData.dark(), child: child!),
                  );
                  if (picked != null) {
                    setDlgState(() => dueBack = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: const Color(0x14FFFFFF)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: Color(0x73FFFFFF), size: 14),
                      const SizedBox(width: 8),
                      Text(
                        dueBack == null
                            ? 'Set due date (optional)'
                            : 'Due: ${dueBack!.day}/${dueBack!.month}/${dueBack!.year}',
                        style: const TextStyle(
                            color: Color(0x73FFFFFF), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0x73FFFFFF))),
            ),
            TextButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                try {
                  await widget.api.checkoutItem(
                    itemId: widget.item.itemId,
                    checkedOutBy: nameCtrl.text.trim(),
                    spaceName: widget.spaceName,
                    dueBackAt: dueBack?.toIso8601String(),
                    notes: notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    setState(() {}); // refresh FutureBuilder
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '${widget.item.name} checked out to ${nameCtrl.text.trim()}'),
                    ));
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Failed to check out. Try again.')),
                    );
                  }
                }
              },
              child: const Text('Check Out',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _showStoreLinks() async {
    final itemName = Uri.encodeComponent(widget.item.name);
    final links = [
      {
        'name': 'Amazon',
        'url': 'https://www.amazon.com/s?k=$itemName',
        'icon': Icons.shopping_bag_outlined
      },
      {
        'name': 'Google Shopping',
        'url': 'https://www.google.com/search?tbm=shop&q=$itemName',
        'icon': Icons.search
      },
      {
        'name': 'eBay',
        'url': 'https://www.ebay.com/sch/i.html?_nkw=$itemName',
        'icon': Icons.store_outlined
      },
      {
        'name': 'Walmart',
        'url': 'https://www.walmart.com/search?q=$itemName',
        'icon': Icons.local_grocery_store_outlined
      },
      {
        'name': 'Target',
        'url': 'https://www.target.com/s?searchTerm=$itemName',
        'icon': Icons.shopping_cart_outlined
      },
    ];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface2(context),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Where to buy "${widget.item.name}"',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text('Tap to open in browser',
                  style: TextStyle(
                      color: Color(0x73FFFFFF), fontSize: 12)),
            ),
            ...links.map((link) => ListTile(
                  leading: Icon(link['icon'] as IconData,
                      color: Colors.white70, size: 20),
                  title: Text(link['name'] as String,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15)),
                  trailing: const Icon(Icons.open_in_new,
                      color: Color(0x4DFFFFFF), size: 16),
                  onTap: () async {
                    final uri = Uri.parse(link['url'] as String);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadDocument() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface2(context),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Colors.white),
              title: const Text('Choose Photo',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined,
                  color: Colors.white),
              title: const Text('Choose PDF',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    List<int>? bytes;
    String? filename;

    if (choice == 'photo') {
      final picker = ImagePicker();
      final x = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85);
      if (x == null) return;
      bytes = await x.readAsBytes();
      filename = x.name;
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      if (picked.bytes == null) return;
      bytes = picked.bytes!.toList();
      filename = picked.name;
    }

    if (!mounted) return;
    try {
      final file = dio.MultipartFile.fromBytes(bytes, filename: filename);
      await widget.api.uploadDocument(
          file: file, itemId: widget.item.itemId);
      _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed. Please try again.')),
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _infoRow(String label, String value) => Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0x73FFFFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w400)),
            const Spacer(),
            Flexible(
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );

  Widget _divider() => Container(
      height: 0.5,
      color: const Color(0x14FFFFFF),
      margin: const EdgeInsets.symmetric(horizontal: 18));

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final canEdit = widget.permission == 'edit';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24)),
        border:
            Border(top: BorderSide(color: Color(0x14FFFFFF), width: 0.5)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(99)),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(item.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5)),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(item.category,
                  style: const TextStyle(
                      color: Color(0x4DFFFFFF), fontSize: 14)),
            ),
            const SizedBox(height: 24),

            // ── Info rows ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0x0AFFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0x14FFFFFF), width: 0.5),
                ),
                child: Column(
                  children: [
                    _infoRow('Category', item.category),
                    _divider(),
                    _infoRow('Location', item.location),
                    _divider(),
                    _infoRow('Quantity', '${item.quantity}'),
                    if (item.brand != null &&
                        item.brand!.isNotEmpty) ...[
                      _divider(),
                      _infoRow('Brand', item.brand!),
                    ],
                    if (item.barcode != null &&
                        item.barcode!.isNotEmpty) ...[
                      _divider(),
                      _infoRow('Barcode', item.barcode!),
                    ],
                    if (item.partNumber != null &&
                        item.partNumber!.isNotEmpty) ...[
                      _divider(),
                      _infoRow('Part number', item.partNumber!),
                    ],
                    if (item.subcategory != null &&
                        item.subcategory!.isNotEmpty) ...[
                      _divider(),
                      _infoRow('Subcategory', item.subcategory!),
                    ],
                    _divider(),
                    _infoRow('Date added', _formatDate(item.createdAt)),
                    if (item.confidence != null) ...[
                      _divider(),
                      _infoRow('AI confidence',
                          '${(item.confidence! * 100).toStringAsFixed(0)}%'),
                    ],
                  ],
                ),
              ),
            ),

            // ── Check Out ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('CHECK OUT',
                          style: TextStyle(
                              color: Color(0x4DFFFFFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6)),
                      const Spacer(),
                      if (canEdit)
                        GestureDetector(
                          onTap: _showCheckoutDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0x0AFFFFFF),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                  color: const Color(0x14FFFFFF)),
                            ),
                            child: const Text('Check Out',
                                style: TextStyle(
                                    color: Color(0x73FFFFFF),
                                    fontSize: 12)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // FutureBuilder re-fetches each rebuild so returning an
                  // item via setState() will show the updated status.
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: widget.api
                        .getItemCheckouts(itemId: item.itemId)
                        .catchError(
                            (_) => <Map<String, dynamic>>[]),
                    builder: (context, snapshot) {
                      final active = (snapshot.data ?? [])
                          .where((c) => c['is_active'] == true)
                          .toList();
                      if (active.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x0A30D158),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0x1A30D158)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: Color(0xFF30D158), size: 14),
                              SizedBox(width: 8),
                              Text('Available — not checked out',
                                  style: TextStyle(
                                      color: Color(0xFF30D158),
                                      fontSize: 12)),
                            ],
                          ),
                        );
                      }
                      final checkout = active.first;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x0AFBBF24),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0x33FBBF24)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline,
                                color: Color(0xFFFBBF24), size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Checked out by ${checkout['checked_out_by']}',
                                style: const TextStyle(
                                    color: Color(0xFFFBBF24),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            if (canEdit)
                              GestureDetector(
                                onTap: () async {
                                  await widget.api.returnItem(
                                      checkoutId: checkout['checkout_id']
                                          as String);
                                  if (mounted) setState(() {});
                                },
                                child: const Text('Return',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Notes ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('NOTES',
                          style: TextStyle(
                              color: Color(0x4DFFFFFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6)),
                      const Spacer(),
                      if (canEdit)
                        _isEditingNotes
                            ? GestureDetector(
                                onTap: _saveNotes,
                                child: const Text('Save',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                              )
                            : GestureDetector(
                                onTap: () => setState(
                                    () => _isEditingNotes = true),
                                child: const Text('Edit',
                                    style: TextStyle(
                                        color: Color(0x73FFFFFF),
                                        fontSize: 13)),
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
                      border: Border.all(
                          color: const Color(0x14FFFFFF), width: 0.5),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: _isEditingNotes
                        ? TextField(
                            controller: _notesCtrl,
                            maxLines: null,
                            autofocus: true,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Add notes about this item...',
                              hintStyle: TextStyle(
                                  color: Color(0x33FFFFFF),
                                  fontSize: 14),
                            ),
                          )
                        : Text(
                            _notesCtrl.text.isNotEmpty
                                ? _notesCtrl.text
                                : 'Tap Edit to add notes...',
                            style: TextStyle(
                              color: _notesCtrl.text.isNotEmpty
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

            // ── Documents ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('DOCUMENTS',
                          style: TextStyle(
                              color: Color(0x4DFFFFFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6)),
                      const Spacer(),
                      if (canEdit)
                        GestureDetector(
                          onTap: _pickAndUploadDocument,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0x0AFFFFFF),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                  color: const Color(0x14FFFFFF),
                                  width: 0.5),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add,
                                    color: Color(0x73FFFFFF), size: 14),
                                SizedBox(width: 4),
                                Text('Add',
                                    style: TextStyle(
                                        color: Color(0x73FFFFFF),
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_localDocs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0x14FFFFFF), width: 0.5),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.description_outlined,
                              color: Color(0x20FFFFFF), size: 28),
                          SizedBox(height: 8),
                          Text('No documents yet',
                              style: TextStyle(
                                  color: Color(0x33FFFFFF),
                                  fontSize: 13)),
                          Text('Add receipts, manuals, or warranties',
                              style: TextStyle(
                                  color: Color(0x20FFFFFF),
                                  fontSize: 12)),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0x14FFFFFF), width: 0.5),
                      ),
                      child: Column(
                        children:
                            _localDocs.asMap().entries.map((entry) {
                          final doc = entry.value;
                          final isLast =
                              entry.key == _localDocs.length - 1;
                          return Column(
                            children: [
                              ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 4),
                                leading: Icon(
                                  (doc.mimeType?.contains('pdf') ==
                                          true)
                                      ? Icons.picture_as_pdf_outlined
                                      : Icons.image_outlined,
                                  color: const Color(0x73FFFFFF),
                                  size: 20,
                                ),
                                title: Text(
                                    doc.displayName ?? doc.filename,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14)),
                                trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Color(0x33FFFFFF),
                                    size: 12),
                                onTap: () {
                                  if (doc.url != null) {
                                    launchUrl(Uri.parse(doc.url!));
                                  }
                                },
                              ),
                              if (!isLast)
                                Container(
                                  height: 0.5,
                                  color: const Color(0x14FFFFFF),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),

            // ── Tags ──────────────────────────────────────────────────
            // Note: GET /sharing/{shareId}/inventory may omit `tags` —
            // if the field is absent the section simply won't render.
            if (item.tags != null && item.tags!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text('TAGS',
                    style: TextStyle(
                        color: Color(0x4DFFFFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6)),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: item.tags!
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0x0AFFFFFF),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                  color: const Color(0x14FFFFFF),
                                  width: 0.5),
                            ),
                            child: Text(tag,
                                style: const TextStyle(
                                    color: Color(0x73FFFFFF),
                                    fontSize: 13)),
                          ))
                      .toList(),
                ),
              ),
            ],

            // ── Where to Buy ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('WHERE TO BUY',
                          style: TextStyle(
                              color: Color(0x4DFFFFFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showStoreLinks,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0x0AFFFFFF),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                                color: const Color(0x14FFFFFF)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 11,
                                  color: Color(0x73FFFFFF)),
                              SizedBox(width: 4),
                              Text('Find stores',
                                  style: TextStyle(
                                      color: Color(0x73FFFFFF),
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_purchaseSourceCtrl.text.trim().isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _purchaseSourceCtrl.text
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .map((store) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0x0AFFFFFF),
                                  borderRadius:
                                      BorderRadius.circular(99),
                                  border: Border.all(
                                      color: const Color(0x14FFFFFF)),
                                ),
                                child: Text(store,
                                    style: const TextStyle(
                                        color: Color(0x99FFFFFF),
                                        fontSize: 12)),
                              ))
                          .toList(),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0x0AFFFFFF)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.storefront_outlined,
                              color: Color(0x4DFFFFFF), size: 16),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tap "Find stores" to get AI-powered purchase links',
                              style: TextStyle(
                                  color: Color(0x4DFFFFFF),
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ── Item QR Code ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text('ITEM QR CODE',
                      style: TextStyle(
                          color: Color(0x4DFFFFFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0x14FFFFFF)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: QrImageView(
                            data: item.itemId,
                            size: 80,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black),
                            dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape:
                                    QrDataModuleShape.square,
                                color: Colors.black),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(item.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(item.location,
                                  style: const TextStyle(
                                      color: Color(0x73FFFFFF),
                                      fontSize: 12)),
                              const SizedBox(height: 8),
                              const Text(
                                  'Scan this code to quickly find this item in FindEZ',
                                  style: TextStyle(
                                      color: Color(0x4DFFFFFF),
                                      fontSize: 11)),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () => SharePlus.instance.share(
                                  ShareParams(
                                      text:
                                          'FindEZ item: ${item.name}\nID: ${item.itemId}\nLocation: ${item.location}'),
                                ),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0x0AFFFFFF),
                                    borderRadius:
                                        BorderRadius.circular(99),
                                    border: Border.all(
                                        color:
                                            const Color(0x14FFFFFF)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.share_outlined,
                                          size: 12,
                                          color: Color(0x73FFFFFF)),
                                      SizedBox(width: 6),
                                      Text('Share item',
                                          style: TextStyle(
                                              color:
                                                  Color(0x73FFFFFF),
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Alert threshold ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text('ALERT ME WHEN BELOW',
                      style: TextStyle(
                          color: Color(0x4DFFFFFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0x14FFFFFF), width: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    child: TextField(
                      controller: _thresholdCtrl,
                      keyboardType: TextInputType.number,
                      readOnly: !canEdit,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.5),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Quantity threshold',
                        hintStyle: TextStyle(
                            color: Color(0x33FFFFFF), fontSize: 14),
                      ),
                      onChanged:
                          canEdit ? (_) => _scheduleThresholdSave() : null,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Close ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0x14FFFFFF), width: 0.5),
                  ),
                  child: const Center(
                    child: Text('Close',
                        style: TextStyle(
                            color: Color(0x73FFFFFF),
                            fontSize: 15,
                            fontWeight: FontWeight.w400)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
