import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:mobile/features/chat/voice_capture.dart';

class Recorder implements VoiceRecorder {
  VoiceResult? result;
  VoidCallback? error;
  Completer<bool>? permission;
  Completer<void>? pendingStop;
  String words = 'Where are my screws?';
  int stops = 0, cancels = 0;
  @override
  Future<bool> start(VoiceResult onResult, VoidCallback onError) async {
    result = onResult;
    error = onError;
    return permission == null ? true : permission!.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    await pendingStop?.future;
    result!(words, true);
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

class Audio extends AudioRecorder {
  final stream = StreamController<Uint8List>();
  Completer<bool>? permission;
  int starts = 0, disposals = 0;
  @override
  Future<bool> hasPermission({bool request = true}) async =>
      permission == null ? true : permission!.future;
  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    expect(config.sampleRate, 16000);
    expect(config.numChannels, 1);
    expect(config.encoder, AudioEncoder.pcm16bits);
    starts++;
    return stream.stream;
  }

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream.empty();
  @override
  Future<String?> stop() async {
    await stream.close();
    return null;
  }

  @override
  Future<void> cancel() async {
    unawaited(stream.close());
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

void main() {
  late Recorder recorder;
  late VoiceCapture voice;
  late List<String> drafts;
  int errors = 0;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (_) async => null,
        );
    recorder = Recorder();
    drafts = [];
    errors = 0;
    voice = VoiceCapture(
      recorder: recorder,
      onSend: drafts.add,
      onError: () => errors++,
    );
  });
  tearDown(() => voice.dispose());
  test('Done waits for transcription and returns exactly one draft', () async {
    recorder.pendingStop = Completer<void>();
    await voice.start();
    final finish = voice.release();
    await Future<void>.delayed(Duration.zero);
    expect(voice.processing, true);
    expect(drafts, isEmpty);
    await voice.release();
    recorder.pendingStop!.complete();
    await finish;
    expect(drafts, ['Where are my screws?']);
    expect(recorder.stops, 1);
    expect(voice.active, false);
  });
  test('cancel during upload ignores late transcription', () async {
    recorder.pendingStop = Completer<void>();
    await voice.start();
    final finish = voice.release();
    await Future<void>.delayed(Duration.zero);
    voice.cancel();
    recorder.pendingStop!.complete();
    await finish;
    expect(drafts, isEmpty);
    expect(errors, 0);
  });
  test(
    'denied permission reports failure and permits another attempt',
    () async {
      recorder.permission = Completer<bool>()..complete(false);
      await voice.start();
      expect(voice.active, false);
      expect(errors, 1);
      recorder.permission = null;
      await voice.start();
      await voice.release();
      expect(drafts, hasLength(1));
    },
  );
  test('cancel before permission resolves cannot return a draft', () async {
    recorder.permission = Completer<bool>();
    final start = voice.start();
    voice.cancel();
    recorder.permission!.complete(true);
    await start;
    expect(voice.active, false);
    expect(drafts, isEmpty);
  });
  test('empty and failed recordings return no draft', () async {
    recorder.words = '';
    await voice.start();
    await voice.release();
    expect(drafts, isEmpty);
    expect(errors, 1);
    await voice.start();
    recorder.error!();
    recorder.result!('late', true);
    expect(drafts, isEmpty);
    expect(errors, 2);
  });
  testWidgets('one-minute limit stops capture once', (t) async {
    await voice.start();
    await t.pump(const Duration(seconds: 61));
    expect(recorder.stops, 1);
    expect(drafts, hasLength(1));
  });
  test('native stream produces WAV and disposes microphone', () async {
    final audio = Audio();
    final results = <String>[];
    final device = DeviceVoiceRecorder(
      createRecorder: () => audio,
      transcribe: (wav, token) async {
        expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
        expect(wav.length, 3244);
        expect(ByteData.sublistView(wav).getUint32(24, Endian.little), 16000);
        expect(wav.sublist(44), everyElement(1));
        return 'Find my drill';
      },
    );
    await device.start(
      (words, _) => results.add(words),
      () => fail('Unexpected error'),
    );
    audio.stream.add(Uint8List.fromList(List.filled(3200, 1)));
    await device.stop();
    expect(results, ['Find my drill']);
    expect(audio.disposals, 1);
  });
  test('native cancel prevents microphone after pending permission', () async {
    final audio = Audio()..permission = Completer<bool>();
    final device = DeviceVoiceRecorder(
      createRecorder: () => audio,
      transcribe: (_, _) async => throw StateError('Unexpected upload'),
    );
    final start = device.start((_, _) => fail('Unexpected result'), () {});
    await Future<void>.delayed(Duration.zero);
    final cancel = device.cancel();
    audio.permission!.complete(true);
    await start;
    await cancel;
    expect(audio.starts, 0);
    expect(audio.disposals, 1);
  });
  test('native cancel aborts upload and suppresses response', () async {
    final audio = Audio();
    final pending = Completer<String>();
    bool cancelled = false;
    final device = DeviceVoiceRecorder(
      createRecorder: () => audio,
      transcribe: (_, token) {
        token.whenCancel.then((_) => cancelled = true);
        return pending.future;
      },
    );
    await device.start((_, _) => fail('Unexpected result'), () {});
    audio.stream.add(Uint8List(3200));
    final stop = device.stop();
    await Future<void>.delayed(Duration.zero);
    await device.cancel();
    pending.complete('late');
    await stop;
    expect(cancelled, true);
    expect(audio.disposals, 1);
  });
}
