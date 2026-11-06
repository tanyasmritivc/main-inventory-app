import 'dart:async';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'push_notifications.dart';

/// Reconnects already-authorized alerts without requesting launch-time consent.
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
    try {
      if (mounted && widget.api.accountId != null) {
        await PushNotifications.registerIfAuthorized(widget.api);
      }
    } catch (_) {
      // The existing Notifications screen exposes Enable/Settings and retry.
      // Permission or APNs failure must not prevent the app from opening.
      debugPrint('Phone alerts could not connect. Retry in Notifications.');
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
  Widget build(BuildContext context) => widget.child;
}
