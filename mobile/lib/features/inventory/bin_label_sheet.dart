import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';

class BinLabelSheet extends StatefulWidget {
  final String spaceName;
  final List<InventoryItem> items;
  const BinLabelSheet({
    required this.spaceName,
    required this.items,
    super.key,
  });
  @override
  State<BinLabelSheet> createState() => _BinLabelSheetState();
}

class _BinLabelSheetState extends State<BinLabelSheet> {
  final GlobalKey _labelKey = GlobalKey();
  bool _sharing = false;

  String get _qrData =>
      'findez://space/${Uri.encodeComponent(widget.spaceName)}';

  Map<String, List<InventoryItem>> get _byCategory {
    final map = <String, List<InventoryItem>>{};
    for (final item in widget.items) {
      (map[item.category] ??= []).add(item);
    }
    return map;
  }

  Future<void> _shareLabel() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _labelKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/bin_label_${widget.spaceName}.png');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'FindEZ bin label: ${widget.spaceName}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share label. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final print = AppTokens.light;
    final categories = _byCategory.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Label',
                    style: TextStyle(color: t.ink, fontSize: 25),
                  ),
                ),
                Text(
                  '${widget.items.length}',
                  style: TextStyle(
                    color: t.ink,
                    fontSize: 18,
                    fontFamily: 'IBMPlexMono',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Share or print this label for ${widget.spaceName}.',
              style: TextStyle(color: t.text2, fontSize: 13),
            ),
            const SizedBox(height: 20),
            RepaintBoundary(
              key: _labelKey,
              child: Container(
                color: print.paper,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.spaceName,
                      style: TextStyle(color: print.ink, fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.items.length} objects',
                      style: TextStyle(
                        color: print.text2,
                        fontSize: 13,
                        fontFamily: 'IBMPlexMono',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: QrImageView(
                        data: _qrData,
                        size: 150,
                        backgroundColor: print.paper,
                        eyeStyle: QrEyeStyle(
                          color: print.ink,
                          eyeShape: QrEyeShape.square,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          color: print.ink,
                          dataModuleShape: QrDataModuleShape.square,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Scan to open in FindEZ',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: print.text2, fontSize: 12),
                    ),
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Divider(color: print.separator),
                      for (final entry in categories.take(6))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: print.ink,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                '${entry.value.length}',
                                style: TextStyle(
                                  color: print.ink,
                                  fontSize: 12,
                                  fontFamily: 'IBMPlexMono',
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (categories.length > 6)
                        Text(
                          '${categories.length - 6} more categories',
                          style: TextStyle(color: print.text2, fontSize: 12),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _sharing ? null : _shareLabel,
              child: _sharing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Share or print'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
