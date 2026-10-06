import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/app_text.dart';

Widget _app({required Brightness brightness}) => MaterialApp(
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
          FilledButton(onPressed: () {}, child: const Text('Framework button')),
        ],
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
  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} app and framework controls share weights', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(boldText: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_app(brightness: brightness));
      expect(_weight(tester, 'Heading'), FontWeight.w600);
      expect(_weight(tester, 'Supporting text'), FontWeight.w500);
      expect(_weight(tester, 'Framework body'), FontWeight.w500);
      expect(_weight(tester, 'Framework toolbar'), FontWeight.w600);
      expect(_weight(tester, 'Framework button'), FontWeight.w600);
      expect(_weight(tester, 'Field hint'), FontWeight.w500);
      await tester.enterText(find.byType(TextField), 'Retained input');
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).style.fontWeight,
        FontWeight.w500,
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(boldText: false);
      await tester.pumpAndSettle();
      expect(_weight(tester, 'Supporting text'), FontWeight.w400);
      expect(_weight(tester, 'Framework body'), FontWeight.w400);
      expect(_weight(tester, 'Heading'), FontWeight.w600);
      expect(find.text('Retained input'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
    final text = tester.widget<RichText>(
      find.descendant(
        of: find.text('Supporting text'),
        matching: find.byType(RichText),
      ),
    );
    expect(text.textScaler.scale(14), closeTo(36.4, .001));
    final context = tester.element(find.byType(TextField));
    final media = MediaQuery.of(context);
    expect(AppTypography.boldTextOf(context), isTrue);
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
    expect(text.style?.fontWeight, FontWeight.w500);
    expect(text.style?.color, Colors.orange);
    expect(text.style?.fontFamily, 'monospace');
    expect(text.style?.letterSpacing, .5);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.textAlign, TextAlign.right);
    expect(text.textScaler, TextScaler.noScaling);
    expect(find.bySemanticsLabel('Readable inventory code'), findsOneWidget);
    semantics.dispose();
  });
}
