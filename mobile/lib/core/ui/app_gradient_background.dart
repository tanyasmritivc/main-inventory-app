import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background,
                AppColors.surface.withValues(alpha: 0.28),
                AppColors.background,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
