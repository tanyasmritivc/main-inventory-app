import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';

/// Non-blocking bottom sheet shown after saving from the scan screen.
/// Offers to generate and show a QR code for the newly saved item.
class QrOfferSheet extends StatelessWidget {
  const QrOfferSheet({super.key, required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F8FA),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: Color(0x14000000), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const Text(
            'Item saved.',
            style: TextStyle(
              color: Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Want to print a QR code for it?',
            style: TextStyle(color: Color(0xFF636366), fontSize: 14),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0x14000000),
                        width: 0.5,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Color(0xFF636366),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => QrDisplaySheet(item: item),
                    );
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'Generate QR',
                        style: TextStyle(
                          color: Color(0xFFF4F4F6),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Displays the generated QR code for an item with an image share button.
class QrDisplaySheet extends StatefulWidget {
  const QrDisplaySheet({super.key, required this.item});

  final InventoryItem item;

  @override
  State<QrDisplaySheet> createState() => _QrDisplaySheetState();
}

class _QrDisplaySheetState extends State<QrDisplaySheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareAsImage() async {
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_${widget.item.itemId}.png');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: '${widget.item.name} — FindEZ',
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share QR. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F8FA),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: Color(0x14000000), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const Text(
            'Item QR Code',
            style: TextStyle(
              color: Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          RepaintBoundary(
            key: _cardKey,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      QrImageView(
                        data: widget.item.itemId,
                        size: 110,
                        backgroundColor: Colors.black,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFFF4F4F6),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFFF4F4F6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Scan to find in FindEZ',
                        style: TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: const TextStyle(
                            color: Color(0xFFF4F4F6),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (widget.item.location.isNotEmpty)
                          Text(
                            widget.item.location,
                            style: const TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 12,
                            ),
                          ),
                        Text(
                          'Qty: ${widget.item.quantity}',
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Divider(color: Color(0xFFEEEEEE), height: 1),
                        const SizedBox(height: 6),
                        const Row(
                          children: [
                            Text(
                              'FindEZ AI',
                              style: TextStyle(
                                color: Color(0xFF999999),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Spacer(),
                            Text(
                              'findez.ai',
                              style: TextStyle(
                                color: Color(0xFF999999),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _sharing ? null : _shareAsImage,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x14000000), width: 0.5),
                    ),
                    child: Center(
                      child: _sharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Color(0xFF3C3C43),
                                strokeWidth: 1.5,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.share_outlined, color: Color(0xFF636366), size: 16),
                                SizedBox(width: 8),
                                Text('Share', style: TextStyle(color: Color(0xFF636366), fontSize: 15)),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x14000000), width: 0.5),
                    ),
                    child: const Center(
                      child: Text('Done', style: TextStyle(color: Color(0xFF636366), fontSize: 15)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet shown when multiple no-barcode items are saved.
/// Lets the user toggle which items to generate QR codes for.
class BulkQrOfferSheet extends StatefulWidget {
  const BulkQrOfferSheet({super.key, required this.items});

  final List<InventoryItem> items;

  @override
  State<BulkQrOfferSheet> createState() => _BulkQrOfferSheetState();
}

class _BulkQrOfferSheetState extends State<BulkQrOfferSheet> {
  late final List<bool> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.filled(widget.items.length, true);
  }

  @override
  Widget build(BuildContext context) {
    final selectedItems = [
      for (int i = 0; i < widget.items.length; i++)
        if (_selected[i]) widget.items[i],
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F8FA),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: Color(0x14000000), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const Text(
            'Generate QR Codes?',
            style: TextStyle(
              color: Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'These items have no barcode.\nAdd a QR so you can scan them later.',
            style: TextStyle(color: Color(0xFF636366), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x14000000), width: 0.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  separatorBuilder: (_, _) => Container(
                    height: 0.5,
                    color: const Color(0x14000000),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  itemBuilder: (_, i) => ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    title: Text(
                      widget.items[i].name,
                      style: const TextStyle(color: Colors.black, fontSize: 14),
                    ),
                    trailing: Switch(
                      value: _selected[i],
                      onChanged: (v) => setState(() => _selected[i] = v),
                      activeThumbColor: Colors.black,
                      activeTrackColor: const Color(0xFF8E8E93),
                      inactiveThumbColor: const Color(0x33000000),
                      inactiveTrackColor: const Color(0x14000000),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: selectedItems.isEmpty
                ? null
                : () {
                    Navigator.of(context).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => BulkQrDisplaySheet(items: selectedItems),
                    );
                  },
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: selectedItems.isEmpty
                    ? const Color(0x33000000)
                    : Colors.black,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Center(
                child: Text(
                  'Generate QR Codes',
                  style: TextStyle(
                    color: selectedItems.isEmpty
                        ? const Color(0xFF8E8E93)
                        : Color(0xFFF4F4F6),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0x14000000), width: 0.5),
              ),
              child: const Center(
                child: Text(
                  'Skip',
                  style: TextStyle(color: Color(0xFF636366), fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays generated QR codes for multiple items with individual share buttons.
class BulkQrDisplaySheet extends StatelessWidget {
  const BulkQrDisplaySheet({super.key, required this.items});

  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F8FA),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border(
            top: BorderSide(color: Color(0x14000000), width: 0.5),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const Text(
              'Your QR Codes',
              style: TextStyle(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Print or save these to identify your items.',
              style: TextStyle(color: Color(0xFF636366), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      _ItemQrCard(item: items[i]),
                      if (i < items.length - 1)
                        Container(
                          height: 0.5,
                          color: const Color(0x14000000),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Center(
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: Color(0xFFF4F4F6),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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

class _ItemQrCard extends StatefulWidget {
  const _ItemQrCard({required this.item});
  final InventoryItem item;

  @override
  State<_ItemQrCard> createState() => _ItemQrCardState();
}

class _ItemQrCardState extends State<_ItemQrCard> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareAsImage() async {
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_${widget.item.itemId}.png');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: '${widget.item.name} — FindEZ',
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share QR. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          RepaintBoundary(
            key: _cardKey,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      QrImageView(
                        data: widget.item.itemId,
                        size: 110,
                        backgroundColor: Colors.black,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFFF4F4F6),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFFF4F4F6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Scan to find in FindEZ',
                        style: TextStyle(color: Color(0xFF999999), fontSize: 8),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: const TextStyle(
                            color: Color(0xFFF4F4F6),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (widget.item.location.isNotEmpty)
                          Text(
                            widget.item.location,
                            style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                          ),
                        Text(
                          'Qty: ${widget.item.quantity}',
                          style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        const Divider(color: Color(0xFFEEEEEE), height: 1),
                        const SizedBox(height: 6),
                        const Row(
                          children: [
                            Text(
                              'FindEZ AI',
                              style: TextStyle(
                                color: Color(0xFF999999),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Spacer(),
                            Text(
                              'findez.ai',
                              style: TextStyle(color: Color(0xFF999999), fontSize: 9),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _sharing ? null : _shareAsImage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0x14000000), width: 0.5),
              ),
              child: _sharing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(color: Color(0xFF3C3C43), strokeWidth: 1.5),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_outlined, color: Color(0xFF636366), size: 14),
                        SizedBox(width: 6),
                        Text('Share QR', style: TextStyle(color: Color(0xFF636366), fontSize: 13)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
