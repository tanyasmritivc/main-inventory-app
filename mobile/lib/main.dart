import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';
import 'package:share_handler/share_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'core/theme_preference.dart';
import 'core/config.dart';
import 'core/low_stock_notifications.dart';
import 'core/pro_status.dart';
import 'core/ui/app_colors.dart';
import 'core/ui/visual_surfaces.dart';
import 'core/ui/launch_loading_screen.dart';
import 'features/auth/password_recovery_page.dart';
import 'features/onboarding/onboarding_prefs.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/splash/splash_page.dart';
import 'features/shell/main_shell.dart';
import 'features/import/shared_spreadsheet_page.dart';
import 'features/teams/team_workspace_page.dart';

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
  await ThemePreference.load();
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
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<SharedMedia>? _sharedMediaSub;
  StreamSubscription<Uri>? _inviteLinkSub;
  StreamSubscription<AuthState>? _shareAuthSub;
  SharedAttachment? _pendingSpreadsheet;
  String? _lastHandledSharePath;
  bool _presentingSharedSpreadsheet = false;
  bool _presentingPasswordRecovery = false;
  bool _presentingTeamInvite = false;
  String? _pendingTeamInviteCode;
  late final ApiClient _api;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(baseUrl: AppConfig.apiBaseUrl);
    _initializeIncomingShares();
    _initializeIncomingLinks();
    _shareAuthSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      _tryPresentSharedSpreadsheet();
      _tryPresentTeamInvite();
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _presentPasswordRecovery();
      }
    });
  }

  Future<void> _initializeIncomingLinks() async {
    final appLinks = AppLinks();
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) _queueTeamInvite(initial);
    } catch (error) {
      debugPrint('[TeamInvite] initial link failed: $error');
    }
    _inviteLinkSub = appLinks.uriLinkStream.listen(
      _queueTeamInvite,
      onError: (Object error) {
        debugPrint('[TeamInvite] link stream failed: $error');
      },
    );
  }

  void _queueTeamInvite(Uri uri) {
    String code = '';
    if (uri.scheme == 'findez' && uri.host == 'team-invite') {
      code = uri.queryParameters['code'] ?? '';
    } else if ((uri.host == 'findez.ai' || uri.host == 'www.findez.ai') &&
        uri.pathSegments.length >= 3 &&
        uri.pathSegments[0] == 'join' &&
        uri.pathSegments[1] == 'team') {
      code = uri.pathSegments[2];
    }
    code = code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (code.length != 6) return;
    _pendingTeamInviteCode = code;
    _tryPresentTeamInvite();
  }

  void _tryPresentTeamInvite() {
    if (_presentingTeamInvite ||
        _pendingTeamInviteCode == null ||
        Supabase.instance.client.auth.currentSession == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _presentingTeamInvite) return;
      final navigator = _navigatorKey.currentState;
      final code = _pendingTeamInviteCode;
      if (navigator == null || code == null) return;
      _presentingTeamInvite = true;
      try {
        final result = await _api.joinTeam(code);
        final membership = Map<String, dynamic>.from(
          result['membership'] ?? const {},
        );
        final teamId = membership['team_id']?.toString() ?? '';
        if (teamId.isEmpty) throw StateError('Team invitation is unavailable');
        _pendingTeamInviteCode = null;
        if (!mounted) return;
        await navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => TeamWorkspacePage(api: _api, initialTeamId: teamId),
          ),
        );
      } catch (error) {
        _pendingTeamInviteCode = null;
        if (!mounted) return;
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('This team invitation is no longer available.'),
          ),
        );
        debugPrint('[TeamInvite] could not join: $error');
      } finally {
        _presentingTeamInvite = false;
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
    _sharedMediaSub?.cancel();
    _inviteLinkSub?.cancel();
    _shareAuthSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemePreference.mode,
      builder: (context, themeMode, _) => MaterialApp(
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _messengerKey,
        debugShowCheckedModeBanner: false,
        title: 'FindEZ',
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(boldText: false),
            child: GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              behavior: HitTestBehavior.translucent,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        themeMode: themeMode,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: _SplashGate(api: _api),
      ),
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
  Future<bool>? _onboardingNeededFuture;
  String? _onboardingFutureForUserId;

  void _bump() {
    setState(() {
      _refresh++;
      _onboardingNeededFuture = _needsOnboarding();
    });
  }

  Future<bool> _needsOnboarding() async =>
      OnboardingPrefs.justSignedUp ||
      await OnboardingPrefs.isPostSignupPending() ||
      await OnboardingPrefs.getPendingCapturePath() != null;

  void _ensureOnboardingFuture() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (_onboardingNeededFuture == null) {
      _onboardingFutureForUserId = uid;
      _onboardingNeededFuture = _needsOnboarding();
      return;
    }

    if (uid != null && uid.isNotEmpty && _onboardingFutureForUserId != uid) {
      _onboardingFutureForUserId = uid;
      _onboardingNeededFuture = _needsOnboarding();
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
          return AppSurfaceBackground(
            child: OnboardingPage(
              api: widget.api,
              saveFirstSpace: false,
              onFinished: () => setState(() => _previewDismissed = true),
            ),
          );
        }
        final session = Supabase.instance.client.auth.currentSession;
        if (snapshot.connectionState == ConnectionState.waiting &&
            session == null) {
          return const AppSurfaceBackground(child: LaunchLoadingScreen());
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
            return const AppSurfaceBackground(child: LaunchLoadingScreen());
          }
          _ensureOnboardingFuture();
          return AppSurfaceBackground(
            child: FutureBuilder<bool>(
              key: ValueKey(_refresh),
              future: _onboardingNeededFuture,
              builder: (context, onboardingSnap) {
                if (!onboardingSnap.hasData) {
                  return const LaunchLoadingScreen();
                }
                if (onboardingSnap.data!) {
                  return OnboardingPage(api: widget.api, onFinished: _bump);
                }
                return MainShell(api: widget.api);
              },
            ),
          );
        }
        return AppSurfaceBackground(
          child: OnboardingPage(api: widget.api, onFinished: _bump),
        );
      },
    );
  }
}
