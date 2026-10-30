import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/app_typography.dart';
import 'package:mobile/core/ui/skeleton.dart';
import 'package:mobile/core/ui/photo_source_sheet.dart';
import 'package:mobile/features/inventory/space_texture.dart';
import 'package:mobile/features/chat/voice_capture.dart';
import 'package:mobile/features/chat/voice_recording_overlay.dart';

Future<void> Function(String, Uint8List)? fluidCapture;

class _Recorder implements VoiceRecorder {
  VoiceResult? result;
  @override
  Future<bool> start(VoiceResult onResult, VoidCallback onError) async {
    result = onResult;
    return true;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}

void main() {
  Future<void> capture(WidgetTester t, String name) async {
    if (fluidCapture == null) return;
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('fluid-frame')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await fluidCapture!(name, data!.buffer.asUint8List());
    image.dispose();
  }

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.6]) {
      testWidgets(
        'recording feedback ${brightness.name} scale$scale preserves cancel',
        (t) async {
          t.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final recorder = _Recorder();
          var sends = 0;
          final voice = VoiceCapture(
            recorder: recorder,
            onSend: (_) => sends++,
            onError: () {},
          );
          await voice.start(autoSend: true);
          await t.pumpWidget(
            RepaintBoundary(
              key: const Key('fluid-frame'),
              child: MaterialApp(
                theme: AppTheme.create(brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: AppTypography(child: child!),
                ),
                home: Scaffold(
                  body: Stack(
                    children: [
                      const Center(child: Text('Find your inventory')),
                      VoiceRecordingOverlay(voice: voice),
                    ],
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(find.text('Now recording'), findsOneWidget);
          recorder.result!('Where did I put my tools?', false);
          await t.pumpAndSettle();
          await capture(t, 'recording-${brightness.name}-$scale');
          await t.tap(find.text('Cancel'));
          expect(voice.active, false);
          recorder.result!('late result', true);
          expect(sends, 0);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          voice.dispose();
        },
      );
    }
    testWidgets('photo chooser and texture atlas ${brightness.name}', (
      t,
    ) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      bool? choice;
      await t.pumpWidget(
        RepaintBoundary(
          key: const Key('fluid-frame'),
          child: MaterialApp(
            theme: AppTheme.create(brightness),
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    const SizedBox(height: 80),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final id in ['a', 'b', 'c', 'd'])
                          SpaceTexture(identity: id, size: 72),
                      ],
                    ),
                    TextButton(
                      onPressed: () async {
                        choice = await showPhotoSourceSheet(context);
                      },
                      child: const Text('Add photo'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Add photo'));
      await t.pumpAndSettle();
      await capture(t, 'photo-textures-${brightness.name}');
      await t.tap(find.text('Choose photo'));
      await t.pumpAndSettle();
      expect(choice, false);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('diagonal skeleton stops animation with Reduce Motion', (
    t,
  ) async {
    await t.pumpWidget(
      RepaintBoundary(
        key: const Key('fluid-frame'),
        child: MaterialApp(
          theme: AppTheme.create(Brightness.dark),
          home: const Scaffold(body: SkeletonPage()),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 650));
    await capture(t, 'diagonal-skeleton');
    t.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    await t.pumpAndSettle();
    expect(t.binding.hasScheduledFrame, false);
    t.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await t.pumpWidget(const SizedBox());
  });
  test(
    'texture assignment remains stable with all four choices distributed',
    () {
      expect(['a', 'b', 'c', 'd'].map(spaceTextureIndex).toSet(), {0, 1, 2, 3});
      expect(
        spaceTextureIndex('space-identity'),
        spaceTextureIndex('space-identity'),
      );
    },
  );
}
