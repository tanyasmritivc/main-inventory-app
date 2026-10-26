import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// One weight policy for app text, framework controls and editable text.
/// Weights stay regular, medium or semibold regardless of OS Bold Text. Other
/// accessibility preferences and text scaling stay intact.
class AppTypography extends StatelessWidget {
  const AppTypography({super.key, required this.child});

  final Widget child;

  static FontWeight _weight(TextStyle style, {bool body = false}) {
    if (body) return FontWeight.w400;
    final normal = style.fontWeight ?? FontWeight.w400;
    return normal.value > FontWeight.w600.value ? FontWeight.w600 : normal;
  }

  static TextStyle styleOf(BuildContext context, TextStyle? style) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final result = (style ?? const TextStyle()).copyWith(
      fontWeight: _weight(effective),
    );
    return effective.fontFamily == 'GeistMono'
        ? GoogleFonts.geistMono(textStyle: result)
        : result;
  }

  static TextStyle bodyStyleOf(BuildContext context, [TextStyle? style]) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    return (style ?? const TextStyle()).copyWith(
      fontWeight: _weight(effective, body: true),
    );
  }

  static ThemeData _theme(ThemeData theme) {
    TextStyle? adapt(TextStyle? style, {bool body = false}) =>
        style?.copyWith(fontWeight: _weight(style, body: body));
    TextTheme textTheme(TextTheme text) => TextTheme(
      displayLarge: adapt(text.displayLarge),
      displayMedium: adapt(text.displayMedium),
      displaySmall: adapt(text.displaySmall),
      headlineLarge: adapt(text.headlineLarge),
      headlineMedium: adapt(text.headlineMedium),
      headlineSmall: adapt(text.headlineSmall),
      titleLarge: adapt(text.titleLarge),
      titleMedium: adapt(text.titleMedium),
      titleSmall: adapt(text.titleSmall),
      bodyLarge: adapt(text.bodyLarge, body: true),
      bodyMedium: adapt(text.bodyMedium, body: true),
      bodySmall: adapt(text.bodySmall, body: true),
      labelLarge: adapt(text.labelLarge),
      labelMedium: adapt(text.labelMedium),
      labelSmall: adapt(text.labelSmall),
    );
    ButtonStyle? buttonStyle(ButtonStyle? style) => style?.copyWith(
      textStyle: WidgetStateProperty.resolveWith(
        (states) => adapt(style.textStyle?.resolve(states)),
      ),
    );
    final input = theme.inputDecorationTheme;
    return theme.copyWith(
      textTheme: textTheme(theme.textTheme),
      filledButtonTheme: FilledButtonThemeData(
        style: buttonStyle(theme.filledButtonTheme.style),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: buttonStyle(theme.elevatedButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttonStyle(theme.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: buttonStyle(theme.textButtonTheme.style),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: buttonStyle(theme.segmentedButtonTheme.style),
      ),
      floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
        extendedTextStyle: adapt(
          theme.floatingActionButtonTheme.extendedTextStyle,
        ),
      ),
      primaryTextTheme: textTheme(theme.primaryTextTheme),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: adapt(theme.appBarTheme.titleTextStyle),
        toolbarTextStyle: adapt(theme.appBarTheme.toolbarTextStyle),
      ),
      inputDecorationTheme: input.copyWith(
        labelStyle: adapt(input.labelStyle, body: true),
        floatingLabelStyle: adapt(input.floatingLabelStyle, body: true),
        helperStyle: adapt(input.helperStyle, body: true),
        hintStyle: adapt(input.hintStyle, body: true),
        errorStyle: adapt(input.errorStyle, body: true),
        counterStyle: adapt(input.counterStyle, body: true),
        prefixStyle: adapt(input.prefixStyle, body: true),
        suffixStyle: adapt(input.suffixStyle, body: true),
      ),
      dialogTheme: theme.dialogTheme.copyWith(
        titleTextStyle: adapt(theme.dialogTheme.titleTextStyle),
        contentTextStyle: adapt(theme.dialogTheme.contentTextStyle, body: true),
      ),
      listTileTheme: theme.listTileTheme.copyWith(
        titleTextStyle: adapt(theme.listTileTheme.titleTextStyle),
        subtitleTextStyle: adapt(
          theme.listTileTheme.subtitleTextStyle,
          body: true,
        ),
        leadingAndTrailingTextStyle: adapt(
          theme.listTileTheme.leadingAndTrailingTextStyle,
          body: true,
        ),
      ),
      snackBarTheme: theme.snackBarTheme.copyWith(
        contentTextStyle: adapt(
          theme.snackBarTheme.contentTextStyle,
          body: true,
        ),
      ),
      popupMenuTheme: theme.popupMenuTheme.copyWith(
        textStyle: adapt(theme.popupMenuTheme.textStyle),
      ),
      tabBarTheme: theme.tabBarTheme.copyWith(
        labelStyle: adapt(theme.tabBarTheme.labelStyle),
        unselectedLabelStyle: adapt(theme.tabBarTheme.unselectedLabelStyle),
      ),
      chipTheme: theme.chipTheme.copyWith(
        labelStyle: adapt(theme.chipTheme.labelStyle),
        secondaryLabelStyle: adapt(theme.chipTheme.secondaryLabelStyle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(boldText: false),
    child: Theme(data: _theme(Theme.of(context)), child: child),
  );
}
