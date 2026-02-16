import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0F1115);
  static const surface = Color(0xFF151821);
  static const surface2 = Color(0xFF1B1F2A);
  static const chip = Color(0xFF151822);
  static const swipe = Color(0xFF1B1E26);

  static const accentBlue = Color(0xFF0D8C6B);
  static const accentPurple = Color(0xFF10A37F);
  static const accentPink = Color(0xFF14B38C);

  static const muted = Color(0xFF9AA3B2);
  static const danger = Color(0xFFFF5C5C);

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accentBlue, accentPurple],
  );
}
