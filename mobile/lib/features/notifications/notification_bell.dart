import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/notification_snapshot.dart';
import '../../core/push_notifications.dart';
import 'notifications_page.dart';

/// A direct inbox entry, independent of the selected inventory.
class NotificationBell extends StatelessWidget {
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
  Widget build(BuildContext context) =>
      _NotificationButton(api: api, count: count, onOpen: onOpen);
}

/// Settings remains the avatar action; its dot reports the existing inbox count.
class NotificationProfileButton extends StatelessWidget {
  const NotificationProfileButton({
    super.key,
    required this.api,
    required this.avatar,
    required this.onOpen,
    this.count,
  });
  final ApiClient api;
  final Widget avatar;
  final Future<void> Function() onOpen;
  final ValueListenable<int>? count;

  @override
  Widget build(BuildContext context) => _NotificationButton(
    key: ValueKey(api.accountId),
    api: api,
    count: count,
    onOpen: onOpen,
    avatar: avatar,
  );
}

class _NotificationButton extends StatefulWidget {
  const _NotificationButton({
    super.key,
    required this.api,
    this.count,
    this.onOpen,
    this.avatar,
  });
  final ApiClient api;
  final ValueListenable<int>? count;
  final Future<void> Function()? onOpen;
  final Widget? avatar;
  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton>
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
        await NotificationsPage.open(
          context,
          api: widget.api,
          onReadStarting: () => ++_generation,
          onUnreadChanged: (count) {
            if (mounted && widget.api.accountId == _account) {
              setState(() => _count = count);
            }
          },
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

  Widget _button(int count) {
    final profile = widget.avatar != null;
    final label = profile ? 'Account' : 'Notifications';
    return IconButton(
      tooltip: !profile && count > 0 ? '$label, $count unread' : label,
      onPressed: _open,
      icon: Semantics(
        label: count > 0 ? '$count unread notifications' : null,
        child: Badge(
          key: profile ? const ValueKey('profile-notification-dot') : null,
          isLabelVisible: count > 0,
          alignment: Alignment.topRight,
          backgroundColor: profile ? const Color(0xFFFF3B30) : null,
          smallSize: 9,
          label: profile ? null : Text(count > 99 ? '99+' : '$count'),
          child: widget.avatar ?? const Icon(Icons.notifications_none_rounded),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.count == null
      ? _button(widget.api.accountId == _account ? _count : 0)
      : ValueListenableBuilder<int>(
          valueListenable: widget.count!,
          builder: (_, count, _) => _button(count),
        );
}
