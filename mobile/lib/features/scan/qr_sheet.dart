import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api_client.dart';

/// Non-blocking bottom sheet shown after saving from the scan screen.
/// Offers to generate and show a QR code for the newly saved item.
class QrOfferSheet extends StatelessWidget {
  const QrOfferSheet({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
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
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const Text(
            'Item saved.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Want to print a QR code for it?',
            style: TextStyle(color: Color(0x73FFFFFF), fontSize: 14),
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
                      color: const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0x14FFFFFF),
                        width: 0.5,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Color(0x73FFFFFF),
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
                      builder: (_) => QrDisplaySheet(itemId: itemId),
                    );
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'Generate QR',
                        style: TextStyle(
                          color: Colors.black,
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

/// Displays the generated QR code for an item with a share button.
class QrDisplaySheet extends StatelessWidget {
  const QrDisplaySheet({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
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
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const Text(
            'Item QR Code',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          QrImageView(
            data: itemId,
            version: QrVersions.auto,
            size: 160,
            backgroundColor: Colors.transparent,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.white,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Scan to identify this item',
            style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 12),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => SharePlus.instance.share(
                    ShareParams(
                      text: 'FindEZ item ID: $itemId',
                      subject: 'FindEZ Item QR',
                    ),
                  ),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0x14FFFFFF),
                        width: 0.5,
                      ),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.share_outlined,
                            color: Color(0x73FFFFFF),
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Share',
                            style: TextStyle(
                              color: Color(0x73FFFFFF),
                              fontSize: 15,
                            ),
                          ),
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
                      color: const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0x14FFFFFF),
                        width: 0.5,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: Color(0x73FFFFFF),
                          fontSize: 15,
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
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
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
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const Text(
            'Generate QR Codes?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'These items have no barcode.\nAdd a QR so you can scan them later.',
            style: TextStyle(color: Color(0x73FFFFFF), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x0AFFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => Container(
                    height: 0.5,
                    color: const Color(0x14FFFFFF),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  itemBuilder: (_, i) => ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    title: Text(
                      widget.items[i].name,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    trailing: Switch(
                      value: _selected[i],
                      onChanged: (v) => setState(() => _selected[i] = v),
                      activeThumbColor: Colors.white,
                      activeTrackColor: const Color(0x4DFFFFFF),
                      inactiveThumbColor: const Color(0x33FFFFFF),
                      inactiveTrackColor: const Color(0x14FFFFFF),
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
                    ? const Color(0x33FFFFFF)
                    : Colors.white,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Center(
                child: Text(
                  'Generate QR Codes',
                  style: TextStyle(
                    color: selectedItems.isEmpty
                        ? const Color(0x4DFFFFFF)
                        : Colors.black,
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
                color: const Color(0x0AFFFFFF),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
              ),
              child: const Center(
                child: Text(
                  'Skip',
                  style: TextStyle(color: Color(0x73FFFFFF), fontSize: 15),
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
          color: Color(0xFF0A0A0A),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border(
            top: BorderSide(color: Color(0x14FFFFFF), width: 0.5),
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
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const Text(
              'Your QR Codes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Print or save these to identify your items.',
              style: TextStyle(color: Color(0x73FFFFFF), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      _buildItemCard(items[i]),
                      if (i < items.length - 1)
                        Container(
                          height: 0.5,
                          color: const Color(0x14FFFFFF),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Center(
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.black,
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

  Widget _buildItemCard(InventoryItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            item.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          QrImageView(
            data: item.itemId,
            version: QrVersions.auto,
            size: 120,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan to identify this item',
            style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 12),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => SharePlus.instance.share(
              ShareParams(
                text: 'FindEZ item ID: ${item.itemId}',
                subject: '${item.name} QR',
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0x0AFFFFFF),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.share_outlined, color: Color(0x73FFFFFF), size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Share QR',
                    style: TextStyle(color: Color(0x73FFFFFF), fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
