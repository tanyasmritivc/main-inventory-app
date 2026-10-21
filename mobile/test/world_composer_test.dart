import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/world/world_composer.dart';

void main() {
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
