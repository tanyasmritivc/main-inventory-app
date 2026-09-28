import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';

void _openQrDisplay(BuildContext context, List<InventoryItem> items) {
  final navigator = Navigator.of(context);
  navigator.pop();
  showModalBottomSheet<void>(
    context: navigator.context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => BulkQrDisplaySheet(items: items),
  );
}

class QrOfferSheet extends StatelessWidget {
  const QrOfferSheet({super.key, required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Object saved', style: TextStyle(color: t.ink, fontSize: 25)),
            const SizedBox(height: 6),
            Text(
              'Make a QR label for ${item.displayName}?',
              style: TextStyle(color: t.text2),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => _openQrDisplay(context, [item]),
              child: const Text('Make a QR label'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip'),
            ),
          ],
        ),
      ),
    );
  }
}

class QrDisplaySheet extends StatelessWidget {
  const QrDisplaySheet({super.key, required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) => BulkQrDisplaySheet(items: [item]);
}

class BulkQrOfferSheet extends StatefulWidget {
  const BulkQrOfferSheet({super.key, required this.items});

  final List<InventoryItem> items;

  @override
  State<BulkQrOfferSheet> createState() => _BulkQrOfferSheetState();
}

class _BulkQrOfferSheetState extends State<BulkQrOfferSheet> {
  late final List<bool> _selected = List.filled(widget.items.length, true);

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final selected = [
      for (var index = 0; index < widget.items.length; index++)
        if (_selected[index]) widget.items[index],
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Make QR labels',
              style: TextStyle(color: t.ink, fontSize: 25),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose which saved objects need a label.',
              style: TextStyle(color: t.text2),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.items.length,
                itemBuilder: (context, index) => CheckboxListTile(
                  title: Text(widget.items[index].displayName),
                  value: _selected[index],
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) =>
                      setState(() => _selected[index] = value ?? false),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => _openQrDisplay(context, selected),
              child: Text(
                'Make ${selected.length} ${selected.length == 1 ? 'label' : 'labels'}',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip'),
            ),
          ],
        ),
      ),
    );
  }
}

class BulkQrDisplaySheet extends StatelessWidget {
  const BulkQrDisplaySheet({super.key, required this.items});

  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your QR labels',
                    style: TextStyle(color: t.ink, fontSize: 25),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share or print a label for each object.',
                    style: TextStyle(color: t.text2),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: items.length,
                itemBuilder: (context, index) => _QrCard(item: items[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrCard extends StatefulWidget {
  const _QrCard({required this.item});

  final InventoryItem item;

  @override
  State<_QrCard> createState() => _QrCardState();
}

class _QrCardState extends State<_QrCard> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('QR label is not ready');
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('QR label could not be rendered');
      final temp = await getTemporaryDirectory();
      final file = File('${temp.path}/findez-qr-${widget.item.itemId}.png');
      await file.writeAsBytes(data.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${widget.item.displayName} | FindEZ',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share QR label. Try again.')),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RepaintBoundary(
            key: _cardKey,
            child: ColoredBox(
              color: print.paper,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    QrImageView(
                      data: 'findez://item/${widget.item.itemId}',
                      size: 116,
                      backgroundColor: print.paper,
                      eyeStyle: QrEyeStyle(color: print.ink),
                      dataModuleStyle: QrDataModuleStyle(color: print.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.item.displayName,
                        style: TextStyle(color: print.ink, fontSize: 17),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _sharing ? null : _share,
            child: Text(_sharing ? 'Preparing label' : 'Share or print'),
          ),
          Divider(color: t.separator),
        ],
      ),
    );
  }
}
