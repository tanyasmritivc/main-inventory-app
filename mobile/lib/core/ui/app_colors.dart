import 'package:flutter/material.dart';

class AppColors {
  static const background = Colors.black;
  static const surface = Color(0xFF171717);
  static const surface2 = Color(0xFF1C1C1E);
  static const chip = Color(0xFF1C1C1E);
  static const swipe = Color(0x1AFFFFFF);

  static const border = Color(0x14FFFFFF);
  static const accent = Color(0xFF2F6FED);
  static const primaryText = Colors.white;
  static const muted = Color(0xFF8E8E93);
  static const hint = Color(0xFF636366);

  static const danger = Color(0xFFFF3B30);

  static const blue = Color(0xFF2F6FED);
  static const indigo = Color(0xFF2F6FED);
  static const purple = Color(0xFFBF5AF2);
  static const orange = Color(0xFFFF9F0A);
  static const pink = Color(0xFFFF375F);

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accent, accent],
  );
}
