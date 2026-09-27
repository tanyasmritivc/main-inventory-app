import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/ui/visual_surfaces.dart';
import '../../core/inventory_cache.dart';
import '../../core/pro_status.dart';
import '../../core/upgrade_sheet.dart';
import 'privacy_policy_page.dart';
import 'terms_of_service_page.dart';

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
  String _avatarUrl = '';
  String _organization = '';
  String _profileRole = '';
  bool _avatarUploading = false;
  bool _editingProfile = false;
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _contactEmailCtrl;
  late final TextEditingController _organizationCtrl;
  late final TextEditingController _profileRoleCtrl;

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
    _organizationCtrl = TextEditingController();
    _profileRoleCtrl = TextEditingController();

    // Seed from local session cache so first frame shows real name, not placeholder
    final sessionMeta =
        Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
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
    _organizationCtrl.dispose();
    _profileRoleCtrl.dispose();
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
          _avatarUrl = profile['avatar_url'] ?? '';
          _organization = profile['organization'] ?? '';
          _profileRole = profile['profile_role'] ?? '';
          _displayNameCtrl.text = _displayName;
          _contactEmailCtrl.text = _contactEmail;
          _organizationCtrl.text = _organization;
          _profileRoleCtrl.text = _profileRole;
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

  Future<void> _chooseAvatarPhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 78,
    );
    if (image == null) return;
    if (mounted) setState(() => _avatarUploading = true);
    try {
      final url = await widget.api.uploadProfilePhoto(
        bytes: await image.readAsBytes(),
        filename: image.name,
      );
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() => _avatarUrl = url);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _removeAvatarPhoto() async {
    setState(() => _avatarUploading = true);
    try {
      await widget.api.deleteProfilePhoto();
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() => _avatarUrl = '');
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _editAvatarPhoto() async {
    if (_avatarUrl.isEmpty) {
      await _chooseAvatarPhoto();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTokens.of(context).card,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose another photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _chooseAvatarPhoto();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFFF6961),
                ),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: Color(0xFFFF6961)),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removeAvatarPhoto();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setConfirmBeforeSave(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('confirm_before_save', value);
    if (mounted) setState(() => _confirmBeforeSave = value);
  }

  Future<void> _sendFeedback() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'info@findez.ai',
      queryParameters: {
        'subject': 'FindEZ Pilot Feedback',
        'body': 'Hi FindEZ team,\n\n',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email us at info@findez.ai')),
      );
    }
  }

  Future<void> _reportProblem() async {
    await _openSupportEmail(
      subject: 'FindEZ Bug Report',
      body: 'Hi FindEZ team,\n\nI found an issue:\n\n',
    );
  }

  Future<void> _openSupportEmail({
    required String subject,
    required String body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'info@findez.ai',
      queryParameters: {'subject': subject, 'body': body},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email us at info@findez.ai'),
          action: SnackBarAction(
            label: 'Copy',
            onPressed: () =>
                Clipboard.setData(const ClipboardData(text: 'info@findez.ai')),
          ),
        ),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface2(dialogContext),
        title: const Text('Delete account'),
        content: const Text(
          'This permanently deletes your account and data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
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
      final data = response.data;
      if (data == null || (data is Map && data['error'] != null)) {
        throw Exception(
          data is Map ? data['error'] : 'Failed to delete account',
        );
      }
      InventoryCache.clear();
      await Supabase.instance.client.auth.signOut();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
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
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(color: AppTokens.of(context).text2),
    ),
  );

  Widget _groupedCard(Widget child) =>
      GroupedSurface(padding: EdgeInsets.zero, child: child);

  Widget _toggleRow({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool last = false,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTokens.rowHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTokens.of(context).text2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
      if (!last) Divider(height: 1, color: AppTokens.of(context).separator),
    ],
  );

  Widget _actionRow({
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool showChevron = true,
    bool last = false,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTokens.rowHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: color ?? AppTokens.of(context).ink,
                    ),
                  ),
                ),
                if (showChevron)
                  Text(
                    'Open',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTokens.of(context).text3,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      if (!last) Divider(height: 1, color: AppTokens.of(context).separator),
    ],
  );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.of(context).bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
        children: [
          // ── Account ──────────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radius),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTokens.of(context).card,
                borderRadius: BorderRadius.circular(AppTokens.radius),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _editingProfile
                            ? _editAvatarPhoto
                            : () => setState(() => _editingProfile = true),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _hexToColor(_avatarColor),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTokens.of(
                                context,
                              ).ink.withValues(alpha: 0.18),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _avatarUploading
                              ? const Padding(
                                  padding: EdgeInsets.all(19),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : _avatarUrl.isNotEmpty
                              ? Image.network(
                                  _avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Center(
                                    child: Text(
                                      _displayName.isNotEmpty
                                          ? _displayName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: AppTokens.of(context).ink,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    _displayName.isNotEmpty
                                        ? _displayName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: AppTokens.of(context).ink,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
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
                                onSubmitted: (_) => FocusManager
                                    .instance
                                    .primaryFocus
                                    ?.unfocus(),
                                style: TextStyle(
                                  color: AppTokens.of(context).ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Display name',
                                  hintStyle: TextStyle(
                                    color: AppTokens.of(context).text3,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              )
                            else
                              Text(
                                _displayName.isNotEmpty
                                    ? _displayName
                                    : 'Set your name',
                                style: TextStyle(
                                  color: _displayName.isNotEmpty
                                      ? AppTokens.of(context).ink
                                      : AppTokens.of(context).text3,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              Supabase
                                      .instance
                                      .client
                                      .auth
                                      .currentUser
                                      ?.email ??
                                  '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTokens.of(context).text2,
                                fontSize: 13,
                              ),
                            ),
                            if (!_editingProfile &&
                                (_profileRole.isNotEmpty ||
                                    _organization.isNotEmpty)) ...[
                              const SizedBox(height: 4),
                              Text(
                                [_profileRole, _organization]
                                    .where((value) => value.isNotEmpty)
                                    .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTokens.of(context).text2,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
                                organization: _organizationCtrl.text.trim(),
                                profileRole: _profileRoleCtrl.text.trim(),
                              );
                              if (!context.mounted) return;
                              setState(() {
                                _displayName = _displayNameCtrl.text.trim();
                                _contactEmail = _contactEmailCtrl.text.trim();
                                _organization = _organizationCtrl.text.trim();
                                _profileRole = _profileRoleCtrl.text.trim();
                                _editingProfile = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated'),
                                ),
                              );
                            } catch (e) {
                              debugPrint(
                                '[ProfilePage] profile save error: $e',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Couldn\'t save profile. Try again.',
                                    ),
                                  ),
                                );
                              }
                              // _editingProfile stays true, so the user's input is preserved
                            }
                          } else {
                            setState(() => _editingProfile = true);
                          }
                        },
                        child: Text(
                          _editingProfile ? 'Save' : 'Edit',
                          style: TextStyle(
                            color: AppTokens.of(context).ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_editingProfile) ...[
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _editAvatarPhoto,
                        icon: const Icon(Icons.add_a_photo_outlined, size: 17),
                        label: Text(
                          _avatarUrl.isEmpty
                              ? 'Add profile photo'
                              : 'Change profile photo',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTokens.of(context).ink,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.groups_2_outlined,
                          color: AppTokens.of(context).text3,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _organizationCtrl,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(
                              color: AppTokens.of(context).ink,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Organization or team (optional)',
                              hintStyle: TextStyle(
                                color: AppTokens.of(context).text3,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          color: AppTokens.of(context).text3,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _profileRoleCtrl,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(
                              color: AppTokens.of(context).ink,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Role (optional)',
                              hintStyle: TextStyle(
                                color: AppTokens.of(context).text3,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          color: AppTokens.of(context).text3,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _contactEmailCtrl,
                            style: TextStyle(
                              color: AppTokens.of(context).ink,
                              fontSize: 14,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            decoration: InputDecoration(
                              hintText: 'Contact email (optional)',
                              hintStyle: TextStyle(
                                color: AppTokens.of(context).text3,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 26, top: 5),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Visible only to people you collaborate with.',
                          style: TextStyle(
                            color: AppTokens.of(context).text3,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Profile color',
                        style: TextStyle(
                          color: AppTokens.of(context).text3,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children:
                          [
                                '#8FB5EE',
                                '#93D8C4',
                                '#B7A4E8',
                                '#F2A9B8',
                                '#F3C78B',
                                '#F0A98D',
                                '#8FCFD1',
                                '#A9ADB5',
                              ]
                              .map(
                                (color) => GestureDetector(
                                  onTap: () async {
                                    setState(() => _avatarColor = color);
                                    await widget.api.updateProfile(
                                      avatarColor: color,
                                    );
                                  },
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: _hexToColor(color),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _avatarColor == color
                                            ? AppTokens.of(context).ink
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ] else if (_contactEmail.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse('mailto:$_contactEmail');
                        if (await canLaunchUrl(uri)) launchUrl(uri);
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            color: AppTokens.of(context).text3,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _contactEmail,
                            style: TextStyle(
                              color: AppTokens.of(context).text2,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.open_in_new,
                            color: AppTokens.of(context).text3,
                            size: 12,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Pro / Upgrade ────────────────────────────────────────────────
          if (_proLoading)
            Container(
              margin: const EdgeInsets.only(top: 16),
              height: 60,
              decoration: BoxDecoration(
                color: AppTokens.of(context).card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTokens.of(context).separator),
              ),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppTokens.of(context).text2,
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
                  Text(
                    'Free Pilot',
                    style: TextStyle(
                      color: AppTokens.of(context).ink,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    ProStatus.pilotNotice ??
                        'Unlimited access through September 11, 2026. '
                            'Standard free-plan limits and optional paid plans begin September 12. '
                            'You will not be charged automatically.',
                    style: TextStyle(
                      color: AppTokens.of(context).text2,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => unawaited(_sendFeedback()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1A34D399),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x3334D399)),
                      ),
                      child: const Text(
                        'Send feedback',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
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
                color: const Color(0x0AE8590C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x33E8590C)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.group, color: Color(0xFFE8590C), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FindEZ Team — Active',
                          style: TextStyle(
                            color: AppTokens.of(context).ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (ProStatus.teamName != null)
                          Text(
                            'Covered by ${ProStatus.teamName}',
                            style: TextStyle(
                              color: AppTokens.of(context).text2,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
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
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF30D158), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'FindEZ Pro — Active',
                    style: TextStyle(
                      color: AppTokens.of(context).ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                color: AppTokens.of(context).card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTokens.of(context).separator),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0x1AE8590C),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.group_outlined,
                            color: Color(0xFFE8590C),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'FindEZ Team',
                          style: TextStyle(
                            color: AppTokens.of(context).ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your whole robotics team shares one inventory. Ask your coach for a join code.',
                      style: TextStyle(
                        color: AppTokens.of(context).text2,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => showJoinTeamDialog(context, widget.api),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8590C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Enter join code',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTokens.of(context).ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Scanning ─────────────────────────────────────────────────────
          _sectionLabel('Scanning'),
          _groupedCard(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toggleRow(
                  label: 'Confirm before saving',
                  subtitle:
                      'Review barcode and manual results. FIND photo results are always reviewed.',
                  value: _confirmBeforeSave,
                  onChanged: (v) => unawaited(_setConfirmBeforeSave(v)),
                  last: true,
                ),
              ],
            ),
          ),

          _sectionLabel('Support'),
          _groupedCard(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionRow(
                  label: 'Send feedback',
                  onTap: () => unawaited(_sendFeedback()),
                ),
                _actionRow(
                  label: 'Report a problem',
                  onTap: () => unawaited(_reportProblem()),
                  last: true,
                ),
              ],
            ),
          ),

          _sectionLabel('Legal'),
          _groupedCard(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionRow(
                  label: 'Privacy Policy',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyPage(),
                    ),
                  ),
                ),
                _actionRow(
                  label: 'Terms of Service',
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

          _sectionLabel('Account'),
          _groupedCard(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionRow(
                  label: 'Sign out',
                  color: const Color(0xFFB8B8BD),
                  showChevron: false,
                  onTap: () =>
                      unawaited(Supabase.instance.client.auth.signOut()),
                ),
                _actionRow(
                  label: 'Delete account',
                  color: const Color(0xFFFF453A),
                  showChevron: false,
                  onTap: () => unawaited(_deleteAccount()),
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
