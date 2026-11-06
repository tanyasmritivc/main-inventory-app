import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/chat/chat_capture_card.dart';
import 'package:mobile/features/chat/extraction_progress_panel.dart';
import '../test/support/hierarchy_fixture.dart';
import '../test/support/scan_live_photo_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  final photo = MemoryImage(extractPhotoFixture);
  Future<void> capture(WidgetTester t, String name) async {
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('scan-audit')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final path = '${Directory.systemTemp.path}/scan-live-$name.png';
    await File(path).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
    debugPrint('SCAN_LIVE_IMAGE $path');
  }

  for (final brightness in Brightness.values) {
    testWidgets('native photo review ${brightness.name}', (t) async {
      final api = ApiClient.forWorld(
        fixture.api,
        'personal',
        isCurrent: () => true,
      );
      final draft = <String, dynamic>{
        'id': 'audit',
        'revision': 1,
        'status': 'draft',
        'source_kind': 'photo',
        'items': [
          for (final data in [
            (
              'Unknown item',
              'Dark flat object under the headphones, mostly hidden',
              '',
              .2,
            ),
            (
              'pink jar candle',
              'Pink glass jar with lid, partly hidden behind the headphones',
              'home decor',
              .68,
            ),
            (
              'black over-ear headphones',
              'Black, over-ear, cushioned ear cups, folded on the desk',
              'audio',
              .94,
            ),
            (
              'silver Mac mini',
              'Silver aluminum desktop computer',
              'computers',
              .91,
            ),
            (
              'white keyboard',
              'Compact keyboard with white keys',
              'computers',
              .89,
            ),
          ].indexed)
            {
              'index': data.$1,
              'selected': true,
              'item': {
                'name': data.$2.$1,
                'notes': data.$2.$2,
                'category': data.$2.$3,
                'quantity': 1,
                'confidence': data.$2.$4,
                'scan_evidence': {'needs_review': true},
              },
            },
        ],
      };
      var scanning = true;
      var message = 'Finding objects in your photo...';
      late StateSetter render;
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(brightness),
          home: RepaintBoundary(
            key: const Key('scan-audit'),
            child: Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.chevron_left),
                          Text('Ask'),
                          Icon(Icons.edit_square),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: StatefulBuilder(
                          builder: (context, set) {
                            render = set;
                            return Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: brightness == Brightness.dark
                                    ? const Color(0xff1c1c1e)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: .08),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      18,
                                      16,
                                      18,
                                      16,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.center_focus_weak, size: 18),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Review extraction',
                                            style: TextStyle(fontSize: 17),
                                          ),
                                        ),
                                        Icon(Icons.close, size: 18),
                                      ],
                                    ),
                                  ),
                                  ScanPhotoFrame(
                                    image: photo,
                                    height: scanning ? 300 : 128,
                                    scanning: scanning,
                                  ),
                                  if (scanning)
                                    ExtractionProgressPanel(message: message)
                                  else
                                    Expanded(
                                      child: ChatCaptureCard(
                                        api: api,
                                        conversationId: 'chat',
                                        draft: draft,
                                        photo: photo,
                                        embedded: true,
                                        onChanged: (_) {},
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: brightness == Brightness.dark
                            ? const Color(0xff1c1c1e)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Add items from a photo'),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [Icon(Icons.add), Icon(Icons.mic_none)],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 800));
      await capture(t, '${brightness.name}-scanning');
      render(() => message = 'Checked 2 of 5 objects...');
      await t.pump(const Duration(milliseconds: 400));
      await capture(t, '${brightness.name}-checking');
      render(() => scanning = false);
      await t.pumpAndSettle();
      await capture(t, '${brightness.name}-review');
      await t.drag(
        find.byKey(const Key('extraction-preview-scroll')),
        const Offset(0, -450),
      );
      await t.pumpAndSettle();
      await capture(t, '${brightness.name}-unknowns');
      expect(find.text('Not sure about this one'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
