import 'package:flutter/material.dart';

/// Scoped entrances keep animation ticks out of the form and world trees.
class WorldEntrance extends StatefulWidget {
  const WorldEntrance({
    super.key,
    required this.child,
    this.delay = 0,
    this.duration = 500,
    this.distance = 14,
    this.backwards = false,
  });
  final Widget child;
  final int delay, duration;
  final double distance;
  final bool backwards;
  @override
  State<WorldEntrance> createState() => _WorldEntranceState();
}

class _WorldEntranceState extends State<WorldEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool? _reduced;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced == reduced) return;
    _reduced = reduced;
    _controller.duration = Duration(
      milliseconds: reduced ? 200 : widget.delay + widget.duration,
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final reduced = _reduced == true;
      final raw = reduced
          ? _controller.value
          : ((_controller.value * (widget.delay + widget.duration) -
                        widget.delay) /
                    widget.duration)
                .clamp(0.0, 1.0);
      final progress = Curves.easeOutCubic.transform(raw);
      return IgnorePointer(
        ignoring: raw == 0,
        child: Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(
              0,
              reduced
                  ? 0
                  : (widget.backwards ? -1 : 1) *
                        widget.distance *
                        (1 - progress),
            ),
            child: child,
          ),
        ),
      );
    },
  );
}

class WorldPress extends StatefulWidget {
  const WorldPress({super.key, required this.child});
  final Widget child;
  @override
  State<WorldPress> createState() => _WorldPressState();
}

class _WorldPressState extends State<WorldPress> {
  bool _down = false;
  void _pressed(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _pressed(true),
    onPointerUp: (_) => _pressed(false),
    onPointerCancel: (_) => _pressed(false),
    child: AnimatedScale(
      scale: _down && !MediaQuery.disableAnimationsOf(context) ? .975 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}
