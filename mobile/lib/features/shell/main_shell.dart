import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/inventory_cache.dart';
import '../../core/pro_status.dart';
import '../../core/ui/glass_card.dart';
import '../chat/chat_page.dart';
import '../inventory/inventory_page.dart';
import '../onboarding/onboarding_prefs.dart';
import '../showcase/tutorial_controller.dart';
import '../profile/privacy_policy_page.dart';
import '../profile/profile_page.dart';
import '../profile/settings_page.dart';
import '../profile/terms_of_service_page.dart';
import '../scan/scan_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.api});

  final ApiClient api;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final PageController _pageController;
  StreamSubscription<AuthState>? _authSub;
  int _currentPage = 3;
  int _inventoryRefreshToken = 0;
  DateTime? _lastTabSwitchRefreshAt;
  VoidCallback? _resetChatCallback;
  VoidCallback? _joinSpaceCallback;
  Future<void> Function(Map<String, dynamic>)? _openAssistDestination;
  String _userInitial = '';
  bool _hasActiveChat = false;

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

  void _animateTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 3);
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    if (email.isNotEmpty) _userInitial = email[0].toUpperCase();

    unawaited(_prefetchInventoryCache());
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
          Navigator.of(context, rootNavigator: true)
              .popUntil((route) => route.isFirst);
        });
      }
    });
  }

  Future<void> _maybeLaunchTutorial() async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (uid.isEmpty) return;
    if (OnboardingPrefs.justSignedUp) {
      OnboardingPrefs.justSignedUp = false;
      await OnboardingPrefs.setCoachmarkPending(uid, true);
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

  @override
  void dispose() {
    _authSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  int get _navigationIndex => switch (_currentPage) {
        3 => 0,
        2 => 1,
        1 => 2,
        _ => 3,
      };

  void _onNavigationTap(int index) {
    const pages = [3, 2, 1, 0];
    _animateTo(pages[index]);
  }

  PreferredSizeWidget _buildAppBar() {
    switch (_currentPage) {
      case 3:
        return AppBar(
          title: const Text('Inventory'),
          actions: [
            TextButton.icon(
              onPressed: () => _joinSpaceCallback?.call(),
              icon: const Icon(Icons.group_add_outlined, size: 18),
              label: const Text('Join'),
            ),
          ],
        );
      case 2:
        return AppBar(title: const Text('Scan'));
      case 1:
        return AppBar(
          title: const Text('Assist'),
          actions: [
            if (_hasActiveChat)
              IconButton(
                icon: const Icon(Icons.add_comment_outlined),
                tooltip: 'New chat',
                onPressed: _resetChatCallback,
              ),
          ],
        );
      default:
        return AppBar(
          title: const Text('Account'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: PageView(
        controller: _pageController,
        reverse: true,
        onPageChanged: (index) {
          final now = DateTime.now();
          final tooSoon = index == 3 &&
              _lastTabSwitchRefreshAt != null &&
              now.difference(_lastTabSwitchRefreshAt!) < const Duration(seconds: 5);
          setState(() {
            _currentPage = index;
            if (index == 3 && !tooSoon) {
              _inventoryRefreshToken++;
              _lastTabSwitchRefreshAt = now;
            }
          });
        },
        children: [
          ProfilePage(api: widget.api),
          ChatPage(
            api: widget.api,
            inPageView: true,
            pageController: _pageController,
            onInventoryMutated: () {
              setState(() => _inventoryRefreshToken++);
              unawaited(_prefetchInventoryCache());
            },
            onRegisterReset: (fn) => _resetChatCallback = fn,
            onChatStateChanged: (hasMessages) =>
                setState(() => _hasActiveChat = hasMessages),
            onOpenDestination: (hint) async {
              _animateTo(3);
              await Future<void>.delayed(const Duration(milliseconds: 350));
              await _openAssistDestination?.call(hint);
            },
          ),
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
          InventoryPage(
            api: widget.api,
            refreshToken: _inventoryRefreshToken,
            showAppBar: false,
            onRegisterJoinSpace: (fn) => setState(() => _joinSpaceCallback = fn),
            onRegisterOpenAssistDestination: (fn) => _openAssistDestination = fn,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navigationIndex,
        onDestinationSelected: _onNavigationTap,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined, key: TutorialController.inventoryIconKey),
            selectedIcon: const Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          const NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          const NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Assist',
          ),
          NavigationDestination(
            icon: CircleAvatar(radius: 11, backgroundColor: const Color(0xFF2C2C2E), child: Text(_userInitial, style: const TextStyle(fontSize: 10, color: Colors.white))),
            selectedIcon: CircleAvatar(radius: 11, backgroundColor: const Color(0xFF7CA2E4), child: Text(_userInitial, style: const TextStyle(fontSize: 10, color: Colors.white))),
            label: 'Account',
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
      path: 'vinodrexfms@ai-robots.co',
      queryParameters: <String, String>{
        'subject': subject,
      },
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
                onTap: () => unawaited(_launchEmail(context, 'FindEZ Feedback')),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Report a problem'),
                onTap: () => unawaited(_launchEmail(context, 'FindEZ Issue Report')),
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
        final res = await Supabase.instance.client.from('profiles').select('first_name').eq('id', userId).maybeSingle();
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
                    )
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
                        final name = (snap.data != null && (snap.data ?? '').isNotEmpty)
                            ? snap.data!
                            : emailFallbackName();
                        return Text(
                          name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                    )
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
                                      color: Colors.white.withValues(alpha: 0.7),
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
                          final response = await Supabase.instance.client.functions.invoke(
                            'delete-user',
                          );

                          if (response.data == null) {
                            throw Exception('Failed to delete account');
                          }

                          final responseData = response.data as Map<String, dynamic>;
                          if (responseData['error'] != null) {
                            throw Exception(responseData['error'] ?? 'Failed to delete account');
                          }

                          InventoryCache.clear();
                          await Supabase.instance.client.auth.signOut();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to delete account: ${friendlyApiError(e, fallback: 'Please try again.')}'),
                              backgroundColor: Theme.of(context).colorScheme.error,
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
                    )
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
            'To delete your account and all associated data,\nemail us at vinodrexfms@ai-robots.co\nfrom your registered email address.',
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
