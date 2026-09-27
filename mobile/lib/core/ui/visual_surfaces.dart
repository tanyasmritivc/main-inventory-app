import 'package:flutter/material.dart';

import '../app_theme.dart';

class AppSurfaceBackground extends StatelessWidget {
  const AppSurfaceBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppTokens.of(context).bg,
    child: SafeArea(child: child),
  );
}

/// A single inset surface. Rows inside it use dividers, not nested borders.
class GroupedSurface extends StatelessWidget {
  const GroupedSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = AppTokens.radius,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: ColoredBox(
      color: AppTokens.of(context).card,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = AppTokens.buttonHeight,
    this.borderRadius = 12,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: child,
    ),
  );
}

class ActionFab extends StatelessWidget {
  const ActionFab({
    super.key,
    required this.onPressed,
    this.heroTag,
    this.label = 'Add',
  });

  final VoidCallback? onPressed;
  final Object? heroTag;
  final String label;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
    heroTag: heroTag,
    onPressed: onPressed,
    elevation: 0,
    label: Text(label),
  );
}
