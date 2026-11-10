import '../teams/team_board_page.dart';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/appearance_controller.dart';
import '../../core/ui/native_presentation.dart';
import 'native_notifications.dart';
import 'notification_preferences.dart';
import '../../core/personalization_notifications.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/notification_snapshot.dart';
import '../../core/push_notifications.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/app_text.dart';
import '../../core/ui/utility_page.dart';
import '../workspaces/invitation_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.api,
    this.onUnreadChanged,
    this.onReadStarting,
    this.native = false,
  });
  final bool native;
  static Future<void> open(
    BuildContext context, {
    required ApiClient api,
    ValueChanged<int>? onUnreadChanged,
    VoidCallback? onReadStarting,
  }) async {
    final native = usesNativePresentation;
    Widget page() => NotificationsPage(
      api: api,
      native: native,
      onUnreadChanged: onUnreadChanged,
      onReadStarting: onReadStarting,
    );
    if (native) {
      await showGeneralDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => page(),
      );
    } else {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page()));
    }
  }

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
  bool _testingPush = false;
  String? _testNotice;
  bool _loading = false;
  bool _reading = false;
  bool _policy = false;
  int _unreadCount = 0;
  int _generation = 0;
  late final String? _account;
  Timer? _timer;
  final _native = NativeNotifications();

  @override
  void initState() {
    super.initState();
    _account = widget.api.accountId;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkPush());
    unawaited(_load());
    if (widget.native) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _presentNative());
    }
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
    _native.dispose();
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

  Future<void> _testPhoneAlert() async {
    if (_testingPush || widget.api.accountId != _account) return;
    setState(() {
      _testingPush = true;
      _testNotice = null;
    });
    try {
      await widget.api.sendTestPush();
      if (mounted && widget.api.accountId == _account) {
        setState(
          () => _testNotice =
              'Apple accepted the test alert. Check your iPhone notifications.',
        );
      }
    } catch (_) {
      if (mounted && widget.api.accountId == _account) {
        setState(
          () => _testNotice =
              'The test alert could not be sent. Check phone permissions and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _testingPush = false);
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
      final response = await widget.api.getNotifications();
      final snapshot = NotificationSnapshot.parse(response);
      if (!_current(generation)) {
        _clearChangedAccount();
        return;
      }
      setState(() {
        _items = snapshot.items;
        _policy = response['policy_version'] == 1;
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

  bool _canOpen(Map<String, dynamic> item) {
    if (item['action'] == 'personalization') return item['id'] is String;
    if (item['action'] == 'access_invitation') {
      final status = (item['invitation'] as Map?)?['status'];
      return status == null || status == 'pending';
    }
    return (item['action']?.toString() ?? '').startsWith('task_') &&
        item['team_id'] != null;
  }

  Future<void> _openItem(Map<String, dynamic> item) async {
    if (!mounted || widget.api.accountId != _account || !_canOpen(item)) return;
    if (item['action'] == 'personalization') {
      await PersonalizationNotifications.open(context, widget.api, {
        'action': 'personalization',
        'notification_id': item['id'],
        'recipient_user_id': _account,
      });
      if (mounted) await _load();
      return;
    }
    if (item['action'] != 'access_invitation') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TeamBoardPage(
            api: widget.api,
            initialTeamId: item['team_id'].toString(),
          ),
        ),
      );
    } else {
      final id =
          (item['invitation'] as Map?)?['invitation_id']?.toString() ??
          (item['metadata'] as Map?)?['invitation_id']?.toString();
      if (id == null) return;
      if (usesNativePresentation) {
        await showGeneralDialog<void>(
          context: context,
          barrierColor: Colors.transparent,
          transitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => AccessInvitationPage(
            api: widget.api,
            invitationId: id,
            transparentHost: true,
          ),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                AccessInvitationPage(api: widget.api, invitationId: id),
          ),
        );
      }
      if (mounted) await _load();
    }
  }

  String _itemKey(Map<String, dynamic> item) =>
      'item:${item['id'] ?? '${item['action']}:${item['team_id']}:${item['created_at']}:${item['summary']}'}';

  Future<void> _dismiss(String? id) async {
    if (!_policy || _reading || _loading || widget.api.accountId != _account) {
      return;
    }
    setState(() => _reading = true);
    try {
      if (id == null) {
        await widget.api.clearNotifications();
      } else {
        await widget.api.dismissNotification(id);
      }
      if (mounted && widget.api.accountId == _account) {
        await _load(afterRead: true);
      }
    } catch (e) {
      if (mounted && widget.api.accountId == _account) {
        setState(() => _error = describeError(e).$1);
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _preferences() async {
    await showNotificationPreferences(context, widget.api);
    if (mounted) {
      await _checkPush();
      await _load();
    }
  }

  Map<String, dynamic> _nativeModel() => {
    'dark': Theme.of(context).brightness == Brightness.dark,
    'textSizeFactor':
        (AppearanceScope.maybeOf(context)?.textSize ?? AppTextSize.standard)
            .factor,
    'loading': _loading,
    'busy': _loading || _reading,
    'empty': _policy ? 'All caught up' : 'No updates yet',
    'options': [
      if (_policy) ...[
        {
          'id': 'preferences',
          'title': 'Notification preferences',
          'symbol': 'slider.horizontal.3',
        },
        {
          'id': 'clear',
          'title': 'Clear notifications',
          'symbol': 'tray',
          'disabled': _loading || _reading || _items?.isNotEmpty != true,
        },
      ],
      {
        'id': 'refresh',
        'title': 'Refresh',
        'symbol': 'arrow.clockwise',
        'disabled': _loading || _reading,
      },
      {
        'id': 'read',
        'title': 'Mark all as read',
        'symbol': 'checkmark',
        'disabled': _unreadCount == 0 || _loading || _reading,
      },
      if (_pushReady && !_policy) ...[
        {
          'id': 'settings',
          'title': 'Phone notification settings',
          'symbol': 'gear',
        },
        {
          'id': 'test',
          'title': _testingPush ? 'Sending test…' : 'Send test notification',
          'symbol': 'bell',
          'disabled': _testingPush,
        },
      ],
    ],
    'sections': [
      if (PushNotifications.supported && !_pushReady && !_policy)
        {
          'title': 'Phone alerts',
          'footer':
              _pushError ??
              'Get workspace updates on your phone. Your feed works without alerts.',
          'rows': [
            {
              'id': _permission == 'denied' ? 'settings' : 'enable',
              'title': _checkingPush
                  ? 'Connecting…'
                  : _permission == 'denied'
                  ? 'Open Settings'
                  : 'Enable phone alerts',
              'symbol': 'bell',
              'action': !_checkingPush,
            },
          ],
        },
      if (_error != null)
        {
          'rows': [
            {
              'id': 'refresh',
              'title': _error,
              'subtitle': 'Tap to retry',
              'symbol': 'arrow.clockwise',
              'action': true,
            },
          ],
        },
      if (_testNotice != null)
        {
          'rows': [
            {'id': 'notice', 'title': _testNotice, 'symbol': 'bell'},
          ],
        },
      if (_items?.isNotEmpty == true)
        {
          'title': _unreadCount > 0
              ? 'Updates · $_unreadCount unread'
              : 'All caught up',
          'rows': [
            for (var i = 0; i < _items!.length; i++)
              {
                'id': _itemKey(_items![i]),
                'title': _describedActivity(_items![i]),
                'subtitle': [
                  _items![i]['team_name']?.toString() ?? '',
                  _time(_items![i]['created_at']?.toString()),
                ].where((x) => x.isNotEmpty).join(' · '),
                'symbol': _symbol(_items![i]['action']?.toString() ?? ''),
                'unread': _items![i]['is_read'] != true,
                'open': _canOpen(_items![i]),
                'dismissible': _policy,
              },
          ],
        },
    ],
  };

  String _symbol(String action) {
    if (action == 'access_invitation') return 'envelope';
    if (action.startsWith('task_')) return 'checkmark.circle';
    if (action.startsWith('item_')) return 'shippingbox';
    if (action.startsWith('space_')) return 'archivebox';
    if (action.startsWith('member_')) return 'person.2';
    return 'bell';
  }

  Future<void> _nativeAction(String id) async {
    if (!mounted || widget.api.accountId != _account) return;
    if (id.startsWith('dismiss:item:')) {
      await _dismiss(id.substring('dismiss:item:'.length));
      return;
    }
    switch (id) {
      case 'preferences':
        await _preferences();
      case 'clear':
        await _dismiss(null);
      case 'refresh':
        await _load();
      case 'read':
        await _markRead();
      case 'enable':
        await _checkPush(request: true);
      case 'settings':
        await _openPhoneSettings();
      case 'test':
        await _testPhoneAlert();
    }
  }

  Future<void> _presentNative() async {
    try {
      while (mounted) {
        final id = await _native.show(_nativeModel(), _nativeAction);
        if (!mounted) return;
        if (id == null) break;
        final index = _items?.indexWhere((item) => _itemKey(item) == id) ?? -1;
        if (index >= 0) await _openItem(_items![index]);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open notifications. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.native) {
      unawaited(_native.update(_nativeModel()));
      return const SizedBox.expand();
    }
    return _page(context);
  }

  Widget _page(BuildContext context) => UtilityPage(
    title: 'Notifications',
    actions: [
      IconButton(
        tooltip: 'Mark all as read',
        onPressed: _unreadCount > 0 && !_reading && !_loading
            ? _markRead
            : null,
        icon: const Icon(CupertinoIcons.check_mark, size: 20),
      ),
      PopupMenuButton<String>(
        tooltip: 'Notification options',
        icon: const Icon(CupertinoIcons.ellipsis, size: 22),
        onSelected: (value) {
          if (value == 'preferences') _preferences();
          if (value == 'clear') _dismiss(null);
          if (value == 'refresh') _load();
          if (value == 'settings') _openPhoneSettings();
          if (value == 'test') _testPhoneAlert();
        },
        itemBuilder: (_) => [
          if (_policy) ...[
            const PopupMenuItem(
              value: 'preferences',
              child: AppText('Notification preferences'),
            ),
            PopupMenuItem(
              value: 'clear',
              enabled: !_loading && !_reading && _items?.isNotEmpty == true,
              child: const AppText('Clear notifications'),
            ),
          ],
          PopupMenuItem(
            value: 'refresh',
            enabled: !_reading && !_loading,
            child: const AppText('Refresh'),
          ),
          if (_pushReady && !_policy) ...[
            const PopupMenuItem(
              value: 'settings',
              child: AppText('Phone notification settings'),
            ),
            PopupMenuItem(
              value: 'test',
              enabled: !_testingPush,
              child: AppText(
                _testingPush ? 'Sending test...' : 'Send test notification',
              ),
            ),
          ],
        ],
      ),
    ],
    body: _inbox(),
  );

  Widget _inbox() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (PushNotifications.supported && !_pushReady && !_policy)
          UtilityCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Phone alerts',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  UtilityHint(
                    _pushError ??
                        'Get workspace updates on your phone. Your feed works without alerts.',
                  ),
                  const SizedBox(height: 6),
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
          ),
        if (_testNotice != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: UtilityHint(_testNotice!),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: AppText(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        if (_loading || _reading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
        if (_items != null && _items!.isEmpty)
          UtilityEmpty(
            icon: CupertinoIcons.bell,
            title: _policy ? 'All caught up' : 'No updates yet',
            message: _policy
                ? 'Alerts that need your attention will appear here.'
                : 'Workspace updates and invitations appear here.',
          ),
        if (_items?.isNotEmpty == true) ...[
          UtilitySection(
            _unreadCount > 0
                ? 'Updates · $_unreadCount unread'
                : 'All caught up',
          ),
          ..._items!.map((item) {
            final unread = item['is_read'] != true;
            final action = item['action']?.toString() ?? '';
            final description = _describedActivity(item);
            final details = [
              item['team_name']?.toString() ?? '',
              _time(item['created_at']?.toString()),
            ].where((part) => part.isNotEmpty).join(' · ');
            return Semantics(
              label: unread ? 'Unread notification' : 'Read notification',
              child: ListTile(
                titleAlignment: ListTileTitleAlignment.top,
                minLeadingWidth: 24,
                horizontalTitleGap: 12,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 10,
                ),
                leading: Icon(_icon(action), color: _color(action), size: 22),
                title: AppText(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: unread ? FontWeight.w400 : FontWeight.w400,
                  ),
                ),
                subtitle: details.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: UtilityHint(details),
                      ),
                onTap: _canOpen(item) ? () => _openItem(item) : null,
                trailing: _policy
                    ? IconButton(
                        tooltip: 'Dismiss notification',
                        onPressed: _reading || _loading
                            ? null
                            : () => _dismiss(item['id'] as String),
                        icon: const Icon(CupertinoIcons.xmark, size: 18),
                      )
                    : unread
                    ? const Icon(
                        CupertinoIcons.circle_fill,
                        size: 7,
                        semanticLabel: 'Unread',
                      )
                    : null,
              ),
            );
          }),
        ],
      ],
    ),
  );

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
