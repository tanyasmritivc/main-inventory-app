import 'package:flutter/material.dart';
import '../app_theme.dart';

class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppTheme.bg(context)),
      child: SafeArea(child: child),
    );
  }
}
