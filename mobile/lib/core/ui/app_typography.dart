import 'package:flutter/material.dart';

/// Native iOS SF Pro (Flutter's Apple system-font alias) for every app surface.
/// One weight policy for app text, framework controls and editable text.
/// Weights stay regular regardless of OS Bold Text. Other
/// accessibility preferences and text scaling stay intact.
class AppTypography extends StatelessWidget {
  const AppTypography({
    super.key,
    required this.child,
    this.bodyPointSize,
    this.captionPointSize,
  });

  final Widget child;
  final double? bodyPointSize;
  final double? captionPointSize;

  static double bodySizeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TypographySizes>()?.body ??
      bodySize;
  static double captionSizeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TypographySizes>()?.caption ??
      captionSize;

  static const double bodySize = 16;
  static const double captionSize = 13;
  static const double titleSize = 20;
  static const String fontFamily = 'CupertinoSystemText';
  // Ordinary body, form and control text shares one default size. Deliberate
  // captions and larger headings/hero values keep their hierarchy and scaling.
  static double? standardSize(
    double? size, {
    double body = bodySize,
    double caption = captionSize,
  }) {
    if (size == null) return null;
    if (size >= 12 && size < 14) return caption;
    if (size >= 14 && size < 20) return body;
    if (size >= 20 && size < 24) return titleSize;
    return size;
  }

  static FontWeight _weight(TextStyle style, {bool body = false}) {
    return FontWeight.w400;
  }

  static TextStyle styleOf(BuildContext context, TextStyle? style) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final result = (style ?? const TextStyle()).copyWith(
      fontWeight: _weight(effective),
      fontStyle: FontStyle.normal,
      letterSpacing:
          effective.fontSize != null &&
              effective.fontSize! >= 14 &&
              effective.fontSize! < 20
          ? 0
          : style?.letterSpacing,
      fontFamily: fontFamily,
      fontSize:
          standardSize(
            effective.fontSize,
            body: bodySizeOf(context),
            caption: captionSizeOf(context),
          ) ??
          bodySizeOf(context),
    );
    return result;
  }

  static TextStyle bodyStyleOf(BuildContext context, [TextStyle? style]) =>
      styleOf(context, style).copyWith(fontSize: bodySizeOf(context));

  static ThemeData _theme(
    ThemeData theme,
    double bodySize,
    double captionSize,
  ) {
    TextStyle? adapt(TextStyle? style, {bool body = false}) => style?.copyWith(
      fontWeight: _weight(style, body: body),
      fontStyle: FontStyle.normal,
      letterSpacing:
          style.fontSize != null &&
              style.fontSize! >= 14 &&
              style.fontSize! < 20
          ? 0
          : style.letterSpacing,
      fontFamily: fontFamily,
      fontSize: standardSize(
        style.fontSize,
        body: bodySize,
        caption: captionSize,
      ),
    );
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
  Widget build(BuildContext context) {
    final body = bodyPointSize ?? bodySizeOf(context);
    final caption = captionPointSize ?? captionSizeOf(context);
    return _TypographySizes(
      body: body,
      caption: caption,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(boldText: false),
        child: Theme(
          data: _theme(Theme.of(context), body, caption),
          child: bodyPointSize == null
              ? child
              : DefaultTextStyle.merge(
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: body,
                    fontWeight: FontWeight.w400,
                  ),
                  child: child,
                ),
        ),
      ),
    );
  }
}

class _TypographySizes extends InheritedWidget {
  const _TypographySizes({
    required this.body,
    required this.caption,
    required super.child,
  });
  final double body;
  final double caption;
  @override
  bool updateShouldNotify(_TypographySizes oldWidget) =>
      body != oldWidget.body || caption != oldWidget.caption;
}
