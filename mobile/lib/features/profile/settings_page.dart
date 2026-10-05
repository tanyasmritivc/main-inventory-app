import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/inventory_cache.dart';
import '../../core/ui/app_gradient_background.dart';
import '../onboarding/onboarding_page.dart';
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
      style: TextStyle(
        color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
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
        color: AppTheme.adaptive(context, const Color(0xFF171717)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
          width: 0.5,
        ),
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
  }) => Column(
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
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.foreground(context, Color(0x33FFFFFF)),
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
      if (!last)
        Divider(
          height: 0.5,
          thickness: 0.5,
          color: AppTheme.adaptive(context, Color(0x14FFFFFF)),
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
        title: Text(
          'Delete Account',
          style: TextStyle(color: AppTheme.foreground(ctx, Colors.white)),
        ),
        content: Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
          style: TextStyle(color: AppTheme.foreground(ctx, Color(0x73FFFFFF))),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.foreground(ctx, Color(0x73FFFFFF)),
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.adaptive(ctx, const Color(0xFFEF4444)),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'delete-user',
      );
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
      path: 'info@findez.ai',
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
            content: Text(
              'Email us at info@findez.ai',
              style: TextStyle(
                color: AppTheme.foreground(context, Colors.white),
                fontSize: 14,
              ),
            ),
            backgroundColor: AppTheme.adaptive(
              context,
              const Color(0xFF1C1C1E),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Copy',
              textColor: AppTheme.adaptive(context, Colors.white),
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: 'info@findez.ai'));
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
      path: 'info@findez.ai',
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
            content: Text(
              'Email us at info@findez.ai',
              style: TextStyle(
                color: AppTheme.foreground(context, Colors.white),
                fontSize: 14,
              ),
            ),
            backgroundColor: AppTheme.adaptive(
              context,
              const Color(0xFF1C1C1E),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Copy',
              textColor: AppTheme.adaptive(context, Colors.white),
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: 'info@findez.ai'));
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
      backgroundColor: AppTheme.adaptive(context, Colors.black),
      appBar: AppBar(
        backgroundColor: AppTheme.adaptive(context, Colors.black),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Settings',
          style: TextStyle(
            color: AppTheme.foreground(context, Colors.white),
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(
          color: AppTheme.foreground(context, Colors.white),
        ),
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
                  iconColor: AppTheme.adaptive(
                    context,
                    const Color(0x73FFFFFF),
                  ),
                  label: 'Sign out',
                  labelColor: AppTheme.adaptive(
                    context,
                    const Color(0x73FFFFFF),
                  ),
                  onTap: () =>
                      unawaited(Supabase.instance.client.auth.signOut()),
                ),
                _actionRow(
                  icon: Icons.delete_outline,
                  iconColor: AppTheme.adaptive(
                    context,
                    const Color(0xFFEF4444),
                  ),
                  label: 'Delete account',
                  labelColor: AppTheme.adaptive(
                    context,
                    const Color(0xFFEF4444),
                  ),
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
                  icon: Icons.play_circle_outline_rounded,
                  iconColor: AppTheme.adaptive(
                    context,
                    const Color(0x73FFFFFF),
                  ),
                  label: 'App tour',
                  labelColor: AppTheme.adaptive(context, Colors.white),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (tourContext) => AppGradientBackground(
                        child: OnboardingPage(
                          isReplay: true,
                          onFinished: () => Navigator.of(tourContext).pop(),
                        ),
                      ),
                    ),
                  ),
                ),
                _actionRow(
                  icon: Icons.mail_outline,
                  iconColor: AppTheme.adaptive(
                    context,
                    const Color(0x73FFFFFF),
                  ),
                  label: 'Send feedback',
                  labelColor: AppTheme.adaptive(context, Colors.white),
                  onTap: () => unawaited(_sendFeedback()),
                ),
                _actionRow(
                  icon: Icons.bug_report_outlined,
                  iconColor: AppTheme.adaptive(
                    context,
                    const Color(0x73FFFFFF),
                  ),
                  label: 'Report a problem',
                  labelColor: AppTheme.adaptive(context, Colors.white),
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
                  iconColor: AppTheme.adaptive(
                    context,
                    const Color(0x73FFFFFF),
                  ),
                  label: 'Privacy Policy',
                  labelColor: AppTheme.adaptive(context, Colors.white),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyPage(),
                    ),
                  ),
                ),
                _actionRow(
                  icon: Icons.description_outlined,
                  iconColor: AppTheme.adaptive(
                    context,
                    const Color(0x73FFFFFF),
                  ),
                  label: 'Terms of Service',
                  labelColor: AppTheme.adaptive(context, Colors.white),
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
