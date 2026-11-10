import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Stationary, opaque page canvas. Soft color stays behind content and never
/// animates with chat tokens, scrolling, or scan progress.
class AppCanvas extends StatelessWidget {
  const AppCanvas({super.key, required this.child, this.ambient = true});
  final Widget child;
  final bool ambient;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _CanvasPainter(
      Theme.of(context).brightness == Brightness.dark,
      !ambient || MediaQuery.highContrastOf(context),
    ),
    child: child,
  );
}

class _CanvasPainter extends CustomPainter {
  const _CanvasPainter(this.dark, this.highContrast);
  final bool dark, highContrast;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = dark ? Colors.black : Colors.white);
    if (highContrast) return;
    final span = math.min(size.height, size.width * 1.8);
    void glow(double x, double y, double radius, Color color) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(size.width * x, span * y),
            size.width * radius,
            [color, color.withValues(alpha: 0)],
            [0, 1],
          ),
      );
    }

    glow(
      .95,
      .02,
      .95,
      dark ? const Color(0x52694638) : const Color(0x70EADBD3),
    );
    glow(
      .40,
      .42,
      .80,
      dark ? const Color(0x4D394757) : const Color(0x7ADAE5EE),
    );
    glow(
      -.10,
      .24,
      .65,
      dark ? const Color(0x2E25413A) : const Color(0x47E4EFE8),
    );
  }

  @override
  bool shouldRepaint(_CanvasPainter oldDelegate) =>
      dark != oldDelegate.dark || highContrast != oldDelegate.highContrast;
}
