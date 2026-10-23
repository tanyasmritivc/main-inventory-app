import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Full-screen scrolling with measured insets and glass above the messages.
class ChatViewport extends StatefulWidget {
  const ChatViewport({
    super.key,
    required this.header,
    required this.footer,
    required this.messages,
    required this.controller,
  });
  final Widget header, footer;
  final List<Widget> messages;
  final ScrollController controller;
  @override
  State<ChatViewport> createState() => _ChatViewportState();
}

class _ChatViewportState extends State<ChatViewport> {
  double _header = 64, _footer = 180;
  Widget _glass({required Widget child, required bool top}) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: top
                    ? [Colors.white, Colors.white, Colors.transparent]
                    : [Colors.transparent, Colors.white, Colors.white],
                stops: top ? [0, .6, 1] : [0, .35, 1],
              ).createShader(rect),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: ColoredBox(color: bg.withValues(alpha: .72)),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            key: const Key('chat-full-viewport'),
            controller: widget.controller,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, _header + 8, 16, _footer + 16),
            children: widget.messages,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _Measure(
            onSize: (size) {
              if (mounted && _header != size.height) {
                setState(() => _header = size.height);
              }
            },
            child: _glass(
              top: true,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 20),
                child: widget.header,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _Measure(
            onSize: (size) {
              if (mounted && _footer != size.height) {
                setState(() => _footer = size.height);
              }
            },
            child: _glass(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
                child: widget.footer,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Measure extends SingleChildRenderObjectWidget {
  const _Measure({required this.onSize, required super.child});
  final ValueChanged<Size> onSize;
  @override
  RenderObject createRenderObject(BuildContext context) => _MeasureBox(onSize);
  @override
  void updateRenderObject(BuildContext context, _MeasureBox renderObject) =>
      renderObject.onSize = onSize;
}

class _MeasureBox extends RenderProxyBox {
  _MeasureBox(this.onSize);
  ValueChanged<Size> onSize;
  Size? previous;
  @override
  void performLayout() {
    super.performLayout();
    if (size == previous) return;
    previous = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(measured);
    });
  }
}
