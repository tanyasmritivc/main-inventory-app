import '../../core/app_theme.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/profile_store.dart';
import '../../core/ui/member_avatar.dart';
import '../home/home_overview.dart';

class ProfileEditorPage extends StatefulWidget {
  const ProfileEditorPage({
    super.key,
    required this.api,
    this.store,
    this.pickPhoto,
  });
  final ApiClient api;
  final ProfileStore? store;
  final Future<XFile?> Function()? pickPhoto;
  @override
  State<ProfileEditorPage> createState() => _ProfileEditorPageState();
}

class _ProfileEditorPageState extends State<ProfileEditorPage> {
  late final ProfileStore _store;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _organization = TextEditingController();
  final _role = TextEditingController();
  final _contact = TextEditingController();
  String _color = '#636366';
  Map<String, String> _initial = {};
  bool _loaded = false, _saving = false, _photoBusy = false, _allowPop = false;
  bool _closing = false;
  String? _owner;
  Map<String, String> get _values => {
    'display_name': _name.text.trim(),
    'organization': _organization.text.trim(),
    'profile_role': _role.text.trim(),
    'contact_email': _contact.text.trim(),
    'avatar_color': _color,
  };
  bool get _dirty =>
      _loaded && _values.entries.any((e) => _initial[e.key] != e.value);
  bool get _busy => _saving || _photoBusy;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? ProfileStore(api: widget.api);
    _owner = _store.owner;
    _store.addListener(_changed);
    unawaited(_load());
  }

  void _changed() {
    if (!mounted) return;
    if (_owner != _store.owner) {
      _owner = _store.owner;
      _name.clear();
      _organization.clear();
      _role.clear();
      _contact.clear();
      _loaded = false;
      _initial = {};
    }
    if (!_loaded &&
        !_store.loading &&
        !_store.failed &&
        _store.profile.isNotEmpty) {
      _populate();
    }
    setState(() {});
  }

  void _populate() {
    _name.text = _store.name;
    _organization.text = _store.text('organization');
    _role.text = _store.text('profile_role');
    _contact.text = _store.text('contact_email');
    _color = RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(_store.color)
        ? _store.color
        : '#636366';
    _initial = _values;
    _loaded = true;
  }

  Future<void> _load({bool force = false}) async {
    final owner = _store.owner;
    await _store.load(force: force);
    if (!mounted || owner != _store.owner || _store.failed) return;
    setState(_populate);
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _save() async {
    if (_busy || !_loaded || !_form.currentState!.validate()) return;
    final values = _values;
    final owner = _store.owner;
    setState(() => _saving = true);
    FocusScope.of(context).unfocus();
    try {
      await widget.api.updateProfile(
        displayName: values['display_name'],
        contactEmail: values['contact_email'],
        organization: values['organization'],
        profileRole: values['profile_role'],
        avatarColor: values['avatar_color'],
      );
      if (!mounted || owner != _store.owner) return;
      _store.applySaved(values, forOwner: owner);
      setState(() => _initial = values);
      _message('Profile updated');
      await _close();
    } catch (_) {
      if (owner == _store.owner) _message("Couldn't save profile. Try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _close() async {
    if (_closing || _photoBusy || (_saving && _dirty)) return;
    _closing = true;
    final discard =
        !_dirty ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Discard changes?'),
                content: const Text(
                  'Your unsaved profile changes will be lost.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep editing'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            ) ==
            true;
    _closing = false;
    if (!mounted || !discard) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _photo({bool remove = false}) async {
    if (_busy) return;
    final owner = _store.owner;
    setState(() => _photoBusy = true);
    final previousUrl = _store.photoUrl;
    try {
      String url = '';
      if (remove) {
        await widget.api.deleteProfilePhoto();
      } else {
        final picked =
            await (widget.pickPhoto?.call() ??
                ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 78,
                ));
        if (picked == null || !mounted || owner != _store.owner) return;
        final bytes = await picked.readAsBytes();
        if (!mounted || owner != _store.owner) return;
        if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
          _message('Choose a photo smaller than 5 MB.');
          return;
        }
        url = await widget.api.uploadProfilePhoto(
          bytes: bytes,
          filename: picked.name,
        );
        if (url.isEmpty) throw StateError('Missing saved photo');
      }
      if (!mounted || owner != _store.owner) return;
      if (previousUrl.isNotEmpty) await NetworkImage(previousUrl).evict();
      if (!mounted || owner != _store.owner) return;
      _store.applySaved({'avatar_url': url}, forOwner: owner);
      _message(remove ? 'Profile photo removed' : 'Profile photo updated');
    } catch (error) {
      if (owner == _store.owner) _message(describeError(error).$1);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _choosePhoto() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.adaptive(context, HomeColors.surface),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Choose photo'),
              onTap: () => Navigator.pop(context, 'choose'),
            ),
            if (_store.photoUrl.isNotEmpty)
              ListTile(
                title: const Text('Remove photo'),
                textColor: Colors.redAccent,
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ListTile(
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    await _photo(remove: choice == 'remove');
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int limit = 120,
    bool email = false,
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.all(16),
    child: TextFormField(
      controller: controller,
      enabled: !_busy,
      maxLength: limit,
      keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
      textCapitalization: email
          ? TextCapitalization.none
          : TextCapitalization.words,
      textInputAction: TextInputAction.next,
      onChanged: (_) => setState(() {}),
      style: TextStyle(
        color: AppTheme.foreground(context, HomeColors.text),
        fontSize: 17,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        labelStyle: TextStyle(
          color: AppTheme.foreground(context, HomeColors.secondary),
          fontWeight: FontWeight.w400,
        ),
        filled: false,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        if (required && text.isEmpty) return 'Enter your name.';
        if (email &&
            text.isNotEmpty &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
          return 'Enter a valid email.';
        }
        return null;
      },
    ),
  );

  Widget _group(List<Widget> children) => Material(
    color: AppTheme.adaptive(context, HomeColors.surface),
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              color: AppTheme.adaptive(context, Color(0xFF2A2A2E)),
              indent: 16,
              endIndent: 16,
            ),
          children[i],
        ],
      ],
    ),
  );

  @override
  void dispose() {
    _store.removeListener(_changed);
    if (widget.store == null) _store.dispose();
    _name.dispose();
    _organization.dispose();
    _role.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_dirty && !_busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_close());
    },
    child: Scaffold(
      backgroundColor: AppTheme.adaptive(context, HomeColors.background),
      appBar: AppBar(
        backgroundColor: AppTheme.adaptive(context, HomeColors.background),
        surfaceTintColor: Colors.transparent,
        leading: BackButton(onPressed: _close),
        title: const Text(
          'Edit profile',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
        ),
      ),
      body: !_loaded
          ? Center(
              child: _store.failed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Could not load profile.'),
                        TextButton(
                          onPressed: () => _load(force: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            )
          : SafeArea(
              top: false,
              child: Form(
                key: _form,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            MemberAvatar(
                              key: ValueKey(_store.photoRevision),
                              name: _store.name,
                              photoUrl: _store.photoUrl,
                              colorHex: _color,
                              size: 76,
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _busy ? null : _choosePhoto,
                              child: Text(
                                _photoBusy
                                    ? 'Updating photo...'
                                    : 'Change photo',
                              ),
                            ),
                            if (_store.email.isNotEmpty)
                              Text(
                                _store.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.foreground(
                                    context,
                                    HomeColors.secondary,
                                  ),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _group([
                        _field('Name', _name, limit: 100, required: true),
                      ]),
                      const SizedBox(height: 24),
                      Text(
                        'Collaboration details',
                        style: TextStyle(
                          color: AppTheme.foreground(
                            context,
                            HomeColors.secondary,
                          ),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _group([
                        _field(
                          'Organization or team (optional)',
                          _organization,
                        ),
                        _field('Role (optional)', _role),
                        _field(
                          'Contact email (optional)',
                          _contact,
                          email: true,
                          limit: 200,
                        ),
                      ]),
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Visible only to people you collaborate with.',
                          style: TextStyle(
                            color: AppTheme.foreground(
                              context,
                              HomeColors.secondary,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      if (_store.photoUrl.isEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Avatar color',
                          style: TextStyle(
                            color: AppTheme.foreground(
                              context,
                              HomeColors.secondary,
                            ),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final color in [
                              '#636366',
                              '#8FB5E9',
                              '#8DD0BD',
                              '#BAA2E6',
                              '#EDA2B9',
                              '#EBC28A',
                            ])
                              Semantics(
                                label: 'Avatar color $color',
                                selected: _color == color,
                                button: true,
                                child: InkWell(
                                  onTap: _busy
                                      ? null
                                      : () => setState(() => _color = color),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(
                                        int.parse(
                                          'FF${color.substring(1)}',
                                          radix: 16,
                                        ),
                                      ),
                                      border: Border.all(
                                        color: _color == color
                                            ? AppTheme.adaptive(
                                                context,
                                                HomeColors.text,
                                              )
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.action,
                          foregroundColor: AppTheme.onAction,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _saving ? 'Saving...' : 'Save changes',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}
