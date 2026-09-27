import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/inventory_cache.dart';
import '../../core/pro_status.dart';
import '../../core/push_notifications.dart';
import '../../core/ui/visual_surfaces.dart';
import '../chat/chat_page.dart';
import '../activity/activity_page.dart';
import '../checkout/checkout_page.dart';
import '../documents/documents_page.dart';
import '../home/home_dashboard.dart';
import '../home/needs_identifying_page.dart';
import '../inventory/inventory_page.dart';
import '../notifications/notifications_page.dart';
import '../onboarding/onboarding_prefs.dart';
import '../showcase/tutorial_controller.dart';
import '../profile/privacy_policy_page.dart';
import '../profile/profile_page.dart';
import '../profile/terms_of_service_page.dart';
import '../scan/scan_page.dart';
import '../scan/project_kits_page.dart';
import '../sharing/sharing_page.dart';
import '../shopping/shopping_list_page.dart';
import '../teams/teams_page.dart';
import '../teams/team_workspace_page.dart';
import '../profile/settings_page.dart';
import 'more_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.api});

  final ApiClient api;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final PageController _pageController;
  StreamSubscription<AuthState>? _authSub;
  int _currentPage = 0;
  int _inventoryRefreshToken = 0;
  int _homeRefreshToken = 0;
  DateTime? _lastTabSwitchRefreshAt;
  VoidCallback? _resetChatCallback;
  Future<void> Function(Map<String, dynamic>)? _openAssistDestination;
  bool _hasActiveChat = false;
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
      // acceptable: read-only background cache warmup; silently skip if
      // the API is unreachable at launch. The inventory page fetches fresh
      // data when it mounts.
    }
  }

  void _animateTo(int page, {bool haptic = false}) {
    if (page == _currentPage) return;
    if (haptic) HapticFeedback.selectionClick();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _pageController.jumpToPage(page);
      return;
    }
    final generation = ++_pageTransitionGeneration;
    setState(() => _pageOpacity = 0);
    Future<void>.delayed(const Duration(milliseconds: 90), () {
      if (!mounted || generation != _pageTransitionGeneration) return;
      _pageController.jumpToPage(page);
      setState(() => _pageOpacity = 1);
    });
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    unawaited(_prefetchInventoryCache());
    unawaited(_loadNotificationCount());
    unawaited(_initializePushNotifications());
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(_loadNotificationCount()),
    );
    unawaited(_maybeLaunchTutorial());

    // Pop all open dialogs/sheets before the auth gate switches to the auth
    // screen. Without this, zombie widgets outlive their inherited dependencies
    // (Navigator, Theme, MediaQuery) and trip _dependents.isEmpty assertions.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
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
      setState(() {
        _inventoryRefreshToken++;
        _homeRefreshToken++;
      });
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

  int get _navigationIndex => _currentPage;

  void _onNavigationTap(int index) {
    _animateTo(index, haptic: true);
  }

  Widget _barItem(int index, String label, {Key? key}) {
    final tokens = AppTokens.of(context);
    final selected = _navigationIndex == index;
    return Expanded(
      child: SizedBox(
        key: key,
        height: 54,
        child: TextButton(
          onPressed: () => _onNavigationTap(index),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            textStyle: Theme.of(context).textTheme.bodySmall,
            backgroundColor: index == 2
                ? (selected ? tokens.accent : tokens.accentSoft)
                : (selected ? tokens.raised : Colors.transparent),
            foregroundColor: index == 2
                ? (selected ? tokens.onAccent : tokens.accentText)
                : (selected ? tokens.ink : tokens.text2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(27),
            ),
          ),
          child: Text(label, maxLines: 1),
        ),
      ),
    );
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
      // Read-only badge refresh; the inbox shows a visible error if opened.
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
    return TextButton(
      onPressed: _openNotifications,
      child: Text(
        _notificationCount > 0 ? 'Inbox $_notificationCount' : 'Inbox',
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    switch (_currentPage) {
      case 0:
      case 4:
        return const PreferredSize(
          preferredSize: Size.fromHeight(0),
          child: SizedBox.shrink(),
        );
      case 3:
        return AppBar(
          title: const Text('Find'),
          actions: [_notificationBell()],
        );
      case 2:
        return AppBar(
          title: const Text('Capture'),
          actions: [_notificationBell()],
        );
      case 1:
        return AppBar(
          title: const Text('Ask FindEZ'),
          actions: [
            if (_hasActiveChat)
              TextButton(
                onPressed: _resetChatCallback,
                child: const Text('New'),
              ),
            _notificationBell(),
          ],
        );
      default:
        return AppBar(title: const Text('Find'));
    }
  }

  Future<void> _openWorkspacePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: widget.api.listTeams(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(describeError(snapshot.error!).$1),
              );
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text('My inventory'),
                  subtitle: Text('Personal spaces'),
                ),
                for (final team in snapshot.data!)
                  ListTile(
                    title: Text((team['name'] ?? 'Team').toString()),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeamWorkspacePage(
                            api: widget.api,
                            initialTeamId: team['team_id']?.toString(),
                          ),
                        ),
                      );
                    },
                  ),
                if (snapshot.data!.isEmpty)
                  const ListTile(title: Text('No team workspaces yet')),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openPage(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _openInventory({String? query}) {
    _openPage(
      InventoryPage(
        api: widget.api,
        refreshToken: _inventoryRefreshToken,
        initialQuery: query,
      ),
    );
  }

  void _openProjects() {
    _openPage(_ProjectLocationsPage(api: widget.api));
  }

  void _openMore(String destination) {
    switch (destination) {
      case 'places':
      case 'objects':
      case 'labels':
        _openInventory();
      case 'documents':
        _openPage(DocumentsPage(api: widget.api));
      case 'projects':
        _openProjects();
      case 'supplies':
        _openPage(ShoppingListPage(api: widget.api));
      case 'checkouts':
        _openPage(CheckoutPage(api: widget.api));
      case 'review':
        _openPage(NeedsIdentifyingPage(api: widget.api));
      case 'activity':
        _openPage(ActivityPage(api: widget.api));
      case 'inbox':
        unawaited(_openNotifications());
      case 'workspaces':
        _openPage(TeamsPage(api: widget.api));
      case 'sharing':
        _openPage(const SharingPage());
      case 'profile':
        _openPage(ProfilePage(api: widget.api));
      case 'settings':
        _openPage(const SettingsPage());
    }
  }

  void _openDecision(int index) {
    switch (index) {
      case 0:
        _openPage(NeedsIdentifyingPage(api: widget.api));
      case 1:
        _openMore('supplies');
      case 2:
        _openProjects();
      case 3:
        _openMore('checkouts');
    }
  }

  void _openPlace(
    String name,
    String? spaceId,
    List<InventoryItem> allItems,
    Map<String, int> thresholds,
  ) {
    final placeItems = allItems
        .where((item) => item.location.toLowerCase() == name.toLowerCase())
        .toList();
    _openPage(
      LocationItemsPage(
        api: widget.api,
        location: name,
        spaceId: spaceId,
        items: placeItems,
        allItems: allItems,
        thresholds: thresholds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: AppTokens.of(context).bg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _pageOpacity,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  unawaited(_loadNotificationCount());
                  final now = DateTime.now();
                  final tooSoon =
                      index == 3 &&
                      _lastTabSwitchRefreshAt != null &&
                      now.difference(_lastTabSwitchRefreshAt!) <
                          const Duration(seconds: 5);
                  setState(() {
                    _currentPage = index;
                    if (index == 3 && !tooSoon) {
                      _inventoryRefreshToken++;
                      _lastTabSwitchRefreshAt = now;
                    }
                    if (index == 0) _homeRefreshToken++;
                  });
                },
                children: [
                  HomeDashboard(
                    api: widget.api,
                    refreshToken: _homeRefreshToken,
                    onAsk: () => _animateTo(1),
                    onDecision: _openDecision,
                    onPlace: _openPlace,
                    onAllPlaces: () => _openMore('places'),
                    onWorkspace: () => unawaited(_openWorkspacePicker()),
                  ),
                  ChatPage(
                    api: widget.api,
                    inPageView: true,
                    pageController: _pageController,
                    onInventoryMutated: () {
                      setState(() {
                        _inventoryRefreshToken++;
                        _homeRefreshToken++;
                      });
                      unawaited(_prefetchInventoryCache());
                    },
                    onRegisterReset: (fn) => _resetChatCallback = fn,
                    onChatStateChanged: (hasMessages) =>
                        setState(() => _hasActiveChat = hasMessages),
                    onOpenDestination: (hint) async {
                      _animateTo(3);
                      await Future<void>.delayed(
                        const Duration(milliseconds: 350),
                      );
                      await _openAssistDestination?.call(hint);
                    },
                  ),
                  ScanPage(
                    api: widget.api,
                    isActive: _currentPage == 2,
                    showAppBar: false,
                    onSaved: () {
                      setState(() {
                        _inventoryRefreshToken++;
                        _homeRefreshToken++;
                      });
                      unawaited(_prefetchInventoryCache());
                    },
                    onSpaceScanned: (spaceName) {
                      setState(() {
                        _inventoryRefreshToken++;
                        _homeRefreshToken++;
                      });
                      _animateTo(3);
                    },
                    onSkipCoachmark: () {},
                  ),
                  InventoryPage(
                    api: widget.api,
                    refreshToken: _inventoryRefreshToken,
                    showAppBar: false,
                    onRegisterOpenAssistDestination: (fn) =>
                        _openAssistDestination = fn,
                  ),
                  MorePage(
                    onOpen: _openMore,
                    onWorkspace: () => unawaited(_openWorkspacePicker()),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 8,
            child: IgnorePointer(
              ignoring: keyboardVisible,
              child: AnimatedSlide(
                offset: keyboardVisible ? const Offset(0, 1.35) : Offset.zero,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: keyboardVisible ? 0 : 1,
                  duration: const Duration(milliseconds: 140),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppTokens.of(
                            context,
                          ).card.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: AppTokens.of(context).separator,
                          ),
                        ),
                        child: Row(
                          children: [
                            _barItem(0, 'Home'),
                            _barItem(
                              1,
                              'Ask',
                              key: TutorialController.assistTabKey,
                            ),
                            _barItem(
                              2,
                              'Capture',
                              key: TutorialController.scanTabKey,
                            ),
                            _barItem(
                              3,
                              'Find',
                              key: TutorialController.inventoryIconKey,
                            ),
                            _barItem(
                              4,
                              'More',
                              key: TutorialController.moreTabKey,
                            ),
                          ],
                        ),
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
        GroupedSurface(
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
        GroupedSurface(
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
                        // is a safe fallback, so the user still sees their email
                        // rather than an empty or broken display name.
                        final name =
                            (snap.data != null && (snap.data ?? '').isNotEmpty)
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

class _ProjectLocationsPage extends StatefulWidget {
  const _ProjectLocationsPage({required this.api});
  final ApiClient api;

  @override
  State<_ProjectLocationsPage> createState() => _ProjectLocationsPageState();
}

class _ProjectLocationsPageState extends State<_ProjectLocationsPage> {
  late final Future<List<Map<String, dynamic>>> _spaces = widget.api
      .listSpaces();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Projects')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _spaces,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(describeError(snapshot.error!).$1));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final locations = <String>{
          'Unsorted',
          for (final space in snapshot.data!)
            if ((space['name'] ?? '').toString().trim().isNotEmpty)
              (space['name'] ?? '').toString().trim(),
        };
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Text(
              'Choose a place to see its project kits.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            GroupedSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final name in locations)
                    ListTile(
                      title: Text(name),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProjectKitsPage(api: widget.api, location: name),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
