import '../../core/account_deletion.dart';
import '../../core/app_theme.dart';
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
import '../../core/profile_store.dart';
import '../../core/ui/member_avatar.dart';
import '../../core/push_notifications.dart';
import '../../core/notification_snapshot.dart';
import '../../core/ui/glass_card.dart';
import '../../core/ui/frosted_surface.dart';
import '../chat/chat_page.dart';
import '../checkout/checkout_page.dart';
import '../documents/documents_page.dart';
import '../home/home_page.dart';
import '../home/home_overview.dart';
import '../inventory/inventory_page.dart';
import '../notifications/notifications_page.dart';
import '../notifications/notification_bell.dart';
import '../onboarding/onboarding_prefs.dart';
import '../showcase/tutorial_controller.dart';
import '../profile/privacy_policy_page.dart';
import '../profile/profile_page.dart';
import '../profile/profile_hub_page.dart';
import '../onboarding/onboarding_page.dart';
import '../onboarding/onboarding_answers.dart';
import '../profile/terms_of_service_page.dart';
import '../review/review_queue_page.dart';
import '../scan/scan_page.dart';
import '../teams/teams_page.dart';
import 'home_navigation.dart';
import 'package:mobile/core/ui/app_text.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.api,
    this.onSwitchContext,
    this.onManageContext,
    this.onWorkspaceNotification,
  });

  final ApiClient api;
  final Future<void> Function()? onSwitchContext, onManageContext;
  final Future<void> Function(Map<String, dynamic>)? onWorkspaceNotification;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late final PageController _pageController;
  late final ProfileStore _profileStore;
  StreamSubscription<AuthState>? _authSub;
  int _currentPage = 0;
  int _inventoryRefreshToken = 0;
  int _inventoryCacheGeneration = 0;
  String? _deletedSpaceId;
  DateTime? _lastTabSwitchRefreshAt;
  Future<void> Function(Map<String, dynamic>)? _openAssistDestination;
  int _inventorySection = 0;
  VoidCallback? _joinSpaceCallback;
  final _notificationCount = ValueNotifier<int>(0);
  bool _openingAccount = false;
  bool _openingNotifications = false;
  Timer? _notificationTimer;
  StreamSubscription<void>? _foregroundPush;
  int _notificationGeneration = 0;
  late final String? _notificationAccount;
  double _pageOpacity = 1;
  int _pageTransitionGeneration = 0;
  int _chatGeneration = 0;
  String? _chatInitialMessage;
  bool _chatHasMessages = false;
  int _chatReturnPage = 0;

  Future<void> _prefetchInventoryCache() async {
    final generation = ++_inventoryCacheGeneration;
    final account = widget.api.accountId;
    try {
      final result = await widget.api.searchItems(query: '');
      if (!mounted ||
          generation != _inventoryCacheGeneration ||
          account != widget.api.accountId) {
        return;
      }
      InventoryCache.setItems(result.items, contextKey: widget.api.cacheKey);
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
    _notificationAccount = widget.api.accountId;
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: 0);
    _profileStore = ProfileStore(api: widget.api);
    unawaited(_profileStore.load());
    unawaited(_prefetchInventoryCache());
    unawaited(_loadNotificationCount());
    _foregroundPush = PushNotifications.received.listen(
      (_) => unawaited(_loadNotificationCount()),
    );
    unawaited(_initializePushNotifications());
    _notificationTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
        unawaited(_loadNotificationCount());
      }
    });
    unawaited(_syncSetupAnswers());
    if (widget.api.inventoryContext == null ||
        widget.api.inventoryContext!.isPersonal) {
      unawaited(_createPendingFirstSpace());
    }
    unawaited(_maybeLaunchTutorial());

    // Pop all open dialogs/sheets before the auth gate switches to the auth
    // screen. Without this, zombie widgets outlive their inherited dependencies
    // (Navigator, Theme, MediaQuery) and trip _dependents.isEmpty assertions.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) {
        InventoryCache.clear();
        ProStatus.reset();
        unawaited(PushNotifications.stop());
      }
      if (widget.api.accountId != _notificationAccount && mounted) {
        _notificationGeneration++;
        setState(() => _notificationCount.value = 0);
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

  Future<void> _syncSetupAnswers() async {
    final account = widget.api.accountId;
    if (account == null) return;
    try {
      await OnboardingAnswerStore.sync(widget.api);
    } catch (_) {
      if (!mounted || widget.api.accountId != account) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const AppText('Your setup answers could not be saved yet.'),
          action: SnackBarAction(label: 'Retry', onPressed: _syncSetupAnswers),
        ),
      );
    }
  }

  Future<void> _maybeLaunchTutorial() async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (uid.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.api.accountId != uid) return;
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
    _notificationGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _notificationTimer?.cancel();
    _foregroundPush?.cancel();
    TutorialController.instance.dismiss();
    _pageController.dispose();
    _profileStore.dispose();
    _notificationCount.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      TutorialController.instance.dismiss();
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadNotificationCount());
      unawaited(_initializePushNotifications());
      setState(() => _inventoryRefreshToken++);
      unawaited(_prefetchInventoryCache());
    }
  }

  int get _navigationIndex => switch (_currentPage) {
    0 => 0,
    2 => 1,
    1 => 2,
    _ => 3,
  };

  void _onNavigationTap(int index) {
    const pages = [0, 2, 1, 3];
    _animateTo(pages[index], haptic: true);
  }

  void _openAsk(String? message) {
    final question = (message ?? '').trim();
    if (question.isNotEmpty) {
      setState(() {
        _chatInitialMessage = question;
        _chatGeneration++;
      });
    }
    _animateTo(1, haptic: true);
  }

  void _leaveChat() {
    FocusManager.instance.primaryFocus?.unfocus();
    _animateTo(_chatReturnPage, haptic: true);
  }

  void _onChatStateChanged(bool hasMessages) {
    if (!mounted || _chatHasMessages == hasMessages) return;
    setState(() => _chatHasMessages = hasMessages);
  }

  Widget _buildAccountControl() => ListenableBuilder(
    listenable: Listenable.merge([_profileStore, _notificationCount]),
    builder: (context, _) => IconButton(
      key: const Key('home-account-button'),
      tooltip: 'Account',
      onPressed: () => unawaited(_openAccount()),
      icon: Badge(
        isLabelVisible: _notificationCount.value > 0,
        label: AppText(
          _notificationCount.value > 99 ? '99+' : '${_notificationCount.value}',
          semanticsLabel: '${_notificationCount.value} unread notifications',
        ),
        child: _profileStore.photoUrl.isEmpty
            ? Icon(
                CupertinoIcons.person_crop_circle,
                size: 28,
                color: AppTheme.textPrimary(context),
              )
            : MemberAvatar(
                key: ValueKey(_profileStore.photoRevision),
                name: _profileStore.name,
                photoUrl: _profileStore.photoUrl,
                colorHex: _profileStore.color,
                size: 28,
              ),
      ),
    ),
  );

  Future<void> _openAccount() async {
    if (_openingAccount) return;
    _openingAccount = true;
    HapticFeedback.lightImpact();
    unawaited(_profileStore.load());
    unawaited(_loadNotificationCount());
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ValueListenableBuilder<int>(
            valueListenable: _notificationCount,
            builder: (context, count, _) => Scaffold(
              backgroundColor: AppTheme.adaptive(
                context,
                HomeColors.background,
              ),
              appBar: AppBar(
                title: const AppText('Account'),
                actions: [
                  NotificationBell(
                    api: widget.api,
                    count: _notificationCount,
                    onOpen: _openNotifications,
                  ),
                ],
              ),
              body: ProfileHubPage(
                api: widget.api,
                store: _profileStore,
                showHeading: false,
                onOpenProfile: _openProfile,
                onOpenSettings: _openSettings,
                onOpenDocuments: _openDocuments,
                onOpenNotifications: _openNotifications,
                onOpenCheckouts: _openCheckouts,
                onOpenTour: _openTour,
                unreadCount: count,
              ),
            ),
          ),
        ),
      );
    } finally {
      _openingAccount = false;
    }
  }

  Future<void> _openProfile() async {
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          api: widget.api,
          accountOnly: true,
          store: _profileStore,
        ),
      ),
    );
  }

  Future<void> _openReview() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewQueuePage(
          api: widget.api,
          onInventoryMutated: () {
            setState(() => _inventoryRefreshToken++);
            unawaited(_prefetchInventoryCache());
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _inventoryRefreshToken++);
  }

  Future<void> _openDocuments() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DocumentsPage(api: widget.api)));
  }

  Future<void> _openCheckouts() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => CheckoutPage(api: widget.api)),
    );
    if (mounted) setState(() => _inventoryRefreshToken++);
  }

  Future<void> _openHomeSpace(Map<String, dynamic> space) async {
    setState(() => _inventorySection = 0);
    _animateTo(3, haptic: true);
    for (
      var attempt = 0;
      attempt < 12 && _openAssistDestination == null;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;
    final open = _openAssistDestination;
    if (open == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Could not open this Space. Please try again.'),
        ),
      );
      return;
    }
    try {
      await open({'space_name': space['name'], 'space_id': space['id']});
      if (mounted) setState(() => _inventoryRefreshToken++);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Could not open this Space. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppTheme.adaptive(context, HomeColors.background),
          appBar: AppBar(title: const AppText('Settings')),
          body: ProfilePage(api: widget.api, settingsOnly: true),
        ),
      ),
    );
  }

  Future<void> _openTour() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (tourContext) => OnboardingPage(
          api: widget.api,
          isReplay: true,
          onFinished: () => Navigator.of(tourContext).pop(),
        ),
      ),
    );
  }

  Future<void> _loadNotificationCount() async {
    if (_openingNotifications || widget.api.accountId != _notificationAccount) {
      return;
    }
    final generation = ++_notificationGeneration;
    try {
      final result = await widget.api.getNotifications();
      if (!mounted ||
          generation != _notificationGeneration ||
          widget.api.accountId != _notificationAccount) {
        return;
      }
      final count = notificationUnreadCount(result);
      setState(() => _notificationCount.value = count);
      await PushNotifications.setBadgeCount(count);
    } catch (_) {
      // Read-only badge refresh; the inbox shows a visible error if opened.
    }
  }

  Future<void> _initializePushNotifications() async {
    try {
      await PushNotifications.initialize(
        onNotificationTap: (payload) async {
          if (widget.onWorkspaceNotification != null) {
            await widget.onWorkspaceNotification!(payload);
            return;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_openNotifications());
          });
        },
      );
      if (!mounted || widget.api.accountId != _notificationAccount) return;
      await PushNotifications.registerIfAuthorized(widget.api);
    } catch (error) {
      // Optional phone alerts can be enabled/retried in the inbox.
    }
  }

  Future<void> _openNotifications() async {
    if (!mounted ||
        _openingNotifications ||
        widget.api.accountId != _notificationAccount) {
      return;
    }
    _openingNotifications = true;
    _notificationGeneration++;
    HapticFeedback.lightImpact();
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotificationsPage(
            api: widget.api,
            onReadStarting: () => _notificationGeneration++,
            onUnreadChanged: (count) {
              if (!mounted || widget.api.accountId != _notificationAccount) {
                return;
              }
              _notificationGeneration++;
              setState(() => _notificationCount.value = count);
            },
          ),
        ),
      );
    } finally {
      _openingNotifications = false;
      if (mounted) unawaited(_loadNotificationCount());
    }
  }

  PreferredSizeWidget? _buildAppBar() {
    final selected = widget.api.inventoryContext;
    if (selected != null) {
      final scaler = MediaQuery.textScalerOf(context);
      return AppBar(
        toolbarHeight: (scaler.scale(14) * 1.2 + scaler.scale(11) * 1.1 + 20)
            .clamp(56, double.infinity),
        title: TextButton(
          key: TutorialController.teamsSegmentKey,
          onPressed: widget.onSwitchContext,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                [
                  selected.organizationName,
                  selected.workspaceName,
                ].whereType<String>().join(' / '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  color: AppTheme.textSecondary(context),
                ),
              ),
              Row(
                children: [
                  Flexible(
                    child: AppText(
                      selected.name,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        color: AppTheme.textPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ],
          ),
        ),
        actions: [
          NotificationBell(
            api: widget.api,
            count: _notificationCount,
            onOpen: _openNotifications,
          ),
          IconButton(
            tooltip: 'Inventory settings',
            onPressed: widget.onManageContext,
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      );
    }
    switch (_currentPage) {
      case 3:
        return AppBar(
          title: SizedBox(
            key: TutorialController.teamsSegmentKey,
            width: 210,
            child: FrostedSurface(
              radius: 10,
              shadow: false,
              tint: AppTheme.surface2(context),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _inventorySection,
                backgroundColor: Colors.transparent,
                thumbColor: AppTheme.neutralSelectionTint(context),
                children: {
                  0: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: AppText(
                      'Spaces',
                      style: TextStyle(
                        color: _inventorySection == 0
                            ? AppTheme.textPrimary(context)
                            : AppTheme.textSecondary(context),
                      ),
                    ),
                  ),
                  1: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: AppText(
                      'Teams',
                      style: TextStyle(
                        color: _inventorySection == 1
                            ? AppTheme.textPrimary(context)
                            : AppTheme.textSecondary(context),
                      ),
                    ),
                  ),
                },
                onValueChanged: (value) {
                  if (value != null && value != _inventorySection) {
                    HapticFeedback.selectionClick();
                    setState(() => _inventorySection = value);
                  }
                },
              ),
            ),
          ),
          actions: [
            if (_inventorySection == 0)
              IconButton(
                onPressed: _joinSpaceCallback,
                icon: const Icon(CupertinoIcons.person_badge_plus, size: 20),
                tooltip: 'Join Shared Space',
              ),
          ],
        );
      case 2:
        return AppBar(title: const AppText('Capture'));
      case 1:
        return null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final chatFocused = _currentPage == 1 && _chatHasMessages;
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final navigation = keyboardVisible || chatFocused
        ? const SizedBox.shrink()
        : HomeNavigation(
            monochrome:
                widget.api.inventoryContext == null &&
                _currentPage == 3 &&
                _inventorySection == 1,
            selectedIndex: _navigationIndex,
            onSelected: _onNavigationTap,
            destinationKeys: {
              0: TutorialController.inventoryIconKey,
              1: TutorialController.scanTabKey,
              2: TutorialController.assistTabKey,
            },
          );
    return Scaffold(
      backgroundColor: AppTheme.adaptive(context, HomeColors.background),
      appBar: _buildAppBar(),
      body: AnimatedOpacity(
        opacity: _pageOpacity,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: PageView(
          controller: _pageController,
          reverse: true,
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
              if (index == 1 && _currentPage != 1) {
                _chatReturnPage = _currentPage;
              }
              _currentPage = index;
              if (index == 3 && !tooSoon) {
                _inventoryRefreshToken++;
                _lastTabSwitchRefreshAt = now;
              }
            });
          },
          children: [
            HomePage(
              api: widget.api,
              refreshToken: _inventoryRefreshToken,
              deletedSpaceId: _deletedSpaceId,
              onOpenAsk: _openAsk,
              accountControl: _buildAccountControl(),
              onOpenReview: _openReview,
              onOpenCheckouts: _openCheckouts,
              onOpenSpace: _openHomeSpace,
            ),
            ChatPage(
              key: ValueKey('chat-$_chatGeneration'),
              api: widget.api,
              initialMessage: _chatInitialMessage,
              inPageView: true,
              pageController: _pageController,
              onChatStateChanged: _onChatStateChanged,
              onBack: _leaveChat,
              onInventoryMutated: () {
                setState(() => _inventoryRefreshToken++);
                unawaited(_prefetchInventoryCache());
              },
              onOpenDestination: (hint) async {
                _animateTo(3);
                await Future<void>.delayed(const Duration(milliseconds: 350));
                await _openAssistDestination?.call(hint);
              },
            ),
            if (!widget.api.canEdit)
              const Center(
                child: AppText(
                  'You have view-only access. Ask or Find items in this inventory.',
                ),
              )
            else
              ScanPage(
                api: widget.api,
                isActive: _currentPage == 2,
                showAppBar: false,
                onSaved: () {
                  setState(() => _inventoryRefreshToken++);
                  unawaited(_prefetchInventoryCache());
                },
                onSpaceScanned: (spaceName) {
                  setState(() => _inventoryRefreshToken++);
                  _animateTo(3);
                },
                onSkipCoachmark: () {},
              ),
            IndexedStack(
              index: _inventorySection,
              children: [
                InventoryPage(
                  api: widget.api,
                  refreshToken: _inventoryRefreshToken,
                  onSpaceDeleted: (spaceId) {
                    _inventoryCacheGeneration++;
                    InventoryCache.removeSpace(
                      spaceId,
                      contextKey: widget.api.cacheKey,
                    );
                    setState(() {
                      _deletedSpaceId = spaceId;
                      _inventoryRefreshToken++;
                    });
                  },
                  showAppBar: false,
                  onRegisterJoinSpace: (fn) {
                    if (_joinSpaceCallback == fn) return;
                    setState(() => _joinSpaceCallback = fn);
                  },
                  onRegisterOpenAssistDestination: (fn) =>
                      _openAssistDestination = fn,
                ),
                if (widget.api.inventoryContext == null)
                  TeamsPage(api: widget.api),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: reduceMotion || keyboardVisible
          ? navigation
          : AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              child: navigation,
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
      color: AppTheme.adaptive(context, Colors.white.withValues(alpha: 0.70)),
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
            child: AppText(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.adaptive(
                  context,
                  Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AppText(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.adaptive(
                context,
                Colors.white.withValues(alpha: 0.70),
              ),
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
        AppText('Your Inventory', style: _sectionTitleStyle(context)),
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
      color: AppTheme.adaptive(context, Colors.white.withValues(alpha: 0.70)),
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
          const SnackBar(content: AppText('Unable to open email app.')),
        );
        return;
      }

      final ok = await launchUrl(uri);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('Unable to open email app.')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Unable to open email app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText('Support', style: _sectionTitleStyle(context)),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.mail_outline),
                title: const AppText('Send feedback'),
                onTap: () =>
                    unawaited(_launchEmail(context, 'FindEZ Feedback')),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.bug_report_outlined),
                title: const AppText('Report a problem'),
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
      backgroundColor: AppTheme.adaptive(context, Colors.black),
      appBar: AppBar(
        title: const AppText('Profile'),
        backgroundColor: AppTheme.adaptive(context, Colors.black),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        color: AppTheme.adaptive(context, Colors.black),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppText(
              'Account',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.adaptive(
                  context,
                  Colors.white.withValues(alpha: 0.70),
                ),
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
                    color: AppTheme.adaptive(
                      context,
                      Colors.white.withValues(alpha: 0.06),
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.adaptive(
                        context,
                        Colors.white.withValues(alpha: 0.15),
                      ),
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
                      AppText(
                        'Signed in as',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.adaptive(
                            context,
                            Colors.white.withValues(alpha: 0.62),
                          ),
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
                          return AppText(
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
            AppText(
              'Actions',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.adaptive(
                  context,
                  Colors.white.withValues(alpha: 0.70),
                ),
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
                    color: AppTheme.adaptive(
                      context,
                      Colors.white.withValues(alpha: 0.06),
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.adaptive(
                        context,
                        Colors.white.withValues(alpha: 0.15),
                      ),
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
                          await PushNotifications.stop();
                          await Supabase.instance.client.auth.signOut();
                        },
                        child: const AppText('Logout'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const AppText('Delete Account'),
                                content: const AppText(
                                  'Are you sure you want to permanently delete your account? This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: AppText(
                                      'Cancel',
                                      style: TextStyle(
                                        color: AppTheme.foreground(
                                          context,
                                          Colors.white.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const AppText('Delete'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmed != true) return;

                          try {
                            await requestAccountDeletion();

                            InventoryCache.clear();
                            await PushNotifications.stop();
                            await Supabase.instance.client.auth.signOut();
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: AppText(
                                  'Failed to delete account: ${friendlyApiError(e, fallback: 'Please try again.')}',
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                            );
                          }
                        },
                        child: const AppText('Delete Account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _ProfileSupportSection(),
            const SizedBox(height: 16),
            AppText(
              'Legal',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.adaptive(
                  context,
                  Colors.white.withValues(alpha: 0.70),
                ),
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
                    color: AppTheme.adaptive(
                      context,
                      Colors.white.withValues(alpha: 0.06),
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.adaptive(
                        context,
                        Colors.white.withValues(alpha: 0.15),
                      ),
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
                        child: const AppText('Privacy Policy'),
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
                        child: const AppText('Terms of Service'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            AppText(
              'To delete your account and all associated data,\nemail us at info@findez.ai\nfrom your registered email address.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.adaptive(
                  context,
                  Colors.white.withValues(alpha: 0.75),
                ),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
