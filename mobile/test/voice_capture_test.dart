import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/features/world/world_composer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/voice_capture.dart';

class Recorder implements VoiceRecorder {
  VoiceResult? result;
  VoidCallback? error;
  Completer<bool>? permission;
  int stops = 0;
  @override
  Future<bool> start(VoiceResult onResult, VoidCallback onError) async {
    result = onResult;
    error = onError;
    return permission == null ? true : permission!.future;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  late Recorder recorder;
  late VoiceCapture voice;
  late List<String> sent;
  int errors = 0;
  setUp(() {
    recorder = Recorder();
    sent = [];
    errors = 0;
    voice = VoiceCapture(
      recorder: recorder,
      onSend: sent.add,
      onError: () => errors++,
    );
  });
  tearDown(() => voice.dispose());
  testWidgets('composer hold and release sends without pressing Send', (
    tester,
  ) async {
    final text = TextEditingController();
    final focus = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldComposer(
            controller: text,
            focusNode: focus,
            onChanged: (_) {},
            onAttach: null,
            onVoice: () {},
            onVoiceStart: () => unawaited(voice.start()),
            onVoiceEnd: () => unawaited(voice.release()),
            onVoiceCancel: voice.cancel,
            onSend: null,
            busy: false,
            listening: false,
            compact: false,
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byTooltip('Hold to speak')),
    );
    await tester.pump();
    recorder.result!('Find my drill', false);
    expect(sent, isEmpty);
    await gesture.up();
    await tester.pump();
    recorder.result!('Find my drill please', true);
    await tester.pump();
    expect(sent, ['Find my drill please']);
    expect(text.text, isEmpty);
    await tester.pumpWidget(const SizedBox());
    text.dispose();
    focus.dispose();
  });
  test('release waits for final words and sends exactly once', () async {
    await voice.start();
    recorder.result!('Find my', false);
    final release = voice.release();
    await Future<void>.delayed(Duration.zero);
    expect(sent, isEmpty);
    recorder.result!('Find my drill', true);
    await release;
    await voice.release();
    recorder.result!('late result', true);
    expect(sent, ['Find my drill']);
    expect(recorder.stops, 1);
  });
  test('release while permission is pending still finishes once', () async {
    recorder.permission = Completer<bool>();
    final start = voice.start();
    final release = voice.release();
    recorder.permission!.complete(true);
    await start;
    recorder.result!('Where are my screws?', true);
    await release;
    expect(sent, ['Where are my screws?']);
  });
  test('cancel ignores final results and never sends', () async {
    await voice.start();
    recorder.result!('do not send', false);
    voice.cancel();
    recorder.result!('do not send', true);
    await voice.release();
    expect(sent, isEmpty);
  });
  test('empty recording sends nothing', () async {
    await voice.start();
    recorder.result!('   ', true);
    await voice.release();
    expect(sent, isEmpty);
  });
  test('denied permission restores idle and reports error', () async {
    recorder.permission = Completer<bool>()..complete(false);
    await voice.start();
    await voice.release();
    expect(voice.active, false);
    expect(sent, isEmpty);
    expect(errors, 1);
  });
  test('native error invalidates callbacks', () async {
    await voice.start();
    recorder.error!();
    recorder.result!('stale words', true);
    await voice.release();
    expect(sent, isEmpty);
    expect(errors, 1);
  });
}
