import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Fades only newly painted glyphs. Markdown keeps its layout, links and semantics;
/// no word widgets, repeated whole-message fades or per-frame widget rebuilds.
class StreamingTextFade extends StatefulWidget {
  const StreamingTextFade({
    super.key,
    required this.enabled,
    required this.child,
  });
  final bool enabled;
  final Widget child;
  @override
  State<StreamingTextFade> createState() => _StreamingTextFadeState();
}

class _StreamingTextFadeState extends State<StreamingTextFade>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => _render?.tick());
  _FadeRender? _render;
  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FadeWidget(
    enabled: widget.enabled,
    connect: (render) => _render = render,
    animate: (active) {
      if (active && !_ticker.isActive) _ticker.start();
      if (!active && _ticker.isActive) _ticker.stop();
    },
    child: widget.child,
  );
}

class _FadeWidget extends SingleChildRenderObjectWidget {
  const _FadeWidget({
    required this.enabled,
    required this.connect,
    required this.animate,
    required super.child,
  });
  final bool enabled;
  final ValueChanged<_FadeRender> connect;
  final ValueChanged<bool> animate;
  @override
  _FadeRender createRenderObject(BuildContext context) {
    final render = _FadeRender(enabled, animate);
    connect(render);
    return render;
  }

  @override
  void updateRenderObject(BuildContext context, _FadeRender renderObject) {
    renderObject.enabled = enabled;
    renderObject.animate = animate;
    connect(renderObject);
  }
}

class _Paragraph {
  _Paragraph(this.render, this.original, this.offset);
  final RenderParagraph render;
  final InlineSpan original;
  final int offset;
}

class _FadeRender extends RenderProxyBox {
  _FadeRender(this._enabled, this.animate);
  bool _enabled;
  ValueChanged<bool> animate;
  static const fade = 180000; // microseconds
  String _plain = '';
  List<int> _born = [];
  List<_Paragraph> _paragraphs = [];
  int get now => SchedulerBinding.instance.currentFrameTimeStamp.inMicroseconds;
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    if (!value) {
      _born = List.filled(_plain.length, -fade);
      tick();
    }
    markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    final paragraphs = <_Paragraph>[];
    final text = StringBuffer();
    void visit(RenderObject object) {
      if (object is RenderParagraph) {
        final original = object.text;
        paragraphs.add(_Paragraph(object, original, text.length));
        text.write(original.toPlainText(includeSemanticsLabels: false));
        text.write('\n');
      } else {
        object.visitChildren(visit);
      }
    }

    child?.visitChildren(visit);
    if (child is RenderParagraph) visit(child!);
    final plain = text.toString();
    var prefix = 0;
    while (prefix < plain.length &&
        prefix < _plain.length &&
        plain.codeUnitAt(prefix) == _plain.codeUnitAt(prefix)) {
      prefix++;
    }
    _born = [
      ..._born.take(prefix),
      ...List.filled(plain.length - prefix, _enabled ? now : -fade),
    ];
    _plain = plain;
    _paragraphs = paragraphs;
    tick();
  }

  void tick() {
    if (!attached) return;
    animate(_enabled && _born.any((birth) => now - birth < fade));
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final time = now;
    if (!_enabled || !_born.any((birth) => time - birth < fade)) {
      super.paint(context, offset);
      return;
    }
    // One temporary layer for this answer. Selection boxes follow the existing
    // paragraph layout exactly, including mixed styles, RTL and wrapped lines.
    final canvas = context.canvas;
    canvas.saveLayer(offset & size, Paint());
    super.paint(context, offset);
    for (final p in _paragraphs) {
      final text = p.original.toPlainText(includeSemanticsLabels: false);
      var start = 0;
      while (start < text.length) {
        final birth = _born[p.offset + start];
        var end = start + 1;
        while (end < text.length && _born[p.offset + end] == birth) {
          end++;
        }
        final progress = ((time - birth) / fade).clamp(0.0, 1.0);
        if (progress < 1 && p.render.attached) {
          final paint = Paint()
            ..color = Colors.black.withValues(
              alpha: 1 - Curves.easeOut.transform(progress),
            )
            ..blendMode = BlendMode.dstOut;
          final origin =
              p.render.localToGlobal(Offset.zero, ancestor: this) + offset;
          for (final box in p.render.getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: end),
          )) {
            canvas.drawRect(box.toRect().shift(origin), paint);
          }
        }
        start = end;
      }
    }
    canvas.restore();
  }

  @override
  void detach() {
    animate(false);
    super.detach();
  }
}
