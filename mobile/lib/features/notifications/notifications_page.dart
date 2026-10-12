import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/notification_snapshot.dart';
import '../../core/push_notifications.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/app_text.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.api,
    this.onUnreadChanged,
    this.onReadStarting,
  });
  final ApiClient api;
  final ValueChanged<int>? onUnreadChanged;
  final VoidCallback? onReadStarting;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>>? _items;
  String? _error;
  String? _pushError;
  String _permission = 'notDetermined';
  bool _pushReady = false;
  bool _checkingPush = false;
  bool _loading = false;
  bool _reading = false;
  int _unreadCount = 0;
  int _generation = 0;
  late final String? _account;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _account = widget.api.accountId;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkPush());
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if ((lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
          ModalRoute.of(context)?.isCurrent == true) {
        unawaited(_load());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkPush());
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _current(int generation) =>
      mounted && generation == _generation && widget.api.accountId == _account;

  void _clearChangedAccount() {
    if (mounted && widget.api.accountId != _account) {
      setState(() {
        _items = null;
        _unreadCount = 0;
        _loading = false;
        _reading = false;
        _error = 'Sign in again to view notifications.';
      });
    }
  }

  Future<void> _checkPush({bool request = false}) async {
    if (!PushNotifications.supported ||
        _checkingPush ||
        widget.api.accountId != _account) {
      return;
    }
    setState(() {
      _checkingPush = true;
      _pushError = null;
    });
    try {
      final ready = request
          ? await PushNotifications.register(widget.api)
          : await PushNotifications.registerIfAuthorized(widget.api);
      final permission = await PushNotifications.authorizationStatus();
      if (!mounted || widget.api.accountId != _account) return;
      setState(() {
        _pushReady = ready;
        _permission = permission;
      });
    } catch (error) {
      if (!mounted || widget.api.accountId != _account) return;
      try {
        final permission = await PushNotifications.authorizationStatus();
        if (mounted) setState(() => _permission = permission);
      } catch (_) {
        /* Keep the last known OS permission state. */
      }
      if (mounted) {
        setState(() {
          _pushReady = false;
          _pushError = describeError(error).$1;
        });
      }
    } finally {
      if (mounted) setState(() => _checkingPush = false);
    }
  }

  Future<void> _openPhoneSettings() async {
    try {
      if (!await launchUrl(Uri.parse('app-settings:'))) {
        throw StateError('settings unavailable');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _pushError =
              'Open iPhone Settings, then FindEZ, to manage alerts.',
        );
      }
    }
  }

  Future<void> _load({bool afterRead = false}) async {
    if (!mounted || ((_loading || _reading) && !afterRead)) return;
    if (widget.api.accountId != _account) {
      _clearChangedAccount();
      return;
    }
    final generation = ++_generation;
    setState(() => _loading = true);
    try {
      final snapshot = NotificationSnapshot.parse(
        await widget.api.getNotifications(),
      );
      if (!_current(generation)) {
        _clearChangedAccount();
        return;
      }
      setState(() {
        _items = snapshot.items;
        _unreadCount = snapshot.unreadCount;
        _error = null;
      });
      widget.onUnreadChanged?.call(snapshot.unreadCount);
      await PushNotifications.setBadgeCount(snapshot.unreadCount);
    } catch (error) {
      if (_current(generation)) {
        setState(() => _error = describeError(error).$1);
      }
      _clearChangedAccount();
    } finally {
      if (_current(generation)) setState(() => _loading = false);
    }
  }

  Future<void> _markRead() async {
    if (_reading ||
        _loading ||
        _unreadCount == 0 ||
        widget.api.accountId != _account) {
      return;
    }
    final generation = ++_generation;
    setState(() {
      _reading = true;
      _error = null;
    });
    widget.onReadStarting?.call();
    try {
      await widget.api.markNotificationsRead();
      if (!_current(generation)) {
        _clearChangedAccount();
        return;
      }
      await _load(afterRead: true);
    } catch (error) {
      if (_current(generation)) {
        setState(() => _error = describeError(error).$1);
      }
      _clearChangedAccount();
    } finally {
      if (mounted && widget.api.accountId == _account) {
        setState(() => _reading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const AppText('Notifications'),
      actions: [
        if (_pushReady)
          IconButton(
            tooltip: 'Phone notification settings',
            onPressed: _openPhoneSettings,
            icon: const Icon(CupertinoIcons.bell),
          ),
        IconButton(
          tooltip: 'Mark all as read',
          onPressed: _unreadCount > 0 && !_reading && !_loading
              ? _markRead
              : null,
          icon: const Icon(CupertinoIcons.check_mark),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _reading || _loading ? null : _load,
          icon: const Icon(CupertinoIcons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        if (PushNotifications.supported && !_pushReady)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  _pushError ??
                      'Enable phone alerts for team updates. Your feed works without them.',
                  style: const TextStyle(fontSize: 13),
                ),
                TextButton(
                  onPressed: _checkingPush
                      ? null
                      : (_permission == 'denied'
                            ? _openPhoneSettings
                            : () => _checkPush(request: true)),
                  child: AppText(
                    _checkingPush
                        ? 'Connecting...'
                        : (_permission == 'denied'
                              ? 'Open Settings'
                              : 'Enable phone alerts'),
                  ),
                ),
              ],
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(18),
            child: AppText(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(child: _inbox()),
      ],
    ),
  );

  Widget _inbox() {
    if (_items == null) {
      return _loading
          ? const Center(child: CircularProgressIndicator())
          : const SizedBox.shrink();
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: _items!.isEmpty
            ? [
                const SizedBox(height: 80),
                const AppText(
                  'No team updates yet',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                AppText(
                  'Updates from your teams appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.foreground(context, AppColors.muted),
                  ),
                ),
              ]
            : _items!.map((item) {
                final unread = item['is_read'] != true;
                final action = item['action']?.toString() ?? '';
                final description = _describedActivity(item);
                final details = [
                  item['team_name']?.toString() ?? '',
                  _time(item['created_at']?.toString()),
                ].where((part) => part.isNotEmpty).join(' | ');
                return Semantics(
                  label: unread ? 'Unread notification' : 'Read notification',
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 7,
                    ),
                    leading: Icon(
                      _icon(action),
                      color: _color(action),
                      size: 22,
                    ),
                    title: AppText(
                      description,
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    subtitle: details.isEmpty ? null : AppText(details),
                    trailing: unread
                        ? const Icon(
                            CupertinoIcons.circle_fill,
                            size: 7,
                            semanticLabel: 'Unread',
                          )
                        : null,
                  ),
                );
              }).toList(),
      ),
    );
  }

  Color _color(String action) {
    if (action == 'task_completed') {
      return AppTheme.adaptive(context, AppColors.success);
    }
    if (action == 'task_deleted' ||
        action == 'item_deleted' ||
        action == 'member_removed') {
      return AppTheme.adaptive(context, AppColors.danger);
    }
    if (action.startsWith('task_')) {
      return AppTheme.adaptive(context, AppColors.warning);
    }
    if (action.startsWith('item_') || action.startsWith('space_')) {
      return AppTheme.adaptive(context, AppColors.info);
    }
    return AppTheme.adaptive(context, AppColors.ai);
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

  String _describedActivity(Map<String, dynamic> item) {
    final displayText = item['display_text']?.toString().trim() ?? '';
    if (displayText.isNotEmpty) return displayText;
    final actor = item['actor_name']?.toString().trim() ?? '';
    final summary = item['summary']?.toString().trim() ?? 'updated the team';
    if (actor.isEmpty) return summary;
    final action = summary.isEmpty
        ? 'updated the team'
        : '${summary[0].toLowerCase()}${summary.substring(1)}';
    return '$actor $action';
  }
}
