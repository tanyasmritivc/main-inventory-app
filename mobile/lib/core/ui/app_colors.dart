import 'package:flutter/material.dart';

class AppColors {
  static const background = Colors.black;
  static const surface = Color(0xFF171717);
  static const surface2 = Color(0xFF1C1C1E);
  static const chip = Color(0xFF1C1C1E);
  static const swipe = Color(0x1AFFFFFF);

  static const border = Color(0x14FFFFFF);
  static const accent = Color(0xFF6997DD);
  static const primaryText = Colors.white;
  static const muted = Color(0xFF8E8E93);
  static const hint = Color(0xFF636366);

  // Brand palette. Keep these role-based: never rotate them across features.
  static const brandSlate = Color(0xFF417B9B);
  static const brandIce = Color(0xFFC2DAF4);
  static const brandIndigo = Color(0xFF343078);
  static const brandLavender = Color(0xFF6997DD);
  static const brandPeriwinkle = Color(0xFFA5A3DB);
  static const brandViolet = Color(0xFF4A2C8C);
  static const brandMist = Color(0xFFA6C8DD);

  // Semantic colors. These meanings are stable across every feature.
  static const success = Color(0xFF30D158);
  static const warning = Color(0xFFFF9F0A);
  static const danger = Color(0xFFFF453A);
  static const info = Color(0xFF64D2FF);
  static const ai = Color(0xFF6997DD);
  static const scan = Color(0xFF32ADE6);

  static const blue = accent;
  static const indigo = brandPeriwinkle;
  static const purple = ai;
  static const orange = warning;
  static const pink = Color(0xFFFF375F);

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [brandPeriwinkle, brandLavender],
  );
}
