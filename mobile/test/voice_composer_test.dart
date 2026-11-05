import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/chat/voice_capture.dart';
import 'package:mobile/features/chat/voice_composer_session.dart';
import 'package:mobile/features/world/world_composer.dart';
import 'voice_capture_test.dart' show Recorder;

Future<void> Function(String, Uint8List)? voiceComposerCapture;

class Meter extends Recorder implements MeteredVoiceRecorder {
  @override
  final ValueNotifier<double> soundLevel = ValueNotifier(0);
}

void main() {
  late Meter recorder;
  late VoiceComposerSession session;
  late List<String> sent;
  Duration captureDelay = Duration.zero;
  DateTime? captureTime;
  void create(WidgetTester t) {
    captureDelay = Duration.zero;
    captureTime = null;
    recorder = Meter();
    sent = [];
    session = VoiceComposerSession(
      recorder: recorder,
      now: () => captureTime ?? t.binding.clock.now().subtract(captureDelay),
      onSend: (words, duration) => sent.add(words),
    );
    addTearDown(session.dispose);
  }

  Future<void> pause(WidgetTester t) async {
    recorder.soundLevel.value = 20;
    await t.pump(const Duration(milliseconds: 500));
    recorder.soundLevel.value = 0;
    await t.pump(const Duration(milliseconds: 1200));
    await t.pump();
  }

  testWidgets(
    'silence transcribes then gives two full seconds before sending once',
    (t) async {
      create(t);
      await session.start();
      recorder.pendingStop = Completer<void>();
      await pause(t);
      expect(session.phase, VoiceComposerPhase.transcribing);
      await t.pump(const Duration(seconds: 4));
      expect(sent, isEmpty);
      recorder.pendingStop!.complete();
      await t.pump();
      expect(session.phase, VoiceComposerPhase.counting);
      await t.pump(const Duration(milliseconds: 1950));
      expect(sent, isEmpty);
      await t.pump(const Duration(milliseconds: 50));
      expect(sent, ['Where are my screws?']);
      await t.pump(const Duration(seconds: 3));
      expect(sent.length, 1);
      expect(session.duration.inMilliseconds, 1700);
    },
  );
  testWidgets('steady meter level does not prematurely stop speech', (t) async {
    create(t);
    await session.start();
    recorder.soundLevel.value = 20;
    await t.pump(const Duration(seconds: 4));
    expect(session.phase, VoiceComposerPhase.listening);
    expect(recorder.stops, 0);
    session.cancel();
  });
  testWidgets('early send waits for transcription and bypasses countdown', (
    t,
  ) async {
    create(t);
    await session.start();
    recorder.pendingStop = Completer<void>();
    session.send();
    session.send();
    await t.pump();
    expect(sent, isEmpty);
    recorder.pendingStop!.complete();
    await t.pump();
    expect(sent, ['Where are my screws?']);
    expect(recorder.stops, 1);
  });
  testWidgets('editing countdown requires explicit send', (t) async {
    create(t);
    await session.start(draft: 'Please help.');
    await pause(t);
    session.edit();
    session.editor.text = 'Edited question';
    await t.pump(const Duration(seconds: 4));
    expect(sent, isEmpty);
    session.send();
    expect(sent, ['Edited question']);
  });
  testWidgets(
    'editing during upload preserves typing and waits for explicit send',
    (t) async {
      create(t);
      await session.start();
      recorder.pendingStop = Completer<void>();
      session.edit();
      session.editor.text = 'Please help.';
      recorder.pendingStop!.complete();
      await t.pump();
      expect(session.editor.text, 'Please help. Where are my screws?');
      await t.pump(const Duration(seconds: 4));
      expect(sent, isEmpty);
      session.send();
      expect(sent, ['Please help. Where are my screws?']);
    },
  );
  testWidgets('cancel upload and countdown ignore late results', (t) async {
    create(t);
    await session.start();
    recorder.pendingStop = Completer<void>();
    session.send();
    session.cancel();
    recorder.pendingStop!.complete();
    await t.pump(const Duration(seconds: 3));
    expect(sent, isEmpty);
    recorder.pendingStop = null;
    await session.start();
    await pause(t);
    session.cancel();
    await t.pump(const Duration(seconds: 3));
    expect(sent, isEmpty);
  });
  testWidgets('cancel pending permission never starts a composer again', (
    t,
  ) async {
    create(t);
    recorder.permission = Completer<bool>();
    final start = session.start();
    session.cancel();
    recorder.permission!.complete(true);
    await start;
    expect(session.active, false);
    expect(sent, isEmpty);
  });
  testWidgets(
    'silent recording and empty transcript return idle without sending',
    (t) async {
      create(t);
      await session.start(draft: 'Keep this');
      await t.pump(const Duration(seconds: 8));
      expect(session.active, false);
      expect(recorder.stops, 0);
      expect(sent, isEmpty);
      await session.start(draft: 'Keep this');
      recorder.words = '';
      session.send();
      await t.pump();
      expect(session.active, false);
      expect(sent, isEmpty);
      expect(session.errorText, isNull);
    },
  );
  testWidgets('permission denial is actionable inline feedback', (t) async {
    create(t);
    recorder.permission = Completer<bool>()..complete(false);
    await session.start();
    expect(session.active, false);
    expect(
      session.errorText,
      'Microphone access is off. Turn it on in Settings.',
    );
    expect(sent, isEmpty);
  });
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.6]) {
      testWidgets(
        'inline composer ${brightness.name} scale$scale listening editing and cancel',
        (t) async {
          create(t);
          t.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final draft = TextEditingController();
          final focus = FocusNode();
          await t.pumpWidget(
            RepaintBoundary(
              key: const Key('voice-frame'),
              child: MaterialApp(
                theme: AppTheme.create(brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    // Native keyboard insets are physical pixels after the
                    // test changes devicePixelRatio. Model a 300pt keyboard.
                    viewInsets: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom > 0
                          ? 300
                          : 0,
                    ),
                    padding: EdgeInsets.zero,
                    viewPadding: EdgeInsets.zero,
                    disableAnimations: scale > 1,
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: WorldComposer(
                        controller: draft,
                        focusNode: focus,
                        onChanged: (_) {},
                        onAttach: () {},
                        onVoice: () => session.start(),
                        onSend: () {},
                        busy: false,
                        listening: false,
                        compact: false,
                        voiceSession: session,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await session.start();
          recorder.soundLevel.value = 20;
          await t.pump();
          await t.pump(const Duration(milliseconds: 650));
          expect(find.text('Listening'), findsOneWidget);
          expect(t.takeException(), isNull);
          Future<void> capture(String state) async {
            if (voiceComposerCapture == null) return;
            // PNG encoding/file I/O is not time spent by the user. Keep the
            // injected session clock still while native visual evidence saves.
            final started = t.binding.clock.now();
            captureTime = started.subtract(captureDelay);
            try {
              final boundary = t.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('voice-frame')),
              );
              final image = await boundary.toImage(pixelRatio: 2);
              try {
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await voiceComposerCapture!(
                  '$state-${brightness.name}-$scale',
                  data!.buffer.asUint8List(),
                );
              } finally {
                image.dispose();
              }
            } finally {
              captureDelay += t.binding.clock.now().difference(started);
              captureTime = null;
            }
          }

          await capture('listening');
          await pause(t);
          await t.pump(const Duration(milliseconds: 450));
          expect(find.text('Sending · tap text to edit'), findsOneWidget);
          await capture('countdown');
          await t.tap(find.byKey(const Key('voice-transcript')));
          await t.pump();
          await t.pump(const Duration(milliseconds: 600));
          expect(find.byKey(const Key('voice-editor')), findsOneWidget);
          final input = t.widget<EditableText>(find.byType(EditableText));
          expect(input.style.fontSize, 16);
          expect(input.style.fontFamily, 'CupertinoSystemText');
          expect(
            t.getSize(find.byKey(const Key('voice-editor'))).height,
            greaterThanOrEqualTo(19 * 1.38 * scale),
          );
          await t.enterText(
            find.byKey(const Key('voice-editor')),
            'Where is the camping lantern?',
          );
          await t.pump(const Duration(seconds: 3));
          expect(sent, isEmpty);
          expect(t.takeException(), isNull);
          await capture('editing');
          await t.tap(find.byTooltip('Cancel voice message'));
          await t.pump(const Duration(milliseconds: 650));
          expect(session.active, false);
          expect(sent, isEmpty);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          draft.dispose();
          focus.dispose();
        },
      );
    }
  }
}
