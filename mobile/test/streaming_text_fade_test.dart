import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/streaming_text_fade.dart';

List<double> alphas(InlineSpan span) {
  if (span is! TextSpan) return [];
  return [
    if ((span.text ?? '').isNotEmpty)
      span.style?.foreground?.color.a ?? span.style?.color?.a ?? 1,
    for (final child in span.children ?? <InlineSpan>[]) ...alphas(child),
  ];
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} only appended glyphs fade, preserving formatting and size',
      (tester) async {
        Widget page(String text, {bool enabled = true}) => MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: RepaintBoundary(
              key: const Key('fade-pixels'),
              child: StreamingTextFade(
                enabled: enabled,
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: brightness == Brightness.light
                          ? Colors.black
                          : Colors.white,
                      fontSize: 18,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Old words ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: text),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(page(''));
        await tester.pumpAndSettle();
        final before = tester.getSize(find.byType(RichText).first);
        await tester.pumpWidget(page('new words 🔧'));
        await tester.pump();
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byType(RichText).first,
        );
        expect(paragraph.text.toPlainText(), 'Old words new words 🔧');
        expect(alphas(paragraph.text).first, 1);
        expect(paragraph.text.toPlainText(), contains('new words 🔧'));
        final during = tester.getSize(find.byType(RichText).first);
        Future<int> newInk() async => (await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('fade-pixels')),
          );
          final image = await boundary.toImage();
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          var ink = 0;
          for (var y = 0; y < image.height; y++) {
            for (var x = before.width.ceil(); x < image.width; x++) {
              ink += data!.getUint8((y * image.width + x) * 4 + 3);
            }
          }
          image.dispose();
          return ink;
        }))!;
        final hidden = await newInk();
        await tester.pump(const Duration(milliseconds: 90));
        expect(tester.getSize(find.byType(RichText).first), during);
        final middle = await newInk();
        await tester.pumpAndSettle();
        final visible = await newInk();
        expect(hidden, 0);
        expect(middle, greaterThan(hidden));
        expect(middle, lessThan(visible));
        expect(alphas(paragraph.text).every((value) => value == 1), isTrue);
        expect(tester.getSize(find.byType(RichText).first), during);
        expect(before.height, during.height);
        await tester.pumpWidget(page('instant', enabled: false));
        await tester.pump();
        expect(alphas(paragraph.text).every((value) => value == 1), isTrue);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
