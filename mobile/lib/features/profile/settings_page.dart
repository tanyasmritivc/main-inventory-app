import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/inventory_cache.dart';
import 'privacy_policy_page.dart';
import 'terms_of_service_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0x4DFFFFFF),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _glassCard(Widget child) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF171717),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
          ),
          child: child,
        ),
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

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface2(ctx),
        title: const Text('Delete Account', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
          style: TextStyle(color: Color(0x73FFFFFF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0x73FFFFFF)),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
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
      InventoryCache.clear();
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(e).$1),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
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
                  labelColor: const Color(0x73FFFFFF),
                  onTap: () =>
                      unawaited(Supabase.instance.client.auth.signOut()),
                ),
                _actionRow(
                  icon: Icons.delete_outline,
                  iconColor: const Color(0xFFEF4444),
                  label: 'Delete account',
                  labelColor: const Color(0xFFEF4444),
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

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
