import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'Assist'),
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

    Future<void> openExternal(String url) async {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Signed in as',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              email.isEmpty ? '—' : email,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
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
            const SizedBox(height: 18),
            Text(
              'Legal',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => openExternal('https://yourappdomain.com/privacy'),
              child: const Text('Privacy Policy'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => openExternal('https://yourappdomain.com/terms'),
              child: const Text('Terms of Service'),
            ),
            const SizedBox(height: 14),
            Text(
              'To delete your account and all associated data, email us at support@yourappdomain.com\n from your registered email address.',
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
