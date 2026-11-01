// FindEZ theme for Flutter. Add google_fonts to pubspec, then use FindezTheme.light.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FzColors {
  static const ink = Color(0xFF111112);
  static const ink2 = Color(0xFF55565B);
  static const ink3 = Color(0xFF8C8D92);
  static const white = Color(0xFFFFFFFF);
  static const paper = Color(0xFFF7FAFD);
  static const line = Color(0xFFE8E8EA);
  static const orange = Color(0xFFE8590C);
  static const orangeInk = Color(0xFFC2410C);
  static const orangeTint = Color(0xFFFFE8DA);
  static const blue = Color(0xFFA9D6F5);
  static const blueDeep = Color(0xFF6FA9D6);
  static const blueTint = Color(0xFFEEF6FD);
  static const night = Color(0xFF0B0B0D);
  static const success = Color(0xFF1E8E5A);
  static const warning = Color(0xFFF2A33A);
  static const danger = Color(0xFFD93B2B);
}

class FindezTheme {
  static ThemeData get light {
    final base = GoogleFonts.plusJakartaSansTextTheme();
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: FzColors.white,
      colorScheme: const ColorScheme.light(
        primary: FzColors.ink, onPrimary: FzColors.white,
        secondary: FzColors.orange, onSecondary: FzColors.ink,
        tertiary: FzColors.blue, surface: FzColors.white, onSurface: FzColors.ink,
        outline: FzColors.line, error: FzColors.danger,
      ),
      textTheme: base.copyWith(
        displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -1.6, color: FzColors.ink),
        headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -.6, color: FzColors.ink),
        titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: FzColors.ink),
        bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, color: FzColors.ink),
        bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, color: FzColors.ink2),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: FzColors.ink, foregroundColor: FzColors.white,
        shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14))),
      cardTheme: CardThemeData(color: FzColors.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: FzColors.line))),
      chipTheme: const ChipThemeData(backgroundColor: FzColors.orangeTint, labelStyle: TextStyle(color: FzColors.orangeInk, fontWeight: FontWeight.w600)),
    );
  }
}
