import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import '../inventory/labels_page.dart';
import '../inventory/world_views.dart';
import '../import/import_sheet_page.dart';
import '../notifications/notifications_page.dart';
import '../onboarding/onboarding_prefs.dart';
import '../showcase/tutorial_controller.dart';
import '../profile/profile_page.dart';
import '../scan/scan_page.dart';
import '../projects/project_kits_page.dart';
import '../sharing/sharing_page.dart';
import '../shopping/shopping_list_page.dart';
import '../teams/teams_page.dart';
import '../teams/workspaces_page.dart';
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
  CaptureMode? _captureRequest;
  int _captureRequestSerial = 0;
  int _homeRefreshToken = 0;
  DateTime? _lastTabSwitchRefreshAt;
  Future<void> Function(Map<String, dynamic>)? _openAssistDestination;
  int _notificationCount = 0;
  bool _openingNotifications = false;
  Timer? _notificationTimer;
  double _pageOpacity = 1;
  int _pageTransitionGeneration = 0;
  late ApiClient _activeApi;
  List<Map<String, dynamic>> _workspaces = const [];
  String? _workspaceId;
  String _workspaceName = '';
  bool _workspaceLoading = true;
  bool _workspaceAvailable = false;

  Future<void> _prefetchInventoryCache() async {
    try {
      final result = await _activeApi.searchItems(query: '');
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

  void _openCaptureMode(CaptureMode mode) {
    setState(() {
      _captureRequest = mode;
      _captureRequestSerial++;
    });
    _animateTo(2);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _activeApi = widget.api;
    unawaited(_loadWorkspaces());

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

  Future<void> _loadWorkspaces() async {
    setState(() {
      _workspaceLoading = true;
    });
    try {
      final workspaces = await widget.api.listWorkspaces();
      if (workspaces.isEmpty) throw StateError('No workspace is available.');
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('active_workspace_$userId');
      final selected = workspaces.firstWhere(
        (row) => row['workspace_id'] == savedId,
        orElse: () => workspaces.firstWhere(
          (row) => row['kind'] == 'personal',
          orElse: () => workspaces.first,
        ),
      );
      if (!mounted) return;
      setState(() {
        _workspaces = workspaces;
        _workspaceId = selected['workspace_id'].toString();
        _workspaceName = selected['name'].toString();
        _activeApi = ApiClient.forWorkspace(
          widget.api,
          workspaceId: _workspaceId!,
        );
        _workspaceAvailable = true;
        _workspaceLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _workspaces = const [];
        _workspaceId = null;
        _workspaceName = 'Your inventory';
        _activeApi = widget.api;
        _workspaceAvailable = false;
        _workspaceLoading = false;
      });
      debugPrint('Workspace switching unavailable: $error');
    }
    unawaited(_prefetchInventoryCache());
    unawaited(_loadNotificationCount());
    unawaited(_initializePushNotifications());
    _notificationTimer ??= Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(_loadNotificationCount()),
    );
    unawaited(_maybeLaunchTutorial());
  }

  Future<void> _selectWorkspace(Map<String, dynamic> workspace) async {
    if (!_workspaceAvailable) return;
    final id = workspace['workspace_id'].toString();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_workspace_$userId', id);
    if (!mounted) return;
    InventoryCache.clear();
    setState(() {
      _workspaceId = id;
      _workspaceName = workspace['name'].toString();
      _activeApi = ApiClient.forWorkspace(widget.api, workspaceId: id);
      _captureRequest = null;
      _captureRequestSerial = 0;
      _inventoryRefreshToken++;
      _homeRefreshToken++;
    });
    unawaited(_prefetchInventoryCache());
    unawaited(_loadNotificationCount());
  }

  Future<void> _maybeLaunchTutorial() async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (uid.isEmpty) return;
    await _createPendingFirstSpace();
    OnboardingPrefs.justSignedUp = false;
    await OnboardingPrefs.setPostSignupPending(false);
    await OnboardingPrefs.setCoachmarkPending(uid, false);
  }

  Future<void> _createPendingFirstSpace() async {
    final name = await OnboardingPrefs.getPendingFirstSpaceName();
    if (name == null) return;
    try {
      final spaces = await _activeApi.listSpaces();
      final alreadyExists = spaces.any(
        (space) =>
            (space['name'] ?? '').toString().trim().toLowerCase() ==
            name.toLowerCase(),
      );
      if (!alreadyExists) await _activeApi.createSpace(name: name);
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
      final result = await _activeApi.getNotifications();
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
      await PushNotifications.register(_activeApi);
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
            api: _activeApi,
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

  Future<void> _openWorkspacePicker() async {
    if (!_workspaceAvailable) return;
    try {
      _workspaces = await widget.api.listWorkspaces();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                'Workspaces',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final workspace in _workspaces)
              ListTile(
                title: Text(workspace['name'].toString()),
                subtitle: Text((workspace['kind'] ?? '').toString()),
                trailing: workspace['workspace_id'] == _workspaceId
                    ? const Text('Selected')
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_selectWorkspace(workspace));
                },
              ),
          ],
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
        api: _activeApi,
        refreshToken: _inventoryRefreshToken,
        initialQuery: query,
      ),
    );
  }

  void _openProjects() {
    _openPage(ProjectKitsPage(api: _activeApi));
  }

  Future<void> _openImport() async {
    try {
      final spaces = await _activeApi.listSpaces();
      if (!mounted) return;
      String? location;
      if (spaces.isNotEmpty) {
        location = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(title: Text('Import into which place?')),
                for (final space in spaces)
                  ListTile(
                    title: Text((space['name'] ?? '').toString()),
                    onTap: () =>
                        Navigator.pop(sheetContext, space['name'].toString()),
                  ),
                ListTile(
                  title: const Text('New place'),
                  onTap: () => Navigator.pop(sheetContext, '__new__'),
                ),
              ],
            ),
          ),
        );
      } else {
        location = '__new__';
      }
      if (location == null || !mounted) return;
      if (location == '__new__') {
        final controller = TextEditingController();
        final name = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Name this place'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Place name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        controller.dispose();
        if (name == null || name.isEmpty) return;
        await _activeApi.createSpace(name: name);
        location = name;
      }
      if (!mounted) return;
      final imported = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ImportSheetPage(api: _activeApi, location: location!),
        ),
      );
      if (imported == true && mounted) {
        setState(() {
          _homeRefreshToken++;
          _inventoryRefreshToken++;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  void _openMore(String destination) {
    switch (destination) {
      case 'places':
        _animateTo(3);
      case 'objects':
        _openPage(AllObjectsPage(api: _activeApi));
      case 'labels':
        _openPage(
          LabelsPage(
            api: _activeApi,
            onScan: () {
              Navigator.pop(context);
              _openCaptureMode(CaptureMode.scan);
            },
            onAddPlace: () {
              Navigator.pop(context);
              _openInventory();
            },
          ),
        );
      case 'documents':
        _openPage(DocumentsPage(api: _activeApi));
      case 'projects':
        _openProjects();
      case 'supplies':
        _openPage(ShoppingListPage(api: _activeApi));
      case 'checkouts':
        _openPage(CheckoutPage(api: _activeApi));
      case 'review':
        _openPage(NeedsIdentifyingPage(api: _activeApi));
      case 'activity':
        _openPage(ActivityPage(api: _activeApi));
      case 'inbox':
        unawaited(_openNotifications());
      case 'workspaces':
        if (!_workspaceAvailable) return;
        _openPage(
          WorkspacesPage(
            api: _activeApi,
            currentWorkspaceId: _workspaceId,
            onSelect: _selectWorkspace,
          ),
        );
      case 'team-spaces':
        _openPage(TeamsPage(api: _activeApi));
      case 'sharing':
        _openPage(const SharingPage());
      case 'profile':
        _openPage(ProfilePage(api: _activeApi));
      case 'settings':
        _openPage(SettingsPage(api: _activeApi));
    }
  }

  void _openDecision(int index) {
    switch (index) {
      case 0:
        _openPage(NeedsIdentifyingPage(api: _activeApi));
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
        api: _activeApi,
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
    if (_workspaceLoading) {
      return Scaffold(
        backgroundColor: AppTokens.of(context).bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GroupedSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Opening your inventory',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: AppTokens.of(context).bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _pageOpacity,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: PageView(
                key: ValueKey(_workspaceId),
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
                    api: _activeApi,
                    workspaceName: _workspaceName,
                    workspaceAvailable: _workspaceAvailable,
                    refreshToken: _homeRefreshToken,
                    onAsk: () => _animateTo(1),
                    onDecision: _openDecision,
                    onPlace: _openPlace,
                    onAllPlaces: () => _animateTo(3),
                    onWorkspace: () => unawaited(_openWorkspacePicker()),
                    onCapture: () => _animateTo(2),
                    onImport: () => unawaited(_openImport()),
                    onWorkspaces: () => _openMore('workspaces'),
                  ),
                  ChatPage(
                    api: _activeApi,
                    inPageView: true,
                    pageController: _pageController,
                    onInventoryMutated: () {
                      setState(() {
                        _inventoryRefreshToken++;
                        _homeRefreshToken++;
                      });
                      unawaited(_prefetchInventoryCache());
                    },
                    onOpenDestination: (hint) async {
                      _animateTo(3);
                      await Future<void>.delayed(
                        const Duration(milliseconds: 350),
                      );
                      await _openAssistDestination?.call(hint);
                    },
                  ),
                  ScanPage(
                    api: _activeApi,
                    isActive: _currentPage == 2,
                    showAppBar: false,
                    requestedMode: _captureRequest,
                    modeRequestSerial: _captureRequestSerial,
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
                    api: _activeApi,
                    refreshToken: _inventoryRefreshToken,
                    workspaceName: _workspaceName,
                    showAppBar: false,
                    onRegisterOpenAssistDestination: (fn) =>
                        _openAssistDestination = fn,
                  ),
                  MorePage(
                    api: _activeApi,
                    refreshToken: _homeRefreshToken,
                    workspaceName: _workspaceName,
                    workspaceAvailable: _workspaceAvailable,
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
                              'Places',
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
