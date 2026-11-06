import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/chat/extraction_progress_panel.dart';
import 'package:mobile/features/chat/scan_region.dart';
import '../test/support/scan_box_photo_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final brightness in Brightness.values) {
    testWidgets('native crop overlay ${brightness.name}', (t) async {
      var regions = applyScanRegions([], {
        'regions': [
          {
            'id': 0,
            'box': [0, 190, 840, 565],
            'state': 'checking',
          },
          {
            'id': 1,
            'box': [30, 70, 480, 280],
            'state': 'checked',
          },
          {
            'id': 2,
            'box': [800, 185, 1000, 400],
            'state': 'pending',
          },
        ],
      });
      var scanning = true;
      var reduced = false;
      late StateSetter update;
      final image = MemoryImage(scanBoxPhotoFixture);
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(brightness),
          home: StatefulBuilder(
            builder: (context, set) {
              update = set;
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduced),
                child: RepaintBoundary(
                  key: const Key('box-audit'),
                  child: Scaffold(
                    body: SafeArea(
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('Review extraction'),
                          ),
                          ScanPhotoFrame(
                            image: image,
                            height: 440,
                            scanning: scanning,
                            regions: regions,
                          ),
                          const ExtractionProgressPanel(
                            message: 'Reading details for 3 objects...',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('scan-region-0')), findsOneWidget);
      Future<void> capture(String state) async {
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('box-audit')),
        );
        final shot = await boundary.toImage(pixelRatio: 2);
        final data = await shot.toByteData(format: ui.ImageByteFormat.png);
        final path =
            '${Directory.systemTemp.path}/scan-box-${brightness.name}-$state.png';
        await File(path).writeAsBytes(data!.buffer.asUint8List());
        shot.dispose();
        debugPrint('SCAN_BOX_IMAGE $path');
      }

      await capture('checking');
      update(() {
        reduced = true;
        regions = applyScanRegions(regions, {
          'states': [
            {'id': 0, 'state': 'checked'},
            {'id': 2, 'state': 'checking'},
          ],
        });
      });
      await t.pump();
      await capture('reduced-motion');
      update(() => scanning = false);
      await t.pump(const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('scan-region-0')), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
