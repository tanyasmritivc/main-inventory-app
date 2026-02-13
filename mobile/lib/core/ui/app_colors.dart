import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0E111A);
  static const surface = Color(0xFF141826);
  static const surface2 = Color(0xFF1A2030);
  static const chip = Color(0xFF121317);
  static const swipe = Color(0xFF1B1C22);

  static const accentBlue = Color(0xFF4F7DFF);
  static const accentPurple = Color(0xFF7A5CFF);
  static const accentPink = Color(0xFFFF4FD8);

  static const muted = Color(0xFF9AA3B2);
  static const danger = Color(0xFFFF5C5C);

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accentBlue, accentPurple, accentPink],
  );
}
