import 'package:flutter/material.dart';

class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.42, 1],
          colors: [Color(0xFF121212), Color(0xFF090909), Color(0xFF050505)],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}
