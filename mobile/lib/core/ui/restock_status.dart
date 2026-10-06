import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'app_typography.dart';

/// Active purchase counts use the brand accent; labels and icons convey state.
abstract final class RestockStatusColors {
  static Color toBuy(BuildContext context) =>
      AppTheme.accentForeground(context);
  static Color onOrder(BuildContext context) =>
      AppTheme.accentForeground(context);
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
