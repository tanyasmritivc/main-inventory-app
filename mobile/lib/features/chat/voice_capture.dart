import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

typedef VoiceResult = void Function(String words, bool finalResult);
typedef TranscribeVoice =
    Future<String> Function(Uint8List wav, CancelToken cancel);

abstract interface class VoiceRecorder {
  Future<bool> start(VoiceResult onResult, VoidCallback onError);
  Future<void> stop();
  Future<void> cancel();
}

/// Microphone audio stays in bounded memory until sent for transcription.
abstract interface class MeteredVoiceRecorder implements VoiceRecorder {
  ValueListenable<double> get soundLevel;
}

enum VoiceFailure { permission, empty, recording, transcription }

class DeviceVoiceRecorder implements MeteredVoiceRecorder {
  DeviceVoiceRecorder({
    required this.transcribe,
    AudioRecorder Function()? createRecorder,
  }) : _createRecorder = createRecorder ?? AudioRecorder.new;
  final TranscribeVoice transcribe;
  final AudioRecorder Function() _createRecorder;
  @override
  final ValueNotifier<double> soundLevel = ValueNotifier<double>(0);
  bool _permissionRequested = false;
  _Recording? _session;
  int _generation = 0;

  @override
  Future<bool> start(VoiceResult onResult, VoidCallback onError) async {
    final generation = ++_generation;
    final previous = _session;
    _session = null;
    await _cancelSession(previous);
    if (generation != _generation) return false;
    final session = _Recording(_createRecorder(), onResult, onError);
    _session = session;
    soundLevel.value = 0;
    session.starting = _start(session);
    return session.starting!;
  }

  Future<bool> _start(_Recording s) async {
    final permitted = await s.recorder.hasPermission(
      request: !_permissionRequested,
    );
    _permissionRequested = true;
    if (!permitted || s.cancelled) return false;
    final stream = await s.recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    if (s.cancelled) return false;
    s.audio = stream.listen(
      (chunk) {
        if (s.cancelled) return;
        if (s.bytes.length + chunk.length > 2080000) {
          s.onError();
          return;
        }
        s.bytes.add(chunk);
      },
      onDone: () {
        if (!s.done.isCompleted) s.done.complete();
      },
      onError: (Object _) {
        if (!s.cancelled) s.onError();
      },
    );
    s.levels = s.recorder
        .onAmplitudeChanged(const Duration(milliseconds: 150))
        .listen(
          (a) {
            if (!s.cancelled && identical(_session, s)) {
              soundLevel.value = ((a.current + 60) / 60 * 35).clamp(0, 35);
            }
          },
          onError: (Object _) {
            if (!s.cancelled) s.onError();
          },
        );
    return true;
  }

  @override
  Future<void> stop() async {
    final s = _session;
    if (s == null || s.cancelled || s.stopping) return;
    s.stopping = true;
    try {
      if (!await s.starting! || s.cancelled) return;
      await s.recorder.stop();
      await s.done.future.timeout(const Duration(seconds: 3));
      await s.levels?.cancel();
      if (s.cancelled) return;
      final pcm = s.bytes.takeBytes();
      if (pcm.length < 3200) {
        s.onResult('', true);
        return;
      }
      final text = await transcribe(pcmToWav(pcm), s.token);
      if (!s.cancelled) s.onResult(text, true);
    } finally {
      await s.close();
      if (identical(_session, s)) _session = null;
    }
  }

  @override
  Future<void> cancel() async {
    _generation++;
    final s = _session;
    _session = null;
    await _cancelSession(s);
  }

  Future<void> _cancelSession(_Recording? s) async {
    if (s == null) return;
    s.cancelled = true;
    s.token.cancel();
    try {
      await s.starting;
    } catch (_) {
      /* Cleanup follows failed startup. */
    }
    await s.close();
  }
}

class _Recording {
  _Recording(this.recorder, this.onResult, this.onError);
  final AudioRecorder recorder;
  final VoiceResult onResult;
  final VoidCallback onError;
  final bytes = BytesBuilder(copy: false);
  final token = CancelToken();
  final done = Completer<void>();
  StreamSubscription<Uint8List>? audio;
  StreamSubscription<Amplitude>? levels;
  Future<bool>? starting;
  Future<void>? _closing;
  bool cancelled = false, stopping = false;
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    try {
      await recorder.cancel();
    } finally {
      await audio?.cancel();
      await levels?.cancel();
      bytes.clear();
      await recorder.dispose();
      if (!done.isCompleted) done.complete();
    }
  }
}

Uint8List pcmToWav(Uint8List pcm) {
  final result = Uint8List(44 + pcm.length);
  final header = ByteData.sublistView(result);
  result.setAll(0, 'RIFF'.codeUnits);
  header.setUint32(4, 36 + pcm.length, Endian.little);
  result.setAll(8, 'WAVEfmt '.codeUnits);
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, 16000, Endian.little);
  header.setUint32(28, 32000, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  result.setAll(36, 'data'.codeUnits);
  header.setUint32(40, pcm.length, Endian.little);
  result.setAll(44, pcm);
  return result;
}

/// Delivers a draft once. Cancel invalidates permission and transcription results.
class VoiceCapture extends ChangeNotifier {
  VoiceCapture({
    required this.recorder,
    required this.onSend,
    required this.onError,
  });
  final VoiceRecorder recorder;
  // Kept as a callback name for callers; this returns text, never sends chat.
  final void Function(String) onSend;
  final VoidCallback onError;
  bool active = false, ready = false, processing = false;
  bool _disposed = false;
  int _generation = 0;
  String transcript = '';
  VoiceFailure? failure;
  bool finalTranscript = false;
  Timer? _limit;
  Future<bool>? _starting;
  ValueListenable<double>? get soundLevel => recorder is MeteredVoiceRecorder
      ? (recorder as MeteredVoiceRecorder).soundLevel
      : null;

  Future<void> start() async {
    if (active || _disposed) return;
    final generation = ++_generation;
    active = true;
    ready = processing = false;
    transcript = '';
    failure = null;
    finalTranscript = false;
    notifyListeners();
    _starting = recorder.start((words, finalResult) {
      if (_disposed || generation != _generation) return;
      transcript = words;
      finalTranscript = finalResult;
      notifyListeners();
    }, () => _fail(generation));
    try {
      final available = await _starting!;
      if (_disposed || generation != _generation) return;
      if (!available) {
        _fail(generation, VoiceFailure.permission);
        return;
      }
      ready = true;
      if (!processing) {
        _limit = Timer(const Duration(seconds: 60), () => unawaited(release()));
      }
      notifyListeners();
    } catch (_) {
      _fail(generation);
    }
  }

  void _fail(int generation, [VoiceFailure? reason]) {
    if (_disposed || generation != _generation) return;
    failure =
        reason ??
        (processing ? VoiceFailure.transcription : VoiceFailure.recording);
    cancel();
    onError();
  }

  Future<void> release() async {
    if (!active || processing || _disposed) return;
    processing = true;
    ready = false;
    _limit?.cancel();
    final generation = _generation;
    notifyListeners();
    try {
      await _starting;
      if (_disposed || generation != _generation) return;
      ready = false;
      await recorder.stop();
      if (_disposed || generation != _generation) return;
      final text = transcript.trim();
      active = processing = false;
      _generation++;
      notifyListeners();
      if (text.isNotEmpty) {
        onSend(text);
      } else {
        failure = VoiceFailure.empty;
        onError();
      }
    } catch (_) {
      _fail(generation);
    }
  }

  void cancel() {
    _generation++;
    _limit?.cancel();
    active = ready = processing = false;
    transcript = '';
    // A failed platform cleanup cannot resurrect a canceled recording.
    unawaited(recorder.cancel().catchError((Object _) {}));
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}
