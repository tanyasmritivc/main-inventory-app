// Network-free native confirmation QA. Never imported by production main.dart.
import 'package:flutter/material.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/scan/confirm_scan_sheet.dart';

void main() {
  runApp(
    MaterialApp(
      theme: AppTheme.create(Brightness.light),
      darkTheme: AppTheme.create(Brightness.dark),
      home: const _Preview(),
    ),
  );
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  String receipt = 'Synthetic preview. No inventory writes.';
  Future<void> show(bool unknown) async {
    final result = await showModalBottomSheet<List<ExtractedInventoryItem>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ConfirmScanSheet(
        defaultLocation: 'Pantry',
        existingItems: const [],
        items: [
          ExtractedInventoryItem(
            name: 'Tablets - blister strip',
            category: 'Health',
            quantity: 1,
            scanEvidence: ScanEvidence(
              needsReview: true,
              identityConfidence: .9,
              quantityBasis: unknown ? 'unknown' : 'visible_packages',
              quantityUnit: unknown ? null : 'blister strip',
              quantityNote: 'Packages counted; contents are not counted.',
              reviewReasons: const ['Foil hides the remaining tablets.'],
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(
      () => receipt = result == null
          ? 'Cancelled. No inventory writes.'
          : 'Accepted ${result.single.quantity} ${result.single.scanEvidence?.quantityUnit}. Review required: ${result.single.needsReview}. No inventory writes.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Capture QA')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(receipt),
          TextButton(
            onPressed: () => show(false),
            child: const Text('Open blister strip'),
          ),
          TextButton(
            onPressed: () => show(true),
            child: const Text('Open uncounted item'),
          ),
        ],
      ),
    ),
  );
}
