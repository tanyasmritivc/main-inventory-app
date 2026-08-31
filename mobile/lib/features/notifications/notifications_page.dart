import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/ui/app_colors.dart';

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

  @override
  void initState() {
    super.initState();
    unawaited(_load());
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
      await widget.api.markNotificationsRead();
      widget.onRead?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeError(error).$1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : _items == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items!.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 190),
                        Icon(
                          CupertinoIcons.bell,
                          color: AppColors.muted,
                          size: 42,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'You’re all caught up',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'Team updates will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _items!.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 62),
                      itemBuilder: (context, index) {
                        final item = _items![index];
                        final unread = item['is_read'] != true;
                        final action = item['action']?.toString() ?? '';
                        final color = _color(action);
                        return Container(
                          color: unread
                              ? AppColors.accent.withValues(alpha: .07)
                              : Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 7,
                            ),
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: .14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _icon(action),
                                    color: color,
                                    size: 18,
                                  ),
                                ),
                                if (unread)
                                  const Positioned(
                                    right: -2,
                                    top: -2,
                                    child: CircleAvatar(
                                      radius: 4,
                                      backgroundColor: AppColors.accent,
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              item['summary']?.toString() ?? 'Team update',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${item['team_name'] ?? 'Team'} · ${_time(item['created_at']?.toString())}',
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Color _color(String action) {
    if (action == 'task_completed') return AppColors.success;
    if (action == 'task_deleted' ||
        action == 'item_deleted' ||
        action == 'member_removed') {
      return AppColors.danger;
    }
    if (action.startsWith('task_')) return AppColors.warning;
    if (action.startsWith('item_') || action.startsWith('space_')) {
      return AppColors.info;
    }
    return AppColors.ai;
  }

  IconData _icon(String action) {
    if (action.startsWith('task_')) return CupertinoIcons.check_mark_circled;
    if (action.startsWith('item_')) return CupertinoIcons.cube_box;
    if (action.startsWith('space_')) return CupertinoIcons.archivebox;
    if (action.startsWith('member_')) return CupertinoIcons.person_2;
    return CupertinoIcons.bell;
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
}
