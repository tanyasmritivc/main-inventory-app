import 'dart:ui';
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Local glass treatment for navigation and small transient controls.
class FrostedSurface extends StatelessWidget {
  const FrostedSurface({
    super.key,
    required this.child,
    this.radius = 20,
    this.tint,
    this.border,
    this.shadow = true,
  });
  final Widget child;
  final double radius;
  final Color? tint, border;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final solid = MediaQuery.highContrastOf(context);
    final base = tint ?? AppTheme.surface(context);
    final outline =
        border ??
        AppTheme.textPrimary(context).withValues(
          alpha: solid
              ? .35
              : dark
              ? .17
              : .13,
        );
    final rounding = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: rounding,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .18 : .07),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: rounding,
        child: BackdropFilter(
          enabled: !solid,
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: rounding,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  base.withValues(alpha: solid ? 1 : .88),
                  base.withValues(alpha: solid ? 1 : .76),
                ],
              ),
              border: Border.all(color: outline),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
