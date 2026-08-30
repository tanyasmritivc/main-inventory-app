import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_handler/share_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'core/low_stock_notifications.dart';
import 'core/pro_status.dart';
import 'core/ui/app_colors.dart';
import 'core/ui/app_gradient_background.dart';
import 'core/ui/launch_loading_screen.dart';
import 'features/auth/auth_page.dart';
import 'features/onboarding/onboarding_prefs.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/splash/splash_page.dart';
import 'features/shell/main_shell.dart';
import 'features/scan/shared_spreadsheet_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Async error: $error');
    debugPrintStack(stackTrace: stack);
    return false;
  };

  const launchMode = int.fromEnvironment('LAUNCH_MODE', defaultValue: 2);
  if (launchMode == 0) {
    runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: Text('SAFE MODE'))),
      ),
    );
    return;
  }

  AppConfig.validate();
  await ProStatus.loadCached();
  await LowStockNotifications.initialize();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  if (launchMode == 1) {
    runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: Text('SAFE MODE (Supabase OK)'))),
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
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _showStartupBanner = true;
  Timer? _startupBannerTimer;
  StreamSubscription<SharedMedia>? _sharedMediaSub;
  StreamSubscription<AuthState>? _shareAuthSub;
  SharedAttachment? _pendingSpreadsheet;
  String? _lastHandledSharePath;
  bool _presentingSharedSpreadsheet = false;
  late final ApiClient _api;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(baseUrl: AppConfig.apiBaseUrl);
    _startupBannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showStartupBanner = false);
      }
    });
    _initializeIncomingShares();
    _shareAuthSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _tryPresentSharedSpreadsheet();
    });
  }

  Future<void> _initializeIncomingShares() async {
    final handler = ShareHandlerPlatform.instance;
    try {
      final initial = await handler.getInitialSharedMedia();
      if (initial != null) _queueSharedMedia(initial);
    } catch (error) {
      debugPrint('[ShareImport] initial share failed: $error');
    }
    _sharedMediaSub = handler.sharedMediaStream.listen(
      _queueSharedMedia,
      onError: (Object error) {
        debugPrint('[ShareImport] share stream failed: $error');
      },
    );
  }

  void _queueSharedMedia(SharedMedia media) {
    for (final attachment in media.attachments ?? const []) {
      if (attachment == null) continue;
      final path = attachment.path;
      final extension = path.split('?').first.split('.').last.toLowerCase();
      if (extension != 'xlsx' && extension != 'csv') continue;
      if (path == _lastHandledSharePath) return;
      _pendingSpreadsheet = attachment;
      _tryPresentSharedSpreadsheet();
      return;
    }
  }

  void _tryPresentSharedSpreadsheet() {
    if (_presentingSharedSpreadsheet ||
        _pendingSpreadsheet == null ||
        Supabase.instance.client.auth.currentSession == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _presentingSharedSpreadsheet) return;
      final navigator = _navigatorKey.currentState;
      final attachment = _pendingSpreadsheet;
      if (navigator == null || attachment == null) return;

      _pendingSpreadsheet = null;
      _lastHandledSharePath = attachment.path;
      _presentingSharedSpreadsheet = true;
      try {
        await ShareHandlerPlatform.instance.resetInitialSharedMedia();
        if (!mounted) return;
        await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                SharedSpreadsheetPage(api: _api, filePath: attachment.path),
          ),
        );
      } catch (error) {
        debugPrint('[ShareImport] could not present import: $error');
      } finally {
        _presentingSharedSpreadsheet = false;
        _tryPresentSharedSpreadsheet();
      }
    });
  }

  @override
  void dispose() {
    _startupBannerTimer?.cancel();
    _sharedMediaSub?.cancel();
    _shareAuthSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = AppColors.background;
    const surface = AppColors.surface;
    const surface2 = AppColors.surface2;

    const scheme = ColorScheme.dark(
      primary: AppColors.blue,
      onPrimary: Colors.white,
      secondary: AppColors.muted,
      surface: surface,
      surfaceContainer: surface2,
      surfaceContainerHigh: Color(0xFF242426),
      error: AppColors.danger,
    );

    final darkTheme = ThemeData(
      fontFamily: GoogleFonts.inter().fontFamily,
      brightness: Brightness.dark,
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      splashFactory: InkRipple.splashFactory,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
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
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.muted),
        actionsIconTheme: const IconThemeData(color: AppColors.muted),
        titleTextStyle: TextStyle(
          fontFamily: GoogleFonts.inter().fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
        space: 0.5,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        prefixIconColor: AppColors.muted,
        hintStyle: TextStyle(color: AppColors.hint),
        labelStyle: TextStyle(color: AppColors.muted),
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.blue, width: 1),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0A0A0A),
        indicatorColor: const Color(0x18FFFFFF),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            );
          }
          return const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.white, size: 22);
          }
          return const IconThemeData(color: AppColors.muted, size: 22);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface2,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
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
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface2,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        contentTextStyle: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.4),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface2,
        modalBackgroundColor: AppColors.surface2,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        showDragHandle: true,
        dragHandleColor: AppColors.muted,
        dragHandleSize: Size(36, 4),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white,
        iconColor: AppColors.muted,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        subtitleTextStyle: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.3),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.surface2,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        textStyle: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.blue,
        linearTrackColor: Color(0x1AFFFFFF),
        circularTrackColor: Color(0x1AFFFFFF),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.blue,
        dividerColor: AppColors.border,
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surface2,
        selectedColor: AppColors.blue,
        disabledColor: AppColors.surface,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
        labelStyle: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        secondaryLabelStyle: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'FindEZ',
      builder: (context, child) {
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.translucent,
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
      themeMode: ThemeMode.dark,
      theme: darkTheme,
      darkTheme: darkTheme,
      home: _SplashGate(api: _api),
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
                          style: Theme.of(context).textTheme.headlineSmall
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: muted, height: 1.35),
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
  static const _previewOnboarding = bool.fromEnvironment('PREVIEW_ONBOARDING');
  int _refresh = 0;
  bool _previewDismissed = false;
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
    // acceptable: no hasError branch on the auth stream — Supabase's
    // onAuthStateChange stream does not emit errors in practice; any
    // auth failure surfaces as a signed-out event instead.
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (_previewOnboarding && !_previewDismissed) {
          return AppGradientBackground(
            child: OnboardingPage(
              onFinished: () => setState(() => _previewDismissed = true),
            ),
          );
        }
        final session = Supabase.instance.client.auth.currentSession;
        if (snapshot.connectionState == ConnectionState.waiting &&
            session == null) {
          return const AppGradientBackground(child: LaunchLoadingScreen());
        }
        if (session != null) {
          // If the stream just delivered the initial cached session AND the
          // access token is already expired, Supabase is attempting a
          // background refresh. Show loading instead of MainShell so we
          // don't fire API calls with a stale token — the stream will fire
          // again with either AuthChangeEvent.tokenRefreshed or .signedOut.
          final isInitialStaleSession =
              snapshot.data?.event == AuthChangeEvent.initialSession &&
              session.expiresAt != null &&
              session.expiresAt! <=
                  DateTime.now().millisecondsSinceEpoch ~/ 1000;
          if (isInitialStaleSession) {
            return const AppGradientBackground(child: LaunchLoadingScreen());
          }
          return AppGradientBackground(child: MainShell(api: widget.api));
        }

        _ensureOnboardingFuture();
        return AppGradientBackground(
          child: FutureBuilder<bool>(
            key: ValueKey(_refresh),
            future: _onboardingCompletedFuture,
            builder: (context, onboardingSnap) {
              if (onboardingSnap.hasError) {
                return Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Something went wrong.',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _bump,
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!onboardingSnap.hasData) {
                return const LaunchLoadingScreen(
                  message: 'Getting things ready…',
                );
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
