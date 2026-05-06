import 'package:flutter/material.dart';

class AppColors {
  static const background = Colors.black;
  static const surface = Color(0x0AFFFFFF);
  static const surface2 = Color(0x1AFFFFFF);
  static const chip = Color(0x0AFFFFFF);
  static const swipe = Color(0x1AFFFFFF);

  static const border = Color(0x14FFFFFF);
  static const accent = Colors.white;
  static const primaryText = Colors.white;
  static const muted = Color(0x73FFFFFF);
  static const hint = Color(0x33FFFFFF);

  static const accentCyan = Color(0xFF55D7FF);
  static const accentPurple = Color(0xFF7B7FF6);
  static const accentPink = Color(0xFFFF6EC7);
  static const accentPeach = Color(0xFFFFB07A);

  static const danger = Color(0xFFFF3B30);

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accentCyan, accentPurple, accentPink, accentPeach],
    stops: [0.0, 0.35, 0.70, 1.0],
  );
}
