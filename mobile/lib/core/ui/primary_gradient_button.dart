import 'package:flutter/material.dart';
import '../app_theme.dart';

import 'app_colors.dart';

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

    final bg = enabled ? Colors.transparent : AppTheme.surface(context);
    final fg = enabled ? Colors.white : AppTheme.textSecondary(context);
    final accent = AppTheme.adaptive(context, AppColors.accent);

    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      scale: _pressed && enabled ? 0.985 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              color: bg,
              gradient: enabled
                  ? LinearGradient(colors: [accent, accent])
                  : null,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
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
      ),
    );
  }
}
