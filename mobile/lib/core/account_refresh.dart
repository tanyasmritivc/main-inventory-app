import 'inventory_cache.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';

/// Refresh server-owned data while its page is visible. Editors and routes
/// above the page opt out; local drafts are never replaced by this controller.
class AccountRefresh with WidgetsBindingObserver {
  AccountRefresh({required this.refresh, required this.isActive}) {
    WidgetsBinding.instance.addObserver(this);
    InventoryCache.changes.addListener(_inventoryChanged);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => check());
  }
  final Future<void> Function() refresh;
  final bool Function() isActive;
  late final Timer _timer;
  bool _disposed = false, _running = false, _changedDuringRefresh = false;

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
      if (_changedDuringRefresh) {
        _changedDuringRefresh = false;
        unawaited(check());
      }
    }
  }

  void _inventoryChanged() {
    if (_running) {
      _changedDuringRefresh = true;
    } else {
      unawaited(check());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(check());
  }

  void dispose() {
    _disposed = true;
    InventoryCache.changes.removeListener(_inventoryChanged);
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
