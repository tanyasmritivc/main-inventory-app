import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api_client.dart';

class SharedInventoryPage extends StatefulWidget {
  const SharedInventoryPage({
    super.key,
    required this.shareId,
    required this.shareName,
    required this.permission,
    required this.api,
  });

  final String shareId;
  final String shareName;
  final String permission;
  final ApiClient api;

  @override
  State<SharedInventoryPage> createState() => _SharedInventoryPageState();
}

class _SharedInventoryPageState extends State<SharedInventoryPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _joinCodeCtrl;

  @override
  void initState() {
    super.initState();
    _joinCodeCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _joinCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final raw = await widget.api.getShareInventory(widget.shareId);
      if (!mounted) return;
      setState(() {
        _items = raw.cast<Map<String, dynamic>>();
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addItem() async {
    final created = await showModalBottomSheet<AddItemRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => _SharedAddItemSheet(initialLocation: widget.shareName),
    );
    if (created == null) return;
    try {
      await widget.api.addItem(item: created);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add item')),
        );
      }
    }
  }

  Future<void> _uploadPhoto() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Colors.white),
              title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.white),
              title: const Text('Choose from Library', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src == null) return;

    final x = await _picker.pickImage(source: src, maxWidth: 2048, imageQuality: 92);
    if (x == null) return;
    final rawBytes = await x.readAsBytes();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Extracting items…')),
    );

    MultiExtractResult extracted;
    try {
      extracted = await widget.api.extractInventoryFromImage(
        bytes: rawBytes.toList(),
        filename: x.name,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to extract items. Try again.')),
      );
      return;
    }

    if (extracted.items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items found in image.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final toSave = extracted.items
          .map((it) => ExtractedInventoryItem(
                name: it.name,
                category: it.category,
                quantity: it.quantity,
                location: widget.shareName,
                subcategory: it.subcategory,
                brand: it.brand,
                partNumber: it.partNumber,
                barcode: it.barcode,
                tags: it.tags,
                confidence: it.confidence,
                notes: it.notes,
              ))
          .toList();
      await widget.api.bulkCreateInventory(items: toSave);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${toSave.length} items added')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save items. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanBarcode() async {
    String? barcode;
    try {
      barcode = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const _SharedBarcodeScannerPage()),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to scan. Please try again.')),
      );
      return;
    }
    if (barcode == null || barcode.trim().isEmpty) return;

    BarcodeLookupResult lookup;
    try {
      lookup = await widget.api.barcodeLookup(barcode: barcode.trim());
    } catch (_) {
      lookup = BarcodeLookupResult();
    }
    if (!mounted) return;

    final request = await showModalBottomSheet<AddItemRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => _SharedAddItemSheet(
        initialLocation: widget.shareName,
        initialName: lookup.name,
        initialCategory: lookup.category,
        initialBarcode: barcode,
      ),
    );
    if (request == null) return;

    try {
      await widget.api.addItem(item: request);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item added')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add item. Try again.')),
      );
    }
  }

  Future<void> _joinSpaceDialog() async {
    _joinCodeCtrl.clear();
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
                controller: _joinCodeCtrl,
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
                final code = _joinCodeCtrl.text.trim().toUpperCase();
                if (code.length != 6) {
                  setDlgState(() => error = 'Enter a 6-character code.');
                  return;
                }
                try {
                  await widget.api.joinShare(code);
                  if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Joined! Check Joined Spaces to view.')),
                    );
                  }
                } catch (e) {
                  setDlgState(() => error = 'Invalid code or already joined.');
                }
              },
              child: const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _sortedCategoryPills() {
    final cats = <String>{};
    for (final it in _items) {
      final c = (it['category'] ?? '').toString().trim();
      cats.add(c.isEmpty ? 'Uncategorized' : c);
    }
    return ['All', ...cats.toList()..sort()];
  }

  bool _matchesSearch(Map<String, dynamic> item) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return (item['name'] ?? '').toString().toLowerCase().contains(q) ||
        (item['category'] ?? '').toString().toLowerCase().contains(q);
  }

  Widget _buildPinnedHeader() {
    final pills = _sortedCategoryPills();
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search in this space...',
                    hintStyle: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Color(0x4DFFFFFF), size: 20),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                              FocusScope.of(context).unfocus();
                            },
                            child: const Icon(Icons.close, color: Color(0x4DFFFFFF), size: 16),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              physics: const BouncingScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: pills.length,
              itemBuilder: (_, i) {
                final label = pills[i];
                final isActive = _selectedCategory == label;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = label),
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
        ],
      ),
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final name = (item['name'] ?? '').toString();
    final category = (item['category'] ?? '').toString().trim();
    final qty = item['quantity']?.toString() ?? '0';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (category.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    category,
                    style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          Text(
            'Qty $qty',
            style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedItems() {
    if (_items.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text('No items in this shared space.', style: TextStyle(color: Color(0x4DFFFFFF))),
        ),
      );
    }

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      final cat = (item['category'] ?? '').toString().trim();
      final key = cat.isEmpty ? 'Uncategorized' : cat;
      groups.putIfAbsent(key, () => []).add(item);
    }
    final sortedCats = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final displayedCats = _selectedCategory == 'All'
        ? sortedCats
        : sortedCats.where((c) => c == _selectedCategory).toList();

    final filteredGroups = <String, List<Map<String, dynamic>>>{};
    for (final cat in displayedCats) {
      final matches = (groups[cat] ?? []).where(_matchesSearch).toList();
      if (matches.isNotEmpty) filteredGroups[cat] = matches;
    }
    final filteredCats = displayedCats.where((c) => filteredGroups.containsKey(c)).toList();

    if (filteredCats.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text('No items match your search', style: TextStyle(color: Color(0x4DFFFFFF))),
        ),
      );
    }

    final children = <Widget>[];
    for (final cat in filteredCats) {
      children.add(Padding(
        padding: const EdgeInsets.only(left: 32, top: 20, bottom: 6),
        child: Text(
          cat.toUpperCase(),
          style: const TextStyle(
            color: Color(0x47FFFFFF),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ));
      children.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
      ));
    }
    children.add(const SizedBox(height: 24));

    return SliverList(delegate: SliverChildListDelegate(children));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: widget.permission == 'edit'
          ? FloatingActionButton(
              heroTag: 'fab_shared_${widget.shareId}',
              onPressed: _addItem,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              child: const Icon(Icons.add),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(
              widget.shareName,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500),
            ),
            centerTitle: true,
            backgroundColor: Colors.black,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(28),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  widget.permission == 'view'
                      ? 'Read only · Shared inventory'
                      : 'Can edit · Shared inventory',
                  style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 12),
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else ...[
            if (widget.permission == 'view')
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x14FFFFFF)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.visibility_outlined, color: Color(0x73FFFFFF), size: 16),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "You're viewing a shared inventory. Contact the owner to make changes.",
                            style: TextStyle(color: Color(0x73FFFFFF), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.permission == 'edit')
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _uploadPhoto,
                              icon: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white60),
                              label: const Text('Upload Photo', style: TextStyle(fontSize: 11, color: Colors.white60)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                backgroundColor: const Color(0x0AFFFFFF),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _scanBarcode,
                              icon: const Icon(Icons.qr_code_scanner, size: 16, color: Colors.white60),
                              label: const Text('Scan Barcode', style: TextStyle(fontSize: 11, color: Colors.white60)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                backgroundColor: const Color(0x0AFFFFFF),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _joinSpaceDialog,
                              icon: const Icon(Icons.person_add_outlined, size: 16, color: Colors.white60),
                              label: const Text('Join Space', style: TextStyle(fontSize: 11, color: Colors.white60)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                backgroundColor: const Color(0x0AFFFFFF),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (_items.isNotEmpty)
              SliverPersistentHeader(
                pinned: true,
                delegate: _SharedSearchPinDelegate(
                  height: 108,
                  child: _buildPinnedHeader(),
                ),
              ),
            _buildGroupedItems(),
          ],
        ],
      ),
    );
  }
}

// ─── Barcode scanner page ────────────────────────────────────────────────────

class _SharedBarcodeScannerPage extends StatefulWidget {
  const _SharedBarcodeScannerPage();

  @override
  State<_SharedBarcodeScannerPage> createState() => _SharedBarcodeScannerPageState();
}

class _SharedBarcodeScannerPageState extends State<_SharedBarcodeScannerPage> {
  MobileScannerController? _controller;
  bool _returned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const <BarcodeFormat>[BarcodeFormat.all],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: controller == null
          ? const SizedBox.shrink()
          : MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (_returned) return;
                final codes = capture.barcodes;
                if (codes.isEmpty) return;
                final raw = codes.first.rawValue;
                if (raw == null || raw.trim().isEmpty) return;
                _returned = true;
                Navigator.of(context).pop(raw.trim());
              },
            ),
    );
  }
}

class _SharedSearchPinDelegate extends SliverPersistentHeaderDelegate {
  const _SharedSearchPinDelegate({required this.child, this.height = 100});

  final Widget child;
  final double height;

  @override double get minExtent => height;
  @override double get maxExtent => height;
  @override bool shouldRebuild(_SharedSearchPinDelegate old) =>
      old.child != child || old.height != height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
}

class _SharedAddItemSheet extends StatefulWidget {
  const _SharedAddItemSheet({
    required this.initialLocation,
    this.initialName,
    this.initialCategory,
    this.initialBarcode,
  });
  final String initialLocation;
  final String? initialName;
  final String? initialCategory;
  final String? initialBarcode;

  @override
  State<_SharedAddItemSheet> createState() => _SharedAddItemSheetState();
}

class _SharedAddItemSheetState extends State<_SharedAddItemSheet> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _quantity;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName ?? '');
    _category = TextEditingController(text: widget.initialCategory ?? '');
    _quantity = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _quantity.dispose();
    super.dispose();
  }

  InputDecoration _field(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0x33FFFFFF), fontSize: 15),
        filled: true,
        fillColor: const Color(0x0AFFFFFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0x40FFFFFF), width: 0.5),
        ),
      );

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
        border: Border(top: BorderSide(color: Color(0x14FFFFFF), width: 0.5)),
      ),
      padding: EdgeInsets.only(left: 16, right: 16, bottom: bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add item',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(controller: _name, style: const TextStyle(color: Colors.white, fontSize: 15), decoration: _field('Name')),
          const SizedBox(height: 10),
          TextField(controller: _category, style: const TextStyle(color: Colors.white, fontSize: 15), decoration: _field('Category')),
          const SizedBox(height: 10),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _field('Quantity'),
          ),
          const SizedBox(height: 10),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Text(
              widget.initialLocation,
              style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 15),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(_quantity.text.trim()) ?? 1;
                Navigator.of(context).pop(
                  AddItemRequest(
                    name: _name.text.trim(),
                    category: _category.text.trim(),
                    quantity: qty,
                    location: widget.initialLocation,
                    barcode: widget.initialBarcode,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0x73FFFFFF), fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
