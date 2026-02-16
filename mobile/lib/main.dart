import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'core/ui/app_colors.dart';
import 'core/ui/app_gradient_background.dart';
import 'features/auth/auth_page.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/onboarding/onboarding_prefs.dart';
import 'features/shell/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  final auth = Supabase.instance.client.auth;
  final ready = Future<void>(() async {
    final sub = auth.onAuthStateChange.listen((_) {});
    try {
      await auth.onAuthStateChange.first.timeout(const Duration(seconds: 2));
    } catch (_) {
      // ignore
    } finally {
      await sub.cancel();
    }
  });
  await ready;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiClient(baseUrl: AppConfig.apiBaseUrl);

    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    const bg = AppColors.background;
    const surface = AppColors.surface;
    const surface2 = AppColors.surface2;
    const accent = AppColors.accentPurple;

    const scheme = ColorScheme.dark(
      primary: accent,
      secondary: AppColors.muted,
      surface: surface,
      error: AppColors.danger,
    );

    return MaterialApp(
      title: 'FindEZ',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        splashFactory: InkSparkle.splashFactory,
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.2),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.1),
          bodyLarge: TextStyle(fontSize: 15, height: 1.35),
          bodyMedium: TextStyle(fontSize: 14, height: 1.35),
          labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.1),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bg,
          surfaceTintColor: bg,
          elevation: 0,
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
        dividerTheme: DividerThemeData(
          color: Colors.white.withValues(alpha: 0.08),
          thickness: 1,
          space: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          prefixIconColor: Colors.white.withValues(alpha: 0.70),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.60)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.00), width: 0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accent.withValues(alpha: 0.55), width: 1.2),
          ),
        ),
        cardTheme: CardTheme(
          color: isIOS ? surface.withValues(alpha: 0.62) : surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Colors.white.withValues(alpha: isIOS ? 0.06 : 0.00),
              width: 1,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.1),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: surface,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.00), width: 0),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: surface2,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: bg,
          indicatorColor: accent.withValues(alpha: 0.14),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.70),
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? accent
                  : Colors.white.withValues(alpha: 0.70),
            ),
          ),
        ),
      ),
      home: _AuthGate(api: api),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return AppGradientBackground(child: MainShell(api: api));
        }

        return FutureBuilder<bool>(
          future: OnboardingPrefs.isCompleted(),
          builder: (context, onboardingSnap) {
            final completed = onboardingSnap.data ?? false;
            return AppGradientBackground(
              child: completed ? const AuthPage() : const OnboardingFlow(),
            );
          },
        );
      },
    );
  }
}
