import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/ui/app_text.dart';

/// Square source coordinates shared by the circular preview and saved bitmap.
Rect profileCropRect(Size image, double zoom, Offset center) {
  final side = math.min(image.width, image.height) / zoom.clamp(1, 6);
  final half = side / 2;
  return Rect.fromCenter(
    center: Offset(
      center.dx.clamp(half, image.width - half),
      center.dy.clamp(half, image.height - half),
    ),
    width: side,
    height: side,
  );
}

Future<Uint8List> renderProfileCrop(ui.Image image, Rect source) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    image,
    source,
    const Rect.fromLTWH(0, 0, 512, 512),
    Paint()..filterQuality = FilterQuality.high,
  );
  final picture = recorder.endRecording();
  final output = await picture.toImage(512, 512);
  try {
    final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Photo could not be prepared');
    return bytes.buffer.asUint8List();
  } finally {
    output.dispose();
    picture.dispose();
  }
}

class ProfilePhotoCropPage extends StatefulWidget {
  const ProfilePhotoCropPage({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<ProfilePhotoCropPage> createState() => _ProfilePhotoCropPageState();
}

class _ProfilePhotoCropPageState extends State<ProfilePhotoCropPage> {
  ui.Image? _image;
  Offset _center = Offset.zero, _anchor = Offset.zero;
  double _zoom = 1, _startZoom = 1;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final codec = await ui.instantiateImageCodec(
        widget.bytes,
        targetWidth: 2048,
        allowUpscaling: false,
      );
      ui.Image image;
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image = image;
        _center = Offset(image.width / 2, image.height / 2);
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'This photo could not be opened. Choose another image.',
        );
      }
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Size get _size => Size(_image!.width.toDouble(), _image!.height.toDouble());
  void _setZoom(double value) => setState(() {
    _zoom = value.clamp(1, 6);
    _center = profileCropRect(_size, _zoom, _center).center;
  });
  Future<void> _save() async {
    if (_saving || _image == null) return;
    setState(() => _saving = true);
    try {
      final bytes = await renderProfileCrop(
        _image!,
        profileCropRect(_size, _zoom, _center),
      );
      if (mounted) Navigator.pop(context, bytes);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'The photo could not be prepared. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('Adjust profile photo')),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(
            360.0,
            math.min(
              constraints.maxWidth - 48,
              math.max(160.0, constraints.maxHeight - 410),
            ),
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const AppText(
                  'Pinch to zoom and drag to position your photo.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_image == null && _error == null)
                  const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_image != null) ...[
                  GestureDetector(
                    key: const ValueKey('profile-crop-preview'),
                    onScaleStart: _saving
                        ? null
                        : (details) {
                            _startZoom = _zoom;
                            final side =
                                math.min(_size.width, _size.height) / _zoom;
                            _anchor =
                                _center +
                                (details.localFocalPoint -
                                        Offset(width / 2, width / 2)) *
                                    (side / width);
                          },
                    onScaleUpdate: _saving
                        ? null
                        : (details) => setState(() {
                            _zoom = (_startZoom * details.scale).clamp(1, 6);
                            final side =
                                math.min(_size.width, _size.height) / _zoom;
                            _center = profileCropRect(
                              _size,
                              _zoom,
                              _anchor -
                                  (details.localFocalPoint -
                                          Offset(width / 2, width / 2)) *
                                      (side / width),
                            ).center;
                          }),
                    child: ClipOval(
                      child: CustomPaint(
                        size: Size.square(width),
                        painter: _ProfileCropPainter(
                          _image!,
                          profileCropRect(_size, _zoom, _center),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Zoom out',
                        onPressed: _saving || _zoom <= 1
                            ? null
                            : () => _setZoom(_zoom - .25),
                        icon: const Icon(Icons.remove),
                      ),
                      Expanded(
                        child: Slider(
                          semanticFormatterCallback: (value) =>
                              '${value.toStringAsFixed(1)} times zoom',
                          min: 1,
                          max: 6,
                          value: _zoom,
                          onChanged: _saving ? null : _setZoom,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Zoom in',
                        onPressed: _saving || _zoom >= 6
                            ? null
                            : () => _setZoom(_zoom + .25),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _zoom = 1;
                            _center = Offset(_size.width / 2, _size.height / 2);
                          }),
                    child: const AppText('Reset'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: AppText(_saving ? 'Preparing...' : 'Use photo'),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: AppText(_error!),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _ProfileCropPainter extends CustomPainter {
  _ProfileCropPainter(this.image, this.source);
  final ui.Image image;
  final Rect source;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
    image,
    source,
    Offset.zero & size,
    Paint()..filterQuality = FilterQuality.high,
  );
  @override
  bool shouldRepaint(_ProfileCropPainter old) =>
      old.image != image || old.source != source;
}
