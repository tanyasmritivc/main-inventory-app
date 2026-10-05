import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/app_colors.dart';

class AppTheme {
  static ThemeData create(Brightness brightness) {
    Color adapt(Color color) => resolve(brightness, color);
    final bg = adapt(AppColors.background);
    final surface = adapt(AppColors.surface);
    final surface2 = adapt(AppColors.surface2);

    final scheme = brightness == Brightness.dark
        ? const ColorScheme.dark(
            primary: Color(0xFFF2F2F7),
            onPrimary: Color(0xFF1C1C1E),
            secondary: AppColors.muted,
            surface: AppColors.surface,
            surfaceContainer: AppColors.surface2,
            surfaceContainerHigh: Color(0xFF242426),
            error: AppColors.danger,
          )
        : const ColorScheme.light(
            primary: lightTextPrimary,
            onPrimary: lightSurface,
            secondary: lightTextSecondary,
            surface: lightSurface,
            surfaceContainer: lightSurface2,
            surfaceContainerHigh: Color(0xFFE6E6E2),
            error: Color(0xFFB92F37),
          );

    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      splashFactory: InkRipple.splashFactory,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.35,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.35,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.35,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
      appBarTheme: AppBarTheme(
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: adapt(AppColors.muted)),
        actionsIconTheme: IconThemeData(color: adapt(AppColors.muted)),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: adapt(Colors.white),
          letterSpacing: 0,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: adapt(AppColors.border),
        thickness: 0.5,
        space: 0.5,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: adapt(AppColors.surface),
        prefixIconColor: adapt(AppColors.muted),
        hintStyle: TextStyle(color: adapt(AppColors.hint)),
        labelStyle: TextStyle(color: adapt(AppColors.muted)),
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: adapt(AppColors.border), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: adapt(Color(0x99FFFFFF)), width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        color: adapt(AppColors.surface),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: adapt(AppColors.border), width: 0.5),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: adapt(Color(0xCC2C2C2E)),
        foregroundColor: adapt(Colors.white),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: adapt(const Color(0x18FFFFFF)),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: adapt(Colors.white),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            );
          }
          return TextStyle(
            color: adapt(AppColors.muted),
            fontSize: 11,
            fontWeight: FontWeight.w400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: adapt(Colors.white), size: 22);
          }
          return IconThemeData(color: adapt(AppColors.muted), size: 22);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface2,
        contentTextStyle: TextStyle(
          color: adapt(Colors.white),
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: adapt(const Color(0xFFF2F2F7)),
          foregroundColor: adapt(const Color(0xFF1C1C1E)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: adapt(Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: adapt(AppColors.border), width: 1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: adapt(AppColors.surface2),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: TextStyle(
          color: adapt(Colors.white),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: adapt(AppColors.muted),
          fontSize: 14,
          height: 1.4,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: adapt(AppColors.surface2),
        modalBackgroundColor: adapt(AppColors.surface2),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: adapt(AppColors.muted),
        dragHandleSize: Size(36, 4),
      ),
      listTileTheme: ListTileThemeData(
        textColor: adapt(Colors.white),
        iconColor: adapt(AppColors.muted),
        titleTextStyle: TextStyle(
          color: adapt(Colors.white),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          color: adapt(AppColors.muted),
          fontSize: 13,
          height: 1.3,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: adapt(AppColors.surface2),
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        textStyle: TextStyle(
          color: adapt(Colors.white),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: adapt(Color(0xFFF2F2F7)),
        linearTrackColor: adapt(Color(0x1AFFFFFF)),
        circularTrackColor: adapt(Color(0x1AFFFFFF)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: adapt(Colors.white),
        unselectedLabelColor: adapt(AppColors.muted),
        indicatorColor: adapt(AppColors.blue),
        dividerColor: adapt(AppColors.border),
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: adapt(AppColors.surface2),
        selectedColor: adapt(AppColors.blue),
        disabledColor: adapt(AppColors.surface),
        side: BorderSide(color: adapt(AppColors.border)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        labelStyle: TextStyle(
          color: adapt(Colors.white),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Light mode colors
  static const Color lightBg = Color(0xFFF7F7F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFEFEFEE);
  static const Color lightBorder = Color(0xFFE6E6E2);
  static const Color lightBorderHover = Color(0x66000000);
  static const Color lightTextPrimary = Color(0xFF111112);
  static const Color lightTextSecondary = Color(0xFF5B5B60);
  static const Color lightTextMuted = Color(0xFF636368);
  static const Color lightHint = Color(0xFF69696E);

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
      ? const Color(0xFF171717)
      : const Color(0xFFFFFFFF);

  static Color cardBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0x14FFFFFF)
      : const Color(0x1A000000);

  static Color sectionLabel(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF8E8E93)
      : lightTextSecondary;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Resolve legacy UI colors without filtering images or printed QR labels.
  /// Dark appearance stays pixel-compatible with the approved build.
  static Color adaptive(BuildContext context, Color color) =>
      resolve(Theme.of(context).brightness, color);

  static Color foreground(BuildContext context, Color color) {
    if (isDark(context)) return color;
    final rgb = color.toARGB32() & 0xFFFFFF;
    if (color.a > 0 &&
        (rgb == 0xFFFFFF ||
            rgb == 0xF2F2F7 ||
            rgb == 0xF2F2F2 ||
            rgb == 0xF1F1F3)) {
      return color.a < 0.8 ? lightTextSecondary : lightTextPrimary;
    }
    return resolve(Brightness.light, color);
  }

  static Color resolve(Brightness brightness, Color color) {
    if (brightness == Brightness.dark) return color;
    final argb = color.toARGB32();
    final rgb = argb & 0xFFFFFF;
    final alpha = (argb >> 24) & 0xFF;
    Color withAlpha(Color value) => value.withAlpha(alpha);
    if (rgb == 0xFFFFFF ||
        rgb == 0xF2F2F7 ||
        rgb == 0xF2F2F2 ||
        rgb == 0xF1F1F3 ||
        rgb == 0xEEEEEE) {
      return withAlpha(lightTextPrimary);
    }
    if (rgb == 0) return alpha < 255 ? color : lightBg;
    switch (rgb) {
      case 0x090909:
      case 0x09090B:
      case 0x0A0A0A:
      case 0x0B0B0D:
      case 0x111111:
      case 0x111113:
      case 0x111214:
        return withAlpha(lightBg);
      case 0x131315:
      case 0x131418:
      case 0x151517:
      case 0x171717:
      case 0x171719:
      case 0x18181A:
      case 0x19191B:
      case 0x1C1C1E:
        return withAlpha(lightSurface);
      case 0x202020:
      case 0x242426:
      case 0x262629:
      case 0x29292E:
      case 0x2A2A2E:
      case 0x2C2C2E:
      case 0x3A3A40:
        return withAlpha(lightSurface2);
      case 0x4A4A4D:
      case 0x555559:
      case 0x636366:
      case 0x666666:
      case 0x6C6C70:
      case 0x737377:
      case 0x7C7C80:
      case 0x85858E:
      case 0x888888:
      case 0x8E8E93:
      case 0x999999:
      case 0x9999A2:
      case 0xA1A1AA:
      case 0xAEAEB2:
      case 0xB8B8BD:
      case 0xB8B8C0:
        return withAlpha(lightTextSecondary);
      case 0x30D158:
      case 0x34D399:
      case 0x59BE96:
        return withAlpha(const Color(0xFF286F50));
      case 0xF59E0B:
      case 0xF5A623:
      case 0xFBBF24:
      case 0xFF9F0A:
      case 0xE2AE43:
      case 0xE4AF46:
        return withAlpha(const Color(0xFF8A5A00));
      case 0xEF4444:
      case 0xFF3B30:
      case 0xFF453A:
      case 0xFF6961:
      case 0xFF375F:
      case 0xF16B74:
        return withAlpha(const Color(0xFFB92F37));
      case 0x64D2FF:
      case 0x64B5FF:
      case 0x6997DD:
        return withAlpha(const Color(0xFF315D98));
      case 0xA78BFA:
        return withAlpha(const Color(0xFF7254AF));
      case 0xFF7A2F:
        return withAlpha(const Color(0xFFB8490A));
      case 0x13241E:
        return const Color(0xFFEAF3EE);
      case 0x281316:
      case 0x35191B:
        return const Color(0xFFFBECEE);
      case 0x282110:
        return const Color(0xFFF7F0DF);
      case 0x102A43:
      case 0x123B63:
      case 0x174A76:
        return const Color(0xFFEAF0F7);
      default:
        return color; // Brand marks, member colors and media stay unchanged.
    }
  }
}
