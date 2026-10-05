import '../../core/app_theme.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/profile_store.dart';
import '../../core/ui/member_avatar.dart';
import '../home/home_overview.dart';

/// The shell's utility destination; inventory browsing stays in Find.
class ProfileHubPage extends StatefulWidget {
  const ProfileHubPage({
    super.key,
    required this.api,
    required this.onOpenProfile,
    required this.onOpenSettings,
    required this.onOpenDocuments,
    required this.onOpenNotifications,
    required this.onOpenCheckouts,
    required this.onOpenTour,
    this.unreadCount = 0,
    this.store,
  });
  final ApiClient api;
  final Future<void> Function() onOpenProfile;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onOpenDocuments;
  final Future<void> Function() onOpenNotifications;
  final Future<void> Function() onOpenCheckouts;
  final Future<void> Function() onOpenTour;
  final int unreadCount;
  final ProfileStore? store;

  @override
  State<ProfileHubPage> createState() => _ProfileHubPageState();
}

class _ProfileHubPageState extends State<ProfileHubPage>
    with AutomaticKeepAliveClientMixin {
  late final ProfileStore _store;
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? ProfileStore(api: widget.api);
    _store.addListener(_changed);
    unawaited(_store.load());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  Future<void> _editProfile() async {
    await widget.onOpenProfile();
    if (mounted) await _store.load(force: true);
  }

  Future<void> _open(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
      }
    }
  }

  Widget _row(String title, Future<void> Function() onTap, {String? detail}) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        title: Text(
          title,
          style: TextStyle(
            color: AppTheme.foreground(context, HomeColors.text),
            fontSize: 16,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (detail != null) ...[
              Text(
                detail,
                style: TextStyle(
                  color: AppTheme.foreground(context, HomeColors.secondary),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.foreground(context, HomeColors.secondary),
              size: 20,
            ),
          ],
        ),
        onTap: () => unawaited(_open(onTap)),
      );

  Widget _group(List<Widget> rows) => Material(
    color: AppTheme.adaptive(context, HomeColors.surface),
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              color: AppTheme.adaptive(context, Color(0xFF2A2A2E)),
              indent: 16,
              endIndent: 16,
            ),
          rows[i],
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? {};
    String text(Object? value) => value is String ? value.trim() : '';
    final savedName = _store.name;
    final cachedName = text(metadata['full_name']).isNotEmpty
        ? text(metadata['full_name'])
        : text(metadata['name']);
    final name = savedName.isNotEmpty ? savedName : cachedName;
    return ColoredBox(
      color: AppTheme.adaptive(context, HomeColors.background),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
          children: [
            Text(
              'Profile',
              style: TextStyle(
                color: AppTheme.foreground(context, HomeColors.text),
                fontSize: 28,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 24),
            Material(
              color: AppTheme.adaptive(context, HomeColors.surface),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => unawaited(_open(_editProfile)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      MemberAvatar(
                        key: ValueKey(_store.photoRevision),
                        name: name,
                        photoUrl: _store.photoUrl,
                        colorHex: _store.color,
                        size: 48,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Your profile' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.foreground(
                                  context,
                                  HomeColors.text,
                                ),
                                fontSize: 17,
                              ),
                            ),
                            if (user?.email?.isNotEmpty ?? false) ...[
                              const SizedBox(height: 4),
                              Text(
                                user!.email!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.foreground(
                                    context,
                                    HomeColors.secondary,
                                  ),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              'Edit profile',
                              style: TextStyle(
                                color: AppTheme.foreground(
                                  context,
                                  HomeColors.secondary,
                                ),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.foreground(context, HomeColors.secondary),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_store.failed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Could not load profile.',
                        style: TextStyle(
                          color: AppTheme.foreground(
                            context,
                            HomeColors.secondary,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _store.load(force: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            _group([_row('Settings', widget.onOpenSettings)]),
            const SizedBox(height: 24),
            _group([
              _row('Documents and notes', widget.onOpenDocuments),
              _row(
                'Notifications',
                widget.onOpenNotifications,
                detail: widget.unreadCount > 0 ? '${widget.unreadCount}' : null,
              ),
              _row('Lent items', widget.onOpenCheckouts),
              _row('App tour', widget.onOpenTour),
            ]),
          ],
        ),
      ),
    );
  }
}
