import '../../core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/ui/app_text.dart';
import 'frosted_surface.dart';

class GlassFab extends StatelessWidget {
  const GlassFab({
    super.key,
    required this.onPressed,
    this.heroTag,
    this.icon = Icons.add_rounded,
    this.label,
  });

  final VoidCallback? onPressed;
  final Object? heroTag;
  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final foreground = onPressed == null
        ? AppTheme.textSecondary(context)
        : AppTheme.textPrimary(context);
    final button = label != null
        ? FloatingActionButton.extended(
            heroTag: heroTag,
            onPressed: onPressed,
            foregroundColor: foreground,
            backgroundColor: Colors.transparent,
            elevation: 0,
            highlightElevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            icon: Icon(icon, color: foreground, size: 22),
            label: AppText(label!),
          )
        : FloatingActionButton(
            heroTag: heroTag,
            onPressed: onPressed,
            foregroundColor: foreground,
            backgroundColor: Colors.transparent,
            elevation: 0,
            highlightElevation: 0,
            shape: const CircleBorder(),
            child: Icon(icon, color: foreground, size: 25),
          );
    return FrostedSurface(
      radius: label == null ? 28 : 18,
      tint: AppTheme.neutralSelectionTint(context),
      border: AppTheme.textPrimary(
        context,
      ).withValues(alpha: MediaQuery.highContrastOf(context) ? .4 : .12),
      child: button,
    );
  }
}
