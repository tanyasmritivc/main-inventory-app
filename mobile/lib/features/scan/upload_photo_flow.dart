import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/pro_status.dart';
import '../../core/pending_captures.dart';
import '../../core/upgrade_sheet.dart';
import 'confirm_scan_sheet.dart';
import 'capture_recovery_sheet.dart';
import 'capture_processing_view.dart';
import '../inventory/manual_add_page.dart';
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

@visibleForTesting
List<ExtractedInventoryItem> itemsWaitingAfterBulkSave({
  required List<ExtractedInventoryItem> confirmed,
  required List<ExtractedInventoryItem> normalized,
  required List<int> normalizedSourceIndices,
  required BulkCreateResult result,
}) {
  final failedIndices = <int>{
    for (final failure in result.failures)
      if (failure['index'] is num) (failure['index'] as num).toInt(),
  };
  String key(String name, String location) =>
      '${name.trim().toLowerCase()}::${location.trim().toLowerCase()}';
  final insertedKeys = {
    for (final item in result.inserted) key(item.name, item.location),
  };
  final savedSourceIndices = <int>{};
  for (var index = 0; index < normalized.length; index++) {
    if (failedIndices.contains(index)) continue;
    if (insertedKeys.contains(
      key(normalized[index].name, normalized[index].location ?? ''),
    )) {
      savedSourceIndices.add(normalizedSourceIndices[index]);
    }
  }
  return [
    for (var index = 0; index < confirmed.length; index++)
      if (!savedSourceIndices.contains(index)) confirmed[index],
  ];
}

Future<void> _offerRecovery({
  required BuildContext context,
  required ApiClient api,
  required PendingCapture pending,
  required Future<void> Function() onItemsSaved,
  required String message,
  required bool showSheet,
  String? barcodeToAssociate,
  VoidCallback? onQueueChanged,
}) async {
  if (!context.mounted) return;
  if (!showSheet) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$message Your photo is waiting in Capture.')),
    );
    return;
  }
  final retry = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CaptureRecoverySheet(capture: pending, message: message),
  );
  if (retry != true || !context.mounted) return;
  await runUploadPhotoFlow(
    context: context,
    api: api,
    preselectedSpace: pending.place,
    onItemsSaved: onItemsSaved,
    barcodeToAssociate: barcodeToAssociate,
    capturedImage: XFile(pending.photoPath),
    queuedCapture: pending,
    onQueueChanged: onQueueChanged,
  );
}

String _normalizeCategory(String rawCategory) {
  final c = rawCategory.trim().toLowerCase();
  if (c.isEmpty || c == 'unsorted') return 'Other';

  if (c.contains('robot') ||
      c.contains('drivetrain') ||
      c.contains('gearbox') ||
      c.contains('motor controller') ||
      c.contains('mecanum') ||
      c.contains('sprocket') ||
      c.contains('pulley') ||
      c.contains('servo') ||
      c.contains('actuator')) {
    return 'Robot Parts';
  }
  if (c.contains('hardware') ||
      c.contains('fastener') ||
      c.contains('bearing') ||
      c.contains('shaft')) {
    return 'Hardware';
  }
  if (c.contains('raw material') ||
      c.contains('extrusion') ||
      c.contains('sheet metal') ||
      c.contains('stock')) {
    return 'Raw Materials';
  }
  if (c.contains('battery') || c.contains('charger')) return 'Batteries';
  if (c.contains('safety') ||
      c.contains('ppe') ||
      c.contains('goggle') ||
      c.contains('glove')) {
    return 'Safety';
  }
  if (c.contains('tool')) return 'Tools';

  if (c.contains('food') ||
      c.contains('grocery') ||
      c.contains('beverage') ||
      c.contains('snack') ||
      c.contains('nut') ||
      c.contains('nuts') ||
      c.contains('bar') ||
      c.contains('kirkland') ||
      c.contains('cashew') ||
      c.contains('almond') ||
      c.contains('pecan')) {
    return 'Food';
  }

  if (c.contains('cosmetic') ||
      c.contains('beauty') ||
      c.contains('makeup') ||
      c.contains('skincare')) {
    return 'Cosmetics';
  }

  if (c.contains('electronic') ||
      c.contains('tech') ||
      c.contains('gadget') ||
      c.contains('computer') ||
      c.contains('phone') ||
      c.contains('appliance')) {
    return 'Electronics';
  }

  if (c.contains('clothing') ||
      c.contains('apparel') ||
      c.contains('fashion') ||
      c.contains('shoe')) {
    return 'Clothing';
  }

  if (c.contains('health') ||
      c.contains('medicine') ||
      c.contains('pharma') ||
      c.contains('supplement') ||
      c.contains('medication')) {
    return 'Health';
  }

  if (c.contains('home') ||
      c.contains('kitchen') ||
      c.contains('furniture') ||
      c.contains('decor') ||
      c.contains('appliance')) {
    return 'Home';
  }

  if (c.contains('book') ||
      c.contains('media') ||
      c.contains('office') ||
      c.contains('stationery')) {
    return 'Office';
  }

  if (c.contains('cleaning') ||
      c.contains('household') ||
      c.contains('supply') ||
      c.contains('adhesive')) {
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
    builder: (ctx) {
      final t = AppTokens.of(ctx);
      return AlertDialog(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
        title: Text(
          '$inserted of $total item${total == 1 ? '' : 's'} saved',
          style: TextStyle(
            color: t.ink,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Some items could not be saved:',
              style: TextStyle(color: t.text2, fontSize: 14),
            ),
            const SizedBox(height: 10),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line, style: TextStyle(color: t.ink, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The remaining objects are waiting in Capture. Open the photo to review them.',
              style: TextStyle(color: t.text2, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Dismiss',
              style: TextStyle(color: AppTokens.of(ctx).accentText),
            ),
          ),
        ],
      );
    },
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
  String? barcodeToAssociate,
  XFile? capturedImage,
  PendingCapture? queuedCapture,
  VoidCallback? onQueueChanged,
}) async {
  // Step 1: pick image source
  final src = capturedImage == null
      ? await showModalBottomSheet<ImageSource>(
          context: context,
          showDragHandle: true,
          builder: (ctx) {
            final t = AppTokens.of(ctx);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add a photograph',
                      style: TextStyle(color: t.ink, fontSize: 24),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Choose how to start.',
                      style: TextStyle(color: t.text2, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text('Take photo', style: TextStyle(color: t.ink)),
                      trailing: Text(
                        'OPEN',
                        style: TextStyle(color: t.text2, fontSize: 11),
                      ),
                      onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                    ),
                    Divider(color: t.separator, height: 1),
                    ListTile(
                      title: Text(
                        'Choose photo',
                        style: TextStyle(color: t.ink),
                      ),
                      trailing: Text(
                        'OPEN',
                        style: TextStyle(color: t.text2, fontSize: 11),
                      ),
                      onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                    ),
                  ],
                ),
              ),
            );
          },
        )
      : null;
  if (capturedImage == null && src == null) return;

  // Step 2: pick image
  final picker = ImagePicker();
  final x =
      capturedImage ??
      await picker.pickImage(source: src!, maxWidth: 2048, imageQuality: 92);
  if (x == null) return;
  if (!context.mounted) return;

  final rawBytes = await x.readAsBytes();
  if (!context.mounted) return;
  final bytes = _compressImageBytes(rawBytes);
  PendingCapture pending;
  try {
    pending =
        queuedCapture ??
        await PendingCaptures.add(
          photo: bytes,
          workspaceId: api.captureScopeId,
          place: preselectedSpace,
        );
    onQueueChanged?.call();
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not keep this photo: ${describeError(error).$1}'),
      ),
    );
    return;
  }

  // Step 3: show loading dialog while extracting
  if (!context.mounted) return;
  var processingVisible = true;
  var processingClosed = false;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: Dialog.fullscreen(
        child: CaptureProcessingView(
          onKeepShooting: () {
            processingVisible = false;
            processingClosed = true;
            Navigator.of(dialogContext).pop();
          },
        ),
      ),
    ),
  );

  // Step 4: call FIND extraction
  debugPrint(
    'FINDEZ bulkCreate: calling extractInventoryFromImage with '
    '${bytes.length} bytes, filename: ${x.name}',
  );
  MultiExtractResult extracted;
  try {
    if (pending.extractedItems != null) {
      extracted = MultiExtractResult.fromJson({
        'items': pending.extractedItems,
      });
    } else {
      extracted = await api.extractInventoryFromImage(
        bytes: bytes,
        filename: x.name,
      );
      pending = await PendingCaptures.saveExtraction(
        pending,
        extracted.items.map((item) => item.toJson()).toList(),
      );
      onQueueChanged?.call();
    }
  } on dio.DioException catch (e) {
    if (processingVisible && context.mounted) Navigator.of(context).pop();
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
        debugPrint('FINDEZ: Pro user got 429, backend bug');
        unawaited(ProStatus.refresh(api));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
          ),
        );
      }
    } else {
      await _offerRecovery(
        context: context,
        api: api,
        pending: pending,
        onItemsSaved: onItemsSaved,
        onQueueChanged: onQueueChanged,
        barcodeToAssociate: barcodeToAssociate,
        showSheet: !processingClosed,
        message: describeError(e).$2 == ErrorKind.offline
            ? 'No connection. The photo will wait until you try again.'
            : 'The photograph could not be processed. Try again when ready.',
      );
    }
    return;
  } catch (error) {
    if (processingVisible && context.mounted) Navigator.of(context).pop();
    if (!context.mounted) return;
    await _offerRecovery(
      context: context,
      api: api,
      pending: pending,
      onItemsSaved: onItemsSaved,
      onQueueChanged: onQueueChanged,
      barcodeToAssociate: barcodeToAssociate,
      showSheet: !processingClosed,
      message: 'Capture stopped: ${describeError(error).$1}',
    );
    return;
  }

  if (processingVisible && context.mounted) Navigator.of(context).pop();
  if (!context.mounted) return;

  if (processingClosed) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${extracted.items.length} ${extracted.items.length == 1 ? 'object is' : 'objects are'} ready to review.',
        ),
        action: SnackBarAction(
          label: 'Review',
          onPressed: () {
            if (!context.mounted) return;
            unawaited(
              runUploadPhotoFlow(
                context: context,
                api: api,
                preselectedSpace: pending.place,
                onItemsSaved: onItemsSaved,
                barcodeToAssociate: barcodeToAssociate,
                capturedImage: XFile(pending.photoPath),
                queuedCapture: pending,
                onQueueChanged: onQueueChanged,
              ),
            );
          },
        ),
      ),
    );
    return;
  }

  if (!context.mounted) return;
  if (extracted.items.isEmpty) {
    final addByHand = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => UnidentifiedCaptureSheet(
        photoBytes: Uint8List.fromList(bytes),
      ),
    );
    if (addByHand == true && context.mounted) {
      final item = await showManualAddPage(
        context,
        api: api,
        initialLocation: preselectedSpace,
        backLabel: 'Photo',
      );
      if (item != null) {
        await onItemsSaved();
        await PendingCaptures.remove(pending);
        onQueueChanged?.call();
      }
    }
    return;
  }

  if (barcodeToAssociate != null) {
    final verified = extracted.items
        .where((item) => item.catalogMatch?.verified == true)
        .toList();
    final candidate = verified.length == 1
        ? verified.single
        : (extracted.items.length == 1 ? extracted.items.single : null);
    if (candidate != null) candidate.barcode = barcodeToAssociate;
  }

  // Step 5: ConfirmScanSheet review is always shown in a space.
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

  final normalizedSourceIndices = <int>[];
  for (var sourceIndex = 0; sourceIndex < confirmed.length; sourceIndex++) {
    final it = confirmed[sourceIndex];
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
    final itemLocation = (rawLoc.isEmpty || rawLoc.toLowerCase() == 'unsorted')
        ? preselectedSpace
        : rawLoc;

    normalized.add(
      ExtractedInventoryItem(
        name: name,
        category: category,
        quantity: it.quantity,
        subcategory: it.subcategory,
        brand: it.brand,
        partNumber: it.partNumber,
        barcode: it.barcode,
        tags: it.tags,
        confidence: it.confidence,
        imageUrl: it.imageUrl,
        sourceFrameUrl: it.sourceFrameUrl,
        notes: it.notes,
        location: itemLocation,
        catalogMatch: it.catalogMatch,
        scanEvidence: it.scanEvidence,
      ),
    );
    indexMap.add(name);
    normalizedSourceIndices.add(sourceIndex);
  }

  if (normalized.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fix the highlighted rows and try again.'),
        ),
      );
    }
    return;
  }

  debugPrint('FINDEZ bulkCreate: saving to space "$preselectedSpace"');
  debugPrint(
    'FINDEZ bulkCreate: sending ${normalized.length} item(s), '
    '${normalized.map((it) => '"${it.name}" [${it.category}] → ${it.location}').join(', ')}',
  );

  // Step 7: save
  BulkCreateResult res;
  try {
    res = await api.bulkCreateInventory(items: normalized);
  } on dio.DioException catch (e) {
    if (!context.mounted) return;
    await _offerRecovery(
      context: context,
      api: api,
      pending: pending,
      onItemsSaved: onItemsSaved,
      onQueueChanged: onQueueChanged,
      barcodeToAssociate: barcodeToAssociate,
      showSheet: true,
      message: 'The objects could not be saved. ${describeError(e).$1}',
    );
    return;
  } catch (e) {
    if (!context.mounted) return;
    await _offerRecovery(
      context: context,
      api: api,
      pending: pending,
      onItemsSaved: onItemsSaved,
      onQueueChanged: onQueueChanged,
      barcodeToAssociate: barcodeToAssociate,
      showSheet: true,
      message: 'The objects could not be saved. ${describeError(e).$1}',
    );
    return;
  }
  if (!context.mounted) return;

  debugPrint(
    'FINDEZ bulkCreate: response, inserted=${res.inserted.length} '
    'failures=${res.failures.length}, '
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
    backendFailures[name] = (f['reason'] ?? 'Couldn\'t save this item.')
        .toString();
  }

  final allFailures = <String, String>{
    ...validationFailures,
    ...backendFailures,
  };
  final insertedCount = res.inserted.length;
  final silentDrops = normalized.length - insertedCount - res.failures.length;
  final remaining = itemsWaitingAfterBulkSave(
    confirmed: confirmed,
    normalized: normalized,
    normalizedSourceIndices: normalizedSourceIndices,
    result: res,
  );

  if (silentDrops > 0) {
    debugPrint(
      'FINDEZ bulkCreate: WARNING, $silentDrops item(s) silently dropped '
      '(server name deduplication). Sent=${normalized.length}, '
      'inserted=$insertedCount, explicit_failures=${res.failures.length}.',
    );
  }

  final totalExpected = confirmed.length;
  final allSucceeded = remaining.isEmpty && allFailures.isEmpty;

  if (insertedCount > 0) {
    try {
      if (remaining.isEmpty) {
        await PendingCaptures.remove(pending);
      } else {
        pending = await PendingCaptures.saveExtraction(
          pending,
          remaining.map((item) => item.toJson()).toList(),
        );
      }
      onQueueChanged?.call();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not update the waiting photo: ${describeError(error).$1}',
            ),
          ),
        );
      }
    }
    if (!context.mounted) return;
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
              builder: (_) => QrOfferSheet(item: noBarcodeItems.first),
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
    await _offerRecovery(
      context: context,
      api: api,
      pending: pending,
      onItemsSaved: onItemsSaved,
      onQueueChanged: onQueueChanged,
      barcodeToAssociate: barcodeToAssociate,
      showSheet: true,
      message: 'No objects were saved. Review the results and try again.',
    );
  }
}
