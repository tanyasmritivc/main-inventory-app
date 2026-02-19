import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0F1115);
  static const surface = Color(0xFF151821);
  static const surface2 = Color(0xFF1B1F2A);
  static const chip = Color(0xFF151822);
  static const swipe = Color(0xFF1B1E26);

  static const accentCyan = Color(0xFF55D7FF);
  static const accentPurple = Color(0xFF7A5CFF);
  static const accentPink = Color(0xFFFF6EC7);
  static const accentPeach = Color(0xFFFFB07A);

  static const muted = Color(0xFF9AA3B2);
  static const danger = Color(0xFFFF5C5C);

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accentCyan, accentPurple, accentPink, accentPeach],
    stops: [0.0, 0.35, 0.70, 1.0],
  );
}
