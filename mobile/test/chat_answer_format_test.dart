import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/chat/ask_answer_view.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.6]) {
      testWidgets(
        '${brightness.name} inventory table and bold heading at $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.create(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: AskAnswerView(
                    refined: true,
                    answer:
                        '# Heading one\n\n## Heading two\n\n### Heading three\n\n#### Heading four\n\n##### Heading five\n\n###### Heading six\n\n**Your gears**\n\n| Part | Quantity | Space |\n|---|---:|---|\n| 30T M0.8 gear | 20 | Fastener DB |\n| 6mm D-bore pinion | 10 | Workshop |',
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(Table), findsOneWidget);
          final weights = <String, FontWeight?>{};
          void inspect(InlineSpan span, [FontWeight? inherited]) {
            final weight = span.style?.fontWeight ?? inherited;
            if (span is TextSpan) {
              if (span.text != null) weights[span.text!.trim()] = weight;
              for (final child in span.children ?? <InlineSpan>[]) {
                inspect(child, weight);
              }
            }
          }

          for (final text in tester.widgetList<RichText>(
            find.byType(RichText),
          )) {
            inspect(text.text);
          }
          for (final text in tester.widgetList<SelectableText>(
            find.byType(SelectableText),
          )) {
            if (text.textSpan != null) {
              inspect(text.textSpan!, text.style?.fontWeight);
            }
          }
          for (final label in [
            'Your gears',
            'Heading one',
            'Heading two',
            'Heading three',
            'Heading four',
            'Heading five',
            'Heading six',
          ]) {
            expect(
              weights[label],
              FontWeight.w600,
              reason: '$label must render with semantic emphasis',
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
