import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../../core/ui/photo_scan_hint.dart';
import 'extraction_progress_panel.dart' show scanProgressValue;
import 'scan_region.dart';

@visibleForTesting
bool? debugNativeScanProgressOverride;
bool get usesNativeScanProgress =>
    debugNativeScanProgressOverride ?? (!kIsWeb && Platform.isIOS);

/// Presentation only. The owning chat/Space retains its request, cancellation,
/// progress events and eventual draft. UIKit receives no API client or URL.
class NativeScanProgress extends StatefulWidget {
  const NativeScanProgress({
    super.key,
    required this.image,
    required this.message,
    required this.onStop,
    this.regions = const [],
  });
  final ImageProvider image;
  final String message;
  final List<ScanRegion> regions;
  final VoidCallback onStop;
  @override
  State<NativeScanProgress> createState() => _NativeScanProgressState();
}

class _NativeScanProgressState extends State<NativeScanProgress> {
  MethodChannel? _channel;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Uint8List? _photo;
  int _imageGeneration = 0;
  bool _stopped = false;
  final _steps = <String>[];
  double _progress = 0;

  void _record() {
    final text = widget.message.trim();
    if (text.isNotEmpty && (_steps.isEmpty || _steps.last != text)) {
      _steps.add(text);
      if (_steps.length > 30) _steps.removeAt(0);
    }
    _progress = math.max(
      _progress,
      scanProgressValue(widget.message, widget.regions),
    );
  }

  Map<String, Object> get _model => {
    'message': widget.message,
    'steps': List<String>.of(_steps),
    'progress': _progress,
    'timing': photoScanTiming,
    'tips': scanTips,
    'footer': 'Nothing is saved until you review and approve.',
    'dark': Theme.of(context).brightness == Brightness.dark,
    'textScale': MediaQuery.textScalerOf(context).scale(16) / 16,
    'reduceMotion': MediaQuery.disableAnimationsOf(context),
    'regions': [
      for (final r in widget.regions)
        {
          'id': r.id,
          'box': [r.box.left, r.box.top, r.box.right, r.box.bottom],
          'phase': r.phase.name,
          'status': r.status,
        },
    ],
  };

  Future<void> _configure() async {
    await _channel?.invokeMethod<void>('configure', _model);
  }

  @override
  void initState() {
    super.initState();
    _record();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolvePhoto();
    unawaited(_configure());
  }

  @override
  void didUpdateWidget(NativeScanProgress old) {
    super.didUpdateWidget(old);
    _record();
    if (old.image != widget.image) _resolvePhoto();
    unawaited(_configure());
  }

  void _resolvePhoto() {
    final next = widget.image.resolve(createLocalImageConfiguration(context));
    if (next.key == _stream?.key) return;
    if (_listener != null) _stream?.removeListener(_listener!);
    final generation = ++_imageGeneration;
    _photo = null;
    _stream = next;
    _listener = ImageStreamListener(
      (info, _) {
        unawaited(_encodePhoto(info, generation));
      },
      onError: (Object error, StackTrace? stack) {
        // The native image placeholder remains; a display failure cannot abort a scan.
      },
    );
    next.addListener(_listener!);
  }

  Future<void> _encodePhoto(ImageInfo info, int generation) async {
    ui.Image? preview;
    ui.Picture? picture;
    try {
      // A bounded display copy only; the original upload and crops are untouched.
      final scale = math.min(
        1.0,
        1400 / math.max(info.image.width, info.image.height),
      );
      final width = math.max(1, (info.image.width * scale).round());
      final height = math.max(1, (info.image.height * scale).round());
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        info.image,
        Rect.fromLTWH(
          0,
          0,
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ),
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint(),
      );
      picture = recorder.endRecording();
      preview = await picture.toImage(width, height);
      final data = await preview.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted || generation != _imageGeneration || data == null) return;
      _photo = data.buffer.asUint8List();
      await _channel?.invokeMethod<void>('photo', _photo);
    } catch (_) {
      // Keep the scan running if its display copy cannot be decoded.
    } finally {
      preview?.dispose();
      picture?.dispose();
      info.dispose();
    }
  }

  @override
  void dispose() {
    _imageGeneration++;
    if (_listener != null) _stream?.removeListener(_listener!);
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UiKitView(
    key: const Key('native-scan-progress'),
    viewType: 'com.findez.app/scan-progress',
    gestureRecognizers: {
      Factory<VerticalDragGestureRecognizer>(
        () => VerticalDragGestureRecognizer(),
      ),
    },
    creationParamsCodec: const StandardMessageCodec(),
    creationParams: _model,
    onPlatformViewCreated: (id) {
      if (!mounted) return;
      _channel = MethodChannel('com.findez.app/scan-progress/$id');
      _channel!.setMethodCallHandler((call) async {
        if (mounted && call.method == 'stop' && !_stopped) {
          _stopped = true;
          widget.onStop();
        }
      });
      unawaited(_configure());
      if (_photo != null) {
        unawaited(_channel!.invokeMethod<void>('photo', _photo));
      }
    },
  );
}
