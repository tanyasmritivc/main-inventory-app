import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/chat_question.dart';
import 'package:mobile/features/chat/chat_question_sheet.dart';
import 'package:mobile/features/chat/extraction_progress_panel.dart';
import 'package:mobile/features/chat/activity_label.dart';

void main() {
  const question = ChatQuestion('1', 'Where should these go?', [
    ChatChoice('Workshop', 'Hardware · FTC', 'Use Workshop', 'existing_space'),
    ChatChoice(
      'Robotics spares',
      'New Space',
      'Create Robotics spares',
      'new_space',
    ),
    ChatChoice('Home tools', 'Equipment', 'Use Home tools', 'existing_space'),
    ChatChoice('Decide later', '', 'I will choose later', 'answer'),
  ]);
  test('malformed questions cannot become reply controls', () {
    expect(
      ChatQuestion.parse({'id': '1', 'prompt': 'Choose', 'choices': []}),
      isNull,
    );
    expect(
      ChatQuestion.parse({
        'id': '1',
        'prompt': 'Choose',
        'choices': [
          {'label': 'x'},
          {'label': 'y'},
        ],
      }),
      isNull,
    );
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} choices fit narrow large text and custom reply does not select an option',
      (t) async {
        t.view.physicalSize = const Size(320, 700);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        String? reply;
        await t.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    reply = await showChatQuestion(context, question);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('Open'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.ensureVisible(find.text('Write my own answer'));
        await t.tap(find.text('Write my own answer'));
        await t.pumpAndSettle();
        expect(reply, '');
        expect(find.byType(ChatQuestionSheet), findsNothing);
      },
    );
  }
  testWidgets(
    'scan progress never advances on elapsed time or regresses; reduced motion is static',
    (t) async {
      Future<void> show(String message, {bool reduce = false}) => t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: Scaffold(body: ExtractionProgressPanel(message: message)),
          ),
        ),
      );
      double? progress() => t
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value;
      await show('Finding objects in your photo...');
      expect(progress(), .25);
      expect(find.byType(ScanPlaceholders), findsOneWidget);
      await t.pump(const Duration(seconds: 7));
      expect(progress(), .25);
      expect(find.text('Looking for the little details...'), findsOneWidget);
      await show('Checked 2 of 4 objects...');
      expect(progress(), .625);
      await show('Reading your photo...');
      expect(progress(), .625);
      await show('Preparing your review...', reduce: true);
      expect(progress(), .875);
      await t.pump(const Duration(seconds: 30));
      expect(progress(), .875);
      expect(t.binding.hasScheduledFrame, isFalse);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
