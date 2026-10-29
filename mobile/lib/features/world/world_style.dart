import 'package:flutter/material.dart';
import '../../core/ui/app_typography.dart';

/// A local visual theme; scoped inventory routes and API contracts are unchanged.
class WorldStyle extends StatelessWidget {
  const WorldStyle({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF4F4F4) : const Color(0xFF111112);
    final muted = dark ? const Color(0xFFA8A8A8) : const Color(0xFF55565B);
    TextStyle text(
      double size, {
      FontWeight weight = FontWeight.w400,
      bool secondary = false,
    }) => TextStyle(
      fontFamily: 'CupertinoSystemText',
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -.25,
      height: 1.35,
      color: secondary ? muted : ink,
    );
    final title = text(30, weight: FontWeight.w600).copyWith(
      fontFamily: 'CupertinoSystemText',
      letterSpacing: -.7,
      height: 1.15,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: ink.withValues(alpha: .10), width: .7),
    );
    return AppTypography(
      child: Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.copyWith(
            headlineLarge: title,
            headlineMedium: title.copyWith(fontSize: 26),
            titleLarge: text(20, weight: FontWeight.w600),
            titleMedium: text(17, weight: FontWeight.w500),
            titleSmall: text(15, weight: FontWeight.w500),
            bodyLarge: text(16),
            bodyMedium: text(15),
            bodySmall: text(13, secondary: true),
            labelLarge: text(15, weight: FontWeight.w500),
          ),
          iconTheme: IconThemeData(color: ink, size: 22),
          listTileTheme: ListTileThemeData(
            titleTextStyle: text(16),
            subtitleTextStyle: text(13, secondary: true),
            iconColor: muted,
            minVerticalPadding: 12,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            hintStyle: text(16, secondary: true),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(borderSide: BorderSide(color: ink)),
            fillColor: ink.withValues(alpha: .035),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: ink,
              textStyle: text(15),
              minimumSize: const Size(44, 44),
              shape: const StadiumBorder(),
            ),
          ),
          popupMenuTheme: PopupMenuThemeData(
            color: dark ? const Color(0xFF262626) : const Color(0xF2FFFFFF),
            surfaceTintColor: Colors.transparent,
            textStyle: text(16),
            elevation: 12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          bottomSheetTheme: theme.bottomSheetTheme.copyWith(
            backgroundColor: dark
                ? const Color(0xFF262626)
                : const Color(0xF7FFFFFF),
            surfaceTintColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
          ),
          dividerTheme: DividerThemeData(
            color: ink.withValues(alpha: .09),
            thickness: .5,
            space: 24,
          ),
        ),
        child: child,
      ),
    );
  }
}
