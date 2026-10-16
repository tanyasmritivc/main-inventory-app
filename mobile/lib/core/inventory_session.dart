import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'inventory_cache.dart';
import 'inventory_context.dart';

/// Owns one navigation session, not a mutable global inventory ID.
class InventorySession extends ChangeNotifier {
  InventorySession(this.source, this.accountId)
    : directoryApi = ApiClient.forAccount(source, accountId);
  final ApiClient source, directoryApi;
  final String accountId;
  InventoryContext? selection;
  ApiClient? inventoryApi;
  bool loading = false;
  Object? error;
  int _generation = 0;
  String? _requestedId, _requestedWorkspace, _requestedOrganization;
  bool _disposed = false;
  String get _key => 'findez.active-inventory:$accountId';

  bool _current(int generation) =>
      !_disposed && generation == _generation && source.accountId == accountId;

  Future<void> restore() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_key);
      if (!_current(generation)) return;
      if (id != null) {
        await open(id);
        return;
      }
    } catch (reason) {
      if (_current(generation)) error = reason;
    }
    if (_current(generation)) {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> open(
    String inventoryId, {
    bool remember = true,
    String? workspaceId,
    String? organizationId,
  }) async {
    final generation = ++_generation;
    _requestedId = inventoryId; _requestedWorkspace = workspaceId; _requestedOrganization = organizationId;
    // Immediately retire old clients, including capture previews and chat streams.
    selection = null;
    inventoryApi = null;
    InventoryCache.clear();
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await directoryApi.collaboration(
        '/inventories/${Uri.encodeComponent(inventoryId)}',
      );
      final next = InventoryContext.fromJson(
        Map<String, dynamic>.from(result['inventory'] as Map),
        accountId: accountId,
        expectedInventory: inventoryId,
        expectedWorkspace: workspaceId,
      );
      if (organizationId != null && next.organizationId != organizationId) {
        throw const FormatException(
          'This workspace belongs to another organization. Refresh and choose again.',
        );
      }
      if (!_current(generation)) return;
      selection = next;
      inventoryApi = ApiClient.forInventory(
        source,
        next,
        isCurrent: () => _current(generation) && identical(selection, next),
      );
      loading = false;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      if (_current(generation) && remember) {
        await prefs.setString(_key, inventoryId);
      }
    } catch (reason) {
      if (!_current(generation)) return;
      // No stale content is displayed during a denied/offline restore.
      selection = null;
      inventoryApi = null;
      loading = false;
      error = reason;
      notifyListeners();
    }
  }

  /// Recheck grants without discarding an active camera/chat draft on resume.
  Future<void> revalidate() async {
    final previous = selection;
    final generation = _generation;
    if (previous == null) return;
    try {
      final result = await directoryApi.collaboration(
        '/inventories/${Uri.encodeComponent(previous.inventoryId)}',
      );
      final next = InventoryContext.fromJson(
        Map<String, dynamic>.from(result['inventory'] as Map),
        accountId: accountId,
        expectedInventory: previous.inventoryId,
        expectedWorkspace: previous.workspaceId,
      );
      if (!_current(generation)) return;
      if (next.role != previous.role ||
          next.canEdit != previous.canEdit ||
          next.canManage != previous.canManage ||
          next.canRename != previous.canRename ||
          next.name != previous.name ||
          next.workspaceName != previous.workspaceName ||
          next.organizationId != previous.organizationId ||
          next.organizationName != previous.organizationName) {
        await open(previous.inventoryId, workspaceId: previous.workspaceId);
      }
    } catch (reason) {
      if (!_current(generation)) return;
      // A denied or unavailable inventory must retire all of its open routes.
      selection = null;
      inventoryApi = null;
      ++_generation;
      InventoryCache.clear();
      error = reason;
      loading = false;
      notifyListeners();
    }
  }

  Future<void> retry() => _requestedId == null ? restore() : open(_requestedId!, workspaceId: _requestedWorkspace, organizationId: _requestedOrganization);

  Future<void> chooseAnother() async {
    _requestedId = null; _requestedWorkspace = null; _requestedOrganization = null;
    ++_generation;
    selection = null;
    inventoryApi = null;
    loading = false;
    error = null;
    InventoryCache.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    InventoryCache.clear();
    super.dispose();
  }
}
