// Network-free native confirmation QA. Never imported by production main.dart.
import 'package:flutter/material.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/scan/confirm_scan_sheet.dart';
import 'package:mobile/features/review/review_queue_page.dart';
import 'package:mobile/features/scan/review_capture.dart';
import '../test/support/hierarchy_fixture.dart';

final fixture = HierarchyFixture();
final reviews = <Map<String, dynamic>>[];
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await fixture.initialize(mockPreferences: false);
  fixture.respond = (request) {
    if (request.path == '/review-items' && request.method == 'GET') {
      return {'items': reviews, 'pending_count': reviews.length};
    }
    if (request.path.startsWith('/review-items/') && request.method == 'POST') {
      final row = <String, dynamic>{
        ...Map<String, dynamic>.from(request.data as Map),
        'review_id': 'qa-review',
        'status': 'pending',
      };
      reviews.clear();
      reviews.add(row);
      return {'review_item': row};
    }
    return {'unread_count': 0, 'notifications': [], 'display_name': 'QA'};
  };
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
            reviewId: 'qa-preview',
            reviewStatus: 'preview',
            reviewToken: 'fixture',
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
    if (result != null) {
      await prepareCaptureForSave(api: fixture.api, items: result);
    }
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
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ReviewQueuePage(api: fixture.api, location: 'Pantry'),
              ),
            ),
            child: const Text('Pantry Review'),
          ),
        ],
      ),
    ),
  );
}
