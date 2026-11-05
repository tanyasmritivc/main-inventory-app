import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/app_text.dart';
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
    Brightness brightness = Brightness.dark,
  }) async {
    t.view.physicalSize = Size(width, width == 320 ? 568 : 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(brightness),
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
  test(
    'known scan items rank by identity confidence, unknowns last, ties stable',
    () {
      Map<String, dynamic> row(
        int index,
        String name, {
        double? score,
        double? legacy,
      }) => {
        'index': index,
        'selected': true,
        'item': {
          'name': name,
          if (score != null) 'scan_evidence': {'identity_confidence': score},
          if (legacy != null) 'confidence': legacy,
        },
      };
      final input = [
        row(0, 'Unknown cable', score: .99),
        row(1, 'Drill', score: .8),
        row(2, 'Wrench', score: .95, legacy: .1),
        row(3, 'Clamp', score: .8),
        row(4, 'Screw'),
        row(5, 'Item 6', score: 1),
        row(6, '', score: .5),
      ];
      final sorted = sortedExtractRows(input);
      expect(sorted.map((r) => r['index']), [2, 1, 3, 4, 5, 0, 6]);
      expect(input.map((r) => r['index']), [0, 1, 2, 3, 4, 5, 6]);
      expect(identical(sorted.first, input[2]), isTrue);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'scan uses app colours and regular semantic sizes ${brightness.name}',
      (t) async {
        await mount(
          t,
          ExtractScanning(photo: landscape, message: ''),
          reduce: true,
          brightness: brightness,
        );
        final title = t.widget<RichText>(
          find.descendant(
            of: find.text('Looking at your photo'),
            matching: find.byType(RichText),
          ),
        );
        expect(title.text.style?.fontFamily, AppTypography.fontFamily);
        expect(title.text.style?.fontSize, AppTypography.titleSize);
        expect(title.text.style?.fontWeight, FontWeight.w400);
        final context = t.element(find.byType(ExtractScanning));
        expect(title.text.style?.color, AppTheme.textPrimary(context));
        final placeholders = t
            .widgetList<Container>(find.byType(Container))
            .where((c) => c.constraints?.maxHeight == 76);
        expect(placeholders, hasLength(3));
        for (final placeholder in placeholders) {
          final colour = (placeholder.decoration as BoxDecoration).color!;
          expect(
            colour.computeLuminance() > .5,
            brightness == Brightness.light,
          );
        }
        expect(t.takeException(), isNull);
        await capture(t, 'scan-theme-${brightness.name}');
        await t.pumpWidget(const SizedBox());
      },
    );
  }
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
