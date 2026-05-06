import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'core/ui/app_colors.dart';
import 'core/ui/app_gradient_background.dart';
import 'core/ui/launch_loading_screen.dart';
import 'features/auth/auth_page.dart';
import 'features/onboarding/onboarding_prefs.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/splash/splash_page.dart';
import 'features/shell/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const launchMode = int.fromEnvironment('LAUNCH_MODE', defaultValue: 2);
  if (launchMode == 0) {
    runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: Text('SAFE MODE')),
        ),
      ),
    );
    return;
  }

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  if (launchMode == 1) {
    runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: Text('SAFE MODE (Supabase OK)')),
        ),
      ),
    );
    return;
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showStartupBanner = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showStartupBanner = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final api = ApiClient(baseUrl: AppConfig.apiBaseUrl);

    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    const bg = AppColors.background;
    const surface = AppColors.surface;
    const surface2 = AppColors.surface2;

    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.muted,
      surface: surface,
      error: AppColors.danger,
    );

    final darkTheme = ThemeData(
        fontFamily: '.SF Pro Text',
        brightness: Brightness.dark,
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        splashFactory: InkRipple.splashFactory,
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.1,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.1,
          ),
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
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.1,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF08090E),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.muted),
          actionsIconTheme: IconThemeData(color: AppColors.muted),
          titleTextStyle: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryText,
            letterSpacing: 0,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.surface2,
          thickness: 0.5,
          space: 0.5,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          prefixIconColor: AppColors.muted,
          hintStyle: TextStyle(color: AppColors.hint),
          labelStyle: TextStyle(color: AppColors.muted),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
            borderSide: BorderSide(
              color: AppColors.surface2,
              width: 0.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
            borderSide: BorderSide(
              color: AppColors.surface2,
              width: 0.5,
            ),
          ),
        ),
        cardTheme: CardThemeData(
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
            backgroundColor: surface2,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: surface,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.00),
              width: 0,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: surface2,
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: surface2,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.background,
          indicatorColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontFamily: '.SF Pro Text',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? AppColors.accent
                  : AppColors.hint,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.accent
                  : AppColors.hint,
            ),
          ),
        ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FindEZ',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            boldText: false,
            textScaler: TextScaler.linear(1.0),
          ),
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),
              if (_showStartupBanner)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: true,
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: 2,
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                          color: AppColors.accent.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      theme: darkTheme,
      home: _SplashGate(api: api),
    );
  }
}

class _SplashGate extends StatefulWidget {
  const _SplashGate({required this.api});

  final ApiClient api;

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return _AuthGate(api: widget.api);
    }
    return SplashPage(
      onFinished: () {
        if (!mounted) return;
        setState(() => _done = true);
      },
    );
  }
}

class _AuthGateLoading extends StatefulWidget {
  const _AuthGateLoading({required this.message});

  final String message;

  @override
  State<_AuthGateLoading> createState() => _AuthGateLoadingState();
}

class _AuthGateLoadingState extends State<_AuthGateLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Colors.white.withValues(alpha: 0.72);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_c.value);
              final scale = 0.985 + (t * 0.015);
              return Transform.scale(
                scale: scale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface2.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'FindEZ',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: muted,
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.api});

  final ApiClient api;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  int _refresh = 0;
  Future<bool>? _onboardingCompletedFuture;
  String? _onboardingFutureForUserId;

  void _bump() {
    setState(() {
      _refresh++;
      _onboardingCompletedFuture = OnboardingPrefs.isCompleted();
    });
  }

  void _ensureOnboardingFuture() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (_onboardingCompletedFuture == null) {
      _onboardingFutureForUserId = uid;
      _onboardingCompletedFuture = OnboardingPrefs.isCompleted();
      return;
    }

    if (uid != null && uid.isNotEmpty && _onboardingFutureForUserId != uid) {
      _onboardingFutureForUserId = uid;
      _onboardingCompletedFuture = OnboardingPrefs.isCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (snapshot.connectionState == ConnectionState.waiting &&
            session == null) {
          return const AppGradientBackground(child: LaunchLoadingScreen());
        }
        if (session != null) {
          return AppGradientBackground(child: MainShell(api: widget.api));
        }

        _ensureOnboardingFuture();
        return AppGradientBackground(
          child: FutureBuilder<bool>(
            key: ValueKey(_refresh),
            future: _onboardingCompletedFuture,
            builder: (context, onboardingSnap) {
              if (!onboardingSnap.hasData) {
                return const LaunchLoadingScreen(message: 'Getting things ready…');
              }
              final completed = onboardingSnap.data ?? false;
              if (!completed) {
                return OnboardingPage(onFinished: _bump);
              }
              return AuthPage(onAuthChanged: _bump);
            },
          ),
        );
      },
    );
  }
}
