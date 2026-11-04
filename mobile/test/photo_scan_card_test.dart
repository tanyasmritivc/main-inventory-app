import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mobile/features/chat/auto_extract/extract_widgets.dart';
import 'support/extract_photo_fixture.dart';

Future<void> Function(String, Uint8List)? photoScanCapture;

void main() {
  final landscape = extractPhotoFixture;
  final portrait = Uint8List.fromList(
    img.encodeJpg(img.copyRotate(img.decodeJpg(landscape)!, angle: 90)),
  );
  Future<void> capture(WidgetTester t, String name) async {
    if (photoScanCapture == null) return;
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('scan-audit-frame')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await photoScanCapture!(name, bytes!.buffer.asUint8List());
    image.dispose();
  }

  Future<void> mount(
    WidgetTester t,
    Widget card, {
    bool reduce = false,
    double scale = 1,
    double width = 390,
  }) async {
    t.view.physicalSize = Size(width, width == 320 ? 568 : 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduce,
            textScaler: TextScaler.linear(scale),
          ),
          child: RepaintBoundary(
            key: const Key('scan-audit-frame'),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(15),
              child: card,
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  List<Map<String, dynamic>> rows(int n) => List.generate(
    n,
    (i) => {
      'index': i,
      'selected': true,
      'item': {
        'name': i == 0 ? 'Headphones' : 'Item ${i + 1}',
        'category': 'Electronics',
        'quantity': 1,
      },
    },
  );
  for (final photo in [('portrait', portrait), ('landscape', landscape)]) {
    testWidgets(
      'photo scan ${photo.$1} preserves aspect in rounded 300-point stage',
      (t) async {
        await mount(
          t,
          ExtractScanning(
            photo: photo.$2,
            message: 'Reading details for 8 objects...',
          ),
        );
        await t.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await t.pump(const Duration(milliseconds: 300));
        expect(find.text('Looking at your photo'), findsOneWidget);
        expect(find.text('0 found'), findsOneWidget);
        final gradient = t.widget<DecoratedBox>(
          find.byKey(const Key('scan-clean-gradient')),
        );
        expect(
          (gradient.decoration as BoxDecoration).gradient,
          isA<LinearGradient>(),
        );
        expect(
          find.byType(RawImage),
          findsOneWidget,
        ); // Only the photo; no grain layer.
        expect(find.textContaining('8 objects'), findsNothing);
        expect(
          t.getSize(find.byKey(const Key('scan-photo-stage'))).height,
          300,
        );
        final images = t.widgetList<Image>(find.byType(Image)).toList();
        expect(images.map((i) => i.fit), contains(BoxFit.contain));
        expect(t.takeException(), isNull);
        await capture(t, 'scan-${photo.$1}');
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  for (final count in [1, 12]) {
    testWidgets(
      'photo scan $count real results scroll horizontally and review callback writes nothing',
      (t) async {
        var reviewed = 0;
        var retaken = 0;
        await mount(
          t,
          ExtractScanning(
            photo: portrait,
            message: '',
            done: true,
            rows: rows(count),
            onReview: () => reviewed++,
            onRetake: () => retaken++,
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('$count of $count selected'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        await t.ensureVisible(
          find.text('Review $count ${count == 1 ? 'item' : 'items'}'),
        );
        await t.pumpAndSettle();
        await capture(t, 'scan-done-$count');
        await t.tap(
          find.text('Review $count ${count == 1 ? 'item' : 'items'}'),
        );
        await t.tap(find.text('Retake'));
        expect(reviewed, 1);
        expect(retaken, 1);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'photo scan no selection disables Review and respects reduced motion',
    (t) async {
      final items = rows(1)..first['selected'] = false;
      await mount(
        t,
        ExtractScanning(
          photo: portrait,
          message: '',
          done: true,
          rows: items,
          onReview: () => fail('No selected items'),
        ),
        reduce: true,
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Select items'));
      await t.tap(find.text('Select items'));
      await t.pumpAndSettle();
      expect(find.text('0 of 1 selected'), findsOneWidget);
      expect(t.binding.hasScheduledFrame, isFalse);
      expect(t.takeException(), isNull);
    },
  );
  for (final stopped in [true, false]) {
    testWidgets(
      'photo scan ${stopped ? 'stopped' : 'error'} retains retry action',
      (t) async {
        var retries = 0;
        await mount(
          t,
          ExtractScanning(
            photo: portrait,
            message: '',
            stopped: stopped,
            error: stopped
                ? null
                : 'Could not finish scanning. Your photo is ready to retry.',
            onRetry: () => retries++,
          ),
        );
        await t.pumpAndSettle();
        expect(
          find.text(stopped ? 'Scan stopped' : "Couldn't read this photo"),
          findsOneWidget,
        );
        expect(find.byKey(const Key('scan-photo-stage')), findsNothing);
        await capture(t, stopped ? 'scan-stopped' : 'scan-error');
        await t.tap(find.text(stopped ? 'Scan again' : 'Try again'));
        expect(retries, 1);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'photo scan smallest phone large text and reduced motion fit without a running ticker',
    (t) async {
      await mount(
        t,
        ExtractScanning(photo: landscape, message: ''),
        reduce: true,
        scale: 2,
        width: 320,
      );
      await t.pumpAndSettle();
      expect(t.binding.hasScheduledFrame, isFalse);
      expect(t.takeException(), isNull);
      await capture(t, 'scan-small-large-text');
    },
  );
}
