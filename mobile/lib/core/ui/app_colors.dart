import 'package:flutter/material.dart';

class AppColors {
  static const background = Colors.black;
  static const surface = Color(0xFF171717);
  static const surface2 = Color(0xFF1C1C1E);
  static const chip = Color(0xFF1C1C1E);
  static const swipe = Color(0x1AFFFFFF);

  static const border = Color(0x14FFFFFF);
  static const accent = Color(0xFF0066B3);
  static const primaryText = Colors.white;
  static const muted = Color(0xFF8E8E93);
  static const hint = Color(0xFF636366);

  // Brand palette. Keep these role-based: never rotate them across features.
  static const brandSlate = Color(0xFF417B9B);
  static const brandIce = Color(0xFFC2DAF4);
  static const brandIndigo = Color(0xFF343078);
  static const brandLavender = Color(0xFFB49CED);
  static const brandPeriwinkle = Color(0xFFA5A3DB);
  static const brandViolet = Color(0xFF4A2C8C);
  static const brandMist = Color(0xFFA6C8DD);

  static const danger = Color(0xFFFF3B30);

  static const blue = Color(0xFF0066B3);
  static const indigo = Color(0xFF0066B3);
  static const purple = Color(0xFFBF5AF2);
  static const orange = Color(0xFFFF9F0A);
  static const pink = Color(0xFFFF375F);

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accent, accent],
  );
}
