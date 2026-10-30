import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Bounded blur that dissolves toward the scrollable content.
class ScrollGlass extends StatelessWidget {
  const ScrollGlass({super.key, required this.child, this.top = true});
  final Widget child;
  final bool top;
  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : Colors.white;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: BackdropGroup(
              child: LayoutBuilder(
                builder: (context, bounds) => Stack(
                  children: [
                    // Each non-overlapping strip samples the same backdrop,
                    // avoiding feedback seams from previously painted strips.
                    for (var i = 0; i < 24; i++)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: bounds.maxHeight * (top ? i : 23 - i) / 24,
                        height: bounds.maxHeight / 24,
                        child: ClipRect(
                          child: BackdropFilter.grouped(
                            filter: ImageFilter.blur(
                              sigmaX: (24 - i) * .625,
                              sigmaY: (24 - i) * .625,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: top
                                ? Alignment.topCenter
                                : Alignment.bottomCenter,
                            end: top
                                ? Alignment.bottomCenter
                                : Alignment.topCenter,
                            colors: [
                              background.withValues(alpha: .85),
                              background.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Measures only when controls actually change size, not on every stream chunk.
class ReportSize extends SingleChildRenderObjectWidget {
  const ReportSize({super.key, required this.onSize, required super.child});
  final ValueChanged<Size> onSize;
  @override
  RenderObject createRenderObject(BuildContext context) => _ReportSize(onSize);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderProxyBox renderObject,
  ) {
    (renderObject as _ReportSize).onSize = onSize;
  }
}

class _ReportSize extends RenderProxyBox {
  _ReportSize(this.onSize);
  ValueChanged<Size> onSize;
  Size? _previous;
  @override
  void performLayout() {
    super.performLayout();
    if (_previous == size) return;
    _previous = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(measured));
  }
}
