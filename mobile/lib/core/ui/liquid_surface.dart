import '../app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'native_menu_button.dart';
import 'native_presentation.dart';
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
    final base = dark ? const Color(0xFF262626) : AppTheme.lightSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: rounding,
        boxShadow: [
          if (shadow && !solid)
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .16 : .075),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: rounding,
        child: BackdropFilter(
          enabled: !solid && dark,
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: rounding,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  base.withValues(
                    alpha: solid || !dark
                        ? 1
                        : quiet
                        ? .85
                        : .95,
                  ),
                  base.withValues(
                    alpha: solid || !dark
                        ? 1
                        : quiet
                        ? .75
                        : .85,
                  ),
                ],
              ),
              border: Border.all(
                width: dark ? .7 : 1,
                color: !dark
                    ? AppTheme.adaptiveBorder(context, Colors.white)
                    : Colors.white.withValues(alpha: solid ? .5 : .18),
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: rounding,
                gradient: solid || !dark
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
  Widget build(BuildContext context) {
    final symbol = <IconData, String>{
      CupertinoIcons.clock: 'clock',
      CupertinoIcons.search: 'magnifyingglass',
      CupertinoIcons.xmark: 'xmark',
      CupertinoIcons.chevron_left: 'chevron.left',
      CupertinoIcons.square_pencil: 'square.and.pencil',
      CupertinoIcons.plus: 'plus',
      CupertinoIcons.ellipsis: 'ellipsis',
    }[icon];
    if (usesNativePresentation && symbol != null) {
      return NativeToolbarButton(
        symbol: symbol,
        label: tooltip,
        onPressed: onPressed,
      );
    }
    return LiquidSurface(
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
}
