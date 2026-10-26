// Actual iOS rendering, synthetic receipts, no network or inventory writes.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/chat_item_action.dart';
import 'package:mobile/features/chat/chat_item_action_card.dart';
import 'package:mobile/features/world/world_action_card.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final brightness in Brightness.values) {
    testWidgets('creation and saved receipt ${brightness.name}', (
      tester,
    ) async {
      const inventory = '11111111-1111-4111-8111-111111111111';
      const item = '22222222-2222-4222-8222-222222222222';
      final api = ApiClient(baseUrl: 'https://api.test');
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(brightness),
          home: RepaintBoundary(
            key: const ValueKey('receipt-frame'),
            child: Scaffold(
              appBar: AppBar(title: const Text('Ask')),
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  WorldActionCard(
                    api: api,
                    action: const {
                      'id': '33333333-3333-4333-8333-333333333333',
                      'version': 2,
                      'status': 'pending',
                      'workspace_label': 'Test Ws',
                      'plan': {
                        'inventories': [
                          {
                            'name': 'FindEZ QA',
                            'spaces': ['Storage'],
                            'items': [
                              {
                                'name': 'AA batteries',
                                'quantity': 10,
                                'location': 'Storage',
                              },
                            ],
                          },
                        ],
                      },
                    },
                  ),
                  const SizedBox(height: 20),
                  ChatItemActionCard(
                    api: api,
                    action: ChatItemAction.parse({
                      'id': '44444444-4444-4444-8444-444444444444',
                      'inventory_id': inventory,
                      'version': 2,
                      'operation': 'edit',
                      'status': 'confirmed',
                      'items': [
                        {
                          'item_id': item,
                          'inventory_id': inventory,
                          'name': 'AA batteries',
                          'quantity': 5,
                          'location': 'Storage',
                          'details': ['Quantity: 8 → 5'],
                        },
                      ],
                    })!,
                    onOpenResource: (link) {
                      expect(link.id, item);
                      opened = true;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Create & complete'), findsOneWidget);
      await tester.ensureVisible(find.text('Open item'));
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('receipt-frame')),
      );
      final frame = await boundary.toImage(pixelRatio: 2);
      final bytes = (await frame.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      final file = File(
        '${Directory.systemTemp.path}/findez-follow-through-${brightness.name}.png',
      );
      await file.writeAsBytes(bytes);
      debugPrint('RECEIPT_VISUAL ${file.path}');
      await Future<void>.delayed(const Duration(seconds: 3));
      frame.dispose();
      await tester.tap(find.text('Open item'));
      expect(opened, isTrue);
    });
  }
}
