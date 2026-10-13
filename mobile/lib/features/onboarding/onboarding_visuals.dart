import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

/// Quiet decoration behind the questionnaire; all content remains on a
/// contrast-safe surface, including when increased contrast is enabled.
class SetupBackdrop extends StatelessWidget {
  const SetupBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(1, -.8),
        radius: 1.2,
        colors: [
          Color.alphaBlend(
            AppTheme.action.withValues(
              alpha: MediaQuery.highContrastOf(context) ? 0 : .045,
            ),
            Theme.of(context).scaffoldBackgroundColor,
          ),
          Theme.of(context).scaffoldBackgroundColor,
        ],
      ),
    ),
    child: child,
  );
}

class SetupGlassPanel extends StatelessWidget {
  const SetupGlassPanel({
    super.key,
    required this.child,
    this.selected = false,
  });
  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .12 : .035),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter.grouped(
          enabled: !highContrast,
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: Duration(
              milliseconds:
                  MediaQuery.disableAnimationsOf(context) ||
                      MediaQuery.accessibleNavigationOf(context)
                  ? 0
                  : 180,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (selected
                          ? AppTheme.accentTint(context)
                          : AppTheme.surface(context))
                      .withValues(alpha: highContrast ? 1 : .94),
                  (selected
                          ? AppTheme.accentTint(context)
                          : AppTheme.surface(context))
                      .withValues(alpha: highContrast ? 1 : .82),
                ],
              ),
              border: Border.all(
                color:
                    (selected
                            ? AppTheme.accentForeground(context)
                            : AppTheme.textPrimary(context))
                        .withValues(
                          alpha: selected
                              ? .6
                              : highContrast
                              ? .3
                              : dark
                              ? .18
                              : .18,
                        ),
                width: selected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
