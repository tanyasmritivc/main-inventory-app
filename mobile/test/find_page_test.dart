import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/inventory/find_page.dart';
import 'package:mobile/features/scan/scan_page.dart';

class _FindApi extends ApiClient {
  _FindApi() : super(baseUrl: 'https://invalid.test');

  @override
  Future<SearchItemsResult> searchItems({required String query}) async =>
      SearchItemsResult(
        items: [
          InventoryItem(
            itemId: '00000000-0000-0000-0000-000000000001',
            name: 'Test object',
            category: 'Other',
            quantity: 4,
            location: 'First place',
            spaceName: 'First place',
            binName: 'Top shelf',
            workspaceName: 'Test workspace',
            createdAt: DateTime(2026),
          ),
          InventoryItem(
            itemId: '00000000-0000-0000-0000-000000000002',
            name: 'Test object',
            category: 'Other',
            quantity: 7,
            location: 'Second place',
            spaceName: 'Second place',
            binName: 'Bottom shelf',
            workspaceName: 'Test workspace',
            createdAt: DateTime(2026),
          ),
        ],
        parsed: const {},
      );
}

void main() {
  testWidgets('Find shows separate place paths and real counts', (
    tester,
  ) async {
    final opened = <CaptureMode>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FindPage(
          api: _FindApi(),
          refreshToken: 0,
          initialQuery: 'test',
          onOpenCamera: opened.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Test workspace / First place / Top shelf'),
      findsOneWidget,
    );
    expect(
      find.text('Test workspace / Second place / Bottom shelf'),
      findsOneWidget,
    );
    expect(find.text('4'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    await tester.tap(find.text('Scan a barcode'));
    await tester.pump();
    expect(opened.last, CaptureMode.scan);
    await tester.tap(find.text('Point the camera at one'));
    await tester.pump();
    expect(opened.last, CaptureMode.see);
  });
}
