import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/inventory_session.dart';
import '../../core/ui/app_text.dart';
import '../shell/main_shell.dart';
import 'hierarchy_page.dart';
import '../../core/place_session.dart';
import '../../core/last_place.dart';
import '../../core/push_notifications.dart';
import '../notifications/notifications_page.dart';
import 'workspace_home.dart';
import 'organization_pill.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A fresh Navigator disposes inventory routes, drafts and sheets when switching.
class InventoryContextHost extends StatefulWidget {
  const InventoryContextHost({
    super.key,
    required this.api,
    this.pickOnly = false,
    this.initialWorkspaceId,
    this.initialInventoryId,
    this.initialOrganizationId,
    this.onInitialInventoryOpened,
  });
  final ApiClient api;
  final bool pickOnly;
  final String? initialWorkspaceId;
  final String? initialInventoryId, initialOrganizationId;
  final Future<void> Function()? onInitialInventoryOpened;
  @override
  State<InventoryContextHost> createState() => _InventoryContextHostState();
}

class _InventoryContextHostState extends State<InventoryContextHost>
    with WidgetsBindingObserver {
  late final InventorySession _session;
  late final PlaceSession _places;
  StreamSubscription<AuthState>? _auth;
  bool _initialAttempted = false, _initialOpened = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = InventorySession(widget.api, widget.api.accountId ?? '')
      ..addListener(_changed);
    _places = PlaceSession(widget.api, widget.api.accountId ?? '')
      ..addListener(_initialPlaceReady);
    _auth = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedOut) unawaited(_clearPlace());
    });
    if (!widget.pickOnly) {
      unawaited(_startPlaces());
    }
  }

  void _initialPlaceReady() {
    if (!mounted ||
        _initialAttempted ||
        widget.initialInventoryId == null ||
        _places.loading ||
        _places.error != null ||
        !_places.navigationReady ||
        _places.current.id != widget.initialWorkspaceId) {
      return;
    }
    _initialAttempted = true;
    unawaited(
      _open(
        widget.initialInventoryId!,
        widget.initialWorkspaceId!,
        widget.initialOrganizationId,
      ),
    );
  }

  Future<void> _startPlaces() async {
    LastPlace? target = widget.initialWorkspaceId == null
        ? null
        : LastPlace.workspace(widget.initialWorkspaceId!);
    var starting = true;
    Map<String, dynamic>? initialInbox;
    try {
      await PushNotifications.initialize(
        onNotificationTap: (payload) async {
          if (!mounted ||
              widget.api.accountId != _places.accountId ||
              (payload['recipient_user_id'] != null &&
                  payload['recipient_user_id'] != _places.accountId)) {
            return;
          }
          final place = placeFromNotification(payload, _places.accountId);
          if (starting) {
            target = place ?? target;
            if (place == null) initialInbox = payload;
            return;
          }
          await _notification(payload);
        },
      );
    } catch (_) {
      /* Optional phone alerts remain retryable in Notifications. */
    }
    if (!mounted) return;
    await _places.restoreNavigation(override: target);
    unawaited(_connectPhoneAlerts());
    starting = false;
    if (initialInbox != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_notification(initialInbox!));
      });
    }
  }

  Future<void> _connectPhoneAlerts() async {
    if (!mounted || widget.api.accountId != _places.accountId) return;
    try {
      await PushNotifications.registerIfAuthorized(widget.api);
    } catch (_) {
      /* The inbox keeps Enable phone alerts available for retry. */
    }
  }

  Future<void> _notification(Map<String, dynamic> payload) async {
    if (!mounted ||
        widget.api.accountId != _places.accountId ||
        (payload['recipient_user_id'] != null &&
            payload['recipient_user_id'] != _places.accountId)) {
      return;
    }
    final target = placeFromNotification(payload, _places.accountId);
    if (target != null) {
      final switching = _places.restoreNavigation(override: target);
      await _session.chooseAnother();
      await switching;
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationsPage(api: _places.api),
        ),
      );
    }
  }

  Future<void> _clearPlace() async {
    try {
      await _places.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This phone could not clear your saved place.'),
          ),
        );
      }
    }
  }

  void _changed() {
    if (mounted) setState(() {});
    if (!_initialOpened &&
        _session.selection?.inventoryId == widget.initialInventoryId &&
        widget.initialInventoryId != null) {
      _initialOpened = true;
      unawaited(_acknowledgeInitial());
    }
  }

  Future<void> _acknowledgeInitial() async {
    try {
      await widget.onInitialInventoryOpened?.call();
    } catch (_) {
      // Keep the landing receipt for the next launch if local removal fails.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_changed);
    _session.dispose();
    _auth?.cancel();
    _places.removeListener(_initialPlaceReady);
    _places.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_connectPhoneAlerts());
    if (state == AppLifecycleState.resumed && _session.selection != null) {
      unawaited(_revalidate());
    }
  }

  Future<void> _revalidate() async {
    final previous = _session.selection;
    if (previous == null) return;
    await _session.revalidate();
    final next = _session.selection;
    if (next != null &&
        (next.organizationId != _places.organizationId ||
            next.workspaceId != _places.current.id)) {
      await _directory();
    }
  }

  Future<void> _directory() async {
    final refreshing = _places.refresh();
    await _session.chooseAnother();
    await refreshing;
  }

  Future<void> _open(String id, String workspace, String? organization) async {
    if (!widget.pickOnly &&
        (_places.current.id != workspace ||
            _places.organizationId != organization ||
            _places.loading ||
            _places.error != null)) {
      return;
    }
    await _session.open(
      id,
      workspaceId: workspace,
      organizationId: organization,
      remember: !widget.pickOnly,
    );
    if (mounted && widget.pickOnly && _session.inventoryApi != null) {
      // The caller uses an independent session-bound client while this picker is
      // disposed. It still cannot be used under a different signed-in account.
      final selected = _session.selection!;
      final account = selected.accountId;
      final api = ApiClient.forInventory(
        widget.api,
        selected,
        isCurrent: () => widget.api.accountId == account,
      );
      Navigator.of(context).pop(api);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _session.selection;
    final api = _session.inventoryApi;
    if (_session.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_session.error != null) {
      return Scaffold(
        appBar: AppBar(title: const AppText('Choose inventory')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(describeError(_session.error!).$1),
              TextButton(
                onPressed: _session.retry,
                child: const AppText('Retry'),
              ),
              TextButton(
                onPressed: _directory,
                child: const AppText('Choose another inventory'),
              ),
            ],
          ),
        ),
      );
    }
    final key = selected == null ? const ValueKey('directory') : ObjectKey(api);
    final navigator = Navigator(
      key: key,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (context) {
          if (selected == null || api == null) {
            if (!widget.pickOnly) {
              return WorkspaceHome(session: _places, onOpenInventory: _open);
            }
            return HierarchyPage(
              api: _session.directoryApi,
              onOpenInventory: _open,
              onClose: widget.pickOnly
                  ? () => Navigator.of(this.context).pop()
                  : null,
            );
          }
          return SafeArea(
            child: MainShell(
              api: api,
              organizationSelector: OrganizationPill(
                api: _places.api,
                id: selected.organizationId,
                name: selected.organizationName ?? 'Personal',
                onSelected: (id) async {
                  final switching = _places.selectOrganization(id);
                  await _session.chooseAnother();
                  await switching;
                },
              ),
              onWorkspaceNotification: _notification,
              onSwitchContext: _directory,
              onManageContext: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HierarchyPage(
                      api: _session.directoryApi,
                      onOpenInventory: _open,
                      level: HierarchyLevel.inventory,
                      id: selected.inventoryId,
                      name: selected.name,
                    ),
                  ),
                );
                if (mounted && identical(selected, _session.selection)) {
                  await _revalidate();
                }
              },
            ),
          );
        },
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        navigator,
        if (_session.refreshError != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              elevation: 4,
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(describeError(_session.refreshError!).$1),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _revalidate,
                            child: const AppText('Retry'),
                          ),
                          TextButton(
                            onPressed: _session.dismissRefreshError,
                            child: const AppText('Dismiss'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
