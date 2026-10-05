import 'package:flutter/material.dart';

import 'brand_colors.dart';

class AppColors {
  static const background = BrandColors.ink;
  static const surface = Color(0xFF1C1C1E);
  static const surface2 = Color(0xFF242426);
  static const chip = surface2;
  static const swipe = Color(0x1AFFFFFF);

  static const border = Color(0xFF363638);
  static const accent = BrandColors.signal;
  static const primaryText = BrandColors.paper;
  static const muted = Color(0xFFAEAEB2);
  static const hint = BrandColors.inkMuted;

  // Semantic colors. These meanings are stable across every feature.
  // Contrast-safe dark variants. Light uses the exact brand status tokens.
  static const success = Color(0xFF75C7A0);
  static const warning = Color(0xFFE2BD75);
  static const danger = Color(0xFFFF858D);
  static const info = muted;
  static const ai = muted;
  static const scan = accent;

  // Compatibility names are neutral, not the retired blue/purple palette.
  static const blue = muted;
  static const indigo = muted;
  static const purple = muted;
  static const orange = warning;
  static const pink = danger;
}
