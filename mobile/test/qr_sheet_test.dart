import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/scan/qr_sheet.dart';

void main() {
  final item = InventoryItem.fromJson({
    'item_id': '00000000-0000-0000-0000-000000000001',
    'name': 'Clamp',
    'category': 'Tools',
    'quantity': 1,
  });

  testWidgets('saved object offers a scannable label in light theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => QrOfferSheet(item: item),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Object saved'), findsOneWidget);
    await tester.tap(find.text('Make a QR label'));
    await tester.pumpAndSettle();
    expect(find.text('Your QR labels'), findsOneWidget);
    expect(find.text('Clamp'), findsOneWidget);
  });
}
