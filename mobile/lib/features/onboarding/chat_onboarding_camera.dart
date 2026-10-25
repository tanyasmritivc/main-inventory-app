import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class ChatOnboardingCamera extends StatefulWidget {
  const ChatOnboardingCamera({super.key});
  @override
  State<ChatOnboardingCamera> createState() => _ChatOnboardingCameraState();
}

class _ChatOnboardingCameraState extends State<ChatOnboardingCamera>
    with WidgetsBindingObserver {
  CameraController? _camera;
  String? _error;
  bool _taking = false, _flash = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _open() async {
    final generation = ++_generation;
    CameraController? opening;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera');
      final controller = opening = CameraController(
        cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        ),
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _error = null;
      });
    } catch (_) {
      await opening?.dispose();
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'Camera unavailable. Allow camera access in Settings, or go back and type a list.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _generation++;
      final controller = _camera;
      setState(() => _camera = null);
      if (controller != null) unawaited(controller.dispose());
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      unawaited(_open());
    }
  }

  Future<void> _take() async {
    if (_taking || _camera == null) return;
    setState(() => _taking = true);
    try {
      final photo = await _camera!.takePicture();
      if (!mounted) return;
      if (!MediaQuery.disableAnimationsOf(context)) {
        setState(() => _flash = true);
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
      if (mounted) Navigator.pop(context, photo);
    } catch (_) {
      if (mounted) {
        setState(() {
          _taking = false;
          _error = 'Could not take the photo. Try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        if (_camera?.value.isInitialized == true)
          Center(child: CameraPreview(_camera!)),
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _Brackets())),
        ),
        SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Point at a shelf, bin or bench',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Take photo',
                child: GestureDetector(
                  onTap: _taking ? null : _take,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE8590C),
                      border: Border.all(color: Colors.white, width: 5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
        if (_flash) const ColoredBox(color: Colors.white),
      ],
    ),
  );
}

class _Brackets extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      28,
      size.height * .24,
      size.width - 28,
      size.height * .7,
    );
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      final dx = corner.dx == rect.left ? 1.0 : -1.0,
          dy = corner.dy == rect.top ? 1.0 : -1.0;
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx, corner.dy + 34 * dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx + 34 * dx, corner.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Brackets oldDelegate) => false;
}
