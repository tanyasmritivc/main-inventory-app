import 'package:flutter/material.dart';

/// A subtle settle between mounted tabs, preserving drafts and scroll positions.
/// A rapid selection retargets from the current frame, rather than flashing back.
class RetainedTabTransition extends StatefulWidget {
  const RetainedTabTransition({
    super.key,
    required this.index,
    required this.children,
  });
  static const duration = Duration(milliseconds: 140);
  static const pageDuration = Duration(milliseconds: 360);
  // Immediate visible feedback, with a gentle settle rather than a slow start.
  static const curve = Curves.easeOutCubic;

  final int index;
  final List<Widget> children;

  @override
  State<RetainedTabTransition> createState() => _RetainedTabTransitionState();
}

class _RetainedTabTransitionState extends State<RetainedTabTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RetainedTabTransition.pageDuration,
    value: 1,
  );
  double _fromOpacity = .94;
  bool _reduceMotion = false;

  double get _opacity =>
      _fromOpacity +
      (1 - _fromOpacity) *
          RetainedTabTransition.curve.transform(_controller.value);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion) _controller.value = 1;
  }

  @override
  void didUpdateWidget(RetainedTabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      _fromOpacity = .94;
      _controller.value = 1;
    } else if (oldWidget.index != widget.index) {
      _fromOpacity = _controller.isAnimating ? _opacity : .94;
      if (_reduceMotion) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final opacity = _opacity;
      return Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            Offstage(
              offstage: i != widget.index,
              child: TickerMode(
                enabled: i == widget.index,
                child: IgnorePointer(
                  ignoring: i != widget.index,
                  child: ExcludeSemantics(
                    excluding: i != widget.index,
                    child: Opacity(
                      opacity: i == widget.index ? opacity : 0,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          i == widget.index ? (1 - opacity) * 64 : 0,
                        ),
                        child: RepaintBoundary(child: widget.children[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
