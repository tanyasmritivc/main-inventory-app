import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF090909);
  static const surface = Color(0xFF141414);
  static const surface2 = Color(0xFF1B1B1B);
  static const surfaceRaised = Color(0xFF242424);
  static const chip = surface2;
  static const swipe = Color(0x1AFFFFFF);

  static const border = Color(0x1FFFFFFF);
  static const borderStrong = Color(0x33FFFFFF);
  static const accent = Color(0xFFE8590C);
  static const onAccent = Color(0xFF0B0B0B);
  static const primaryText = Color(0xFFF5F5F5);
  static const muted = Color(0xFFA7A7A7);
  static const hint = Color(0xFF737373);

  // Brand palette. The product stays monochrome except for one orange accent.
  static const brandSlate = Color(0xFF737373);
  static const brandIce = primaryText;
  static const brandIndigo = surfaceRaised;
  static const brandLavender = accent;
  static const brandPeriwinkle = Color(0xFFC7C7C7);
  static const brandViolet = Color(0xFF3A3A3A);
  static const brandMist = muted;

  // Semantic colors. These meanings are stable across every feature.
  static const success = Color(0xFF30D158);
  static const warning = Color(0xFFFF9F0A);
  static const danger = Color(0xFFFF453A);
  static const info = Color(0xFF64D2FF);
  static const ai = accent;
  static const scan = accent;

  static const blue = accent;
  static const indigo = accent;
  static const purple = ai;
  static const orange = warning;
  static const pink = Color(0xFFFF375F);

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accent, accent],
  );
}
