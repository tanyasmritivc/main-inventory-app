import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'frosted_surface.dart';

/// A quiet glass surface for neutral actions and selection controls.
class GlassControl extends StatelessWidget {
  const GlassControl({
    super.key,
    required this.child,
    this.radius = 16,
    this.selected = false,
    this.enabled = true,
  });

  final Widget child;
  final double radius;
  final bool selected, enabled;

  static ButtonStyle buttonStyle(
    BuildContext context, {
    required ButtonStyle base,
    double radius = 16,
  }) {
    final foreground = WidgetStateProperty.resolveWith<Color>(
      (states) => states.contains(WidgetState.disabled)
          ? AppTheme.textSecondary(context)
          : AppTheme.textPrimary(context),
    );
    return base.copyWith(
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      foregroundColor: foreground,
      iconColor: foreground,
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      side: const WidgetStatePropertyAll(BorderSide.none),
      backgroundBuilder: (context, states, child) => GlassControl(
        radius: radius,
        enabled: !states.contains(WidgetState.disabled),
        selected: states.contains(WidgetState.selected),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final tint = Color.alphaBlend(
      AppTheme.action.withValues(alpha: selected ? .08 : 0),
      AppTheme.surface(context),
    );
    final border = selected
        ? AppTheme.accentForeground(
            context,
          ).withValues(alpha: highContrast ? 1 : (enabled ? .6 : .4))
        : AppTheme.textPrimary(
            context,
          ).withValues(alpha: highContrast ? .4 : (enabled ? .15 : .08));
    return FrostedSurface(
      radius: radius,
      tint: tint,
      border: border,
      shadow: false,
      child: child,
    );
  }
}
