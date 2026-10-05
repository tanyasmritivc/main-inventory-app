import '../../core/app_theme.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 18,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final content = Padding(padding: padding, child: child);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.adaptive(
          context,
          AppColors.surface2.withValues(alpha: 0.95),
        ),
        borderRadius: radius,
        border: Border.all(
          color: AppTheme.adaptive(
            context,
            Colors.white.withValues(alpha: 0.10),
          ),
          width: 0.75,
        ),
      ),
      child: content,
    );
  }
}
