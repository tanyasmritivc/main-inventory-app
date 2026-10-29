import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/app_colors.dart';
import 'ui/brand_colors.dart';
import 'ui/glass_control.dart';

class AppTheme {
  static ThemeData create(Brightness brightness) {
    Color adapt(Color color) => resolve(brightness, color);
    final bg = adapt(AppColors.background);
    final surface = adapt(AppColors.surface);
    final surface2 = adapt(AppColors.surface2);
    Widget glassBackground(
      BuildContext context,
      Set<WidgetState> states,
      Widget? child,
    ) => GlassControl(
      enabled: !states.contains(WidgetState.disabled),
      child: child ?? const SizedBox.shrink(),
    );

    final scheme = brightness == Brightness.dark
        ? const ColorScheme.dark(
            primary: BrandColors.paper,
            onPrimary: BrandColors.ink,
            primaryContainer: AppColors.surface2,
            onPrimaryContainer: BrandColors.paper,
            secondary: AppColors.muted,
            onSecondary: BrandColors.ink,
            secondaryContainer: AppColors.surface2,
            onSecondaryContainer: BrandColors.paper,
            tertiary: AppColors.muted,
            onTertiary: BrandColors.ink,
            tertiaryContainer: AppColors.surface2,
            onTertiaryContainer: BrandColors.paper,
            surface: AppColors.surface,
            onSurface: BrandColors.paper,
            onSurfaceVariant: AppColors.muted,
            surfaceContainer: AppColors.surface2,
            surfaceContainerHigh: AppColors.surface2,
            outline: AppColors.muted,
            outlineVariant: AppColors.border,
            error: AppColors.danger,
            onError: BrandColors.ink,
            errorContainer: Color(0xFF2F1D21),
            onErrorContainer: AppColors.danger,
          )
        : const ColorScheme.light(
            primary: BrandColors.ink,
            onPrimary: BrandColors.paper,
            primaryContainer: BrandColors.surface,
            onPrimaryContainer: BrandColors.ink,
            secondary: lightTextSecondary,
            onSecondary: BrandColors.paper,
            secondaryContainer: BrandColors.surface,
            onSecondaryContainer: BrandColors.ink,
            tertiary: lightTextSecondary,
            onTertiary: BrandColors.paper,
            tertiaryContainer: BrandColors.surface,
            onTertiaryContainer: BrandColors.ink,
            surface: lightSurface,
            onSurface: BrandColors.ink,
            onSurfaceVariant: BrandColors.inkSoft,
            surfaceContainer: lightSurface2,
            surfaceContainerHigh: Color(0xFFE6E6E2),
            outline: BrandColors.inkSoft,
            outlineVariant: BrandColors.hairline,
            error: BrandColors.danger,
            onError: BrandColors.paper,
            errorContainer: Color(0xFFFBECEE),
            onErrorContainer: BrandColors.ink,
          );

    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: bg,
      splashFactory: InkRipple.splashFactory,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        ),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ).apply(fontFamily: 'Inter'),
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
          fontWeight: FontWeight.w500,
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
          borderSide: BorderSide(
            color: accentForegroundFor(brightness),
            width: 1,
          ),
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
        backgroundColor: accentTintFor(brightness),
        foregroundColor: adapt(Colors.white),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: navigationTintFor(brightness),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: navigationForegroundFor(brightness),
              fontSize: 11,
              fontWeight: FontWeight.w500,
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
            return IconThemeData(
              color: navigationForegroundFor(brightness),
              size: 22,
            );
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
          backgroundColor: Colors.transparent,
          foregroundColor: adapt(Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ).copyWith(backgroundBuilder: glassBackground),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: adapt(Colors.white),
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ).copyWith(backgroundBuilder: glassBackground),
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
          foregroundColor: adapt(AppColors.primaryText),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: adapt(AppColors.surface),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: TextStyle(
          color: adapt(Colors.white),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: adapt(AppColors.muted),
          fontSize: 14,
          height: 1.4,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        // Sheets already draw a handle inside their scrollable content. Native
        // handles are opt-in on simple sheets, never globally duplicated.
        showDragHandle: false,
        dragHandleColor: adapt(AppColors.muted),
        dragHandleSize: Size(36, 4),
      ),
      listTileTheme: ListTileThemeData(
        textColor: adapt(Colors.white),
        iconColor: adapt(AppColors.muted),
        titleTextStyle: TextStyle(
          color: adapt(Colors.white),
          fontSize: 15,
          fontWeight: FontWeight.w500,
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
        indicatorColor: accentForegroundFor(brightness),
        dividerColor: adapt(AppColors.border),
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: adapt(AppColors.surface),
        selectedColor: surface2,
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
          color: adapt(Colors.white),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Light mode colors
  static const Color lightBg = BrandColors.paper;
  static const Color lightSurface = BrandColors.paper;
  static const Color lightSurface2 = BrandColors.surface;
  static const Color lightBorder = BrandColors.hairline;
  static const Color lightBorderHover = Color(0x66000000);
  static const Color lightTextPrimary = BrandColors.ink;
  static const Color lightTextSecondary = BrandColors.inkSoft;
  // The guide's muted gray is used for non-text details. These accessible
  // derivatives keep small labels readable on both Paper and Surface.
  static const Color lightTextMuted = Color(0xFF636368);
  static const Color lightHint = Color(0xFF69696E);

  // Dark neutral counterparts of the same monochrome brand.
  static const Color darkBg = BrandColors.night;
  static const Color darkSurface = AppColors.surface;
  static const Color darkSurface2 = AppColors.surface2;
  static const Color darkBorder = AppColors.border;
  static const Color darkBorderHover = Color(0x33FFFFFF);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFAEAEB2);
  static const Color darkTextMuted = Color(0xFFA0A0A6);
  static const Color darkHint = darkTextMuted;

  // Shared semantic colors and neutral action fill.
  static const Color amber = AppColors.warning;
  static const Color danger = AppColors.danger;
  static const Color success = AppColors.success;
  static const Color blue = AppColors.info;
  static const Color action = AppColors.accent;
  static const Color onAction = BrandColors.ink;

  // Controls are neutral. Navigation keeps its separate orange selection.
  static Color accentForegroundFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;
  static Color accentForeground(BuildContext context) =>
      accentForegroundFor(Theme.of(context).brightness);
  static Color accentTintFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFF333335)
      : const Color(0xFFF0F0F2);
  static Color accentTint(BuildContext context) =>
      accentTintFor(Theme.of(context).brightness);

  static Color navigationForegroundFor(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFFF6803D)
      : const Color(0xFFB83E05);
  static Color navigationTintFor(Brightness brightness) => Color.alphaBlend(
    BrandColors.signal.withValues(alpha: 0.08),
    brightness == Brightness.dark ? darkSurface : lightSurface,
  );

  static Color neutralSelectionTint(BuildContext context) =>
      accentTint(context);

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

  static Color cardBg(BuildContext context) => surface(context);

  static Color cardBorder(BuildContext context) => border(context);

  static Color sectionLabel(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkTextMuted
      : lightTextSecondary;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Resolve legacy UI colors without filtering images or printed QR labels.
  /// Both modes share monochrome roles; original media/identity colors are not
  /// passed through this helper.
  static Color adaptive(BuildContext context, Color color) =>
      resolve(Theme.of(context).brightness, color);

  static Color foreground(BuildContext context, Color color) {
    final dark = isDark(context);
    final rgb = color.toARGB32() & 0xFFFFFF;
    // Ink is also a background token. In a foreground role it must stay
    // readable, including when a child receives an already-resolved color.
    if (rgb == 0x111112) return color;
    if (rgb == 0xE6E6E9 || rgb == 0xE8590C) {
      return accentForeground(context).withValues(alpha: color.a);
    }
    if (color.a > 0 &&
        (rgb == 0xFFFFFF ||
            rgb == 0xF2F2F7 ||
            rgb == 0xF2F2F2 ||
            rgb == 0xF1F1F3)) {
      return color.a < 0.8
          ? (dark ? darkTextSecondary : lightTextSecondary)
          : (dark ? darkTextPrimary : lightTextPrimary);
    }
    return resolve(dark ? Brightness.dark : Brightness.light, color);
  }

  static Color resolve(Brightness brightness, Color color) {
    final dark = brightness == Brightness.dark;
    final argb = color.toARGB32();
    final rgb = argb & 0xFFFFFF;
    final alpha = (argb >> 24) & 0xFF;
    Color withAlpha(Color value) => value.withAlpha(alpha);
    if (rgb == 0xFFFFFF ||
        rgb == 0xF2F2F7 ||
        rgb == 0xF2F2F2 ||
        rgb == 0xF1F1F3 ||
        rgb == 0xEEEEEE) {
      return withAlpha(dark ? darkTextPrimary : lightTextPrimary);
    }
    if (rgb == 0) return alpha < 255 ? color : (dark ? darkBg : lightBg);
    switch (rgb) {
      case 0x8C8D92:
        return withAlpha(dark ? darkHint : lightHint);
      case 0x090909:
      case 0x09090B:
      case 0x0A0A0A:
      case 0x0B0B0D:
      case 0x111111:
      case 0x111112:
      case 0x111113:
      case 0x111214:
        return withAlpha(dark ? darkBg : lightBg);
      case 0x131315:
      case 0x131418:
      case 0x151517:
      case 0x171717:
      case 0x171719:
      case 0x18181A:
      case 0x19191B:
      case 0x1C1C1E:
      case 0x262626:
        return withAlpha(dark ? darkSurface : lightSurface);
      case 0x202020:
      case 0x242426:
      case 0x303030:
      case 0x262629:
      case 0x29292E:
      case 0x2A2A2E:
      case 0x2C2C2E:
      case 0x3A3A40:
        return withAlpha(dark ? darkSurface2 : lightSurface2);
      case 0x363638:
        return withAlpha(dark ? darkBorder : lightBorder);
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
      case 0x96969C:
      case 0x999999:
      case 0x9999A2:
      case 0xA1A1AA:
      case 0xAEAEB2:
      case 0xB8B8BD:
      case 0xB8B8C0:
        return withAlpha(dark ? darkTextSecondary : lightTextSecondary);
      case 0x30D158:
      case 0x34D399:
      case 0x59BE96:
      case 0x75C7A0:
      case 0x2F7D5A:
        return withAlpha(dark ? AppColors.success : BrandColors.success);
      case 0xF59E0B:
      case 0xF5A623:
      case 0xFBBF24:
      case 0xFF9F0A:
      case 0xE2AE43:
      case 0xE4AF46:
      case 0xE2BD75:
      case 0x8A5A00:
        return withAlpha(dark ? AppColors.warning : BrandColors.warning);
      case 0xEF4444:
      case 0xFF3B30:
      case 0xFF453A:
      case 0xFF6961:
      case 0xFF375F:
      case 0xF16B74:
      case 0xFF858D:
      case 0xC9363E:
        return withAlpha(dark ? AppColors.danger : BrandColors.danger);
      case 0x64D2FF:
      case 0x64B5FF:
      case 0x6997DD:
      case 0xA78BFA:
      case 0xC084FC:
      case 0x417B9B:
      case 0x343078:
      case 0x4A2C8C:
      case 0x0A84FF:
      case 0x007AFF:
      case 0x8B5CF6:
      case 0xFF7A2F:
        return withAlpha(dark ? darkTextSecondary : lightTextSecondary);
      case 0xE8590C:
        return withAlpha(action);
      case 0x13241E:
        return dark ? const Color(0xFF15281F) : const Color(0xFFEAF3EE);
      case 0x281316:
      case 0x35191B:
        return dark ? const Color(0xFF2F1D21) : const Color(0xFFFBECEE);
      case 0x282110:
        return dark ? const Color(0xFF302719) : const Color(0xFFF7F0DF);
      case 0x102A43:
      case 0x123B63:
      case 0x174A76:
        return dark ? darkSurface2 : lightSurface2;
      default:
        return color; // Brand marks, member colors and media stay unchanged.
    }
  }
}
