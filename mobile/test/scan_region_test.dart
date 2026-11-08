import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/scan_region.dart';
import 'package:mobile/features/chat/extraction_progress_panel.dart';

void main() {
  test('all detected regions beyond eight receive progress updates', () {
    final regions = applyScanRegions([], {
      'regions': List.generate(
        24,
        (i) => {
          'id': i,
          'box': [0, 0, 100, 100],
          'state': 'pending',
        },
      ),
    });
    expect(regions, hasLength(24));
    final done = applyScanRegions(regions, {
      'states': List.generate(24, (i) => {'id': i, 'state': 'checked'}),
    });
    expect(done.every((r) => r.phase == ScanRegionPhase.checked), isTrue);
    expect(done.last.id, 23);
  });
  test('accepts only unambiguous bounded crop coordinates', () {
    final result = applyScanRegions([], {
      'regions': [
        {
          'id': 0,
          'box': [100, 200, 500, 800],
          'state': 'pending',
        },
        {
          'id': 1,
          'box': [-1, 0, 10, 10],
          'state': 'pending',
        },
        {
          'id': 2,
          'box': [10, 0, 0, 10],
          'state': 'pending',
        },
        {
          'id': 3,
          'box': [0, 0, double.nan, 10],
          'state': 'pending',
        },
        {
          'id': 4,
          'box': [0, 0, 10, 10],
          'state': 'invented',
        },
        {
          'id': 5,
          'box': [0, 0, 10, 10],
          'state': 'pending',
        },
        {
          'id': 5,
          'box': [1, 1, 20, 20],
          'state': 'pending',
        },
      ],
    });
    expect(result.length, 1);
    expect(result.single.box, const Rect.fromLTRB(.1, .2, .5, .8));
    expect(applyScanRegions(result, null), same(result));
  });
  test('real activity updates preserve identity and completed crops', () {
    final initial = applyScanRegions([], {
      'regions': [
        {
          'id': 0,
          'box': [0, 0, 1000, 1000],
          'state': 'pending',
        },
      ],
    });
    final checking = applyScanRegions(initial, {
      'states': [
        {'id': 0, 'state': 'checking'},
        {'id': 7, 'state': 'checking'},
      ],
    });
    expect(checking.single.phase, ScanRegionPhase.checking);
    final done = applyScanRegions(checking, {
      'states': [
        {'id': 0, 'state': 'unreadable'},
      ],
    });
    final replay = applyScanRegions(done, {
      'states': [
        {'id': 0, 'state': 'checking'},
      ],
    });
    expect(replay.single.phase, ScanRegionPhase.unreadable);
    expect(replay.single.box, initial.single.box);
  });
  for (final size in [const Size(200, 400), const Size(400, 200)]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'boxes track the real photo $size $brightness, reduced motion and stop',
        (t) async {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawColor(Colors.grey, BlendMode.src);
          final picture = recorder.endRecording();
          late Uint8List bytes;
          await t.runAsync(() async {
            final image = await picture.toImage(
              size.width.toInt(),
              size.height.toInt(),
            );
            bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List();
            image.dispose();
          });
          picture.dispose();
          final image = MemoryImage(bytes);
          final regions = [
            const ScanRegion(
              0,
              Rect.fromLTRB(.1, .2, .8, .9),
              ScanRegionPhase.checking,
            ),
          ];
          Widget frame(bool scanning) => MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 300,
                    child: ScanPhotoFrame(
                      image: image,
                      height: 300,
                      scanning: scanning,
                      regions: regions,
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpWidget(frame(true));
          await t.runAsync(() async {
            await precacheImage(image, t.element(find.byType(ScanPhotoFrame)));
          });
          await t.pumpAndSettle();
          final regionFinder = find.byKey(const ValueKey('scan-region-0'));
          expect(regionFinder, findsOneWidget);
          final actual = t.getRect(regionFinder);
          final photoBounds = t.getRect(find.byType(Image));
          final expected = scanBoxRect(
            regions.single.box,
            size,
            photoBounds.size,
          ).shift(photoBounds.topLeft);
          expect(actual.left, closeTo(expected.left, .001));
          expect(actual.top, closeTo(expected.top, .001));
          expect(actual.right, closeTo(expected.right, .001));
          expect(actual.bottom, closeTo(expected.bottom, .001));
          final animation = t.widget<AnimatedContainer>(
            find.descendant(
              of: regionFinder,
              matching: find.byType(AnimatedContainer),
            ),
          );
          expect(animation.duration, Duration.zero);
          expect(
            find.bySemanticsLabel('Object 1, Reading details'),
            findsOneWidget,
          );
          await t.pumpWidget(frame(false));
          await t.pumpAndSettle();
          expect(regionFinder, findsNothing);
          expect(
            find.byKey(const ValueKey('scan-region-badge-0')),
            findsNothing,
          );
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
