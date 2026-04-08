import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/inventory_cache.dart';
import '../chat/chat_page.dart';
import '../documents/documents_page.dart';
import '../inventory/inventory_page.dart';
import '../profile/privacy_policy_page.dart';
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

  final List<Widget?> _tabs = List<Widget?>.filled(5, null);

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
          .limit(250);

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
    widget.api.warmupAi();
    _tabs[0] = ChatPage(
      api: widget.api,
      onInventoryMutated: () {
        setState(() {
          _inventoryRefreshToken++;
        });
      },
    );
    unawaited(_prefetchInventoryCache());
  }

  void _ensureTabBuilt(int i) {
    if (_tabs[i] != null) return;
    switch (i) {
      case 1:
        _tabs[i] = ScanPage(
          api: widget.api,
          onSaved: () {
            setState(() {
              _inventoryRefreshToken++;
            });
          },
        );
        return;
      case 2:
        _tabs[i] = InventoryPage(
          api: widget.api,
          refreshToken: _inventoryRefreshToken,
        );
        return;
      case 3:
        _tabs[i] = DocumentsPage(api: widget.api);
        return;
      case 4:
        _tabs[i] = const _ProfilePage();
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
      body: IndexedStack(
        index: _index,
        children: List<Widget>.generate(
          5,
          (i) => _tabs[i] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _ensureTabBuilt(i);
            _index = i;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Assist'),
          NavigationDestination(icon: Icon(Icons.center_focus_strong_outlined), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.view_list_outlined), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Docs'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    const bgGradient = LinearGradient(
      colors: [
        Color(0xFF020617),
        Color(0xFF0F172A),
        Color(0xFF020617),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: bgGradient),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
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
                  ],
                ),
              ),
            ),
          ),
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
