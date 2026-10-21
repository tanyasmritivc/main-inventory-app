import 'dart:ui';
import 'package:flutter/material.dart';

/// Bounded frosted material for controls, never a full-screen blur.
class LiquidSurface extends StatelessWidget {
  const LiquidSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.quiet = false,
    this.shadow = true,
  });
  final Widget child;
  final double radius;
  final bool quiet, shadow;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solid = MediaQuery.highContrastOf(context);
    final rounding = BorderRadius.circular(radius);
    final base = dark ? const Color(0xFF242322) : const Color(0xFFFFFCF8);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: rounding,
        boxShadow: [
          if (shadow && !solid)
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .16 : .045),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: rounding,
        child: BackdropFilter(
          enabled: !solid,
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: rounding,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  base.withValues(
                    alpha: solid
                        ? 1
                        : quiet
                        ? .60
                        : .78,
                  ),
                  base.withValues(
                    alpha: solid
                        ? 1
                        : quiet
                        ? .44
                        : .60,
                  ),
                ],
              ),
              border: Border.all(
                width: .7,
                color: (dark ? Colors.white : const Color(0xFF6D5141))
                    .withValues(
                      alpha: solid
                          ? .5
                          : dark
                          ? .18
                          : .14,
                    ),
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: rounding,
                gradient: solid
                    ? null
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, .24, 1],
                        colors: [
                          Colors.white.withValues(alpha: dark ? .055 : .38),
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class LiquidIconButton extends StatelessWidget {
  const LiquidIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => LiquidSurface(
    radius: 30,
    shadow: false,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 21),
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.all(10),
      ),
    ),
  );
}
