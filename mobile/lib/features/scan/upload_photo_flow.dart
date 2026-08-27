import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/pro_status.dart';
import '../../core/upgrade_sheet.dart';
import 'confirm_scan_sheet.dart';
import 'qr_sheet.dart';

List<int> _compressImageBytes(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes.toList();
    const maxDim = 1920;
    img.Image resized = decoded;
    if (decoded.width >= decoded.height && decoded.width > maxDim) {
      resized = img.copyResize(decoded, width: maxDim);
    } else if (decoded.height > decoded.width && decoded.height > maxDim) {
      resized = img.copyResize(decoded, height: maxDim);
    }
    return img.encodeJpg(resized, quality: 85);
  } catch (_) {
    return bytes.toList();
  }
}

String _normalizeCategory(String rawCategory) {
  final c = rawCategory.trim().toLowerCase();
  if (c.isEmpty || c == 'unsorted') return 'Other';

  if (c.contains('food') || c.contains('grocery') || c.contains('beverage') ||
      c.contains('snack') || c.contains('nut') || c.contains('nuts') ||
      c.contains('bar') || c.contains('kirkland') || c.contains('cashew') ||
      c.contains('almond') || c.contains('pecan')) {
    return 'Food';
  }

  if (c.contains('cosmetic') || c.contains('beauty') || c.contains('makeup') ||
      c.contains('skincare')) {
    return 'Cosmetics';
  }

  if (c.contains('electronic') || c.contains('tech') || c.contains('gadget') ||
      c.contains('computer') || c.contains('phone') ||
      c.contains('appliance')) {
    return 'Electronics';
  }

  if (c.contains('clothing') || c.contains('apparel') ||
      c.contains('fashion') || c.contains('shoe')) {
    return 'Clothing';
  }

  if (c.contains('health') || c.contains('medicine') ||
      c.contains('pharma') || c.contains('supplement') ||
      c.contains('medication')) {
    return 'Health';
  }

  if (c.contains('home') || c.contains('kitchen') ||
      c.contains('furniture') || c.contains('decor') ||
      c.contains('appliance')) {
    return 'Home';
  }

  if (c.contains('book') || c.contains('media') || c.contains('office') ||
      c.contains('stationery')) {
    return 'Office';
  }

  if (c.contains('cleaning') || c.contains('household') ||
      c.contains('supply') || c.contains('adhesive') ||
      c.contains('tool')) {
    return 'Supplies';
  }

  if (c.contains('toy') || c.contains('game') || c.contains('hobby')) {
    return 'Toys';
  }

  if (c.contains('accessories') || c.contains('accessory')) return 'Other';

  return 'Other';
}

void _showSaveFailureSummary({
  required BuildContext context,
  required int total,
  required int inserted,
  required Map<String, String> allFailures,
  required int silentDrops,
}) {
  final lines = <String>[];
  for (final entry in allFailures.entries) {
    lines.add('• "${entry.key}": ${entry.value}');
  }
  if (silentDrops > 0) {
    lines.add(
      '• $silentDrops item${silentDrops == 1 ? '' : 's'} could not be '
      'identified by the server (possible name conflict).',
    );
  }
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        '$inserted of $total item${total == 1 ? '' : 's'} saved',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Some items could not be saved:',
            style: TextStyle(color: Color(0x99FFFFFF), fontSize: 14),
          ),
          const SizedBox(height: 10),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Fix the highlighted rows and tap Save All to retry.',
            style: TextStyle(color: Color(0x73FFFFFF), fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'Dismiss',
            style: TextStyle(color: Color(0xFF0A84FF)),
          ),
        ),
      ],
    ),
  );
}

/// Runs the full Upload Photo flow with a pre-selected destination space.
///
/// Picks a photo, extracts items with AI, shows the ConfirmScanSheet review
/// step, saves via bulkCreateInventory, and shows a QR offer sheet if every
/// item saved successfully (or a failure summary on partial save).
///
/// [preselectedSpace] is the space name already known (e.g. the space the
/// user is viewing). The location picker from the Scan tab is skipped.
/// [onItemsSaved] is called after a successful (or partial) save so the
/// caller can refresh its item list.
Future<void> runUploadPhotoFlow({
  required BuildContext context,
  required ApiClient api,
  required String preselectedSpace,
  required Future<void> Function() onItemsSaved,
}) async {
  // Step 1: pick image source
  final src = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: Colors.white),
                title: const Text('Take Photo',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined, color: Colors.white),
                title: const Text('Choose from Library',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (src == null) return;

  // Step 2: pick image
  final picker = ImagePicker();
  final x = await picker.pickImage(source: src, maxWidth: 2048, imageQuality: 92);
  if (x == null) return;
  if (!context.mounted) return;

  final rawBytes = await x.readAsBytes();
  final bytes = _compressImageBytes(rawBytes);

  // Step 3: show loading dialog while extracting
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Extracting items…',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  // Step 4: call AI extraction
  debugPrint(
    'FINDEZ bulkCreate: calling extractInventoryFromImage with '
    '${bytes.length} bytes, filename: ${x.name}',
  );
  MultiExtractResult extracted;
  try {
    extracted = await api.extractInventoryFromImage(
      bytes: bytes,
      filename: x.name,
    );
  } on dio.DioException catch (e) {
    if (context.mounted) Navigator.of(context).pop();
    if (!context.mounted) return;
    if (e.response?.statusCode == 429) {
      if (!ProStatus.isPro) {
        final detail = e.response?.data?['detail'];
        final message = detail is Map
            ? detail['message'] as String?
            : 'You\'ve reached your free scan limit.';
        await showUpgradeSheet(
          context,
          api,
          reason: message ?? 'You\'ve reached your free scan limit.',
        );
      } else {
        debugPrint('FINDEZ: Pro user got 429 — backend bug');
        unawaited(ProStatus.refresh(api));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Something went wrong. Please try again.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to extract items. Try again.')),
      );
    }
    return;
  } catch (_) {
    if (context.mounted) Navigator.of(context).pop();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to extract items. Try again.')),
    );
    return;
  }

  if (context.mounted) Navigator.of(context).pop(); // close loading dialog
  if (!context.mounted) return;

  if (extracted.items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No items found in image.')),
    );
    return;
  }

  // Step 5: ConfirmScanSheet review — always shown (no pref gate in-space)
  final confirmed = await showModalBottomSheet<List<ExtractedInventoryItem>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ConfirmScanSheet(
      items: extracted.items,
      defaultLocation: preselectedSpace,
    ),
  );
  if (confirmed == null || !context.mounted) return;

  // Step 6: normalize and build payload
  final normalized = <ExtractedInventoryItem>[];
  final indexMap = <String>[]; // item name per index, for failure lookup
  final validationFailures = <String, String>{};

  for (final it in confirmed) {
    final name = it.name.trim();
    final category = _normalizeCategory(it.category);

    if (name.isEmpty || category.isEmpty) {
      validationFailures[name.isEmpty ? '(unnamed)' : name] =
          'Name and category are required.';
      continue;
    }

    // Respect per-item location the user may have edited in ConfirmScanSheet;
    // fall back to preselectedSpace for empty or "Unsorted" values.
    final rawLoc = (it.location ?? '').trim();
    final itemLocation =
        (rawLoc.isEmpty || rawLoc.toLowerCase() == 'unsorted')
            ? preselectedSpace
            : rawLoc;

    normalized.add(ExtractedInventoryItem(
      name: name,
      category: category,
      quantity: it.quantity,
      subcategory: it.subcategory,
      brand: it.brand,
      partNumber: it.partNumber,
      barcode: it.barcode,
      tags: it.tags,
      confidence: it.confidence,
      notes: it.notes,
      location: itemLocation,
    ));
    indexMap.add(name);
  }

  if (normalized.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fix the highlighted rows and try again.')),
      );
    }
    return;
  }

  debugPrint('FINDEZ bulkCreate: saving to space "$preselectedSpace"');
  debugPrint(
    'FINDEZ bulkCreate: sending ${normalized.length} item(s) — '
    '${normalized.map((it) => '"${it.name}" [${it.category}] → ${it.location}').join(', ')}',
  );

  // Step 7: save
  BulkCreateResult res;
  try {
    res = await api.bulkCreateInventory(items: normalized);
  } on dio.DioException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(describeError(e).$1)),
    );
    return;
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(describeError(e).$1)),
    );
    return;
  }
  if (!context.mounted) return;

  debugPrint(
    'FINDEZ bulkCreate: response — inserted=${res.inserted.length} '
    'failures=${res.failures.length} — '
    '${res.inserted.map((it) => '"${it.name}" id=${it.itemId}').join(', ')}',
  );

  // Map backend failure indices back to item names
  final backendFailures = <String, String>{};
  for (final f in res.failures) {
    final idx = (f['index'] is num)
        ? (f['index'] as num).toInt()
        : int.tryParse((f['index'] ?? '').toString());
    if (idx == null) continue;
    final name = (idx >= 0 && idx < indexMap.length) ? indexMap[idx] : null;
    if (name == null) continue;
    backendFailures[name] =
        (f['reason'] ?? 'Couldn\'t save this item.').toString();
  }

  final allFailures = <String, String>{
    ...validationFailures,
    ...backendFailures,
  };
  final insertedCount = res.inserted.length;
  final silentDrops =
      normalized.length - insertedCount - res.failures.length;

  if (silentDrops > 0) {
    debugPrint(
      'FINDEZ bulkCreate: WARNING — $silentDrops item(s) silently dropped '
      '(server name deduplication). Sent=${normalized.length}, '
      'inserted=$insertedCount, explicit_failures=${res.failures.length}.',
    );
  }

  final totalExpected = confirmed.length;
  final allSucceeded = allFailures.isEmpty &&
      silentDrops == 0 &&
      insertedCount == normalized.length;

  if (insertedCount > 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allSucceeded
              ? 'Saved $insertedCount item${insertedCount == 1 ? '' : 's'} to $preselectedSpace'
              : 'Saved $insertedCount of $totalExpected items to $preselectedSpace',
        ),
      ),
    );

    await onItemsSaved();
    if (!context.mounted) return;

    if (allSucceeded) {
      final noBarcodeItems = res.inserted
          .where((it) => it.barcode == null || it.barcode!.trim().isEmpty)
          .toList();
      if (noBarcodeItems.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (noBarcodeItems.length == 1) {
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) =>
                  QrOfferSheet(item: noBarcodeItems.first),
            );
          } else {
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => BulkQrOfferSheet(items: noBarcodeItems),
            );
          }
        });
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        _showSaveFailureSummary(
          context: context,
          total: totalExpected,
          inserted: insertedCount,
          allFailures: allFailures,
          silentDrops: silentDrops,
        );
      });
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Couldn\'t save those items. Fix the highlighted rows and try again.'),
      ),
    );
  }
}
