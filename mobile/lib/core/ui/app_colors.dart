import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF08090E);
  static const surface = Color(0xFF111318);
  static const surface2 = Color(0xFF1E2028);
  static const chip = Color(0xFF111318);
  static const swipe = Color(0xFF1E2028);

  static const accent = Color(0xFF7B7FF6);
  static const primaryText = Color(0xFFF0F0F5);
  static const muted = Color(0xFF6B6E7A);
  static const hint = Color(0xFF3A3D47);

  static const accentCyan = Color(0xFF55D7FF);
  static const accentPurple = Color(0xFF7B7FF6);
  static const accentPink = Color(0xFFFF6EC7);
  static const accentPeach = Color(0xFFFFB07A);

  static const danger = Color(0xFFFF5C5C);

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accentCyan, accentPurple, accentPink, accentPeach],
    stops: [0.0, 0.35, 0.70, 1.0],
  );
}
