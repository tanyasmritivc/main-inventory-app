import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// Purchase progress colors are local to restocking, not global brand accents.
abstract final class RestockStatusColors {
  static Color toBuy(BuildContext context) =>
      AppTheme.foreground(context, AppColors.warning);
  static Color onOrder(BuildContext context) => AppTheme.isDark(context)
      ? const Color(0xFF8BBEFF)
      : const Color(0xFF2059A6);
}

class RestockSummary extends StatelessWidget {
  const RestockSummary({
    required this.toBuy,
    required this.onOrder,
    this.style,
    super.key,
  });
  final int toBuy, onOrder;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$toBuy to buy',
          style: TextStyle(
            color: toBuy > 0
                ? RestockStatusColors.toBuy(context)
                : AppTheme.textSecondary(context),
          ),
        ),
        TextSpan(
          text: ' | ',
          style: TextStyle(color: AppTheme.textSecondary(context)),
        ),
        TextSpan(
          text: '$onOrder on order',
          style: TextStyle(
            color: onOrder > 0
                ? RestockStatusColors.onOrder(context)
                : AppTheme.textSecondary(context),
          ),
        ),
      ],
    ),
    style: AppTypography.styleOf(context, style),
    semanticsLabel: '$toBuy to buy | $onOrder on order',
  );
}
