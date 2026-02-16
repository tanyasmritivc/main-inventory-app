import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: isIOS
            ? DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.background,
                      AppColors.accentPurple.withValues(alpha: 0.06),
                      AppColors.background,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
                child: child,
              )
            : child,
      ),
    );
  }
}
