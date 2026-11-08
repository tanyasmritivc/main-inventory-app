import 'dart:async';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'push_notifications.dart';

/// Requests iOS consent after authentication, before welcome announcements.
class LaunchNotificationPermission extends StatefulWidget {
  const LaunchNotificationPermission({
    super.key,
    required this.api,
    required this.child,
  });

  final ApiClient api;
  final Widget child;

  @override
  State<LaunchNotificationPermission> createState() =>
      _LaunchNotificationPermissionState();
}

class _LaunchNotificationPermissionState
    extends State<LaunchNotificationPermission>
    with WidgetsBindingObserver {
  bool _started = false;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _started) return;
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != null && state != AppLifecycleState.resumed) return;
      _started = true;
      unawaited(_request());
    });
    // A resume can arrive without a pending frame (for example a background
    // launch). Ensure the post-frame permission check actually runs.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _request() async {
    final owner = widget.api.accountId;
    try {
      if (owner != null) await PushNotifications.requestPermissionIfNeeded();
    } catch (_) {
      // A native permission error must not block authenticated use.
      debugPrint('Phone alerts could not connect. Retry in Notifications.');
    } finally {
      if (mounted && widget.api.accountId == owner) {
        setState(() => _settled = true);
        if (owner != null) unawaited(_register(owner));
      }
    }
  }

  Future<void> _register(String owner) async {
    try {
      if (mounted && widget.api.accountId == owner) {
        await PushNotifications.registerIfAuthorized(widget.api);
      }
    } catch (_) {
      // Registration can retry on resume without delaying the welcome sheet.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_started) _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationPermissionReady(ready: _settled, child: widget.child);
}

class NotificationPermissionReady extends InheritedWidget {
  const NotificationPermissionReady({
    super.key,
    required this.ready,
    required super.child,
  });
  final bool ready;
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NotificationPermissionReady>()
          ?.ready ??
      true;
  @override
  bool updateShouldNotify(NotificationPermissionReady oldWidget) =>
      ready != oldWidget.ready;
}
