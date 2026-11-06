import '../app_theme.dart';
import 'package:flutter/material.dart';

/// Quiet content surface. Glass is reserved for controls above the content.
class ContentCard extends StatelessWidget {
  const ContentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
  });
  final Widget child;
  final EdgeInsetsGeometry padding, margin;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1C1C1E) : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: !dark
              ? AppTheme.adaptiveBorder(context, Colors.white)
              : Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: MediaQuery.highContrastOf(context) ? .45 : .10,
                ),
          width: dark ? .5 : 1,
        ),
      ),
      child: child,
    );
  }
}
