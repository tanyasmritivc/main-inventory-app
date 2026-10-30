import 'package:flutter/material.dart';
import '../../core/ui/navigation_motion.dart';

/// Retains every tab; only the incoming and outgoing destinations paint.
class RetainedTabTransition extends StatefulWidget {
  const RetainedTabTransition({
    super.key,
    required this.index,
    required this.children,
  });
  static const duration = Duration(milliseconds: 100);
  static const curve = Curves.easeOutCubic;
  final int index;
  final List<Widget> children;
  @override
  State<RetainedTabTransition> createState() => _RetainedTabTransitionState();
}

class _RetainedTabTransitionState extends State<RetainedTabTransition>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: NavigationMotion.duration,
    value: 1,
  )..addStatusListener(_settled);
  int? _outgoing;
  double _start = 0;

  @override
  void initState() {
    super.initState();
    NativeMotionPreferences.instance.addListener(_preferencesChanged);
  }

  void _preferencesChanged() {
    if (!mounted) return;
    if (!NavigationMotion.enabled(
      context,
      NativeMotionPreferences.instance.value,
    )) {
      _controller.value = 1;
      _outgoing = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preferencesChanged();
  }

  void _settled(AnimationStatus status) {
    if (status == AnimationStatus.completed && _outgoing != null && mounted) {
      setState(() => _outgoing = null);
    }
  }

  @override
  void didUpdateWidget(RetainedTabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      // A rapid retarget keeps the visually dominant prior scene underneath.
      final previous = _controller.isAnimating && _controller.value < .5
          ? _outgoing ?? oldWidget.index
          : oldWidget.index;
      final returning = _outgoing == widget.index;
      _start = _controller.isAnimating
          ? (returning ? 1 - _controller.value : _controller.value)
          : 0;
      _outgoing = previous == widget.index ? oldWidget.index : previous;
      if (NavigationMotion.enabled(
        context,
        NativeMotionPreferences.instance.value,
      )) {
        _controller.forward(from: _start);
      } else {
        _controller.value = 1;
        _outgoing = null;
      }
    }
  }

  @override
  void dispose() {
    NativeMotionPreferences.instance.removeListener(_preferencesChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<MotionPreferences>(
    valueListenable: NativeMotionPreferences.instance,
    builder: (context, preferences, _) {
      final animate = NavigationMotion.enabled(context, preferences);
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          // Stable keyed wrappers preserve text fields/scroll positions when the
          // selected page is painted last. Inactive tabs never receive input.
          children: [
            for (final i in [
              for (var n = 0; n < widget.children.length; n++)
                if (n != widget.index) n,
              widget.index,
            ])
              Offstage(
                key: ValueKey(i),
                offstage: i != widget.index && (!animate || i != _outgoing),
                child: TickerMode(
                  enabled: i == widget.index,
                  child: IgnorePointer(
                    ignoring: i != widget.index,
                    child: ExcludeSemantics(
                      excluding: i != widget.index,
                      child: Opacity(
                        opacity: !animate
                            ? 1
                            : i == widget.index
                            ? NavigationMotion.incoming(_controller.value)
                            : NavigationMotion.outgoing(_controller.value),
                        child: RepaintBoundary(
                          child: Material(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.black
                                : Colors.white,
                            child: widget.children[i],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
