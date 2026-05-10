import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/inventory_cache.dart';
import '../sharing/sharing_page.dart';
import 'privacy_policy_page.dart';
import 'terms_of_service_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final Future<String?> _nameFuture;
  bool _confirmBeforeSave = false;

  @override
  void initState() {
    super.initState();
    _nameFuture = _loadFirstName();
    _loadScanSettings();
  }

  Future<void> _loadScanSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _confirmBeforeSave = prefs.getBool('confirm_before_save') ?? false;
    });
  }

  Future<void> _setConfirmBeforeSave(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('confirm_before_save', value);
    if (mounted) setState(() => _confirmBeforeSave = value);
  }

  Future<String?> _loadFirstName() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return null;
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('first_name')
          .eq('id', userId)
          .maybeSingle();
      final first = (res?['first_name'] as String?)?.trim();
      return (first != null && first.isNotEmpty) ? first : null;
    } catch (_) {
      return null;
    }
  }

  String get _displayName {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final e = email.trim();
    if (e.isEmpty) return '—';
    final at = e.indexOf('@');
    if (at <= 0) return e;
    return e.substring(0, at);
  }

  Future<void> _sendFeedback() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'vinodrexfms@ai-robotics.co',
      queryParameters: {
        'subject': 'FindEZ Feedback',
        'body': 'Hi FindEZ team,\n\n',
      },
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Email us at vinodrexfms@ai-robotics.co',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            backgroundColor: const Color(0xFF1C1C1E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Copy',
              textColor: Colors.white,
              onPressed: () {
                Clipboard.setData(
                  const ClipboardData(text: 'vinodrexfms@ai-robotics.co'),
                );
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _reportProblem() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'vinodrexfms@ai-robotics.co',
      queryParameters: {
        'subject': 'FindEZ Bug Report',
        'body': 'Hi FindEZ team,\n\nI found an issue:\n\n',
      },
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Email us at vinodrexfms@ai-robotics.co',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            backgroundColor: const Color(0xFF1C1C1E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Copy',
              textColor: Colors.white,
              onPressed: () {
                Clipboard.setData(
                  const ClipboardData(text: 'vinodrexfms@ai-robotics.co'),
                );
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final response =
          await Supabase.instance.client.functions.invoke('delete-user');
      if (response.data == null) throw Exception('Failed to delete account');
      final data = response.data as Map<String, dynamic>;
      if (data['error'] != null) {
        throw Exception(data['error'] ?? 'Failed to delete account');
      }
      InventoryCache.setItems(const []);
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0x4DFFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _glassCard(Widget child) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
          ),
          child: child,
        ),
      );

  Widget _statRow(String label, String value, {bool last = false}) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0x73FFFFFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!last)
            const Divider(
              height: 0.5,
              thickness: 0.5,
              color: Color(0x14FFFFFF),
              indent: 0,
              endIndent: 0,
            ),
        ],
      );

  Widget _toggleRow({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool last = false,
  }) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0x4DFFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0x4DFFFFFF),
                  inactiveThumbColor: const Color(0x33FFFFFF),
                  inactiveTrackColor: const Color(0x14FFFFFF),
                ),
              ],
            ),
          ),
          if (!last)
            const Divider(
              height: 0.5,
              thickness: 0.5,
              color: Color(0x14FFFFFF),
              indent: 0,
              endIndent: 0,
            ),
        ],
      );

  Widget _actionRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color labelColor,
    bool showChevron = true,
    required VoidCallback onTap,
    bool last = false,
  }) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Icon(icon, color: iconColor, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    if (showChevron)
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0x33FFFFFF),
                        size: 18,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!last)
            const Divider(
              height: 0.5,
              thickness: 0.5,
              color: Color(0x14FFFFFF),
              indent: 0,
              endIndent: 0,
            ),
        ],
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final items = InventoryCache.items;
    final itemsTracked = items.length;
    final locationSet = <String>{};
    for (final it in items) {
      final loc = it.location.trim().isEmpty ? 'Unsorted' : it.location.trim();
      locationSet.add(loc.toLowerCase());
    }
    final spaces = locationSet.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // ── Account ──────────────────────────────────────────────────────
          _sectionLabel('ACCOUNT'),
          _glassCard(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_outline,
                    color: Color(0x4DFFFFFF),
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  FutureBuilder<String?>(
                    future: _nameFuture,
                    builder: (context, snap) {
                      final name =
                          (snap.data != null && snap.data!.isNotEmpty)
                              ? snap.data!
                              : _displayName;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Signed in as',
                            style: TextStyle(
                              color: Color(0x4DFFFFFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Your Inventory ───────────────────────────────────────────────
          _sectionLabel('YOUR INVENTORY'),
          _glassCard(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statRow('Items tracked', '$itemsTracked'),
                _statRow('Spaces', '$spaces'),
                _statRow('Scans this week', '0', last: true),
              ],
            ),
          ),

          // ── Team ─────────────────────────────────────────────────────────
          _sectionLabel('TEAM'),
          _glassCard(
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SharingPage()),
              ),
              child: const SizedBox(
                height: 64,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Icon(Icons.people_outline,
                          color: Color(0x73FFFFFF), size: 18),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Team Sharing',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Share your inventory with teammates',
                              style: TextStyle(
                                  color: Color(0x4DFFFFFF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: Color(0x33FFFFFF), size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Actions ──────────────────────────────────────────────────────
          _sectionLabel('ACTIONS'),
          _glassCard(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionRow(
                  icon: Icons.logout,
                  iconColor: const Color(0x73FFFFFF),
                  label: 'Sign out',
                  labelColor: Colors.white,
                  onTap: () =>
                      unawaited(Supabase.instance.client.auth.signOut()),
                ),
                _actionRow(
                  icon: Icons.delete_outline,
                  iconColor: const Color(0xFFFF3B30),
                  label: 'Delete account',
                  labelColor: const Color(0xFFFF3B30),
                  showChevron: false,
                  onTap: () => unawaited(_deleteAccount()),
                  last: true,
                ),
              ],
            ),
          ),

          // ── Support ──────────────────────────────────────────────────────
          _sectionLabel('SUPPORT'),
          _glassCard(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionRow(
                  icon: Icons.mail_outline,
                  iconColor: const Color(0x73FFFFFF),
                  label: 'Send feedback',
                  labelColor: Colors.white,
                  onTap: () => unawaited(_sendFeedback()),
                ),
                _actionRow(
                  icon: Icons.bug_report_outlined,
                  iconColor: const Color(0x73FFFFFF),
                  label: 'Report a problem',
                  labelColor: Colors.white,
                  onTap: () => unawaited(_reportProblem()),
                  last: true,
                ),
              ],
            ),
          ),

          // ── Legal ────────────────────────────────────────────────────────
          _sectionLabel('LEGAL'),
          _glassCard(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionRow(
                  icon: Icons.shield_outlined,
                  iconColor: const Color(0x73FFFFFF),
                  label: 'Privacy Policy',
                  labelColor: Colors.white,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyPage(),
                    ),
                  ),
                ),
                _actionRow(
                  icon: Icons.description_outlined,
                  iconColor: const Color(0x73FFFFFF),
                  label: 'Terms of Service',
                  labelColor: Colors.white,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TermsOfServicePage(),
                    ),
                  ),
                  last: true,
                ),
              ],
            ),
          ),

          // ── Scanning ─────────────────────────────────────────────────────
          _sectionLabel('SCANNING'),
          _glassCard(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toggleRow(
                  label: 'Confirm before saving',
                  subtitle:
                      'Review and verify AI results before anything is saved.\nRecommended for business use.',
                  value: _confirmBeforeSave,
                  onChanged: (v) => unawaited(_setConfirmBeforeSave(v)),
                  last: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
