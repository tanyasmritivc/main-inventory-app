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
import 'core/launch_notification_permission.dart';
import 'core/pro_status.dart';
import 'core/ui/app_colors.dart';
import 'core/ui/app_gradient_background.dart';
import 'core/ui/launch_loading_screen.dart';
import 'core/ui/findez_wordmark.dart';
import 'features/auth/password_recovery_page.dart';
import 'features/onboarding/onboarding_prefs.dart';
import 'features/onboarding/onboarding_v5_page.dart';
import 'features/onboarding/onboarding_v5_store.dart';
import 'features/onboarding/chat_onboarding_gate.dart';
import 'features/profile/plans_welcome.dart';
import 'features/splash/splash_page.dart';
import 'features/workspaces/inventory_context_host.dart';
import 'features/scan/shared_spreadsheet_page.dart';
import 'features/sharing/invitation_host.dart';
import 'package:mobile/core/ui/app_text.dart';

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
        home: Scaffold(body: Center(child: AppText('SAFE MODE'))),
      ),
    );
    return;
  }

  AppConfig.validate();
  await LowStockNotifications.initialize();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  await ProStatus.loadCached();

  try {
    await OnboardingPrefs.prepareGuidedTourInstall(
      hasSession: Supabase.instance.client.auth.currentSession != null,
    );
  } catch (_) {
    // Keep the app usable without displaying an unconfirmed automatic tour.
    debugPrint('Could not prepare the one-time guided tour');
  }

  if (launchMode == 1) {
    runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: AppText('SAFE MODE (Supabase OK)'))),
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
    _shareAuthSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        _tryPresentSharedSpreadsheet();
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _presentPasswordRecovery();
        }
      },
      onError: (Object error, StackTrace stack) {
        // LaunchAuthGate presents reconnect/retry without clearing the session.
        debugPrint('Session refresh is temporarily unavailable.');
      },
    );
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
        final selectedApi = await navigator.push<ApiClient>(
          MaterialPageRoute(
            builder: (_) => InventoryContextHost(api: _api, pickOnly: true),
          ),
        );
        if (selectedApi != null && mounted) {
          await navigator.push<bool>(
            MaterialPageRoute(
              builder: (_) => SharedSpreadsheetPage(
                api: selectedApi,
                filePath: attachment.path,
              ),
            ),
          );
        }
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
              child: AppTypography(
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: Theme.of(context).brightness == Brightness.light
                      ? SystemUiOverlayStyle.dark
                      : SystemUiOverlayStyle.light,
                  child: GestureDetector(
                    // Avoid competing with native controls when no keyboard
                    // needs dismissal. The shell hides tabs while it is open.
                    onTap: MediaQuery.viewInsetsOf(context).bottom > 0
                        ? () => FocusManager.instance.primaryFocus?.unfocus()
                        : null,
                    behavior: HitTestBehavior.translucent,
                    child: LaunchNotificationPermission(
                      api: _api,
                      child: InvitationHost(
                        api: _api,
                        navigatorKey: _navigatorKey,
                        ready: _invitationReady,
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
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
                        AppText(
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
  bool _retryingSession = false;
  bool _onboardingActive = false;
  final _onboardingStore = OnboardingV5Store();
  String? _retriedAnswersFor;

  Widget _onboarding() => OnboardingV5Page(
    store: _onboardingStore,
    onFinished: () {
      if (mounted) setState(() => _onboardingActive = false);
    },
  );

  Future<void> _retryAnswers(User user) async {
    try {
      await _onboardingStore.bind(user);
      final method = await _onboardingStore.sync(Supabase.instance.client);
      if (method != null) {
        onboardingEvent('onboarding_completed', {'auth_method': method});
      }
    } catch (_) {
      // The account-bound receipt is retained for the next signed-in launch.
      // This optional preference write must not block access to saved inventory.
      debugPrint('Onboarding answers remain on this device for retry.');
    }
  }

  bool _sessionRetryFailed = false;

  Future<void> _retrySession() async {
    if (_retryingSession) return;
    setState(() {
      _retryingSession = true;
      _sessionRetryFailed = false;
    });
    try {
      await Supabase.instance.client.auth.refreshSession().timeout(
        const Duration(seconds: 20),
      );
    } catch (_) {
      if (mounted) setState(() => _sessionRetryFailed = true);
    } finally {
      if (mounted) setState(() => _retryingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Refresh/network failures are stream errors, not proof of sign-out.
    // Only the auth client's confirmed session state decides authentication.
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (_previewOnboarding || _onboardingActive) return _onboarding();
        final session = Supabase.instance.client.auth.currentSession;
        if (snapshot.connectionState == ConnectionState.waiting &&
            session == null) {
          return const AppGradientBackground(child: LaunchLoadingScreen());
        }
        if (session != null && !session.user.isAnonymous) {
          if (session.isExpired &&
              (snapshot.hasError || _sessionRetryFailed || _retryingSession)) {
            return Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppText('Reconnect to continue'),
                        const SizedBox(height: 12),
                        const AppText(
                          'Your sign-in is saved. Check your connection and try again.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _retryingSession ? null : _retrySession,
                          child: AppText(
                            _retryingSession ? 'Connecting...' : 'Retry',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
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
          if (_retriedAnswersFor != session.user.id) {
            _retriedAnswersFor = session.user.id;
            unawaited(_retryAnswers(session.user));
          }
          return ColoredBox(
            color: AppTheme.adaptive(context, const Color(0xFF09090B)),
            child: PlansWelcomeGate(
              key: ValueKey(session.user.id),
              user: session.user,
              child: ChatOnboardingGate(api: widget.api),
            ),
          );
        }

        _onboardingActive = true;
        return _onboarding();
      },
    );
  }
}
