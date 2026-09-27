import 'package:flutter/material.dart';

/// Mobile visual tokens shared by the light and dark themes.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.bg,
    required this.card,
    required this.raised,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.onAccent,
    required this.ok,
    required this.warn,
    required this.danger,
    required this.info,
  });

  final Color bg, card, raised, line, lineStrong, ink, text2, text3;
  final Color accent, onAccent, ok, warn, danger, info;

  static const double radius = 14;
  static const double rowHeight = 54;
  static const double buttonHeight = 48;
  static const double bottomBarClearance = 86;

  static const light = AppTokens(
    bg: Color(0xFFF7F7F6),
    card: Color(0xFFFFFFFF),
    raised: Color(0xFFF0F0EE),
    line: Color(0xFFE6E6E2),
    lineStrong: Color(0xFFD8D8D3),
    ink: Color(0xFF111112),
    text2: Color(0xFF55555B),
    text3: Color(0xFF8A8A90),
    accent: Color(0xFFE8590C),
    onAccent: Color(0xFFFFFFFF),
    ok: Color(0xFF2F7D5A),
    warn: Color(0xFF8A5A00),
    danger: Color(0xFFC9363E),
    info: Color(0xFF3568B8),
  );

  static const Color darkBg = Color(0xFF111112);
  static const Color darkCard = Color(0xFF1D1D1E);
  static const Color darkRaised = Color(0xFF29292B);
  static const Color darkLine = Color(0xFF343437);
  static const Color darkLineStrong = Color(0xFF48484B);
  static const Color darkInk = Color(0xFFF7F7F6);
  static const Color darkText2 = Color(0xFFB7B7BC);
  static const Color darkText3 = Color(0xFF919197);
  static const Color darkAccent = Color(0xFFE8590C);
  static const Color darkOnAccent = Color(0xFFFFFFFF);
  static const Color darkOk = Color(0xFF68B98E);
  static const Color darkWarn = Color(0xFFE1AA52);
  static const Color darkDanger = Color(0xFFF0787E);
  static const Color darkInfo = Color(0xFF82A9EE);

  static const dark = AppTokens(
    bg: darkBg,
    card: darkCard,
    raised: darkRaised,
    line: darkLine,
    lineStrong: darkLineStrong,
    ink: darkInk,
    text2: darkText2,
    text3: darkText3,
    accent: darkAccent,
    onAccent: darkOnAccent,
    ok: darkOk,
    warn: darkWarn,
    danger: darkDanger,
    info: darkInfo,
  );

  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>()!;

  @override
  AppTokens copyWith({
    Color? bg,
    Color? card,
    Color? raised,
    Color? line,
    Color? lineStrong,
    Color? ink,
    Color? text2,
    Color? text3,
    Color? accent,
    Color? onAccent,
    Color? ok,
    Color? warn,
    Color? danger,
    Color? info,
  }) => AppTokens(
    bg: bg ?? this.bg,
    card: card ?? this.card,
    raised: raised ?? this.raised,
    line: line ?? this.line,
    lineStrong: lineStrong ?? this.lineStrong,
    ink: ink ?? this.ink,
    text2: text2 ?? this.text2,
    text3: text3 ?? this.text3,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    ok: ok ?? this.ok,
    warn: warn ?? this.warn,
    danger: danger ?? this.danger,
    info: info ?? this.info,
  );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

class AppTheme {
  static ThemeData get light => _build(AppTokens.light, Brightness.light);
  static ThemeData get dark => _build(AppTokens.dark, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final text = base.textTheme
        .apply(fontFamily: 'Inter')
        .copyWith(
          displaySmall: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 32,
            fontWeight: FontWeight.w300,
          ),
          headlineSmall: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 25,
            fontWeight: FontWeight.w400,
          ),
          titleLarge: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 25,
            fontWeight: FontWeight.w400,
          ),
          titleMedium: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
          titleSmall: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          bodySmall: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          labelLarge: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          labelMedium: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        )
        .apply(bodyColor: t.ink, displayColor: t.ink);
    return base.copyWith(
      extensions: [t],
      scaffoldBackgroundColor: t.bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: t.accent,
        onPrimary: t.onAccent,
        secondary: t.ink,
        onSecondary: t.card,
        error: t.danger,
        onError: t.card,
        surface: t.card,
        onSurface: t.ink,
      ),
      textTheme: text,
      primaryTextTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: text.titleMedium?.copyWith(color: t.ink),
      ),
      cardTheme: CardThemeData(
        color: t.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
      ),
      dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        tileColor: t.card,
        textColor: t.ink,
        iconColor: t.text2,
        minVerticalPadding: 10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        titleTextStyle: text.bodyMedium,
        subtitleTextStyle: text.bodySmall?.copyWith(color: t.text2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.card,
        hintStyle: text.bodyMedium?.copyWith(color: t.text3),
        labelStyle: text.bodySmall?.copyWith(color: t.text2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.accent),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.onAccent,
          minimumSize: const Size(0, AppTokens.buttonHeight),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.ink,
          minimumSize: const Size(0, AppTokens.buttonHeight),
          side: BorderSide(color: t.lineStrong),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: t.ink),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleMedium,
        contentTextStyle: text.bodyMedium?.copyWith(color: t.text2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.card,
        modalBackgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.raised,
        contentTextStyle: text.bodyMedium,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.raised,
        selectedColor: t.accent,
        side: BorderSide(color: t.line),
        labelStyle: text.bodySmall,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: t.accent),
      tabBarTheme: TabBarThemeData(
        labelColor: t.ink,
        unselectedLabelColor: t.text2,
        indicatorColor: t.accent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        elevation: 0,
      ),
    );
  }

  static Color bg(BuildContext context) => AppTokens.of(context).bg;
  static Color surface(BuildContext context) => AppTokens.of(context).card;
  static Color surface2(BuildContext context) => AppTokens.of(context).raised;
  static Color border(BuildContext context) => AppTokens.of(context).line;
  static Color borderHover(BuildContext context) =>
      AppTokens.of(context).lineStrong;
  static Color textPrimary(BuildContext context) => AppTokens.of(context).ink;
  static Color textSecondary(BuildContext context) =>
      AppTokens.of(context).text2;
  static Color textMuted(BuildContext context) => AppTokens.of(context).text3;
  static Color cardBg(BuildContext context) => AppTokens.of(context).card;
  static Color cardBorder(BuildContext context) => AppTokens.of(context).line;
  static Color sectionLabel(BuildContext context) =>
      AppTokens.of(context).text2;
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
