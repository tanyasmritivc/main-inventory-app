import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/ui/visual_surfaces.dart';

Future<T?> _optionalRead<T>(Future<T> Function() read) async {
  try {
    return await read();
  } catch (_) {
    return null;
  }
}

class MorePage extends StatefulWidget {
  const MorePage({
    super.key,
    required this.api,
    required this.refreshToken,
    required this.workspaceName,
    this.workspaceAvailable = true,
    required this.onOpen,
    required this.onWorkspace,
  });

  final ApiClient api;
  final int refreshToken;
  final String workspaceName;
  final bool workspaceAvailable;
  final void Function(String destination) onOpen;
  final VoidCallback onWorkspace;

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  _MoreData? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant MorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profileFuture = widget.api.getMyProfile();
      final notificationsFuture = _optionalRead(widget.api.getNotifications);
      final profile = await profileFuture;
      final notifications = await notificationsFuture;
      if (!mounted) return;
      setState(() {
        _data = _MoreData(
          profile: profile,
          notificationCount: (notifications?['unread_count'] as num?)?.toInt(),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = describeError(error).$1;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final data = _data;
    return SafeArea(
      top: true,
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text('More', style: text.headlineMedium),
            const SizedBox(height: 18),
            if (_loading && data == null)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              GroupedSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Account could not load', style: text.titleMedium),
                    const SizedBox(height: 6),
                    Text(_error!, style: text.bodyMedium),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (data != null)
              Semantics(
                button: true,
                label: 'Profile, ${data.name}',
                child: GroupedSurface(
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () => widget.onOpen('profile'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: t.raised,
                            child: Text(data.initial, style: text.bodyLarge),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data.name, style: text.bodyLarge),
                                Text(
                                  data.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall?.copyWith(
                                    color: t.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            _group('Inventory', [
              const _MoreLink('All objects', 'objects'),
              const _MoreLink('Documents', 'documents'),
              const _MoreLink('Labels', 'labels'),
            ]),
            _group('Planning', [
              const _MoreLink('Projects', 'projects'),
              const _MoreLink('Restock list', 'supplies'),
              const _MoreLink('Borrowed items', 'checkouts'),
            ]),
            _group('Updates', [
              const _MoreLink('Review', 'review'),
              const _MoreLink('Activity', 'activity'),
              _MoreLink(
                'Notifications',
                'inbox',
                data?.notificationCount == 0 ? null : data?.notificationCount,
              ),
            ]),
            _group('Account', [
              if (widget.workspaceAvailable)
                const _MoreLink('Workspaces', 'workspaces'),
              const _MoreLink('Teams', 'team-spaces'),
              const _MoreLink('Sharing', 'sharing'),
              const _MoreLink('Settings', 'settings'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _group(String heading, List<_MoreLink> links) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: text.titleSmall?.copyWith(color: t.text2)),
          const SizedBox(height: 10),
          Column(
            children: [
              for (var index = 0; index < links.length; index++) ...[
                if (index > 0) Divider(height: 1, color: t.separator),
                Semantics(
                  button: true,
                  child: ListTile(
                    tileColor: t.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    minTileHeight: 54,
                    title: Text(links[index].label, style: text.bodyLarge),
                    trailing: links[index].count != null
                        ? Text(
                            '${links[index].count}',
                            style: text.bodyMedium?.copyWith(color: t.text2),
                          )
                        : Icon(Icons.chevron_right, color: t.text2),
                    onTap: () => widget.onOpen(links[index].destination),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MoreLink {
  const _MoreLink(this.label, this.destination, [this.count]);
  final String label;
  final String destination;
  final int? count;
}

class _MoreData {
  const _MoreData({required this.profile, required this.notificationCount});
  final Map<String, dynamic> profile;
  final int? notificationCount;

  String get name {
    final value = (profile['display_name'] ?? '').toString().trim();
    return value.isEmpty ? 'Your account' : value;
  }

  String get email => (profile['email'] ?? '').toString().trim();
  String get initial => name.isEmpty ? '' : name.substring(0, 1).toUpperCase();
}
