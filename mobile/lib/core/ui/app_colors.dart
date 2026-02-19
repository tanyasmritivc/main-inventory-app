import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0F1115);
  static const surface = Color(0xFF151821);
  static const surface2 = Color(0xFF1B1F2A);
  static const chip = Color(0xFF151822);
  static const swipe = Color(0xFF1B1E26);

  static const accentBlue = Color(0xFF4F5DDA);
  static const accentPurple = Color(0xFF6A58D6);
  static const accentPink = Color(0xFF7A68D8);

  static const muted = Color(0xFF9AA3B2);
  static const danger = Color(0xFFFF5C5C);

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accentBlue, accentPurple],
  );
}
