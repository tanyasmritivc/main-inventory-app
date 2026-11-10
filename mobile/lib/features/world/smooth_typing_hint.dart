import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Reveal the settled text on frame boundaries, without relaying it out for each
/// character. The soft edge makes each new glyph appear rather than snap in.
class SmoothTypingHint extends StatelessWidget {
  const SmoothTypingHint({
    super.key,
    required this.text,
    required this.visibleCharacters,
  });
  final String text;
  final double visibleCharacters;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final style = DefaultTextStyle.of(context).style;
      final direction = Directionality.of(context);
      final scaler = MediaQuery.textScalerOf(context);
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: bounds.maxWidth);
      final width = math.min(bounds.maxWidth, painter.width);
      final offsets = [
        for (var i = 0; i <= text.length; i++)
          painter.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dx,
      ];
      painter.dispose();
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(
          width: width,
          child: Builder(
            builder: (context) {
              final value = visibleCharacters;
              final child = Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
              if (value >= text.length) return child;
              final index = value.floor().clamp(0, text.length);
              final next = math.min(index + 1, text.length);
              final edge =
                  offsets[index] +
                  (offsets[next] - offsets[index]) * (value - index);
              final end = width == 0 ? 0.0 : (edge / width).clamp(0.0, 1.0);
              final start = width == 0
                  ? 0.0
                  : ((edge - 9) / width).clamp(0.0, end);
              return ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: direction == TextDirection.ltr
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  end: direction == TextDirection.ltr
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  colors: const [
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: [0, start, end, 1],
                ).createShader(rect),
                child: child,
              );
            },
          ),
        ),
      );
    },
  );
}
