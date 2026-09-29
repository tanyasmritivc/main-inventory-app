import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/push_notifications.dart';
import '../inventory/world_views.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.api, this.onRead});

  final ApiClient api;
  final VoidCallback? onRead;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>>? _items;
  String? _error;
  bool _pushReady = false;
  bool _registeringPush = true;
  String? _pushError;
  bool _markingRead = false;

  @override
  void initState() {
    super.initState();
    unawaited(_registerPush());
    unawaited(_load());
  }

  Future<void> _registerPush() async {
    setState(() {
      _registeringPush = true;
      _pushError = null;
    });
    try {
      final ready = await PushNotifications.register(widget.api);
      if (!mounted) return;
      setState(() {
        _pushReady = ready;
        _registeringPush = false;
        _pushError = ready
            ? null
            : 'This phone could not receive notifications.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pushReady = false;
        _registeringPush = false;
        _pushError = describeError(error).$1;
      });
    }
  }

  Future<void> _load() async {
    try {
      final result = await widget.api.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(
          result['notifications'] ?? const [],
        );
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeError(error).$1);
    }
  }

  Future<void> _markAllRead() async {
    if (_markingRead || _items == null) return;
    setState(() => _markingRead = true);
    try {
      await widget.api.markNotificationsRead();
      await PushNotifications.setBadgeCount(0);
      if (!mounted) return;
      setState(() {
        _items = _items!.map((item) => {...item, 'is_read': true}).toList();
      });
      widget.onRead?.call();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    } finally {
      if (mounted) setState(() => _markingRead = false);
    }
  }

  Future<void> _testPush() async {
    try {
      await widget.api.sendTestPush();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final items = _items;
    final unread = items?.where((item) => item['is_read'] != true).length ?? 0;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            WorldHeader(
              title: 'Notifications',
              onBack: () => Navigator.of(context).pop(),
              actions: [
                if (unread > 0)
                  TextButton(
                    onPressed: _markingRead ? null : _markAllRead,
                    child: const Text('Read all'),
                  ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  children: [
                    if (items == null && _error == null)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      WorldSection(
                        title: 'Could not load notifications',
                        children: [
                          WorldRow(title: _error!, count: '', onTap: _load),
                          WorldRow(title: 'Try again', count: '', onTap: _load),
                        ],
                      )
                    else if (items!.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          'You are all caught up. Updates will appear here.',
                          style: TextStyle(color: t.text2, fontSize: 15),
                        ),
                      ),
                    if (items != null && items.isNotEmpty)
                      WorldSection(
                        title: unread == 0 ? 'Recent' : '$unread unread',
                        children: [
                          for (final item in items)
                            WorldRow(
                              title: _describedActivity(item),
                              subtitle:
                                  '${item['team_name'] ?? 'Your workspace'}  ·  ${_time(item['created_at']?.toString())}',
                              count: (item['activity_type'] ?? '')
                                  .toString()
                                  .toUpperCase(),
                            ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    WorldSection(
                      title: 'On this phone',
                      children: [
                        WorldRow(
                          title: _registeringPush
                              ? 'Connecting notifications'
                              : _pushReady
                              ? 'Phone notifications are on'
                              : 'Phone notifications are off',
                          subtitle: _pushReady
                              ? 'FindEZ can send updates to this phone.'
                              : _pushError ?? 'Trying to connect this phone.',
                          count: '',
                          onTap: _registeringPush || _pushReady
                              ? null
                              : _registerPush,
                        ),
                      ],
                    ),
                    if (_pushReady)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton(
                          onPressed: _testPush,
                          child: const Text('Send a test notification'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _time(String? raw) {
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    if (date == null) return '';
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  String _describedActivity(Map<String, dynamic> item) {
    final displayText = item['display_text']?.toString().trim() ?? '';
    if (displayText.isNotEmpty) return displayText;
    final actor = item['actor_name']?.toString().trim() ?? '';
    final summary =
        item['summary']?.toString().trim() ?? 'updated the workspace';
    if (actor.isEmpty) return summary;
    final action = summary.isEmpty
        ? 'updated the workspace'
        : '${summary[0].toLowerCase()}${summary.substring(1)}';
    return '$actor $action';
  }
}
