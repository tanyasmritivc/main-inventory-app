import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/inventory_cache.dart';
import '../../core/pro_status.dart';
import '../../core/push_notifications.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/glass_card.dart';
import '../activity/activity_page.dart';
import '../chat/chat_page.dart';
import '../checkout/checkout_page.dart';
import '../documents/documents_page.dart';
import '../inventory/inventory_page.dart';
import '../notifications/notifications_page.dart';
import '../onboarding/onboarding_prefs.dart';
import '../profile/privacy_policy_page.dart';
import '../profile/profile_page.dart';
import '../profile/terms_of_service_page.dart';
import '../scan/scan_page.dart';
import '../shopping/shopping_list_page.dart';
import '../showcase/tutorial_controller.dart';
import '../teams/teams_page.dart';
import 'app_destination.dart';
import 'primary_navigation_bar.dart';

enum _MemoryTool { documents, checkouts, lowStock, activity }

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.api,
    this.destinationPagesForTesting,
    this.enableRuntimeServices = true,
  }) : assert(
         destinationPagesForTesting == null ||
             destinationPagesForTesting.length == 5,
       );

  final ApiClient api;

  /// Replaces destination pages in shell widget tests only.
  final List<Widget>? destinationPagesForTesting;

  /// Disables network, push, auth, and tutorial startup in widget tests.
  final bool enableRuntimeServices;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final PageController _pageController;
  StreamSubscription<AuthState>? _authSub;
  AppDestination _currentDestination = initialAppDestination;
  int _inventoryRefreshToken = 0;
  DateTime? _lastInventoryRefreshAt;
  VoidCallback? _resetChatCallback;
  Future<void> Function(Map<String, dynamic>)? _openMemoryDestination;
  bool _hasActiveChat = false;
  int _memorySection = 0;
  VoidCallback? _joinSpaceCallback;
  int _notificationCount = 0;
  bool _openingNotifications = false;
  Timer? _notificationTimer;
  double _pageOpacity = 1;
  int _pageTransitionGeneration = 0;

  Future<void> _prefetchInventoryCache() async {
    try {
      final result = await widget.api.searchItems(query: '');
      InventoryCache.setItems(result.items);
    } catch (_) {
      // Read-only cache warmup. Live destinations show their own error state.
    }
  }

  void _animateTo(AppDestination destination, {bool haptic = false}) {
    if (destination == _currentDestination) return;
    if (haptic) HapticFeedback.selectionClick();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _pageController.jumpToPage(destination.index);
      return;
    }
    final generation = ++_pageTransitionGeneration;
    setState(() => _pageOpacity = 0);
    Future<void>.delayed(const Duration(milliseconds: 90), () {
      if (!mounted || generation != _pageTransitionGeneration) return;
      _pageController.jumpToPage(destination.index);
      setState(() => _pageOpacity = 1);
    });
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: initialAppDestination.index);
    if (widget.enableRuntimeServices) {
      unawaited(_prefetchInventoryCache());
      unawaited(_loadNotificationCount());
      unawaited(_initializePushNotifications());
      _notificationTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => unawaited(_loadNotificationCount()),
      );
      unawaited(_maybeLaunchTutorial());

      // Pop dialogs and sheets before authentication replaces the shell.
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
        state,
      ) {
        if (state.event == AuthChangeEvent.signedOut) {
          InventoryCache.clear();
          ProStatus.reset();
        }
        if (state.event == AuthChangeEvent.signedOut && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(
              context,
              rootNavigator: true,
            ).popUntil((route) => route.isFirst);
          });
        }
      });
    }
  }

  Future<void> _maybeLaunchTutorial() async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (uid.isEmpty) return;
    await _createPendingFirstSpace();
    final postSignupPending = await OnboardingPrefs.isPostSignupPending();
    if (OnboardingPrefs.justSignedUp || postSignupPending) {
      OnboardingPrefs.justSignedUp = false;
      await OnboardingPrefs.setCoachmarkPending(uid, true);
      await OnboardingPrefs.setPostSignupPending(false);
    }
    final pending = await OnboardingPrefs.isCoachmarkPending(uid);
    final seen = await OnboardingPrefs.hasSeenCoachmark(uid);
    if (!pending || seen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await TutorialController.instance.maybeStart(
        userId: uid,
        pageController: _pageController,
        context: context,
      );
    });
  }

  Future<void> _createPendingFirstSpace() async {
    final name = await OnboardingPrefs.getPendingFirstSpaceName();
    if (name == null) return;
    try {
      final spaces = await widget.api.listSpaces();
      final alreadyExists = spaces.any(
        (space) =>
            (space['name'] ?? '').toString().trim().toLowerCase() ==
            name.toLowerCase(),
      );
      if (!alreadyExists) await widget.api.createSpace(name: name);
      await OnboardingPrefs.setPendingFirstSpaceName(null);
      if (!mounted) return;
      setState(() => _inventoryRefreshToken++);
      unawaited(_prefetchInventoryCache());
    } catch (error) {
      debugPrint('Could not create onboarding Space: $error');
      // Preserve the name so a temporary network failure can retry later.
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _notificationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onNavigationTap(AppDestination destination) {
    _animateTo(destination, haptic: true);
  }

  Future<void> _loadNotificationCount() async {
    try {
      final result = await widget.api.getNotifications();
      if (!mounted) return;
      setState(
        () =>
            _notificationCount = (result['unread_count'] as num?)?.toInt() ?? 0,
      );
      await PushNotifications.setBadgeCount(_notificationCount);
    } catch (_) {
      // Read-only badge refresh. The inbox shows a visible error if opened.
    }
  }

  Future<void> _initializePushNotifications() async {
    try {
      await PushNotifications.initialize(
        onNotificationTap: (_) async {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_openNotifications());
          });
        },
      );
      await PushNotifications.register(widget.api);
    } catch (error) {
      debugPrint('Push notifications are unavailable: $error');
    }
  }

  Future<void> _openNotifications() async {
    if (!mounted || _openingNotifications) return;
    _openingNotifications = true;
    HapticFeedback.lightImpact();
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotificationsPage(
            api: widget.api,
            onRead: () {
              if (mounted) setState(() => _notificationCount = 0);
              unawaited(PushNotifications.setBadgeCount(0));
            },
          ),
        ),
      );
      await _loadNotificationCount();
    } finally {
      _openingNotifications = false;
    }
  }

  Widget _notificationBell() {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: _openNotifications,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(CupertinoIcons.bell, size: 21),
          if (_notificationCount > 0)
            Positioned(
              right: -7,
              top: -7,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _notificationCount > 99 ? '99+' : '$_notificationCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openMemoryTool(_MemoryTool tool) async {
    final page = switch (tool) {
      _MemoryTool.documents => DocumentsPage(api: widget.api),
      _MemoryTool.checkouts => CheckoutPage(api: widget.api),
      _MemoryTool.lowStock => ShoppingListPage(api: widget.api),
      _MemoryTool.activity => ActivityPage(api: widget.api),
    };
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _showMemoryTools() async {
    HapticFeedback.lightImpact();
    final selected = await showModalBottomSheet<_MemoryTool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.doc),
              title: const Text('Documents'),
              onTap: () => Navigator.pop(sheetContext, _MemoryTool.documents),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.arrow_left_right),
              title: const Text('Check-outs'),
              onTap: () => Navigator.pop(sheetContext, _MemoryTool.checkouts),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.cart),
              title: const Text('Low stock'),
              onTap: () => Navigator.pop(sheetContext, _MemoryTool.lowStock),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.clock),
              title: const Text('Activity'),
              onTap: () => Navigator.pop(sheetContext, _MemoryTool.activity),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) await _openMemoryTool(selected);
  }

  PreferredSizeWidget _buildAppBar() {
    switch (_currentDestination) {
      case AppDestination.memory:
        return AppBar(
          title: SizedBox(
            key: TutorialController.teamsSegmentKey,
            width: 210,
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _memorySection,
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Spaces'),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Teams'),
                ),
              },
              onValueChanged: (value) {
                if (value != null && value != _memorySection) {
                  HapticFeedback.selectionClick();
                  setState(() => _memorySection = value);
                }
              },
            ),
          ),
          actions: [
            if (_memorySection == 0)
              IconButton(
                onPressed: _joinSpaceCallback,
                icon: const Icon(CupertinoIcons.person_badge_plus, size: 20),
                tooltip: 'Join Shared Space',
              ),
            IconButton(
              onPressed: _showMemoryTools,
              icon: const Icon(CupertinoIcons.square_grid_2x2, size: 20),
              tooltip: 'Memory tools',
            ),
            _notificationBell(),
          ],
        );
      case AppDestination.ask:
        return AppBar(
          title: Text(_currentDestination.appBarTitle),
          actions: [
            if (_hasActiveChat)
              IconButton(
                icon: const Icon(CupertinoIcons.square_pencil, size: 20),
                tooltip: 'New chat',
                onPressed: _resetChatCallback,
              ),
            _notificationBell(),
          ],
        );
      default:
        return AppBar(
          title: Text(_currentDestination.appBarTitle),
          actions: [_notificationBell()],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _pageOpacity,
              duration: AppTokens.motionFast,
              curve: Curves.easeOutCubic,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  if (widget.enableRuntimeServices) {
                    unawaited(_loadNotificationCount());
                  }
                  final destination = AppDestination.values[index];
                  final isInventoryDestination =
                      destination == AppDestination.find ||
                      destination == AppDestination.memory;
                  final now = DateTime.now();
                  final tooSoon =
                      isInventoryDestination &&
                      _lastInventoryRefreshAt != null &&
                      now.difference(_lastInventoryRefreshAt!) <
                          const Duration(seconds: 5);
                  setState(() {
                    _currentDestination = destination;
                    if (isInventoryDestination && !tooSoon) {
                      _inventoryRefreshToken++;
                      _lastInventoryRefreshAt = now;
                    }
                  });
                },
                children:
                    (widget.destinationPagesForTesting ??
                            [
                              ChatPage(
                                key: const ValueKey('destination-ask'),
                                api: widget.api,
                                inPageView: true,
                                pageController: _pageController,
                                onInventoryMutated: () {
                                  setState(() => _inventoryRefreshToken++);
                                  unawaited(_prefetchInventoryCache());
                                },
                                onRegisterReset: (fn) =>
                                    _resetChatCallback = fn,
                                onChatStateChanged: (hasMessages) => setState(
                                  () => _hasActiveChat = hasMessages,
                                ),
                                onOpenDestination: (hint) async {
                                  _animateTo(AppDestination.memory);
                                  await Future<void>.delayed(
                                    const Duration(milliseconds: 350),
                                  );
                                  await _openMemoryDestination?.call(hint);
                                },
                              ),
                              ScanPage(
                                key: const ValueKey('destination-capture'),
                                api: widget.api,
                                isActive:
                                    _currentDestination ==
                                    AppDestination.capture,
                                showAppBar: false,
                                onSaved: () {
                                  setState(() => _inventoryRefreshToken++);
                                  unawaited(_prefetchInventoryCache());
                                },
                                onSpaceScanned: (spaceName) {
                                  setState(() => _inventoryRefreshToken++);
                                  _animateTo(AppDestination.memory);
                                },
                                onSkipCoachmark: () {},
                              ),
                              InventoryPage(
                                key: const ValueKey('destination-find'),
                                api: widget.api,
                                refreshToken: _inventoryRefreshToken,
                                showAppBar: false,
                                presentation: InventoryPagePresentation.find,
                              ),
                              IndexedStack(
                                key: const ValueKey('destination-memory'),
                                index: _memorySection,
                                children: [
                                  InventoryPage(
                                    api: widget.api,
                                    refreshToken: _inventoryRefreshToken,
                                    showAppBar: false,
                                    presentation:
                                        InventoryPagePresentation.memory,
                                    onRegisterJoinSpace: (fn) {
                                      if (_joinSpaceCallback == fn) return;
                                      setState(() => _joinSpaceCallback = fn);
                                    },
                                    onRegisterOpenAssistDestination: (fn) =>
                                        _openMemoryDestination = fn,
                                  ),
                                  TeamsPage(api: widget.api),
                                ],
                              ),
                              ProfilePage(
                                key: const ValueKey('destination-profile'),
                                api: widget.api,
                              ),
                            ])
                        .map((page) => _KeepAlivePage(child: page))
                        .toList(),
              ),
            ),
          ),
          Positioned(
            left: AppTokens.space12,
            right: AppTokens.space12,
            bottom: AppTokens.space8,
            child: IgnorePointer(
              ignoring: keyboardVisible,
              child: AnimatedSlide(
                offset: keyboardVisible ? const Offset(0, 1.35) : Offset.zero,
                duration: AppTokens.motionStandard,
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: keyboardVisible ? 0 : 1,
                  duration: AppTokens.motionFast,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: PrimaryNavigationBar(
                        selected: _currentDestination,
                        onSelected: _onNavigationTap,
                        iconKeys: {
                          AppDestination.ask: TutorialController.assistTabKey,
                          AppDestination.capture: TutorialController.scanTabKey,
                          AppDestination.memory:
                              TutorialController.inventoryIconKey,
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ─── Private helper widgets kept for potential reuse ─────────────────────────

class _ProfileControlCenter extends StatefulWidget {
  const _ProfileControlCenter();

  @override
  State<_ProfileControlCenter> createState() => _ProfileControlCenterState();
}

class _ProfileControlCenterState extends State<_ProfileControlCenter> {
  TextStyle? _sectionTitleStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Colors.white.withValues(alpha: 0.70),
      fontWeight: FontWeight.w600,
    );
  }

  Widget _statRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.70),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = InventoryCache.items;
    final itemsTracked = items.length;

    final locations = <String>{};
    for (final it in items) {
      final loc = it.location.trim().isEmpty ? 'Unsorted' : it.location.trim();
      locations.add(loc.toLowerCase());
    }
    final spaces = locations.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your Inventory', style: _sectionTitleStyle(context)),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statRow(label: 'Items tracked', value: '$itemsTracked'),
              const Divider(height: 1),
              _statRow(label: 'Spaces', value: '$spaces'),
              const Divider(height: 1),
              _statRow(label: 'Scans this week', value: '0'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileSupportSection extends StatelessWidget {
  const _ProfileSupportSection();

  TextStyle? _sectionTitleStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Colors.white.withValues(alpha: 0.70),
      fontWeight: FontWeight.w600,
    );
  }

  Future<void> _launchEmail(BuildContext context, String subject) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'info@findez.ai',
      queryParameters: <String, String>{'subject': subject},
    );
    try {
      final can = await canLaunchUrl(uri);
      if (!context.mounted) return;
      if (!can) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open email app.')),
        );
        return;
      }

      final ok = await launchUrl(uri);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open email app.')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open email app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Support', style: _sectionTitleStyle(context)),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.mail_outline),
                title: const Text('Send feedback'),
                onTap: () =>
                    unawaited(_launchEmail(context, 'FindEZ Feedback')),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Report a problem'),
                onTap: () =>
                    unawaited(_launchEmail(context, 'FindEZ Issue Report')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Retained as a legacy fallback while MainShell uses the feature ProfilePage.
// ignore: unused_element
class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

    String emailFallbackName() {
      final e = email.trim();
      if (e.isEmpty) return '—';
      final at = e.indexOf('@');
      if (at <= 0) return e;
      return e.substring(0, at);
    }

    Future<String?> loadFirstName() async {
      if (userId.isEmpty) return null;
      try {
        final res = await Supabase.instance.client
            .from('profiles')
            .select('first_name')
            .eq('id', userId)
            .maybeSingle();
        final first = (res?['first_name'] as String?)?.trim();
        return (first != null && first.isNotEmpty) ? first : null;
      } catch (e) {
        return null;
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        color: Colors.black,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Account',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.70),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Signed in as',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<String?>(
                        future: loadFirstName(),
                        builder: (context, snap) {
                          // acceptable: no hasError branch because emailFallbackName()
                          // is a safe fallback — the user still sees their email
                          // rather than an empty or broken display name.
                          final name =
                              (snap.data != null &&
                                  (snap.data ?? '').isNotEmpty)
                              ? snap.data!
                              : emailFallbackName();
                          return Text(
                            name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.1,
                                ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _ProfileControlCenter(),
            const SizedBox(height: 16),
            Text(
              'Actions',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.70),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          await Supabase.instance.client.auth.signOut();
                        },
                        child: const Text('Logout'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Delete Account'),
                                content: const Text(
                                  'Are you sure you want to permanently delete your account? This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmed != true) return;

                          try {
                            final response = await Supabase
                                .instance
                                .client
                                .functions
                                .invoke('delete-user');

                            if (response.data == null) {
                              throw Exception('Failed to delete account');
                            }

                            final responseData =
                                response.data as Map<String, dynamic>;
                            if (responseData['error'] != null) {
                              throw Exception(
                                responseData['error'] ??
                                    'Failed to delete account',
                              );
                            }

                            InventoryCache.clear();
                            await Supabase.instance.client.auth.signOut();
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to delete account: ${friendlyApiError(e, fallback: 'Please try again.')}',
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                            );
                          }
                        },
                        child: const Text('Delete Account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _ProfileSupportSection(),
            const SizedBox(height: 16),
            Text(
              'Legal',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.70),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyPage(),
                            ),
                          );
                        },
                        child: const Text('Privacy Policy'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TermsOfServicePage(),
                            ),
                          );
                        },
                        child: const Text('Terms of Service'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'To delete your account and all associated data,\nemail us at info@findez.ai\nfrom your registered email address.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
