import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../inventory/world_views.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _name = TextEditingController();
  final _organization = TextEditingController();
  final _role = TextEditingController();
  Map<String, dynamic>? _profile;
  String? _error;
  String _avatarUrl = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _name.dispose();
    _organization.dispose();
    _role.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.api.getMyProfile();
      if (!mounted) return;
      _name.text = (profile['display_name'] ?? '').toString();
      _organization.text = (profile['organization'] ?? '').toString();
      _role.text = (profile['profile_role'] ?? '').toString();
      setState(() {
        _profile = profile;
        _avatarUrl = (profile['avatar_url'] ?? '').toString();
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeError(error).$1);
    }
  }

  Future<void> _save() async {
    if (_saving || _profile == null) return;
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your name before saving.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.updateProfile(
        displayName: _name.text.trim(),
        organization: _organization.text.trim(),
        profileRole: _role.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 78,
    );
    if (photo == null) return;
    setState(() => _saving = true);
    try {
      final url = await widget.api.uploadProfilePhoto(
        bytes: await photo.readAsBytes(),
        filename: photo.name,
      );
      if (mounted) setState(() => _avatarUrl = url);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeEmail() async {
    final oldEmail = Supabase.instance.client.auth.currentUser?.email ?? '';
    final controller = TextEditingController(text: oldEmail);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change sign-in email'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'New email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send confirmation'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty || email == oldEmail) return;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: email),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check the new address to confirm the change.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final profile = _profile;
    final email =
        Supabase.instance.client.auth.currentUser?.email ??
        (profile?['contact_email'] ?? '').toString();
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            WorldHeader(
              title: 'Edit profile',
              onBack: () => Navigator.pop(context),
              actions: [
                TextButton(
                  onPressed: _saving || profile == null ? null : _save,
                  child: Text(_saving ? 'Saving' : 'Save'),
                ),
              ],
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
                        title: 'Could not load profile',
                        children: [
                          WorldRow(title: _error!, count: ''),
                          WorldRow(title: 'Try again', count: '', onTap: _load),
                        ],
                      )
                    else ...[
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: t.s2,
                              backgroundImage: _avatarUrl.isEmpty
                                  ? null
                                  : NetworkImage(_avatarUrl),
                              child: _avatarUrl.isEmpty
                                  ? Text(
                                      _name.text.isEmpty
                                          ? ''
                                          : _name.text[0].toUpperCase(),
                                      style: TextStyle(
                                        color: t.ink,
                                        fontSize: 30,
                                      ),
                                    )
                                  : null,
                            ),
                            TextButton(
                              onPressed: _saving ? null : _changePhoto,
                              child: const Text('Change photo'),
                            ),
                          ],
                        ),
                      ),
                      WorldSection(
                        title: 'You',
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: TextField(
                              controller: _name,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                              ),
                            ),
                          ),
                          WorldRow(
                            title: 'Email',
                            subtitle: email,
                            count: 'CHANGE',
                            onTap: _saving ? null : _changeEmail,
                          ),
                          WorldRow(
                            title: 'Time zone',
                            subtitle: DateTime.now().timeZoneName,
                            count: '',
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                        child: Text(
                          'A new sign-in email takes effect after you confirm it.',
                          style: TextStyle(color: t.text2, fontSize: 13),
                        ),
                      ),
                      WorldSection(
                        title: 'What other people see',
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: TextField(
                              controller: _organization,
                              decoration: const InputDecoration(
                                labelText: 'Organization',
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: TextField(
                              controller: _role,
                              decoration: const InputDecoration(
                                labelText: 'Role',
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                        child: Text(
                          'Your email is not shown to other workspace members.',
                          style: TextStyle(color: t.text2, fontSize: 13),
                        ),
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
