import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef VoiceResult = void Function(String words, bool finalResult);

abstract interface class VoiceRecorder {
  Future<bool> start(VoiceResult onResult, VoidCallback onError);
  Future<void> stop();
  Future<void> cancel();
}

class DeviceVoiceRecorder implements VoiceRecorder {
  DeviceVoiceRecorder({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();
  final SpeechToText _speech;
  final soundLevel = ValueNotifier<double>(0);
  @override
  Future<bool> start(VoiceResult onResult, VoidCallback onError) async {
    soundLevel.value = 0;
    // initialize caches its first callback. Rebind each recording explicitly.
    _speech.errorListener = (_) => onError();
    if (!await _speech.initialize(onError: _speech.errorListener)) return false;
    await _speech.listen(
      onSoundLevelChange: (value) => soundLevel.value = value,
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 5),
    );
    return true;
  }

  @override
  Future<void> stop() => _speech.stop();
  @override
  Future<void> cancel() => _speech.cancel();
}

/// Release waits for the native final result and delivers a transcript only once.
/// Cancellation invalidates callbacks, including a pending permission request.
class VoiceCapture extends ChangeNotifier {
  VoiceCapture({
    required this.recorder,
    required this.onSend,
    required this.onError,
  });
  final VoiceRecorder recorder;
  final void Function(String) onSend;
  final VoidCallback onError;
  bool active = false;
  bool ready = false;
  bool _autoSend = false;
  ValueListenable<double>? get soundLevel => recorder is DeviceVoiceRecorder
      ? (recorder as DeviceVoiceRecorder).soundLevel
      : null;
  bool _released = false, _disposed = false;
  int _generation = 0;
  String transcript = '';
  Completer<void>? _final;
  Future<bool>? _starting;

  Future<void> start({bool autoSend = false}) async {
    if (active || _disposed) return;
    final generation = ++_generation;
    active = true;
    ready = false;
    _autoSend = autoSend;
    _released = false;
    transcript = '';
    _final = Completer<void>();
    notifyListeners();
    _starting = recorder.start((words, finalResult) {
      if (_disposed || generation != _generation) return;
      transcript = words;
      if (finalResult && !_final!.isCompleted) _final!.complete();
      notifyListeners();
      if (finalResult && _autoSend) unawaited(release());
    }, () => _fail(generation));
    try {
      final available = await _starting!;
      if (_disposed || generation != _generation) {
        await recorder.cancel();
        return;
      }
      if (!available) {
        _fail(generation);
      } else {
        ready = true;
        notifyListeners();
      }
    } catch (_) {
      _fail(generation);
    }
  }

  void _fail(int generation) {
    if (_disposed || generation != _generation) return;
    cancel();
    onError();
  }

  Future<void> release() async {
    if (!active || _released || _disposed) return;
    _released = true;
    final generation = _generation;
    try {
      await _starting;
      if (_disposed || generation != _generation) return;
      await recorder.stop();
      await _final!.future.timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () {},
      );
      if (_disposed || generation != _generation) return;
      final text = transcript.trim();
      active = false;
      _generation++;
      notifyListeners();
      if (text.isNotEmpty) onSend(text);
    } catch (_) {
      _fail(generation);
    }
  }

  void cancel() {
    _generation++;
    active = false;
    ready = false;
    transcript = '';
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
