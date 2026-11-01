import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/notification_snapshot.dart';
import '../../core/push_notifications.dart';
import 'notifications_page.dart';

/// A direct inbox entry, independent of the selected inventory.
class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    required this.api,
    this.count,
    this.onOpen,
  });
  final ApiClient api;
  final ValueListenable<int>? count;
  final Future<void> Function()? onOpen;
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with WidgetsBindingObserver {
  late final String? _account;
  int _count = 0, _generation = 0;
  bool _opening = false, _loading = false;
  Timer? _timer;
  StreamSubscription<void>? _received;
  @override
  void initState() {
    super.initState();
    _account = widget.api.accountId;
    WidgetsBinding.instance.addObserver(this);
    if (widget.count == null) {
      unawaited(_load());
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed &&
            ModalRoute.of(context)?.isCurrent == true) {
          unawaited(_load());
        }
      });
      _received = PushNotifications.received.listen((_) => unawaited(_load()));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.count == null) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (_loading || _opening || !mounted || widget.api.accountId != _account) {
      return;
    }
    _loading = true;
    final generation = ++_generation;
    try {
      final count = notificationUnreadCount(
        await widget.api.getNotifications(),
      );
      if (!mounted ||
          generation != _generation ||
          widget.api.accountId != _account) {
        return;
      }
      setState(() => _count = count);
      await PushNotifications.setBadgeCount(count);
    } catch (_) {
      // Keep the inbox available. Its page provides explicit error and Retry.
    } finally {
      _loading = false;
    }
  }

  Future<void> _open() async {
    if (_opening || widget.api.accountId != _account) return;
    _opening = true;
    ++_generation;
    try {
      if (widget.onOpen != null) {
        await widget.onOpen!();
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NotificationsPage(
              api: widget.api,
              onReadStarting: () => ++_generation,
              onUnreadChanged: (count) {
                if (mounted && widget.api.accountId == _account) {
                  setState(() => _count = count);
                }
              },
            ),
          ),
        );
      }
    } finally {
      _opening = false;
      if (mounted && widget.count == null) unawaited(_load());
    }
  }

  @override
  void dispose() {
    ++_generation;
    _timer?.cancel();
    _received?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _button(int count) => IconButton(
    tooltip: count > 0 ? 'Notifications, $count unread' : 'Notifications',
    onPressed: _open,
    icon: Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: const Icon(Icons.notifications_none_rounded),
    ),
  );
  @override
  Widget build(BuildContext context) => widget.count == null
      ? _button(widget.api.accountId == _account ? _count : 0)
      : ValueListenableBuilder<int>(
          valueListenable: widget.count!,
          builder: (_, count, _) => _button(count),
        );
}
