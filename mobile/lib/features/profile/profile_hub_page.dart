import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
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
  });
  final ApiClient api;
  final Future<void> Function() onOpenProfile;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onOpenDocuments;
  final Future<void> Function() onOpenNotifications;
  final Future<void> Function() onOpenCheckouts;
  final Future<void> Function() onOpenTour;
  final int unreadCount;

  @override
  State<ProfileHubPage> createState() => _ProfileHubPageState();
}

class _ProfileHubPageState extends State<ProfileHubPage>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic> _profile = {};
  bool _failed = false;
  int _generation = 0;
  StreamSubscription<AuthState>? _auth;
  String? _owner;
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _owner = Supabase.instance.client.auth.currentUser?.id;
    _auth = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      final owner = state.session?.user.id;
      if (!mounted || owner == _owner) return;
      _owner = owner;
      _generation++;
      setState(() {
        _profile = {};
        _failed = false;
      });
      if (owner != null) unawaited(_load());
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _auth?.cancel();
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final owner = Supabase.instance.client.auth.currentUser?.id;
    final generation = ++_generation;
    try {
      final profile = await widget.api.getMyProfile();
      if (!mounted ||
          generation != _generation ||
          owner != Supabase.instance.client.auth.currentUser?.id) {
        return;
      }
      setState(() {
        _profile = profile;
        _failed = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  Future<void> _editProfile() async {
    await widget.onOpenProfile();
    if (mounted) await _load();
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
          style: const TextStyle(color: HomeColors.text, fontSize: 16),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (detail != null) ...[
              Text(
                detail,
                style: const TextStyle(
                  color: HomeColors.secondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 10),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              color: HomeColors.secondary,
              size: 20,
            ),
          ],
        ),
        onTap: () => unawaited(_open(onTap)),
      );

  Widget _group(List<Widget> rows) => Material(
    color: HomeColors.surface,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 1,
              color: Color(0xFF2A2A2E),
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
    final savedName = text(_profile['display_name']);
    final cachedName = text(metadata['full_name']).isNotEmpty
        ? text(metadata['full_name'])
        : text(metadata['name']);
    final name = savedName.isNotEmpty ? savedName : cachedName;
    return ColoredBox(
      color: HomeColors.background,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                color: HomeColors.text,
                fontSize: 28,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 24),
            Material(
              color: HomeColors.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => unawaited(_open(_editProfile)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xFF2A2A2E),
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: HomeColors.text,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Your profile' : name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: HomeColors.text,
                                fontSize: 17,
                              ),
                            ),
                            if (user?.email?.isNotEmpty ?? false) ...[
                              const SizedBox(height: 4),
                              Text(
                                user!.email!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: HomeColors.secondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            const Text(
                              'Edit profile',
                              style: TextStyle(
                                color: HomeColors.secondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: HomeColors.secondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Could not load profile.',
                        style: TextStyle(color: HomeColors.secondary),
                      ),
                    ),
                    TextButton(onPressed: _load, child: const Text('Retry')),
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
