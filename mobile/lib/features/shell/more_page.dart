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
      final profileFuture = _optionalRead(widget.api.getMyProfile);
      final workspacesFuture = widget.workspaceAvailable
          ? _optionalRead(widget.api.listWorkspaces)
          : Future<List<Map<String, dynamic>>?>.value(null);
      final spacesFuture = _optionalRead(widget.api.listSpaces);
      final itemsFuture = _optionalRead(
        () => widget.api.searchItems(query: ''),
      );
      final notificationsFuture = _optionalRead(widget.api.getNotifications);
      final kitsFuture = _optionalRead(widget.api.getProjectKits);
      final profile = await profileFuture;
      final workspaces = await workspacesFuture;
      final spaces = await spacesFuture;
      final items = (await itemsFuture)?.items;
      final notifications = await notificationsFuture;
      final kits = await kitsFuture;
      if (!mounted) return;
      setState(() {
        _data = _MoreData(
          profile: profile ?? const <String, dynamic>{},
          teamCount: workspaces?.length,
          placeCount: spaces?.length,
          objectCount: items?.length,
          projectCount: kits?.length,
          supplyCount:
              items == null ||
                  !items.every((item) => item.reorderPointAvailable)
              ? null
              : items
                    .where(
                      (item) =>
                          item.reorderPoint != null &&
                          item.reorderPoint! > 0 &&
                          item.quantity < item.reorderPoint!,
                    )
                    .length,
          reviewCount: items?.where((item) => item.needsIdentifying).length,
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
          children: [
            TextButton(
              onPressed: widget.workspaceAvailable ? widget.onWorkspace : null,
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: t.ink,
                disabledForegroundColor: t.ink,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 54),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.workspaceName, style: text.headlineMedium),
                  if (widget.workspaceAvailable) ...[
                    const SizedBox(width: 8),
                    Text('⌄', style: text.headlineMedium),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('More', style: text.titleLarge),
            const SizedBox(height: 14),
            if (_loading && data == null)
              const GroupedSurface(
                child: Text('Loading your account and counts'),
              )
            else if (_error != null)
              GroupedSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Counts could not load', style: text.titleMedium),
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
              GroupedSurface(
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
                                data.teamCount == null
                                    ? data.email
                                    : '${data.email} · ${data.teamCount} workspaces',
                                style: text.bodySmall?.copyWith(color: t.text2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            _group('Your world', [
              _MoreLink('Places', 'places', data?.placeCount),
              _MoreLink('All objects', 'objects', data?.objectCount),
              const _MoreLink('Documents', 'documents'),
              const _MoreLink('Labels', 'labels'),
            ]),
            _group('What you are doing', [
              _MoreLink('Projects', 'projects', data?.projectCount),
              _MoreLink('Supplies', 'supplies', data?.supplyCount),
              const _MoreLink('Checkouts', 'checkouts'),
            ]),
            _group('Keeping it true', [
              _MoreLink('Review', 'review', data?.reviewCount),
              const _MoreLink('Activity', 'activity'),
              _MoreLink('Notifications', 'inbox', data?.notificationCount),
            ]),
            _group('You', [
              if (widget.workspaceAvailable)
                _MoreLink('Workspaces', 'workspaces', data?.teamCount),
              const _MoreLink('Team spaces', 'team-spaces'),
              const _MoreLink('Shared spaces', 'sharing'),
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
          GroupedSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < links.length; index++) ...[
                  if (index > 0) Divider(height: 1, color: t.separator),
                  InkWell(
                    onTap: () => widget.onOpen(links[index].destination),
                    child: SizedBox(
                      height: 56,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                links[index].label,
                                style: text.bodyLarge,
                              ),
                            ),
                            if (links[index].count case final int count)
                              Text(
                                '$count',
                                style: text.bodyMedium?.copyWith(
                                  fontFamily: 'IBMPlexMono',
                                  color: t.text2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
  const _MoreData({
    required this.profile,
    required this.teamCount,
    required this.placeCount,
    required this.objectCount,
    required this.projectCount,
    required this.supplyCount,
    required this.reviewCount,
    required this.notificationCount,
  });
  final Map<String, dynamic> profile;
  final int? teamCount;
  final int? placeCount;
  final int? objectCount;
  final int? projectCount;
  final int? supplyCount;
  final int? reviewCount;
  final int? notificationCount;

  String get name {
    final value = (profile['display_name'] ?? '').toString().trim();
    return value.isEmpty ? 'Your account' : value;
  }

  String get email => (profile['email'] ?? '').toString().trim();
  String get initial => name.isEmpty ? '' : name.substring(0, 1).toUpperCase();
}
