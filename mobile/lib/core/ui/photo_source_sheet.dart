import 'photo_scan_hint.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'liquid_surface.dart';
import 'native_presentation.dart';

Future<bool?> showPhotoSourceSheet(
  BuildContext context, {
  bool scanning = false,
}) async {
  if (usesNativePresentation) {
    final result = await NativePresentation.show(
      context,
      model: {
        'kind': 'photoSource',
        if (scanning) 'message': '$photoScanTiming $photoScanTip',
      },
    );
    if (!context.mounted) return null;
    if (result?['error'] is String) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result!['error'] as String)));
      return null;
    }
    return switch (result?['action']) {
      'camera' => true,
      'photos' => false,
      _ => null,
    };
  }
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LiquidSurface(
          radius: 28,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(CupertinoIcons.camera),
                  title: const Text('Take photo'),
                  trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onTap: () => Navigator.pop(context, true),
                ),
                const Divider(height: 1, indent: 54, endIndent: 16),
                ListTile(
                  leading: const Icon(CupertinoIcons.photo_on_rectangle),
                  title: const Text('Choose photo'),
                  trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onTap: () => Navigator.pop(context, false),
                ),
                if (scanning)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: PhotoScanHint(),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
