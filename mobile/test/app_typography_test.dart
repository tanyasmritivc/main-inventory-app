import 'package:mobile/features/chat/ask_answer_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/app_text.dart';

Future<void> Function(WidgetTester, String)? typographyCapture;

Widget _app({required Brightness brightness}) => RepaintBoundary(
  key: const Key('typography-frame'),
  child: MaterialApp(
    theme: AppTheme.create(brightness),
    builder: (_, child) => AppTypography(child: child!),
    home: Scaffold(
      appBar: AppBar(title: const Text('Framework toolbar')),
      body: Builder(
        builder: (context) => ListView(
          children: [
            const AppText(
              'Heading',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const AppText(
              'Supporting text',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
            ),
            const Text('Framework body'),
            TextField(
              style: AppTypography.bodyStyleOf(
                context,
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              decoration: InputDecoration(
                hintText: 'Field hint',
                hintStyle: AppTypography.bodyStyleOf(
                  context,
                  const TextStyle(fontWeight: FontWeight.w400),
                ),
              ),
            ),
            FilledButton(
              onPressed: () {},
              child: const Text('Framework button'),
            ),
          ],
        ),
      ),
    ),
  ),
);

FontWeight? _weight(WidgetTester tester, String label) => tester
    .widget<RichText>(
      find.descendant(of: find.text(label), matching: find.byType(RichText)),
    )
    .text
    .style
    ?.fontWeight;

void main() {
  testWidgets(
    'compact Space sizing is local and preserves accessibility scaling',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(Brightness.light),
          builder: (context, child) => AppTypography(
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2.6)),
              child: child!,
            ),
          ),
          home: const Scaffold(
            body: Column(
              children: [
                AppText('App body', style: TextStyle(fontSize: 15)),
                AppTypography(
                  bodyPointSize: 15,
                  captionPointSize: 12,
                  child: Column(
                    children: [
                      AppText('Space body', style: TextStyle(fontSize: 17)),
                      AppText('Space caption', style: TextStyle(fontSize: 13)),
                      Text('Space framework'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      for (final entry in {
        'App body': 16.0,
        'Space body': 15.0,
        'Space caption': 12.0,
        'Space framework': 15.0,
      }.entries) {
        final rich = t.widget<RichText>(
          find.descendant(
            of: find.text(entry.key),
            matching: find.byType(RichText),
          ),
        );
        expect(rich.text.style?.fontSize, entry.value, reason: entry.key);
        expect(rich.text.style?.fontFamily, AppTypography.fontFamily);
        expect(rich.textScaler.scale(entry.value), entry.value * 2.6);
      }
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'AI response headings and body remain regular ${brightness.name}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(brightness),
            builder: (_, child) => AppTypography(child: child!),
            home: const Scaffold(
              body: AskAnswerView(
                answer: '# Inventory heading\n\nRegular **emphasis** body.',
                isLoading: true,
              ),
            ),
          ),
        );
        await tester.pump();
        final texts = tester.widgetList<RichText>(find.byType(RichText));
        final heading = texts.firstWhere(
          (t) => t.text.toPlainText() == 'Inventory heading',
        );
        final body = texts.firstWhere(
          (t) => t.text.toPlainText().contains('Regular'),
        );
        void check(InlineSpan span, TextStyle inherited, FontWeight weight) {
          final style = inherited.merge(span.style);
          if (span is TextSpan) {
            if ((span.text ?? '').isNotEmpty) {
              expect(style.fontWeight, weight);
              expect(style.fontFamily, 'CupertinoSystemText');
            }
            for (final child in span.children ?? <InlineSpan>[]) {
              check(child, style, weight);
            }
          }
        }

        check(heading.text, const TextStyle(), FontWeight.w400);
        check(body.text, const TextStyle(), FontWeight.w400);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} text weights stay light when OS Bold Text changes',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(boldText: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pumpWidget(_app(brightness: brightness));
        await typographyCapture?.call(tester, brightness.name);
        expect(_weight(tester, 'Heading'), FontWeight.w400);
        expect(_weight(tester, 'Supporting text'), FontWeight.w400);
        expect(_weight(tester, 'Framework body'), FontWeight.w400);
        expect(_weight(tester, 'Framework toolbar'), FontWeight.w400);
        expect(_weight(tester, 'Framework button'), FontWeight.w400);
        expect(_weight(tester, 'Field hint'), FontWeight.w400);
        for (final label in [
          'Supporting text',
          'Framework body',
          'Framework button',
        ]) {
          final text = tester.widget<RichText>(
            find.descendant(
              of: find.text(label),
              matching: find.byType(RichText),
            ),
          );
          expect(text.text.style?.fontSize, 16, reason: label);
        }
        expect(
          tester
              .widget<RichText>(
                find.descendant(
                  of: find.text('Heading'),
                  matching: find.byType(RichText),
                ),
              )
              .text
              .style
              ?.fontSize,
          24,
        );
        expect(
          tester.widget<EditableText>(find.byType(EditableText)).style.fontSize,
          16,
        );
        for (final label in [
          'Heading',
          'Supporting text',
          'Framework body',
          'Framework toolbar',
          'Framework button',
          'Field hint',
        ]) {
          final text = tester.widget<RichText>(
            find.descendant(
              of: find.text(label),
              matching: find.byType(RichText),
            ),
          );
          expect(
            text.text.style?.fontFamily,
            'CupertinoSystemText',
            reason: label,
          );
        }
        await tester.enterText(find.byType(TextField), 'Retained input');
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .style
              .fontFamily,
          'CupertinoSystemText',
        );
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .style
              .fontWeight,
          FontWeight.w400,
        );
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(boldText: false);
        await tester.pumpAndSettle();
        expect(_weight(tester, 'Supporting text'), FontWeight.w400);
        expect(_weight(tester, 'Framework body'), FontWeight.w400);
        expect(_weight(tester, 'Heading'), FontWeight.w400);
        expect(find.text('Retained input'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets('inherited and local typography agrees ${brightness.name}', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(brightness),
          builder: (_, child) => AppTypography(child: child!),
          home: Scaffold(
            body: Builder(
              builder: (context) => ListView(
                children: [
                  for (final size in [14.0, 15.5, 16.0, 17.0, 18.0, 19.0])
                    DefaultTextStyle(
                      style: TextStyle(
                        fontSize: size,
                        fontFamily: 'serif',
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.4,
                      ),
                      child: AppText(
                        'Inherited $size',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  const AppText(
                    'Explicit body',
                    style: TextStyle(fontSize: 19),
                  ),
                  const AppText('Caption', style: TextStyle(fontSize: 12.5)),
                  const AppText('Title', style: TextStyle(fontSize: 22)),
                  const AppText('Hero', style: TextStyle(fontSize: 34)),
                  TextField(
                    style: AppTypography.bodyStyleOf(
                      context,
                      const TextStyle(fontSize: 13),
                    ),
                    controller: TextEditingController(text: 'Input'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      for (final label in [
        for (final size in [14.0, 15.5, 16.0, 17.0, 18.0, 19.0])
          'Inherited $size',
        'Explicit body',
        'Caption',
        'Title',
        'Hero',
      ]) {
        final rich = t.widget<RichText>(
          find.descendant(
            of: find.text(label),
            matching: find.byType(RichText),
          ),
        );
        final style = rich.text.style!;
        expect(style.fontFamily, 'CupertinoSystemText', reason: label);
        expect(style.fontWeight, FontWeight.w400, reason: label);
        expect(style.fontSize, switch (label) {
          'Caption' => 13,
          'Title' => 20,
          'Hero' => 34,
          _ => 16,
        }, reason: label);
        if (label.startsWith('Inherited')) {
          expect(style.letterSpacing, 0);
          expect(style.color, Colors.orange);
        }
      }
      expect(
        t.widget<EditableText>(find.byType(EditableText)).style.fontSize,
        16,
      );
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('typography preserves scaling and other accessibility features', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.6;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(
          boldText: true,
          accessibleNavigation: true,
          disableAnimations: true,
          highContrast: true,
          invertColors: true,
        );
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_app(brightness: Brightness.dark));
    await typographyCapture?.call(tester, 'large-text');
    final text = tester.widget<RichText>(
      find.descendant(
        of: find.text('Supporting text'),
        matching: find.byType(RichText),
      ),
    );
    expect(text.textScaler.scale(14), closeTo(36.4, .001));
    final context = tester.element(find.byType(TextField));
    final media = MediaQuery.of(context);
    expect(media.boldText, isFalse);
    expect(media.accessibleNavigation, isTrue);
    expect(media.disableAnimations, isTrue);
    expect(media.highContrast, isTrue);
    expect(media.invertColors, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app text retains semantics, clipping and explicit text styles', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(boldText: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppText(
            'Visible code',
            semanticsLabel: 'Readable inventory code',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: Colors.orange,
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: .5,
            ),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text('Visible code'));
    expect(text.style?.fontWeight, FontWeight.w400);
    expect(text.style?.color, Colors.orange);
    expect(text.style?.fontFamily, 'CupertinoSystemText');
    expect(text.style?.letterSpacing, 0);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.textAlign, TextAlign.right);
    expect(text.textScaler, TextScaler.noScaling);
    expect(find.bySemanticsLabel('Readable inventory code'), findsOneWidget);
    semantics.dispose();
  });
}
