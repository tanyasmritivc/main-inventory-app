import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/inventory_cache.dart';
import '../../core/theme_preference.dart';
import '../inventory/world_views.dart';
import 'privacy_policy_page.dart';
import 'profile_page.dart';
import 'terms_of_service_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _profile;
  String? _error;
  bool _confirmBeforeSave = false;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final profile = await widget.api.getMyProfile();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _confirmBeforeSave = prefs.getBool('confirm_before_save') ?? false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeError(error).$1);
    }
  }

  Future<void> _setConfirm(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('confirm_before_save', value);
      if (mounted) setState(() => _confirmBeforeSave = value);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'Your account and its personal data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _working = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'delete-user',
      );
      final data = response.data;
      if (data is! Map || data['error'] != null) {
        throw StateError(
          data is Map
              ? (data['error'] ?? 'Account deletion failed.').toString()
              : 'Account deletion failed.',
        );
      }
      InventoryCache.clear();
      await Supabase.instance.client.auth.signOut();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _working = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _emailSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'info@findez.ai',
      queryParameters: {'subject': 'FindEZ support'},
    );
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email info@findez.ai for support.')),
      );
    }
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final profile = _profile;
    final name = (profile?['display_name'] ?? '').toString();
    final email =
        (profile?['contact_email'] ??
                Supabase.instance.client.auth.currentUser?.email ??
                '')
            .toString();
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            WorldHeader(
              title: 'Settings',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  children: [
                    if (profile == null && _error == null)
                      const Center(child: CircularProgressIndicator())
                    else if (_error != null)
                      WorldSection(
                        title: 'Could not load settings',
                        children: [
                          WorldRow(title: _error!, count: ''),
                          WorldRow(title: 'Try again', count: '', onTap: _load),
                        ],
                      )
                    else ...[
                      WorldSection(
                        title: 'Your account',
                        children: [
                          WorldRow(
                            title: name.isEmpty ? 'Your profile' : name,
                            subtitle: email,
                            count: 'EDIT',
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfilePage(api: widget.api),
                                ),
                              );
                              if (mounted) await _load();
                            },
                          ),
                        ],
                      ),
                      WorldSection(
                        title: 'Appearance',
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Theme',
                                  style: TextStyle(color: t.ink, fontSize: 15),
                                ),
                                const SizedBox(height: 10),
                                ValueListenableBuilder<ThemeMode>(
                                  valueListenable: ThemePreference.mode,
                                  builder: (context, mode, _) => Wrap(
                                    spacing: 8,
                                    children: [
                                      for (final choice in ThemeMode.values)
                                        ChoiceChip(
                                          label: Text(switch (choice) {
                                            ThemeMode.light => 'Light',
                                            ThemeMode.dark => 'Dark',
                                            ThemeMode.system => 'System',
                                          }),
                                          selected: mode == choice,
                                          onSelected: (_) async {
                                            try {
                                              await ThemePreference.set(choice);
                                            } catch (error) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    describeError(error).$1,
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const WorldRow(
                            title: 'Text size',
                            subtitle: 'Follows your phone',
                            count: '',
                          ),
                        ],
                      ),
                      WorldSection(
                        title: 'Your photographs',
                        children: [
                          const WorldRow(
                            title: 'Source photographs',
                            subtitle:
                                'The full frame is kept beside each captured object.',
                            count: '',
                          ),
                          SwitchListTile.adaptive(
                            title: const Text('Review before saving'),
                            subtitle: const Text(
                              'Check the result of each capture before it enters inventory.',
                            ),
                            value: _confirmBeforeSave,
                            onChanged: _setConfirm,
                          ),
                        ],
                      ),
                      WorldSection(
                        title: 'Help and legal',
                        children: [
                          WorldRow(
                            title: 'Contact support',
                            count: '',
                            onTap: _emailSupport,
                          ),
                          WorldRow(
                            title: 'Privacy policy',
                            count: '',
                            onTap: () => _open(const PrivacyPolicyPage()),
                          ),
                          WorldRow(
                            title: 'Terms of service',
                            count: '',
                            onTap: () => _open(const TermsOfServicePage()),
                          ),
                        ],
                      ),
                      WorldSection(
                        title: 'Account',
                        children: [
                          WorldRow(
                            title: _working ? 'Working' : 'Sign out',
                            count: '',
                            onTap: _working ? null : _signOut,
                          ),
                          WorldRow(
                            title: 'Delete account',
                            count: '',
                            onTap: _working ? null : _deleteAccount,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
