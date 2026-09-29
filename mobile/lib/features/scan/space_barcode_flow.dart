import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import 'confirm_scan_sheet.dart';
import 'upload_photo_flow.dart';

Future<void> runSpaceBarcodeFlow({
  required BuildContext context,
  required ApiClient api,
  required String preselectedSpace,
  required Future<void> Function() onItemsSaved,
}) async {
  final barcode = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const _SpaceBarcodeScannerPage()),
  );
  if (barcode == null || barcode.trim().isEmpty || !context.mounted) return;
  final scanCode = barcode.trim();

  BarcodeLookupResult lookup;
  try {
    lookup = await api.barcodeLookup(barcode: scanCode);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(describeError(error).$1)),
    );
    return;
  }
  if (!context.mounted) return;

  final name = (lookup.name ?? '').trim();
  final isUnknown = name.isEmpty || name.toLowerCase() == 'unknown item';
  if (isUnknown) {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Unknown barcode', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Photograph the product label so FindEZ can read its manufacturer and part number.', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 15)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'label'),
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scan Product Label'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, 'manual'),
                  child: const Text('Enter details manually'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'label') {
      await runUploadPhotoFlow(
        context: context,
        api: api,
        preselectedSpace: preselectedSpace,
        barcodeToAssociate: scanCode,
        onItemsSaved: onItemsSaved,
      );
      return;
    }
    if (action != 'manual') return;
  }

  final items = [
    ExtractedInventoryItem(
      name: isUnknown ? '' : name,
      category: (lookup.category ?? '').trim().isEmpty ? 'Other' : lookup.category!.trim(),
      quantity: 1,
      brand: (lookup.brand ?? '').trim().isEmpty ? null : lookup.brand!.trim(),
      partNumber: (lookup.model ?? '').trim().isEmpty ? null : lookup.model!.trim(),
      barcode: scanCode,
      location: preselectedSpace,
    ),
  ];
  final confirmed = await showModalBottomSheet<List<ExtractedInventoryItem>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ConfirmScanSheet(items: items, defaultLocation: preselectedSpace),
  );
  if (confirmed == null || confirmed.isEmpty || !context.mounted) return;

  final payload = confirmed.map((item) => ExtractedInventoryItem(
    name: item.name.trim(),
    category: item.category.trim().isEmpty ? 'Other' : item.category.trim(),
    quantity: item.quantity,
    subcategory: item.subcategory,
    brand: item.brand,
    partNumber: item.partNumber,
    barcode: item.barcode,
    tags: item.tags,
    confidence: item.confidence,
    notes: item.notes,
    location: preselectedSpace,
    catalogMatch: item.catalogMatch,
  )).where((item) => item.name.isNotEmpty).toList();
  if (payload.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Name is required.')),
    );
    return;
  }

  try {
    final result = await api.bulkCreateInventory(items: payload);
    if (!context.mounted) return;
    if (result.inserted.isEmpty) {
      final reason = result.failures.isNotEmpty
          ? (result.failures.first['reason'] ?? 'Could not save this item.').toString()
          : 'Could not save this item.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
      return;
    }
    await onItemsSaved();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${result.inserted.first.name} to $preselectedSpace')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(describeError(error).$1)),
    );
  }
}

class _SpaceBarcodeScannerPage extends StatefulWidget {
  const _SpaceBarcodeScannerPage();

  @override
  State<_SpaceBarcodeScannerPage> createState() => _SpaceBarcodeScannerPageState();
}

class _SpaceBarcodeScannerPageState extends State<_SpaceBarcodeScannerPage> {
  late final MobileScannerController _controller;
  bool _returned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(formats: const [BarcodeFormat.all]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Scan Barcode'), backgroundColor: Colors.black),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (_returned || capture.barcodes.isEmpty) return;
          final value = capture.barcodes.first.rawValue?.trim();
          if (value == null || value.isEmpty) return;
          _returned = true;
          Navigator.of(context).pop(value);
        },
      ),
    );
  }
}
