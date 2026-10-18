import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as bitmap;
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/profile/profile_photo_crop_page.dart';

Uint8List bands() {
  final image = bitmap.Image(width: 600, height: 200);
  for (var y = 0; y < 200; y++) {
    for (var x = 0; x < 600; x++) {
      image.setPixelRgb(
        x,
        y,
        x < 200 ? 255 : 0,
        x >= 200 && x < 400 ? 255 : 0,
        x >= 400 ? 255 : 0,
      );
    }
  }
  return bitmap.encodePng(image);
}

void main() {
  testWidgets(
    'saved pixels exactly match the positioned square with no empty borders',
    (tester) async {
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bands());
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        try {
          final initial = bitmap.decodePng(
            await renderProfileCrop(
              image,
              profileCropRect(const Size(600, 200), 1, const Offset(300, 100)),
            ),
          )!;
          expect(initial.width, 512);
          expect(initial.height, 512);
          expect(initial.getPixel(256, 256).g, greaterThan(240));
          final moved = bitmap.decodePng(
            await renderProfileCrop(
              image,
              profileCropRect(const Size(600, 200), 2, const Offset(999, -50)),
            ),
          )!;
          expect(moved.getPixel(256, 256).b, greaterThan(240));
          expect(moved.getPixel(0, 0).a, 255);
          expect(moved.getPixel(511, 511).a, 255);
        } finally {
          image.dispose();
        }
      });
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} user can zoom, drag, reset and explicitly accept a crop',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Uint8List? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(brightness),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await Navigator.push<Uint8List>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilePhotoCropPage(bytes: bands()),
                      ),
                    );
                  },
                  child: const Text('Open crop'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open crop'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(
          find.byKey(const ValueKey('profile-crop-preview')),
          findsOneWidget,
        );
        final middle = tester.getCenter(
          find.byKey(const ValueKey('profile-crop-preview')),
        );
        final first = await tester.createGesture(pointer: 1),
            second = await tester.createGesture(pointer: 2);
        await first.down(middle - const Offset(25, 0));
        await second.down(middle + const Offset(25, 0));
        await tester.pump();
        await first.moveTo(middle - const Offset(50, 0));
        await second.moveTo(middle + const Offset(50, 0));
        await tester.pump();
        expect(
          tester.widget<Slider>(find.byType(Slider)).value,
          greaterThan(1),
        );
        await first.up();
        await second.up();
        await tester.pump();
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pump();
        expect(
          tester.widget<Slider>(find.byType(Slider)).value,
          greaterThan(1),
        );
        await tester.drag(
          find.byKey(const ValueKey('profile-crop-preview')),
          const Offset(-80, 0),
        );
        await tester.pump();
        await tester.tap(find.text('Reset'));
        await tester.pump();
        expect(tester.widget<Slider>(find.byType(Slider)).value, 1);
        await tester.tap(find.text('Use photo'));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        expect(result, isNotNull);
        expect(bitmap.decodePng(result!)!.width, 512);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
