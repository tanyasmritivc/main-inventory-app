import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/pro_status.dart';
import '../../core/upgrade_sheet.dart';
import '../../core/inventory_cache.dart';
import '../sharing/sharing_page.dart';
import 'privacy_policy_page.dart';
import 'terms_of_service_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final Future<String?> _nameFuture;
  bool _confirmBeforeSave = false;
  bool _isPro = false;
  bool _proLoading = true;
  String _displayName = '';
  String _contactEmail = '';
  String _avatarColor = '#636366';
  bool _editingProfile = false;
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _contactEmailCtrl;

  @override
  void initState() {
    super.initState();
    _isPro = ProStatus.isPro;
    _proLoading = !ProStatus.isPro;
    _nameFuture = _loadFirstName();
    _loadScanSettings();
    _loadSubscriptionStatus();
    _displayNameCtrl = TextEditingController();
    _contactEmailCtrl = TextEditingController();
    _loadFullProfile();
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _contactEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final isPro = await ProStatus.refresh(widget.api);
      if (mounted) setState(() {
        _isPro = isPro;
        _proLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _isPro = ProStatus.isPro;
        _proLoading = false;
      });
    }
  }

  Future<void> _loadFullProfile() async {
    try {
      final profile = await widget.api.getMyProfile();
      if (mounted) setState(() {
        _displayName = profile['display_name'] ?? '';
        _contactEmail = profile['contact_email'] ?? '';
        _avatarColor = profile['avatar_color'] ?? '#636366';
        _displayNameCtrl.text = _displayName;
        _contactEmailCtrl.text = _contactEmail;
      });
    } catch (_) {}
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

  Future<void> _subscribe(String plan) async {
    try {
      final url = await widget.api.createCheckoutSession(plan: plan);
      if (url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open checkout. Try again.')),
        );
      }
    }
  }

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

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

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
      backgroundColor: AppTheme.bg(context),
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
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // ── Account ──────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(0, 8, 0, 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x14FFFFFF)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _editingProfile ? null : () => setState(() => _editingProfile = true),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _hexToColor(_avatarColor),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_editingProfile)
                            TextField(
                              controller: _displayNameCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(
                                hintText: 'Display name',
                                hintStyle: TextStyle(color: Color(0x4DFFFFFF)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            )
                          else
                            Text(
                              _displayName.isNotEmpty ? _displayName : 'Set your name',
                              style: TextStyle(
                                color: _displayName.isNotEmpty ? Colors.white : const Color(0x4DFFFFFF),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            Supabase.instance.client.auth.currentUser?.email ?? '',
                            style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        if (_editingProfile) {
                          try {
                            await widget.api.updateProfile(
                              displayName: _displayNameCtrl.text.trim(),
                              contactEmail: _contactEmailCtrl.text.trim(),
                            );
                            setState(() {
                              _displayName = _displayNameCtrl.text.trim();
                              _contactEmail = _contactEmailCtrl.text.trim();
                              _editingProfile = false;
                            });
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profile updated')),
                            );
                          } catch (_) {}
                        } else {
                          setState(() => _editingProfile = true);
                        }
                      },
                      child: Text(
                        _editingProfile ? 'Save' : 'Edit',
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                if (_editingProfile) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Color(0x14FFFFFF), height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined, color: Color(0x4DFFFFFF), size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _contactEmailCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'Contact email (visible to teammates)',
                            hintStyle: TextStyle(color: Color(0x4DFFFFFF)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Avatar color', style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 12)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [
                      '#0A84FF', '#30D158', '#FF9F0A', '#FF375F',
                      '#BF5AF2', '#5E5CE6', '#FF6B35', '#636366',
                    ].map((color) => GestureDetector(
                      onTap: () async {
                        setState(() => _avatarColor = color);
                        await widget.api.updateProfile(avatarColor: color);
                      },
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: _hexToColor(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _avatarColor == color ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ] else if (_contactEmail.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Color(0x14FFFFFF), height: 1),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse('mailto:$_contactEmail');
                      if (await canLaunchUrl(uri)) launchUrl(uri);
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.email_outlined, color: Color(0x4DFFFFFF), size: 14),
                        const SizedBox(width: 8),
                        Text(
                          _contactEmail,
                          style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 13),
                        ),
                        const Spacer(),
                        const Icon(Icons.open_in_new, color: Color(0x4DFFFFFF), size: 12),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Pro / Upgrade ────────────────────────────────────────────────
          if (_proLoading)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0x0AFFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x14FFFFFF)),
              ),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Color(0x73FFFFFF),
                  ),
                ),
              ),
            )
          else if (_isPro)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x0A30D158),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x3330D158)),
              ),
              child: const Row(children: [
                Icon(Icons.check_circle, color: Color(0xFF30D158), size: 20),
                SizedBox(width: 10),
                Text('FindEZ Pro — Active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            )
          else
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F1B2D), Color(0xFF0A1628)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0x334B8BF5), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0x1A4B8BF5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.bolt, color: Color(0xFF4B8BF5), size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'FindEZ Pro',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x1A4B8BF5),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: const Color(0x334B8BF5)),
                          ),
                          child: const Text(
                            'UPGRADE',
                            style: TextStyle(
                              color: Color(0xFF4B8BF5),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Unlock the full power of FindEZ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...['Unlimited spaces & items', 'Unlimited AI photo scans', 'Share spaces with anyone', 'Spreadsheet import'].map((f) =>
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: const Color(0x1A4B8BF5),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Icon(Icons.check, color: Color(0xFF4B8BF5), size: 10),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              f,
                              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () => showUpgradeSheet(context, widget.api),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B8BF5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'View Plans',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0x0A4B8BF5),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          '✦ Save 28% with annual plan',
                          style: TextStyle(
                            color: Color(0x664B8BF5),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
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

          const SizedBox(height: 24),
          const Center(
            child: Text(
              'by AI Robots Inc',
              style: TextStyle(
                color: Color(0x4DFFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
