import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/inventory_cache.dart';
import '../../core/ui/glass_card.dart';
import '../chat/chat_page.dart';
import '../documents/documents_page.dart';
import '../inventory/inventory_page.dart';
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
    unawaited(_prefetchInventoryCache());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: _index,
        children: [
          ChatPage(api: widget.api),
          ScanPage(
            api: widget.api,
            onSaved: () {
              setState(() {
                _inventoryRefreshToken++;
                _index = 2;
              });
            },
          ),
          InventoryPage(api: widget.api, refreshToken: _inventoryRefreshToken),
          DocumentsPage(api: widget.api),
          const _ProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

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

    Future<void> openExternal(String url) async {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Account',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.all(18),
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
                        : (email.isEmpty ? '—' : email);
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
          const SizedBox(height: 16),
          Text(
            'Actions',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                FilledButton(
                  onPressed: () {},
                  child: const Text('Go Pro'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                  },
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Legal',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton(
                  onPressed: () => openExternal('https://yourappdomain.com/privacy'),
                  child: const Text('Privacy Policy'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => openExternal('https://yourappdomain.com/terms'),
                  child: const Text('Terms of Service'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'To delete your account and all associated data, email us at support@yourappdomain.com\nfrom your registered email address.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}
