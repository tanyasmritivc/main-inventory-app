import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
                        '**Your gears**\n\n| Part | Quantity | Space |\n|---|---:|---|\n| 30T M0.8 gear | 20 | Fastener DB |\n| 6mm D-bore pinion | 10 | Workshop |',
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(Table), findsOneWidget);
          final markdown = tester.widget<MarkdownBody>(
            find.byType(MarkdownBody),
          );
          expect(markdown.styleSheet!.strong!.fontWeight, FontWeight.w600);
          expect(
            markdown.styleSheet!.strong!.color,
            markdown.styleSheet!.p!.color,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
