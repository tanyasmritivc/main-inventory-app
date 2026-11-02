import 'dart:async';
import 'package:flutter/material.dart';
import 'voice_capture.dart';

enum VoiceComposerPhase {
  idle,
  starting,
  listening,
  transcribing,
  counting,
  editing,
}

/// UI/send flow over the existing bounded recorder and Whisper transport.
class VoiceComposerSession extends ChangeNotifier {
  VoiceComposerSession({
    required VoiceRecorder recorder,
    required this.onSend,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    capture = VoiceCapture(
      recorder: recorder,
      onSend: _transcribed,
      onError: _failed,
    )..addListener(_captureChanged);
    capture.soundLevel?.addListener(_levelChanged);
  }
  final void Function(String, Duration) onSend;
  final DateTime Function() _now;
  late final VoiceCapture capture;
  final editor = TextEditingController();
  VoiceComposerPhase phase = VoiceComposerPhase.idle;
  String? errorText;
  String _prefix = '';
  bool _disposed = false, _sendWhenReady = false, _heardSpeech = false;
  DateTime? _started, _lastSpeech, _countdown, _lastSample;
  Timer? _ticker;
  Duration duration = Duration.zero;
  final List<double> levels = [];
  bool get active => phase != VoiceComposerPhase.idle;
  bool get editing => phase == VoiceComposerPhase.editing;
  bool get partial => !capture.finalTranscript && capture.transcript.isNotEmpty;
  bool get canSend =>
      active &&
      phase != VoiceComposerPhase.starting &&
      (capture.active || editor.text.trim().isNotEmpty);
  String get text => editing || phase == VoiceComposerPhase.counting
      ? editor.text
      : _combine(_prefix, capture.transcript);
  double get countdownProgress => _countdown == null
      ? 0
      : (_now().difference(_countdown!).inMilliseconds / 2000).clamp(0, 1);
  String get status => switch (phase) {
    VoiceComposerPhase.starting => 'Starting microphone...',
    VoiceComposerPhase.listening => 'Listening',
    VoiceComposerPhase.transcribing => 'Transcribing...',
    VoiceComposerPhase.counting => 'Sending · tap text to edit',
    VoiceComposerPhase.editing => 'Editing · tap send when ready',
    VoiceComposerPhase.idle => '',
  };
  static String _combine(String a, String b) =>
      [a.trimRight(), b.trim()].where((s) => s.isNotEmpty).join(' ');

  Future<void> start({String draft = ''}) async {
    if (active || _disposed) return;
    _prefix = draft;
    editor.text = draft;
    errorText = null;
    _sendWhenReady = _heardSpeech = false;
    _started = _lastSpeech = _countdown = _lastSample = null;
    duration = Duration.zero;
    levels.clear();
    phase = VoiceComposerPhase.starting;
    notifyListeners();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
    await capture.start();
  }

  void _captureChanged() {
    if (_disposed || !active) return;
    if (capture.ready && phase == VoiceComposerPhase.starting) {
      _started = _now();
      phase = VoiceComposerPhase.listening;
    }
    if (capture.processing && !editing) phase = VoiceComposerPhase.transcribing;
    notifyListeners();
  }

  void _levelChanged() {
    if (_disposed || phase != VoiceComposerPhase.listening) return;
    // The existing meter maps -60..0 dBFS to 0..35. No generated waveform.
    if ((capture.soundLevel?.value ?? 0) >= 6) {
      _heardSpeech = true;
      _lastSpeech = _now();
    }
  }

  void _tick() {
    if (_disposed || !active) return;
    final now = _now();
    if (phase == VoiceComposerPhase.listening && _started != null) {
      duration = now.difference(_started!);
      _levelChanged();
      if (_lastSample == null ||
          now.difference(_lastSample!).inMilliseconds >= 70) {
        levels.add(((capture.soundLevel?.value ?? 0) / 35).clamp(0, 1));
        if (levels.length > 120) levels.removeAt(0);
        _lastSample = now;
      }
      if (!_heardSpeech && duration >= const Duration(seconds: 8)) {
        cancel();
        return;
      }
      if (_heardSpeech &&
          _lastSpeech != null &&
          now.difference(_lastSpeech!) >= const Duration(milliseconds: 1200)) {
        unawaited(capture.release());
      }
    }
    if (phase == VoiceComposerPhase.counting && countdownProgress >= 1) {
      _deliver();
      return;
    }
    notifyListeners();
  }

  void _transcribed(String words) {
    if (_disposed || !active) return;
    if (editing) {
      // Insert the completed recording without overwriting edits made while it
      // was being transcribed. No provisional result is sent automatically.
      final selection = editor.selection;
      final at = selection.isValid ? selection.end : editor.text.length;
      final before = editor.text.substring(0, at);
      final after = editor.text.substring(at);
      final inserted = _combine(before, words);
      editor.value = TextEditingValue(
        text: '$inserted$after',
        selection: TextSelection.collapsed(offset: inserted.length),
      );
    } else {
      editor.text = _combine(_prefix, words);
    }
    if (_sendWhenReady) {
      _deliver();
      return;
    }
    if (!editing) {
      phase = VoiceComposerPhase.counting;
      _countdown = _now();
    }
    notifyListeners();
  }

  void edit() {
    if (!active || editing) return;
    _countdown = null;
    _sendWhenReady = false;
    // With batch-only Whisper there are no partial words to duplicate here.
    editor.text = phase == VoiceComposerPhase.counting ? editor.text : _prefix;
    phase = VoiceComposerPhase.editing;
    editor.selection = TextSelection.collapsed(offset: editor.text.length);
    notifyListeners();
    if (capture.active) unawaited(capture.release());
  }

  void notifyEditorChanged() {
    if (!_disposed) notifyListeners();
  }

  void send() {
    if (!canSend || _disposed) return;
    _countdown = null;
    if (capture.active) {
      _sendWhenReady = true;
      unawaited(capture.release());
    } else {
      _deliver();
    }
  }

  void _deliver() {
    if (_disposed || !active) return;
    final words = editor.text.trim();
    final elapsed = duration;
    cancel();
    if (words.isNotEmpty) onSend(words, elapsed);
  }

  void _failed() {
    if (_disposed || !active) return;
    final failure = capture.failure;
    final preserveEdit =
        editing && editor.text.trim().isNotEmpty && editor.text != _prefix;
    if (preserveEdit) {
      _sendWhenReady = false;
      _countdown = null;
    } else {
      cancel();
    }
    errorText = switch (failure) {
      VoiceFailure.empty => null,
      VoiceFailure.permission =>
        'Microphone access is off. Turn it on in Settings.',
      _ => 'Could not transcribe your message. Please try again.',
    };
    notifyListeners();
  }

  void cancel() {
    _ticker?.cancel();
    _ticker = null;
    _countdown = null;
    phase = VoiceComposerPhase.idle;
    _sendWhenReady = false;
    capture.cancel();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    capture.soundLevel?.removeListener(_levelChanged);
    capture.removeListener(_captureChanged);
    capture.dispose();
    editor.dispose();
    super.dispose();
  }
}

String voiceTime(Duration duration) =>
    '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
