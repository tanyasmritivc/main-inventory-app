import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/inventory_cache.dart';
import '../../core/pro_status.dart';
import '../../core/profile_store.dart';
import '../../core/upgrade_sheet.dart';
import 'privacy_policy_page.dart';
import 'terms_of_service_page.dart';
import 'profile_editor_page.dart';
import 'appearance_settings.dart';
import 'package:mobile/core/ui/app_text.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.api,
    this.accountOnly = false,
    this.settingsOnly = false,
    this.store,
  }) : assert(!(accountOnly && settingsOnly));

  final ApiClient api;
  final bool accountOnly;
  final bool settingsOnly;
  final ProfileStore? store;

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
    if (!widget.accountOnly) {
      _loadScanSettings();
      _loadSubscriptionStatus();
    }
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

    if (!widget.settingsOnly && !widget.accountOnly) _loadFullProfile();
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
    final owner = Supabase.instance.client.auth.currentUser?.id;
    try {
      final profile = await widget.api.getMyProfile();
      if (mounted && owner == Supabase.instance.client.auth.currentUser?.id) {
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
      if (!mounted || owner != Supabase.instance.client.auth.currentUser?.id) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Couldn’t load your profile.')),
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
    if (_avatarUploading) return;
    setState(() => _avatarUploading = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 78,
      );
      if (image == null || !mounted) return;
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
      ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _removeAvatarPhoto() async {
    if (_avatarUploading) return;
    setState(() => _avatarUploading = true);
    try {
      await widget.api.deleteProfilePhoto();
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() => _avatarUrl = '');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
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
      backgroundColor: AppTheme.adaptive(context, const Color(0xFF1C1C1E)),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const AppText('Choose another photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _chooseAvatarPhoto();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: AppTheme.foreground(sheetContext, Color(0xFFFF6961)),
                ),
                title: AppText(
                  'Remove photo',
                  style: TextStyle(
                    color: AppTheme.foreground(sheetContext, Color(0xFFFF6961)),
                  ),
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
        const SnackBar(content: AppText('Email us at info@findez.ai')),
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
          content: const AppText('Email us at info@findez.ai'),
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
        title: const AppText('Delete account'),
        content: const AppText(
          'This permanently deletes your account and data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.adaptive(
                dialogContext,
                const Color(0xFFEF4444),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('Delete'),
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
      ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return RegExp(r'^[a-fA-F0-9]{6}$').hasMatch(h)
        ? Color(int.parse('FF$h', radix: 16))
        : AppTheme.adaptive(context, const Color(0xFF636366));
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 26, 0, 9),
    child: AppText(
      text,
      style: TextStyle(
        color: AppTheme.foreground(context, Color(0xFF8E8E93)),
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
          color: AppTheme.adaptive(
            context,
            const Color(0xFF1C1C1E).withValues(alpha: 0.92),
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.adaptive(
              context,
              Colors.white.withValues(alpha: 0.09),
            ),
            width: 0.5,
          ),
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
  }) => Column(
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
                  AppText(
                    label,
                    style: TextStyle(
                      color: AppTheme.foreground(context, Colors.white),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AppText(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
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
              activeTrackColor: AppTheme.adaptive(
                context,
                const Color(0xFF6997DD),
              ),
              inactiveThumbColor: AppTheme.adaptive(
                context,
                const Color(0x33FFFFFF),
              ),
              inactiveTrackColor: AppTheme.adaptive(
                context,
                const Color(0x14FFFFFF),
              ),
            ),
          ],
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

  Widget _actionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
    bool showChevron = true,
    bool last = false,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppTheme.foreground(
                  context,
                  color.withValues(alpha: 0.75),
                ),
                size: 19,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: AppText(
                  label,
                  style: TextStyle(
                    color: AppTheme.foreground(context, color),
                    fontSize: 15,
                  ),
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.foreground(
                    context,
                    color.withValues(alpha: 0.25),
                  ),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
      if (!last)
        Divider(
          height: 0.5,
          thickness: 0.5,
          color: AppTheme.adaptive(context, Color(0x14FFFFFF)),
        ),
    ],
  );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.accountOnly) {
      return ProfileEditorPage(api: widget.api, store: widget.store);
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          // ── Account ──────────────────────────────────────────────────────
          if (!widget.settingsOnly)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.adaptive(
                      context,
                      const Color(0xFF1C1C1E).withValues(alpha: 0.94),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.adaptive(
                        context,
                        Colors.white.withValues(alpha: 0.12),
                      ),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Tooltip(
                            message: 'Edit profile photo',
                            child: GestureDetector(
                              onTap: _editingProfile
                                  ? _editAvatarPhoto
                                  : () =>
                                        setState(() => _editingProfile = true),
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: _hexToColor(_avatarColor),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.adaptive(
                                      context,
                                      Colors.white.withValues(alpha: 0.18),
                                    ),
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
                                          child: AppText(
                                            _displayName.isNotEmpty
                                                ? _displayName[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              color: AppTheme.foreground(
                                                context,
                                                Colors.white,
                                              ),
                                              fontSize: 24,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: AppText(
                                          _displayName.isNotEmpty
                                              ? _displayName[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: AppTheme.foreground(
                                              context,
                                              Colors.white,
                                            ),
                                            fontSize: 24,
                                            fontWeight: FontWeight.w600,
                                          ),
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
                                    style: AppTypography.bodyStyleOf(
                                      context,
                                      TextStyle(
                                        color: AppTheme.foreground(
                                          context,
                                          Colors.white,
                                        ),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Display name',
                                      hintStyle: AppTypography.bodyStyleOf(
                                        context,
                                        TextStyle(
                                          color: AppTheme.foreground(
                                            context,
                                            Color(0x4DFFFFFF),
                                          ),
                                        ),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  )
                                else
                                  AppText(
                                    _displayName.isNotEmpty
                                        ? _displayName
                                        : 'Set your name',
                                    style: TextStyle(
                                      color: _displayName.isNotEmpty
                                          ? AppTheme.foreground(
                                              context,
                                              Colors.white,
                                            )
                                          : AppTheme.foreground(
                                              context,
                                              const Color(0x4DFFFFFF),
                                            ),
                                      fontSize: 19,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                AppText(
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
                                    color: AppTheme.foreground(
                                      context,
                                      Color(0xFF8E8E93),
                                    ),
                                    fontSize: 13,
                                  ),
                                ),
                                if (!_editingProfile &&
                                    (_profileRole.isNotEmpty ||
                                        _organization.isNotEmpty)) ...[
                                  const SizedBox(height: 4),
                                  AppText(
                                    [_profileRole, _organization]
                                        .where((value) => value.isNotEmpty)
                                        .join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppTheme.foreground(
                                        context,
                                        Color(0xFF8E8E93),
                                      ),
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
                                    _contactEmail = _contactEmailCtrl.text
                                        .trim();
                                    _organization = _organizationCtrl.text
                                        .trim();
                                    _profileRole = _profileRoleCtrl.text.trim();
                                    _editingProfile = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: AppText('Profile updated'),
                                    ),
                                  );
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: AppText(
                                          'Couldn\'t save profile. Try again.',
                                        ),
                                      ),
                                    );
                                  }
                                  // _editingProfile stays true — user's input is not lost
                                }
                              } else {
                                setState(() => _editingProfile = true);
                              }
                            },
                            child: AppText(
                              _editingProfile ? 'Save' : 'Edit',
                              style: TextStyle(
                                color: AppTheme.foreground(
                                  context,
                                  Colors.white,
                                ),
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
                            icon: const Icon(
                              Icons.add_a_photo_outlined,
                              size: 17,
                            ),
                            label: AppText(
                              _avatarUrl.isEmpty
                                  ? 'Add profile photo'
                                  : 'Change profile photo',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.adaptive(
                                context,
                                Colors.white,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.groups_2_outlined,
                              color: AppTheme.foreground(
                                context,
                                Color(0x4DFFFFFF),
                              ),
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _organizationCtrl,
                                textCapitalization: TextCapitalization.words,
                                style: AppTypography.bodyStyleOf(
                                  context,
                                  TextStyle(
                                    color: AppTheme.foreground(
                                      context,
                                      Colors.white,
                                    ),
                                    fontSize: 14,
                                  ),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Organization or team (optional)',
                                  hintStyle: AppTypography.bodyStyleOf(
                                    context,
                                    TextStyle(
                                      color: AppTheme.foreground(
                                        context,
                                        Color(0x4DFFFFFF),
                                      ),
                                    ),
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
                              color: AppTheme.foreground(
                                context,
                                Color(0x4DFFFFFF),
                              ),
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _profileRoleCtrl,
                                textCapitalization: TextCapitalization.words,
                                style: AppTypography.bodyStyleOf(
                                  context,
                                  TextStyle(
                                    color: AppTheme.foreground(
                                      context,
                                      Colors.white,
                                    ),
                                    fontSize: 14,
                                  ),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Role (optional)',
                                  hintStyle: AppTypography.bodyStyleOf(
                                    context,
                                    TextStyle(
                                      color: AppTheme.foreground(
                                        context,
                                        Color(0x4DFFFFFF),
                                      ),
                                    ),
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
                              color: AppTheme.foreground(
                                context,
                                Color(0x4DFFFFFF),
                              ),
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _contactEmailCtrl,
                                style: AppTypography.bodyStyleOf(
                                  context,
                                  TextStyle(
                                    color: AppTheme.foreground(
                                      context,
                                      Colors.white,
                                    ),
                                    fontSize: 14,
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => FocusManager
                                    .instance
                                    .primaryFocus
                                    ?.unfocus(),
                                decoration: InputDecoration(
                                  hintText: 'Contact email (optional)',
                                  hintStyle: AppTypography.bodyStyleOf(
                                    context,
                                    TextStyle(
                                      color: AppTheme.foreground(
                                        context,
                                        Color(0x4DFFFFFF),
                                      ),
                                    ),
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
                            child: AppText(
                              'Visible only to people you collaborate with.',
                              style: TextStyle(
                                color: AppTheme.foreground(
                                  context,
                                  Color(0x4DFFFFFF),
                                ),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppText(
                            'Profile color',
                            style: TextStyle(
                              color: AppTheme.foreground(
                                context,
                                Color(0x4DFFFFFF),
                              ),
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
                                                ? AppTheme.adaptive(
                                                    context,
                                                    Colors.white,
                                                  )
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
                                color: AppTheme.foreground(
                                  context,
                                  Color(0x4DFFFFFF),
                                ),
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              AppText(
                                _contactEmail,
                                style: TextStyle(
                                  color: AppTheme.foreground(
                                    context,
                                    Color(0x73FFFFFF),
                                  ),
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.open_in_new,
                                color: AppTheme.foreground(
                                  context,
                                  Color(0x4DFFFFFF),
                                ),
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
            ),

          // ── Pro / Upgrade ────────────────────────────────────────────────
          if (!widget.accountOnly) ...[
            if (_proLoading)
              Container(
                margin: const EdgeInsets.only(top: 16),
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.adaptive(context, const Color(0xFF171717)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                  ),
                ),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppTheme.adaptive(context, Color(0x73FFFFFF)),
                    ),
                  ),
                ),
              )
            else if (_isPilotMode)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.rocket_launch_outlined,
                          color: AppTheme.textSecondary(context),
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: AppText(
                            'Free Pilot',
                            style: TextStyle(
                              color: AppTheme.foreground(context, Colors.white),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AppText(
                      ProStatus.pilotNotice ?? ProStatus.defaultPilotNotice,
                      style: TextStyle(
                        color: AppTheme.foreground(context, Color(0x99FFFFFF)),
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
                          color: AppTheme.surface2(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border(context)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mail_outline,
                              color: AppTheme.textSecondary(context),
                              size: 15,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: AppText(
                                'Send feedback',
                                style: TextStyle(
                                  color: AppTheme.textPrimary(context),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
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
                  color: AppTheme.adaptive(context, const Color(0x0AA78BFA)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.adaptive(context, const Color(0x33A78BFA)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.group,
                      color: AppTheme.foreground(context, Color(0xFFA78BFA)),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            'FindEZ Team — Active',
                            style: TextStyle(
                              color: AppTheme.foreground(context, Colors.white),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (ProStatus.teamName != null)
                            AppText(
                              'Covered by ${ProStatus.teamName}',
                              style: TextStyle(
                                color: AppTheme.foreground(
                                  context,
                                  Color(0x73FFFFFF),
                                ),
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
                  color: AppTheme.adaptive(context, const Color(0x0A30D158)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.adaptive(context, const Color(0x3330D158)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.foreground(context, Color(0xFF30D158)),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    AppText(
                      'FindEZ Pro — Active',
                      style: TextStyle(
                        color: AppTheme.foreground(context, Colors.white),
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
                  color: AppTheme.adaptive(context, const Color(0xFF171717)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                  ),
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
                              color: AppTheme.adaptive(
                                context,
                                const Color(0x1AA78BFA),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.group_outlined,
                              color: AppTheme.foreground(
                                context,
                                Color(0xFFA78BFA),
                              ),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          AppText(
                            'FindEZ Team',
                            style: TextStyle(
                              color: AppTheme.foreground(context, Colors.white),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppText(
                        'Your whole robotics team shares one inventory. Ask your coach for a join code.',
                        style: TextStyle(
                          color: AppTheme.foreground(
                            context,
                            Color(0x73FFFFFF),
                          ),
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
                            color: AppTheme.adaptive(
                              context,
                              const Color(0xFFA78BFA),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: AppText(
                            'Enter join code',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.foreground(context, Colors.white),
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

            const AppearanceSettings(),

            // ── Scanning ─────────────────────────────────────────────────────
            _sectionLabel('Scanning'),
            _glassCard(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _toggleRow(
                    label: 'Confirm before saving',
                    subtitle: 'Review AI results before saving.',
                    value: _confirmBeforeSave,
                    onChanged: (v) => unawaited(_setConfirmBeforeSave(v)),
                    last: true,
                  ),
                ],
              ),
            ),

            _sectionLabel('Support'),
            _glassCard(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionRow(
                    icon: Icons.mail_outline,
                    label: 'Send feedback',
                    onTap: () => unawaited(_sendFeedback()),
                  ),
                  _actionRow(
                    icon: Icons.bug_report_outlined,
                    label: 'Report a problem',
                    onTap: () => unawaited(_reportProblem()),
                    last: true,
                  ),
                ],
              ),
            ),

            _sectionLabel('Legal'),
            _glassCard(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionRow(
                    icon: Icons.shield_outlined,
                    label: 'Privacy Policy',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage(),
                      ),
                    ),
                  ),
                  _actionRow(
                    icon: Icons.description_outlined,
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
            _glassCard(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionRow(
                    icon: Icons.logout,
                    label: 'Sign out',
                    color: AppTheme.adaptive(context, const Color(0xFFB8B8BD)),
                    showChevron: false,
                    onTap: () => unawaited(_signOut()),
                  ),
                  _actionRow(
                    icon: Icons.delete_outline,
                    label: 'Delete account',
                    color: AppTheme.adaptive(context, const Color(0xFFFF453A)),
                    showChevron: false,
                    onTap: () => unawaited(_deleteAccount()),
                    last: true,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
