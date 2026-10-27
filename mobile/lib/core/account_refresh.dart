import 'dart:async';
import 'package:flutter/widgets.dart';

/// Refresh server-owned data while its page is visible. Editors and routes
/// above the page opt out; local drafts are never replaced by this controller.
class AccountRefresh with WidgetsBindingObserver {
  AccountRefresh({required this.refresh, required this.isActive}) {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => check());
  }
  final Future<void> Function() refresh;
  final bool Function() isActive;
  late final Timer _timer;
  bool _disposed = false, _running = false;

  Future<void> check() async {
    final state = WidgetsBinding.instance.lifecycleState;
    if (_disposed ||
        _running ||
        (state != null && state != AppLifecycleState.resumed) ||
        !isActive()) {
      return;
    }
    _running = true;
    try {
      await refresh(); // Loaders retain their normal user-facing error handling.
    } finally {
      _running = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(check());
  }

  void dispose() {
    _disposed = true;
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
