import 'package:flutter/material.dart';

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

  // Dark mode colors (existing)
  static const Color darkBg = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF171717);
  static const Color darkSurface2 = Color(0xFF1C1C1E);
  static const Color darkBorder = Color(0x14FFFFFF);
  static const Color darkBorderHover = Color(0x33FFFFFF);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFAEAEB2);
  static const Color darkTextMuted = Color(0xFF8E8E93);
  static const Color darkHint = Color(0xFF636366);

  // Shared accent colors (same in both modes)
  static const Color amber = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF30D158);
  static const Color blue = Color(0xFF2F6FED);

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
      ? const Color(0xFF171717)
      : const Color(0xFFFFFFFF);

  static Color cardBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0x14FFFFFF)
      : const Color(0x1A000000);

  static Color sectionLabel(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF8E8E93)
      : const Color(0x80000000);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
