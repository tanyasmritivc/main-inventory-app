import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/inventory_cache.dart';
import '../../core/ui/glass_card.dart';
import '../chat/chat_page.dart';
import '../inventory/inventory_page.dart';
import '../profile/privacy_policy_page.dart';
import '../profile/profile_page.dart';
import '../profile/terms_of_service_page.dart';
import '../scan/scan_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.api});

  final ApiClient api;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  int _inventoryRefreshToken = 0;
  late final PageController _pageController;

  final List<Widget?> _tabs = List<Widget?>.filled(3, null);

  ChatPage _buildAskTab() {
    return ChatPage(
      api: widget.api,
      onInventoryMutated: () {
        setState(() {
          _inventoryRefreshToken++;
          _tabs[2] = null;
        });
        _ensureTabBuilt(2);
        unawaited(_prefetchInventoryCache());
      },
      onProfileTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProfilePage(api: widget.api)),
        );
      },
    );
  }

  Future<void> _prefetchInventoryCache() async {
    try {
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null || uid.isEmpty) return;

      final resp = await supabase
          .from('items')
          .select('item_id,name,category,quantity,location,created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(1000);

      final rows = (resp as List<dynamic>).cast<Map<String, dynamic>>();
      final items = rows.map(InventoryItem.fromJson).toList();
      InventoryCache.setItems(items);
    } catch (_) {
      // Best-effort only.
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    widget.api.warmupAi();
    _tabs[0] = _buildAskTab();
    unawaited(_prefetchInventoryCache());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _ensureTabBuilt(index);
      _index = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onScanSaved() {
    setState(() {
      _inventoryRefreshToken++;
      _tabs[2] = null;
    });
    _ensureTabBuilt(2);
    unawaited(_prefetchInventoryCache());
  }

  void _ensureTabBuilt(int i) {
    if (_tabs[i] != null) return;
    switch (i) {
      case 1:
        return;
      case 2:
        _tabs[i] = InventoryPage(
          api: widget.api,
          refreshToken: _inventoryRefreshToken,
        );
        return;
      case 0:
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _ensureTabBuilt(index);
            _index = index;
          });
        },
        children: [
          _tabs[0] ?? const SizedBox.shrink(),
          ScanPage(
            api: widget.api,
            isActive: _index == 1,
            onSaved: _onScanSaved,
          ),
          _tabs[2] ?? const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 0.5, color: const Color(0x14FFFFFF)),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _onTabTapped,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded),
                label: 'Ask',
              ),
              NavigationDestination(
                icon: Icon(Icons.qr_code_scanner_outlined),
                selectedIcon: Icon(Icons.qr_code_scanner),
                label: 'Scan',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'My Stuff',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
                          // Call the Edge Function to delete user data
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

                          // Clear cache and sign out
                          InventoryCache.setItems(const []);
                          await Supabase.instance.client.auth.signOut();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to delete account: ${e.toString()}'),
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
