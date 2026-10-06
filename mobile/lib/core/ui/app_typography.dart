import 'package:flutter/material.dart';

/// One weight policy for app text, framework controls and editable text.
/// The real device preference stays in this scope while Flutter's blanket
/// w700 override is suppressed below it. Text scaling is never replaced.
class AppTypography extends StatelessWidget {
  const AppTypography({super.key, required this.child});

  final Widget child;

  static bool boldTextOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_TypographyPreference>()
          ?.boldText ??
      MediaQuery.boldTextOf(context);

  static FontWeight _weight(
    TextStyle style,
    bool boldText, {
    bool body = false,
    FontWeight? boldWeight,
  }) {
    final normal = style.fontWeight ?? FontWeight.w400;
    if (boldText) {
      return boldWeight ??
          (!body &&
                  (normal.value >= FontWeight.w600.value ||
                      (style.fontSize ?? 0) >= 20)
              ? FontWeight.w600
              : FontWeight.w500);
    }
    return normal.value > FontWeight.w600.value ? FontWeight.w600 : normal;
  }

  static TextStyle styleOf(
    BuildContext context,
    TextStyle? style, {
    FontWeight? boldWeight,
  }) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    return (style ?? const TextStyle()).copyWith(
      fontWeight: _weight(
        effective,
        boldTextOf(context),
        boldWeight: boldWeight,
      ),
    );
  }

  static TextStyle bodyStyleOf(BuildContext context, [TextStyle? style]) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    return (style ?? const TextStyle()).copyWith(
      fontWeight: _weight(effective, boldTextOf(context), body: true),
    );
  }

  static ThemeData _theme(ThemeData theme, bool boldText) {
    TextStyle? adapt(TextStyle? style, {bool body = false}) =>
        style?.copyWith(fontWeight: _weight(style, boldText, body: body));
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
    final input = theme.inputDecorationTheme;
    return theme.copyWith(
      textTheme: textTheme(theme.textTheme),
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
  Widget build(BuildContext context) {
    final boldText = boldTextOf(context);
    return _TypographyPreference(
      boldText: boldText,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(boldText: false),
        child: Theme(data: _theme(Theme.of(context), boldText), child: child),
      ),
    );
  }
}

class _TypographyPreference extends InheritedWidget {
  const _TypographyPreference({required this.boldText, required super.child});

  final bool boldText;

  @override
  bool updateShouldNotify(_TypographyPreference oldWidget) =>
      boldText != oldWidget.boldText;
}
