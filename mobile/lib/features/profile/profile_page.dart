import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/pro_status.dart';
import '../../core/upgrade_sheet.dart';
import '../sharing/sharing_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _confirmBeforeSave = false;
  bool _isPro = false;
  bool _isTeamCovered = false;
  bool _isPilotMode = false;
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
    _isTeamCovered = ProStatus.isTeamCovered;
    _isPilotMode = ProStatus.isPilotMode;
    _proLoading = !ProStatus.isPro && !ProStatus.isPilotMode;
    _loadScanSettings();
    _loadSubscriptionStatus();
    _displayNameCtrl = TextEditingController();
    _contactEmailCtrl = TextEditingController();

    // Seed from local session cache so first frame shows real name, not placeholder
    final sessionMeta = Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
    final fullName = (sessionMeta['full_name'] as String? ?? '').trim();
    final fallbackName = (sessionMeta['name'] as String? ?? '').trim();
    final cachedName = fullName.isNotEmpty ? fullName : fallbackName;
    if (cachedName.isNotEmpty) {
      _displayName = cachedName;
      _displayNameCtrl.text = cachedName;
    }

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
      await ProStatus.refresh(widget.api);
      if (mounted) {
        setState(() {
        _isPro = ProStatus.isPro;
        _isTeamCovered = ProStatus.isTeamCovered;
        _isPilotMode = ProStatus.isPilotMode;
        _proLoading = false;
      });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
        _isPro = ProStatus.isPro;
        _isTeamCovered = ProStatus.isTeamCovered;
        _isPilotMode = ProStatus.isPilotMode;
        _proLoading = false;
      });
      }
    }
  }

  Future<void> _loadFullProfile() async {
    try {
      final profile = await widget.api.getMyProfile();
      if (mounted) {
        setState(() {
        _displayName = profile['display_name'] ?? '';
        _contactEmail = profile['contact_email'] ?? '';
        _avatarColor = profile['avatar_color'] ?? '#636366';
        _displayNameCtrl.text = _displayName;
        _contactEmailCtrl.text = _contactEmail;
      });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t load your profile.')),
      );
    }
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

  Future<void> _sendFeedback() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'vinodrexfms@ai-robotics.co',
      queryParameters: {
        'subject': 'FindEZ Pilot Feedback',
        'body': 'Hi FindEZ team,\n\n',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email us at vinodrexfms@ai-robotics.co')),
      );
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 26, 0, 9),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      );

  Widget _glassCard(Widget child) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09), width: 0.5),
            ),
            child: child,
          ),
        ),
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
                  activeTrackColor: const Color(0xFF8E8E93),
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          // ── Account ──────────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.5),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _editingProfile ? null : () => setState(() => _editingProfile = true),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _hexToColor(_avatarColor),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                        ),
                        child: Center(
                          child: Text(
                            _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
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
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            Supabase.instance.client.auth.currentUser?.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
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
                            if (!context.mounted) return;
                            setState(() {
                              _displayName = _displayNameCtrl.text.trim();
                              _contactEmail = _contactEmailCtrl.text.trim();
                              _editingProfile = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profile updated')),
                            );
                          } catch (e) {
                            debugPrint('[ProfilePage] profile save error: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Couldn\'t save profile. Try again.')),
                              );
                            }
                            // _editingProfile stays true — user's input is not lost
                          }
                        } else {
                          setState(() => _editingProfile = true);
                        }
                      },
                      child: Text(
                        _editingProfile ? 'Save' : 'Edit',
                        style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if (_editingProfile) ...[
                  const SizedBox(height: 16),
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
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
                      '#8E8E93', '#30D158', '#FF9F0A', '#FF375F',
                      '#BF5AF2', '#8E8E93', '#FF6B35', '#636366',
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
          ),
          ),

          // ── Pro / Upgrade ────────────────────────────────────────────────
          if (_proLoading)
            Container(
              margin: const EdgeInsets.only(top: 16),
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
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
          else if (_isPilotMode)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x0A34D399),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x3334D399)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.rocket_launch_outlined,
                        color: Color(0xFF34D399), size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Free Pilot',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    ProStatus.pilotNotice ??
                        'Unlimited access through September 11, 2026. '
                        'Standard free-plan limits and optional paid plans begin September 12. '
                        'You will not be charged automatically.',
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => unawaited(_sendFeedback()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0x1A34D399),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x3334D399)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mail_outline,
                              color: Color(0xFF34D399), size: 15),
                          SizedBox(width: 6),
                          Text(
                            'Send feedback',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_isTeamCovered)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x0AA78BFA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x33A78BFA)),
              ),
              child: Row(children: [
                const Icon(Icons.group, color: Color(0xFFA78BFA), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FindEZ Team — Active',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      if (ProStatus.teamName != null)
                        Text('Covered by ${ProStatus.teamName}',
                            style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 12)),
                    ],
                  ),
                ),
              ]),
            )
          else if (_isPro)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x0A30D158),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x3330D158)),
              ),
              child: const Row(children: [
                Icon(Icons.check_circle, color: Color(0xFF30D158), size: 20),
                SizedBox(width: 10),
                Text('FindEZ Pro — Active',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            )
          else
            Container(
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x14FFFFFF)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0x1AA78BFA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.group_outlined,
                            color: Color(0xFFA78BFA), size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'FindEZ Team',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    const Text(
                      'Your whole robotics team shares one inventory. Ask your coach for a join code.',
                      style: TextStyle(
                          color: Color(0x73FFFFFF), fontSize: 13, height: 1.45),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => showJoinTeamDialog(context, widget.api),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA78BFA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Enter join code',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Team ─────────────────────────────────────────────────────────
          _sectionLabel('Team'),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: GestureDetector(
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
                          Icon(Icons.people_alt_rounded,
                              color: Color(0xFF8E8E93), size: 18),
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
                                      color: Color(0xFF8E8E93),
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
            ),
          ),

          // ── Scanning ─────────────────────────────────────────────────────
          _sectionLabel('Scanning'),
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
