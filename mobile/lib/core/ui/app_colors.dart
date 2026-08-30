import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF4F4F6);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFFFFFFF);
  static const chip = Color(0xFFFFFFFF);
  static const swipe = Color(0x1A000000);

  static const border = Color(0x14000000);
  static const accent = Color(0xFF40C8E0);
  static const primaryText = Colors.black;
  static const muted = Color(0xFF8E8E93);
  static const hint = Color(0xFF636366);

  static const accentCyan = Color(0xFF55D7FF);
  static const accentPurple = Color(0xFF7B7FF6);
  static const accentPink = Color(0xFFFF6EC7);
  static const accentPeach = Color(0xFFFFB07A);

  static const danger = Color(0xFFFF3B30);

  static const blue = Color(0xFF40C8E0);
  static const indigo = Color(0xFF40C8E0);
  static const purple = Color(0xFFBF5AF2);
  static const teal = Color(0xFF32D74B);
  static const orange = Color(0xFFFF9F0A);
  static const pink = Color(0xFFFF375F);

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accentCyan, accentPurple, accentPink, accentPeach],
    stops: [0.0, 0.35, 0.70, 1.0],
  );
}
