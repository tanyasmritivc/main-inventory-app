import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/pro_status.dart';
import '../../core/upgrade_sheet.dart';
import 'capture_client.dart';
import 'capture_controller.dart';
import 'confirm_scan_sheet.dart';
import 'qr_sheet.dart';

/// Runs photo Capture from an existing Space.
///
/// The shared [CaptureController] owns FIND, cancellation, result state, and
/// mutation safety. This function only coordinates the modal presentation.
Future<void> runUploadPhotoFlow({
  required BuildContext context,
  required ApiClient api,
  required String preselectedSpace,
  required Future<void> Function() onItemsSaved,
  String? barcodeToAssociate,
}) async {
  final source = await _chooseSource(context);
  if (source == null || !context.mounted) return;

  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 2048,
    imageQuality: 92,
  );
  if (file == null || !context.mounted) return;

  final controller = CaptureController(gateway: CaptureClient(api));
  try {
    final run = controller.analyzePhoto(
      bytes: await file.readAsBytes(),
      filename: file.name,
      barcodeToAssociate: barcodeToAssociate,
    );
    if (!context.mounted) return;
    var progressOpen = true;
    unawaited(
      _showProgress(
        context,
        controller,
      ).whenComplete(() => progressOpen = false),
    );
    final result = await run;
    if (context.mounted && progressOpen) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (!context.mounted || result == CaptureRunOutcome.cancelled) return;
    if (result == CaptureRunOutcome.failed) {
      if (controller.failureKind == CaptureFailureKind.limit &&
          !ProStatus.isPro) {
        await showUpgradeSheet(
          context,
          api,
          reason:
              controller.errorMessage ?? 'Your photo scan limit was reached.',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              controller.errorMessage ?? 'The photo could not be analyzed.',
            ),
          ),
        );
      }
      return;
    }

    while (controller.drafts.isNotEmpty && context.mounted) {
      if (!context.mounted) return;
      final reviewed = await showModalBottomSheet<List<ExtractedInventoryItem>>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => ConfirmScanSheet(
          items: controller.drafts.map((draft) => draft.item).toList(),
          defaultLocation: preselectedSpace,
        ),
      );
      if (reviewed == null || !context.mounted) return;
      controller.replaceDrafts(reviewed);
      final outcome = await controller.save(destination: preselectedSpace);
      if (!context.mounted) return;
      if (outcome == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              controller.errorMessage ?? 'The items could not be saved.',
            ),
          ),
        );
        return;
      }
      if (outcome.inserted.isNotEmpty) await onItemsSaved();
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome.allSucceeded
                ? 'Remembered ${outcome.inserted.length} ${outcome.inserted.length == 1 ? 'item' : 'items'} in $preselectedSpace.'
                : 'Remembered ${outcome.inserted.length} of ${outcome.total} results.',
          ),
        ),
      );
      if (outcome.allSucceeded) {
        _offerQrCodes(context, outcome.inserted);
        return;
      }

      final reviewRemaining = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Some results still need attention'),
          content: const Text(
            'Successfully saved items were removed. You can edit the remaining results without duplicating them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Done'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Review remaining'),
            ),
          ],
        ),
      );
      if (reviewRemaining != true) return;
    }
  } finally {
    controller.dispose();
  }
}

Future<ImageSource?> _chooseSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            minVerticalPadding: 12,
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
          ListTile(
            minVerticalPadding: 12,
            leading: const Icon(Icons.photo_outlined),
            title: const Text('Choose from library'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showProgress(BuildContext context, CaptureController controller) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AnimatedBuilder(
      animation: controller,
      builder: (_, _) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Remembering this photo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(switch (controller.stage) {
                CaptureStage.preparing => 'Preparing your photo',
                CaptureStage.detecting => 'Finding objects',
                CaptureStage.understanding =>
                  'Reading labels and identifying items',
                CaptureStage.saving => 'Saving to your memory',
                null => 'Finishing',
              }, textAlign: TextAlign.center),
              if (controller.showLongWaitHint) ...[
                const SizedBox(height: 12),
                const Text(
                  'Complex scenes can take longer while FIND separates each object.',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await controller.cancelActive();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Stop'),
            ),
          ],
        ),
      ),
    ),
  );
}

void _offerQrCodes(BuildContext context, List<InventoryItem> inserted) {
  final items = inserted
      .where((item) => (item.barcode ?? '').trim().isEmpty)
      .toList();
  if (items.isEmpty) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: items.length > 1,
      builder: (_) => items.length == 1
          ? QrOfferSheet(item: items.single)
          : BulkQrOfferSheet(items: items),
    );
  });
}
