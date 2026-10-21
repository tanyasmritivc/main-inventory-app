import 'dart:async';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'push_notifications.dart';

/// Requests the iOS system permission after the first active app frame.
/// It never holds up onboarding, authentication or inventory navigation.
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
      final allowed = await PushNotifications.requestPermissionIfNeeded();
      if (mounted && allowed && widget.api.accountId != null) {
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
