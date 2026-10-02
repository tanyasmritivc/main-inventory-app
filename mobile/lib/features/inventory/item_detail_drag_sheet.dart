import 'dart:async';

import 'package:flutter/material.dart';

/// Coordinates item scrolling and downward dismissal through one controller.
/// The modal's own drag handler must be disabled so it cannot bypass onDismiss.
class ItemDetailDragSheet extends StatefulWidget {
  const ItemDetailDragSheet({
    super.key,
    required this.builder,
    required this.onDismiss,
  });

  final ScrollableWidgetBuilder builder;
  final Future<bool> Function() onDismiss;

  @override
  State<ItemDetailDragSheet> createState() => _ItemDetailDragSheetState();
}

class _ItemDetailDragSheetState extends State<ItemDetailDragSheet> {
  final _controller = DraggableScrollableController();
  bool _dismissRequested = false;

  void _restore() {
    if (!mounted || !_controller.isAttached || _dismissRequested) return;
    if (_controller.size < 1) {
      unawaited(
        _controller.animateTo(
          1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    final closed = await widget.onDismiss();
    // Keep dismissal latched throughout the modal's exit animation. Late idle
    // notifications must not expand the sheet while it is sliding offscreen.
    if (!mounted || closed) return;
    _dismissRequested = false;
    _restore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          if (notification.depth != 0) return false;
          if (notification.extent <= notification.minExtent &&
              !_dismissRequested) {
            _dismissRequested = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(_dismiss());
            });
          }
          // Stop the parent BottomSheet from popping without save checks.
          return true;
        },
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (notification) {
            if (notification.depth == 0 && !_dismissRequested) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
            }
            return false;
          },
          child: DraggableScrollableSheet(
            controller: _controller,
            initialChildSize: 1,
            maxChildSize: 1,
            minChildSize: 0.7,
            expand: false,
            shouldCloseOnMinExtent: false,
            builder: widget.builder,
          ),
        ),
      );
}
