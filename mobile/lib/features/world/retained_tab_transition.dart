import 'package:flutter/material.dart';

/// Mounted tabs switch immediately, retaining drafts and scroll positions.
/// Only the tab indicator animates; pages never fade or block new interactions.
class RetainedTabTransition extends StatelessWidget {
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
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (var i = 0; i < children.length; i++)
        Offstage(
          offstage: i != index,
          child: TickerMode(
            enabled: i == index,
            child: IgnorePointer(
              ignoring: i != index,
              child: ExcludeSemantics(
                excluding: i != index,
                child: RepaintBoundary(child: children[i]),
              ),
            ),
          ),
        ),
    ],
  );
}
