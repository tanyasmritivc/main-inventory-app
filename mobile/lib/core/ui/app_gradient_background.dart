import 'package:flutter/material.dart';

class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          stops: [0, 0.34, 0.7, 1],
          colors: [
            Color(0xFF1A1110),
            Color(0xFF09090C),
            Color(0xFF071012),
            Color(0xFF000000),
          ],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}
