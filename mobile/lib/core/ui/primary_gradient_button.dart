import 'package:flutter/material.dart';
import '../app_theme.dart';

import 'frosted_surface.dart';

class PrimaryGradientButton extends StatefulWidget {
  const PrimaryGradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 52,
    this.borderRadius = 18,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final double borderRadius;

  @override
  State<PrimaryGradientButton> createState() => _PrimaryGradientButtonState();
}

class _PrimaryGradientButtonState extends State<PrimaryGradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    final fg = enabled
        ? AppTheme.textPrimary(context)
        : AppTheme.textSecondary(context);

    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      scale: _pressed && enabled ? 0.985 : 1,
      child: FrostedSurface(
        radius: widget.borderRadius,
        tint: enabled
            ? AppTheme.neutralSelectionTint(context)
            : AppTheme.surface(context),
        shadow: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.height),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Center(
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(letterSpacing: 0.2),
                    child: IconTheme.merge(
                      data: IconThemeData(color: fg),
                      child: DefaultTextStyle.merge(
                        style: TextStyle(color: fg),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
