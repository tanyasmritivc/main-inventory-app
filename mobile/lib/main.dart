import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_handler/share_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'core/appearance_controller.dart';
import 'core/config.dart';
import 'core/low_stock_notifications.dart';
import 'core/pro_status.dart';
import 'core/ui/app_colors.dart';
import 'core/ui/app_gradient_background.dart';
import 'core/ui/launch_loading_screen.dart';
import 'core/ui/findez_wordmark.dart';
import 'features/auth/auth_page.dart';
import 'features/auth/password_recovery_page.dart';
import 'features/onboarding/onboarding_prefs.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/splash/splash_page.dart';
import 'features/shell/main_shell.dart';
import 'features/scan/shared_spreadsheet_page.dart';
import 'features/sharing/invitation_host.dart';

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

  final appearance = AppearanceController();
  await appearance.load();
  runApp(MyApp(appearance: appearance));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.appearance});

  final AppearanceController? appearance;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<SharedMedia>? _sharedMediaSub;
  StreamSubscription<AuthState>? _shareAuthSub;
  SharedAttachment? _pendingSpreadsheet;
  String? _lastHandledSharePath;
  bool _presentingSharedSpreadsheet = false;
  bool _presentingPasswordRecovery = false;
  bool _invitationReady = false;
  late final ApiClient _api;
  late final AppearanceController _appearance;

  @override
  void initState() {
    super.initState();
    _appearance = widget.appearance ?? AppearanceController();
    unawaited(_appearance.load());
    _api = ApiClient(baseUrl: AppConfig.apiBaseUrl);
    _initializeIncomingShares();
    _shareAuthSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      _tryPresentSharedSpreadsheet();
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _presentPasswordRecovery();
      }
    });
  }

  void _presentPasswordRecovery() {
    if (_presentingPasswordRecovery) return;
    _presentingPasswordRecovery = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navigator = _navigatorKey.currentState;
      if (!mounted || navigator == null) {
        _presentingPasswordRecovery = false;
        return;
      }
      await navigator.push<void>(
        MaterialPageRoute(builder: (_) => const PasswordRecoveryPage()),
      );
      _presentingPasswordRecovery = false;
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
    if (widget.appearance == null) _appearance.dispose();
    _sharedMediaSub?.cancel();
    _shareAuthSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppearanceScope(
      controller: _appearance,
      child: AnimatedBuilder(
        animation: _appearance,
        builder: (context, _) => MaterialApp(
          navigatorKey: _navigatorKey,
          scaffoldMessengerKey: _messengerKey,
          debugShowCheckedModeBanner: false,
          title: 'FindEZ',
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: _appearance.textScaler(
                  MediaQuery.textScalerOf(context),
                ),
              ),
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: Theme.of(context).brightness == Brightness.light
                    ? SystemUiOverlayStyle.dark
                    : SystemUiOverlayStyle.light,
                child: GestureDetector(
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: InvitationHost(
                    api: _api,
                    navigatorKey: _navigatorKey,
                    ready: _invitationReady,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
          themeMode: _appearance.themeMode,
          theme: AppTheme.create(Brightness.light),
          darkTheme: AppTheme.create(Brightness.dark),
          home: _SplashGate(
            api: _api,
            onReady: () {
              if (mounted) setState(() => _invitationReady = true);
            },
          ),
        ),
      ),
    );
  }
}

class _SplashGate extends StatefulWidget {
  const _SplashGate({required this.api, required this.onReady});

  final ApiClient api;
  final VoidCallback onReady;

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return LaunchAuthGate(api: widget.api);
    }
    return SplashPage(
      onFinished: () {
        if (!mounted) return;
        setState(() => _done = true);
        widget.onReady();
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
    final muted = AppTheme.foreground(
      context,
      Colors.white.withValues(alpha: 0.72),
    );
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
                    color: AppTheme.adaptive(
                      context,
                      AppColors.surface2.withValues(alpha: 0.92),
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: AppTheme.adaptive(
                        context,
                        Colors.white.withValues(alpha: 0.06),
                      ),
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
                        const FindEZWordmark(),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.adaptive(
                                context,
                                Colors.white.withValues(alpha: 0.85),
                              ),
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

/// Fresh, signed-out installs see onboarding before authentication. Cached
/// sessions and completed introductions keep the existing returning-user flow.
class LaunchAuthGate extends StatefulWidget {
  const LaunchAuthGate({super.key, required this.api});

  final ApiClient api;

  @override
  State<LaunchAuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<LaunchAuthGate> {
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
              isReplay: true,
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
          return ColoredBox(
            color: AppTheme.adaptive(context, const Color(0xFF09090B)),
            child: SafeArea(child: MainShell(api: widget.api)),
          );
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
                        Text(
                          'Something went wrong.',
                          style: TextStyle(
                            color: AppTheme.foreground(context, Colors.white),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _bump,
                          child: Text(
                            'Retry',
                            style: TextStyle(
                              color: AppTheme.foreground(context, Colors.white),
                            ),
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
