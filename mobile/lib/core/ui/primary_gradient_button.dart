import 'package:flutter/material.dart';

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
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final enabled = widget.onPressed != null;

    final bg = enabled ? Colors.transparent : AppColors.surface;
    final fg = enabled ? Colors.white : Colors.white.withValues(alpha: 0.55);

    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      scale: _pressed && enabled ? 0.985 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            height: widget.height,
            decoration: BoxDecoration(
              color: isIOS ? bg : (enabled ? AppColors.accentPurple : bg),
              gradient: (!enabled || !isIOS) ? null : AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isIOS ? 0.22 : 0.28),
                  blurRadius: isIOS ? 22 : 18,
                  offset: Offset(0, isIOS ? 10 : 8),
                ),
              ],
            ),
            child: InkWell(
              onTap: widget.onPressed,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              child: Center(
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
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
    );
  }
}
