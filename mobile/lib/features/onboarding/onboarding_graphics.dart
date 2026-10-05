import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

// Code-native illustrations stay crisp at every size and in both themes.
// No photographs, user data, remote assets or permission prompts are involved.
class PhysicalMemoryGraphic extends StatelessWidget {
  const PhysicalMemoryGraphic({super.key, required this.object});
  final int object;
  @override
  Widget build(BuildContext context) => _Graphic(
    label:
        'Illustration: ${['a drill', 'a cable', 'batteries'][object]} connected to a photo, location and notes.',
    scene: _Scene.memory,
    object: object,
  );
}

class CaptureGraphic extends StatelessWidget {
  const CaptureGraphic({
    super.key,
    required this.captured,
    required this.duration,
  });
  final bool captured;
  final Duration duration;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: captured ? 1 : 0),
    duration: duration,
    curve: Curves.easeOutCubic,
    builder: (_, value, _) => _Graphic(
      label: captured
          ? 'Sample illustration: a drill highlighted for review.'
          : 'Sample illustration: a drill and boxes on a shelf, inside a photo frame.',
      scene: _Scene.capture,
      progress: value,
    ),
  );
}

class LocationGraphic extends StatelessWidget {
  const LocationGraphic({super.key, required this.isCable});
  final bool isCable;
  @override
  Widget build(BuildContext context) => _Graphic(
    label:
        'Illustration: ${isCable ? 'a cable' : 'a drill'} with a saved location pin.',
    scene: _Scene.location,
    object: isCable ? 1 : 0,
  );
}

class ConnectedWorldGraphic extends StatelessWidget {
  const ConnectedWorldGraphic({
    super.key,
    required this.shared,
    required this.duration,
  });
  final bool shared;
  final Duration duration;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: duration,
    child: _Graphic(
      key: ValueKey(shared),
      label: shared
          ? 'Illustration: items, photos and project notes connected to a shared Space.'
          : 'Illustration: items, photos and project notes connected to a personal Space.',
      scene: _Scene.world,
      shared: shared,
    ),
  );
}

enum _Scene { memory, capture, location, world }

class _Graphic extends StatelessWidget {
  const _Graphic({
    super.key,
    required this.label,
    required this.scene,
    this.object = 0,
    this.progress = 0,
    this.shared = false,
  });
  final String label;
  final _Scene scene;
  final int object;
  final double progress;
  final bool shared;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 320 / 190,
        child: CustomPaint(
          painter: _MemoryPainter(
            scene: scene,
            object: object,
            progress: progress,
            shared: shared,
            ink: AppTheme.textPrimary(context),
            soft: AppTheme.textSecondary(context),
            line: AppTheme.border(context),
            fill: AppTheme.surface2(context),
            ground: AppTheme.surface(context),
          ),
        ),
      ),
    ),
  );
}

class _MemoryPainter extends CustomPainter {
  _MemoryPainter({
    required this.scene,
    required this.object,
    required this.progress,
    required this.shared,
    required this.ink,
    required this.soft,
    required this.line,
    required this.fill,
    required this.ground,
  });
  final _Scene scene;
  final int object;
  final double progress;
  final bool shared;
  final Color ink, soft, line, fill, ground;

  Paint _stroke([Color? color, double width = 2]) => Paint()
    ..color = color ?? ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _box(Canvas canvas, Rect rect, {double radius = 10, Color? color}) {
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(shape, Paint()..color = color ?? fill);
    canvas.drawRRect(shape, _stroke(line, 1.5));
  }

  void _drill(Canvas canvas, Offset offset, double scale) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    // Distinct body, chuck, angled handle, trigger and battery pack.
    final handle = Path()
      ..moveTo(39, 32)
      ..lineTo(67, 32)
      ..lineTo(60, 92)
      ..lineTo(28, 92)
      ..close();
    canvas.drawPath(handle, Paint()..color = soft);
    canvas.drawPath(handle, _stroke(ink, 1.7));
    _box(canvas, const Rect.fromLTWH(8, 7, 93, 39), radius: 18, color: soft);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(88, 12, 31, 30),
        const Radius.circular(10),
      ),
      Paint()..color = ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(116, 20, 20, 14),
        const Radius.circular(4),
      ),
      Paint()..color = soft,
    );
    canvas.drawLine(
      const Offset(137, 27),
      const Offset(151, 27),
      _stroke(ink, 5),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 88, 55, 19),
        const Radius.circular(6),
      ),
      Paint()..color = ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, 47, 8, 16),
        const Radius.circular(3),
      ),
      Paint()..color = ink,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(22 + i * 8, 18),
        Offset(22 + i * 8, 29),
        _stroke(ground, 2),
      );
    }
    canvas.restore();
  }

  void _cable(Canvas canvas, Offset offset, double scale) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    final wire = Path()
      ..moveTo(18, 14)
      ..cubicTo(7, 27, 17, 82, 61, 88)
      ..cubicTo(122, 101, 147, 51, 114, 31)
      ..cubicTo(72, 2, 25, 45, 55, 67)
      ..cubicTo(88, 91, 134, 65, 138, 93);
    canvas.drawPath(wire, _stroke(ink, 6));
    _box(canvas, const Rect.fromLTWH(5, 0, 23, 24), radius: 5, color: soft);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, -9, 13, 11),
        const Radius.circular(3),
      ),
      Paint()..color = ink,
    );
    _box(canvas, const Rect.fromLTWH(126, 91, 23, 23), radius: 5, color: soft);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(131, 112, 13, 11),
        const Radius.circular(3),
      ),
      Paint()..color = ink,
    );
    canvas.restore();
  }

  void _batteries(Canvas canvas, Offset offset, double scale) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    for (var i = 0; i < 3; i++) {
      final x = i * 42.0;
      final y = i == 1 ? 0.0 : 12.0;
      _box(
        canvas,
        Rect.fromLTWH(x, y + 8, 29, 85),
        radius: 7,
        color: i == 1 ? soft : fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 9, y + 2, 11, 8),
          const Radius.circular(2),
        ),
        Paint()..color = ink,
      );
      canvas.drawLine(
        Offset(x + 10, y + 27),
        Offset(x + 19, y + 27),
        _stroke(ink),
      );
      canvas.drawLine(
        Offset(x + 14.5, y + 22.5),
        Offset(x + 14.5, y + 31.5),
        _stroke(ink),
      );
      canvas.drawLine(
        Offset(x + 9, y + 65),
        Offset(x + 20, y + 65),
        _stroke(ink),
      );
    }
    canvas.restore();
  }

  void _item(Canvas canvas, Offset point, double scale) => switch (object) {
    1 => _cable(canvas, point, scale),
    2 => _batteries(canvas, point, scale),
    _ => _drill(canvas, point, scale),
  };

  void _node(Canvas canvas, Offset center, int kind, {double size = 44}) {
    _box(
      canvas,
      Rect.fromCenter(center: center, width: size, height: size),
      radius: 12,
    );
    canvas.save();
    canvas.translate(center.dx - 12, center.dy - 12);
    final pen = _stroke(soft, 1.8);
    switch (kind) {
      case 0: // Photograph.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(1, 2, 22, 20),
            const Radius.circular(3),
          ),
          pen,
        );
        canvas.drawCircle(const Offset(8, 8), 2, pen);
        canvas.drawPath(
          Path()
            ..moveTo(3, 18)
            ..lineTo(9, 12)
            ..lineTo(13, 16)
            ..lineTo(17, 11)
            ..lineTo(21, 18),
          pen,
        );
      case 1: // Location.
        canvas.drawPath(
          Path()
            ..moveTo(12, 23)
            ..quadraticBezierTo(-3, 7, 6, 3)
            ..quadraticBezierTo(12, -1, 18, 3)
            ..quadraticBezierTo(27, 7, 12, 23)
            ..close(),
          pen,
        );
        canvas.drawCircle(const Offset(12, 8), 3, pen);
      case 2: // Note.
        canvas.drawPath(
          Path()
            ..moveTo(5, 1)
            ..lineTo(16, 1)
            ..lineTo(21, 6)
            ..lineTo(21, 23)
            ..lineTo(5, 23)
            ..close(),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(15, 1)
            ..lineTo(15, 7)
            ..lineTo(21, 7),
          pen,
        );
        canvas.drawLine(const Offset(9, 12), const Offset(17, 12), pen);
        canvas.drawLine(const Offset(9, 17), const Offset(17, 17), pen);
      case 3: // Project checklist.
        for (var i = 0; i < 3; i++) {
          final y = 4 + i * 8.0;
          canvas.drawPath(
            Path()
              ..moveTo(2, y)
              ..lineTo(4, y + 2)
              ..lineTo(7, y - 2),
            pen,
          );
          canvas.drawLine(Offset(11, y), Offset(22, y), pen);
        }
      default: // Person.
        canvas.drawCircle(const Offset(12, 6), 4, pen);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 14, 16, 9),
            const Radius.circular(5),
          ),
          pen,
        );
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 320, size.height / 190);
    switch (scene) {
      case _Scene.memory:
        for (final point in [
          const Offset(35, 32),
          const Offset(283, 32),
          const Offset(40, 157),
          const Offset(278, 157),
        ]) {
          canvas.drawPath(
            Path()
              ..moveTo(160, 94)
              ..quadraticBezierTo(point.dx, 94, point.dx, point.dy),
            _stroke(line, 1.6),
          );
        }
        canvas.drawOval(
          const Rect.fromLTWH(82, 149, 153, 13),
          Paint()..color = line.withValues(alpha: .55),
        );
        _item(canvas, const Offset(91, 44), .94);
        _node(canvas, const Offset(35, 32), 0);
        _node(canvas, const Offset(283, 32), 1);
        _node(canvas, const Offset(40, 157), 2);
        _node(canvas, const Offset(278, 157), 3);
      case _Scene.capture:
        _box(
          canvas,
          const Rect.fromLTWH(1, 1, 318, 188),
          radius: 18,
          color: ground,
        );
        _box(canvas, const Rect.fromLTWH(22, 33, 78, 113), radius: 5);
        _box(canvas, const Rect.fromLTWH(203, 63, 89, 84), radius: 5);
        canvas.drawLine(
          const Offset(60, 33),
          const Offset(60, 75),
          _stroke(line),
        );
        canvas.drawLine(
          const Offset(245, 63),
          const Offset(245, 95),
          _stroke(line),
        );
        _box(
          canvas,
          const Rect.fromLTWH(26, 155, 268, 11),
          radius: 3,
          color: soft,
        );
        _drill(canvas, const Offset(82, 58), .92);
        final pen = _stroke(ink, 2);
        for (final entry in [
          (const Offset(75, 33), 1.0, 1.0),
          (const Offset(245, 33), -1.0, 1.0),
          (const Offset(75, 161), 1.0, -1.0),
          (const Offset(245, 161), -1.0, -1.0),
        ]) {
          canvas.drawPath(
            Path()
              ..moveTo(entry.$1.dx, entry.$1.dy + 16 * entry.$3)
              ..lineTo(entry.$1.dx, entry.$1.dy)
              ..lineTo(entry.$1.dx + 16 * entry.$2, entry.$1.dy),
            pen,
          );
        }
        if (progress > 0 && progress < 1) {
          canvas.drawLine(
            Offset(77, 35 + progress * 120),
            Offset(243, 35 + progress * 120),
            _stroke(ink.withValues(alpha: .5)),
          );
        }
        if (progress >= .99) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(79, 49, 145, 105),
              const Radius.circular(11),
            ),
            _stroke(ink, 1.5),
          );
          canvas.drawCircle(const Offset(224, 49), 10, Paint()..color = ink);
          canvas.drawPath(
            Path()
              ..moveTo(219, 49)
              ..lineTo(223, 53)
              ..lineTo(230, 45),
            _stroke(ground, 2),
          );
        }
      case _Scene.location:
        canvas.drawOval(
          const Rect.fromLTWH(41, 145, 224, 15),
          Paint()..color = line.withValues(alpha: .55),
        );
        _item(canvas, const Offset(60, 36), 1.04);
        canvas.drawPath(
          Path()
            ..moveTo(202, 98)
            ..quadraticBezierTo(252, 114, 265, 70),
          _stroke(line, 1.7),
        );
        _node(canvas, const Offset(271, 42), 1, size: 58);
      case _Scene.world:
        final points = [
          const Offset(42, 41),
          const Offset(279, 41),
          const Offset(44, 150),
          const Offset(277, 150),
        ];
        for (final point in points) {
          canvas.drawLine(const Offset(160, 95), point, _stroke(line, 1.7));
        }
        _box(canvas, const Rect.fromLTWH(109, 50, 102, 90), radius: 20);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(130, 71, 60, 13),
            const Radius.circular(3),
          ),
          _stroke(ink, 2.2),
        );
        canvas.drawPath(
          Path()
            ..moveTo(136, 84)
            ..lineTo(136, 118)
            ..lineTo(184, 118)
            ..lineTo(184, 84),
          _stroke(ink, 2.2),
        );
        canvas.drawLine(
          const Offset(154, 96),
          const Offset(166, 96),
          _stroke(ink, 2.2),
        );
        _node(canvas, points[0], 0);
        _node(canvas, points[1], 2);
        _node(canvas, points[2], 3);
        _node(canvas, points[3], shared ? 4 : 1);
        if (shared) _node(canvas, const Offset(291, 166), 4, size: 31);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MemoryPainter oldDelegate) =>
      scene != oldDelegate.scene ||
      object != oldDelegate.object ||
      progress != oldDelegate.progress ||
      shared != oldDelegate.shared ||
      ink != oldDelegate.ink ||
      soft != oldDelegate.soft ||
      line != oldDelegate.line ||
      fill != oldDelegate.fill ||
      ground != oldDelegate.ground;
}
