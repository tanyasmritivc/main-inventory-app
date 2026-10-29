import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/world/world_composer.dart';
import 'package:mobile/core/app_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('composer actions and surface are monochrome $brightness', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'Ready to send');
      final focus = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(brightness),
          home: Scaffold(
            body: WorldComposer(
              controller: controller,
              focusNode: focus,
              onChanged: (_) {},
              onAttach: () {},
              onVoice: () {},
              onSend: () {},
              onFirstCamera: () {},
              busy: false,
              listening: false,
              compact: false,
            ),
          ),
        ),
      );
      void neutral(Color c) {
        final channels = [c.r, c.g, c.b]..sort();
        expect(channels.last - channels.first, lessThan(.01));
      }

      for (final tooltip in ['Send message', 'Snap a shelf']) {
        final button = tester.widget<IconButton>(
          find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == tooltip,
          ),
        );
        final background = button.style!.backgroundColor!.resolve({})!;
        final foreground = button.style!.foregroundColor!.resolve({})!;
        neutral(background);
        neutral(foreground);
        final luminance = [
          background.computeLuminance(),
          foreground.computeLuminance(),
        ]..sort();
        expect(
          (luminance.last + .05) / (luminance.first + .05),
          greaterThan(4.5),
        );
      }
      for (final box in tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(WorldComposer),
          matching: find.byType(DecoratedBox),
        ),
      )) {
        final decoration = box.decoration;
        if (decoration is BoxDecoration && decoration.color != null) {
          neutral(decoration.color!);
        }
      }
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      focus.dispose();
    });
  }
  for (final reduced in [false, true]) {
    testWidgets(
      'placeholder respects draft, focus and reduced motion $reduced',
      (tester) async {
        final controller = TextEditingController();
        final focus = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(
                body: WorldComposer(
                  controller: controller,
                  focusNode: focus,
                  onChanged: (_) {},
                  onAttach: () {},
                  onVoice: () {},
                  onSend: null,
                  busy: false,
                  listening: false,
                  compact: false,
                ),
              ),
            ),
          ),
        );
        expect(find.text('Describe your inventory…'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 65));
        expect(controller.text, isEmpty);
        expect(
          find.text(reduced ? 'Describe your inventory…' : 'Wh'),
          findsOneWidget,
        );
        await tester.enterText(find.byType(TextField), 'Keep this draft');
        await tester.pump(const Duration(seconds: 5));
        expect(controller.text, 'Keep this draft');
        controller.clear();
        await tester.pump(const Duration(seconds: 5));
        expect(find.text('Describe your inventory…'), findsOneWidget);
        expect(focus.hasFocus, isTrue);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        focus.dispose();
        await tester.pump(const Duration(seconds: 5));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
