import 'package:flutter/material.dart';

/// The complete interior palette, with phone surfaces for Flutter pages.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.ink,
    required this.paper,
    required this.s1,
    required this.s2,
    required this.s3,
    required this.line,
    required this.line2,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.accentText,
    required this.accentSoft,
    required this.accentLine,
    required this.ok,
    required this.warn,
    required this.danger,
    required this.info,
    required this.bg,
    required this.card,
    required this.separator,
  });

  final Color ink, paper, s1, s2, s3, line, line2, text2, text3;
  final Color accent, accentText, accentSoft, accentLine;
  final Color ok, warn, danger, info;
  final Color bg, card, separator;

  // Compatibility names used by existing mobile surfaces.
  Color get raised => s2;
  Color get lineStrong => line2;
  Color get onAccent => const Color(0xFF111112);

  static const double radius = 14;
  static const double rowHeight = 54;
  static const double buttonHeight = 48;
  static const double bottomBarClearance = 86;

  static const light = AppTokens(
    ink: Color(0xFF111112),
    paper: Color(0xFFFFFFFF),
    s1: Color(0xFFF7F7F6),
    s2: Color(0xFFF0F0EE),
    s3: Color(0xFFE9E9E5),
    line: Color(0xFFE6E6E2),
    line2: Color(0xFFD8D8D3),
    text2: Color(0xFF55555B),
    text3: Color(0xFF6A6A70),
    accent: Color(0xFFE8590C),
    accentText: Color(0xFFB8430B),
    accentSoft: Color(0xFFFDF3EC),
    accentLine: Color(0xFFF0D3BC),
    ok: Color(0xFF2F7D5A),
    warn: Color(0xFF8A5A00),
    danger: Color(0xFFC9363E),
    info: Color(0xFF3568B8),
    bg: Color(0xFFF1F1EF),
    card: Color(0xFFFFFFFF),
    separator: Color(0xFFE4E4E0),
  );

  static const dark = AppTokens(
    ink: Color(0xFFF4F4F2),
    paper: Color(0xFF0E0E10),
    s1: Color(0xFF161619),
    s2: Color(0xFF1D1D21),
    s3: Color(0xFF25252A),
    line: Color(0xFF26262B),
    line2: Color(0xFF33333A),
    text2: Color(0xFFA6A6AE),
    text3: Color(0xFF84848C),
    accent: Color(0xFFFF7A33),
    accentText: Color(0xFFFF7A33),
    accentSoft: Color(0xFF241610),
    accentLine: Color(0xFF4A2D1A),
    ok: Color(0xFF5FBF92),
    warn: Color(0xFFD9A441),
    danger: Color(0xFFF0737C),
    info: Color(0xFF6E9EE8),
    bg: Color(0xFF08080A),
    card: Color(0xFF17171B),
    separator: Color(0xFF26262B),
  );

  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>()!;

  @override
  AppTokens copyWith({
    Color? ink,
    Color? paper,
    Color? s1,
    Color? s2,
    Color? s3,
    Color? line,
    Color? line2,
    Color? text2,
    Color? text3,
    Color? accent,
    Color? accentText,
    Color? accentSoft,
    Color? accentLine,
    Color? ok,
    Color? warn,
    Color? danger,
    Color? info,
    Color? bg,
    Color? card,
    Color? separator,
  }) => AppTokens(
    ink: ink ?? this.ink,
    paper: paper ?? this.paper,
    s1: s1 ?? this.s1,
    s2: s2 ?? this.s2,
    s3: s3 ?? this.s3,
    line: line ?? this.line,
    line2: line2 ?? this.line2,
    text2: text2 ?? this.text2,
    text3: text3 ?? this.text3,
    accent: accent ?? this.accent,
    accentText: accentText ?? this.accentText,
    accentSoft: accentSoft ?? this.accentSoft,
    accentLine: accentLine ?? this.accentLine,
    ok: ok ?? this.ok,
    warn: warn ?? this.warn,
    danger: danger ?? this.danger,
    info: info ?? this.info,
    bg: bg ?? this.bg,
    card: card ?? this.card,
    separator: separator ?? this.separator,
  );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      ink: Color.lerp(ink, other.ink, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      s1: Color.lerp(s1, other.s1, t)!,
      s2: Color.lerp(s2, other.s2, t)!,
      s3: Color.lerp(s3, other.s3, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentLine: Color.lerp(accentLine, other.accentLine, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
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
      dividerTheme: DividerThemeData(
        color: t.separator,
        thickness: 1,
        space: 1,
      ),
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
          borderSide: BorderSide(color: t.separator),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.separator),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.accent),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.ink,
          foregroundColor: t.paper,
          minimumSize: const Size(0, AppTokens.buttonHeight),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.ink,
          foregroundColor: t.paper,
          minimumSize: const Size(0, AppTokens.buttonHeight),
          textStyle: text.labelLarge,
          elevation: 0,
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
        selectedColor: t.ink,
        side: BorderSide(color: t.separator),
        labelStyle: text.bodySmall?.copyWith(
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected) ? t.paper : t.ink,
          ),
        ),
        checkmarkColor: t.paper,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: t.accent),
      tabBarTheme: TabBarThemeData(
        labelColor: t.ink,
        unselectedLabelColor: t.text2,
        indicatorColor: t.accent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.ink,
        foregroundColor: t.paper,
        elevation: 0,
      ),
    );
  }

  static Color bg(BuildContext context) => AppTokens.of(context).bg;
  static Color surface(BuildContext context) => AppTokens.of(context).card;
  static Color surface2(BuildContext context) => AppTokens.of(context).raised;
  static Color border(BuildContext context) => AppTokens.of(context).separator;
  static Color borderHover(BuildContext context) =>
      AppTokens.of(context).lineStrong;
  static Color textPrimary(BuildContext context) => AppTokens.of(context).ink;
  static Color textSecondary(BuildContext context) =>
      AppTokens.of(context).text2;
  static Color textMuted(BuildContext context) => AppTokens.of(context).text3;
  static Color cardBg(BuildContext context) => AppTokens.of(context).card;
  static Color cardBorder(BuildContext context) =>
      AppTokens.of(context).separator;
  static Color sectionLabel(BuildContext context) =>
      AppTokens.of(context).text2;
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
