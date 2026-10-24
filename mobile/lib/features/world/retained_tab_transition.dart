import 'package:flutter/material.dart';

/// Dissolves between mounted tabs without losing drafts or scroll positions.
/// A rapid selection retargets from the current frame, rather than flashing back.
class RetainedTabTransition extends StatefulWidget {
  const RetainedTabTransition({
    super.key,
    required this.index,
    required this.children,
  });
  final int index;
  final List<Widget> children;

  @override
  State<RetainedTabTransition> createState() => _RetainedTabTransitionState();
}

class _RetainedTabTransitionState extends State<RetainedTabTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );
  late List<double> _from = _target;
  bool _reduceMotion = false;

  List<double> get _target => List.generate(
    widget.children.length,
    (i) => i == widget.index ? 1.0 : 0.0,
  );

  List<double> _values(int selected) {
    final progress = Curves.easeInOutCubic.transform(_controller.value);
    return List.generate(widget.children.length, (i) {
      final end = i == selected ? 1.0 : 0.0;
      return _from[i] + (end - _from[i]) * progress;
    });
  }

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
      _from = _target;
      _controller.value = 1;
    } else if (oldWidget.index != widget.index) {
      _from = _values(oldWidget.index);
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
      final values = _values(widget.index);
      return Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            Offstage(
              offstage: values[i] == 0,
              child: TickerMode(
                enabled: i == widget.index,
                child: IgnorePointer(
                  ignoring: i != widget.index,
                  child: ExcludeSemantics(
                    excluding: i != widget.index,
                    child: Opacity(
                      opacity: values[i].clamp(0.0, 1.0),
                      child: RepaintBoundary(child: widget.children[i]),
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
