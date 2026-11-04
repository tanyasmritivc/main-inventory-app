import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Drag dismissal for custom slide-up routes. Scrollable content must reach
/// its top first. maybePop preserves the child's save/permission PopScope.
class SwipeDownSheet extends StatefulWidget {
  const SwipeDownSheet({super.key, required this.child});
  final Widget child;
  @override
  State<SwipeDownSheet> createState() => _SwipeDownSheetState();
}

class _SwipeDownSheetState extends State<SwipeDownSheet>
    with SingleTickerProviderStateMixin {
  late final _offset = AnimationController.unbounded(vsync: this);
  Offset? _start;
  VelocityTracker? _velocity;
  bool _atTop = true, _fromTop = false, _closing = false;
  int? _pointer;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    // The route animates its departure from the current dragged position.
    final route = ModalRoute.of(context);
    final closed = await Navigator.of(context).maybePop();
    if (!mounted) return;
    if (!closed || route?.isActive == true) {
      _closing = false;
      await _offset.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    onDismiss: () => unawaited(_dismiss()),
    child: NotificationListener<ScrollNotification>(
      onNotification: (notice) {
        if (notice.metrics.axis == Axis.vertical && notice.depth == 0) {
          _atTop = notice.metrics.pixels <= notice.metrics.minScrollExtent + .5;
        }
        return false;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (_pointer != null || _closing) return;
          _pointer = event.pointer;
          _offset.stop();
          _start = event.position;
          _fromTop = _atTop || event.localPosition.dy < 56;
          _velocity = VelocityTracker.withKind(event.kind)
            ..addPosition(event.timeStamp, event.position);
        },
        onPointerMove: (event) {
          if (event.pointer != _pointer || _start == null || _closing) return;
          _velocity?.addPosition(event.timeStamp, event.position);
          final distance = event.position - _start!;
          if (_fromTop && distance.dy > 12 && distance.dy > distance.dx.abs()) {
            _offset.value = distance.dy - 12;
          }
        },
        onPointerUp: (event) {
          if (event.pointer != _pointer) return;
          _pointer = null;
          final speed = _velocity?.getVelocity().pixelsPerSecond.dy ?? 0;
          if (_offset.value > 90 || (_offset.value > 20 && speed > 700)) {
            unawaited(_dismiss());
          } else {
            unawaited(
              _offset.animateTo(
                0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
              ),
            );
          }
        },
        onPointerCancel: (event) {
          if (event.pointer != _pointer) return;
          _pointer = null;
          unawaited(
            _offset.animateTo(
              0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
            ),
          );
        },
        child: AnimatedBuilder(
          animation: _offset,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, _offset.value),
            child: child,
          ),
          child: widget.child,
        ),
      ),
    ),
  );
}
