import 'package:flutter/material.dart';

import 'ui/app_colors.dart';

class AppTheme {
  // Light mode colors
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFE5E5EA);
  static const Color lightBorder = Color(0x33000000);
  static const Color lightBorderHover = Color(0x66000000);
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF636366);
  static const Color lightTextMuted = Color(0xFF8E8E93);
  static const Color lightHint = Color(0xFFAEAEB2);

  // Dark mode colors follow the shared FindEZ product tokens.
  static const Color darkBg = AppColors.background;
  static const Color darkSurface = AppColors.surface;
  static const Color darkSurface2 = AppColors.surface2;
  static const Color darkBorder = AppColors.border;
  static const Color darkBorderHover = AppColors.borderStrong;
  static const Color darkTextPrimary = AppColors.primaryText;
  static const Color darkTextSecondary = AppColors.muted;
  static const Color darkTextMuted = AppColors.hint;
  static const Color darkHint = AppColors.hint;

  // Shared accent colors (same in both modes)
  static const Color amber = AppColors.warning;
  static const Color danger = AppColors.danger;
  static const Color success = AppColors.success;
  static const Color blue = AppColors.accent;

  // Adaptive helpers
  static Color bg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBg : lightBg;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkSurface
      : lightSurface;

  static Color surface2(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkSurface2
      : lightSurface2;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkBorder
      : lightBorder;

  static Color borderHover(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkBorderHover
      : lightBorderHover;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkTextPrimary
      : lightTextPrimary;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkTextSecondary
      : lightTextSecondary;

  static Color textMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkTextMuted
      : lightTextMuted;

  static Color cardBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.surface
      : const Color(0xFFFFFFFF);

  static Color cardBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.border
      : const Color(0x1A000000);

  static Color sectionLabel(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.hint
      : const Color(0x80000000);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
