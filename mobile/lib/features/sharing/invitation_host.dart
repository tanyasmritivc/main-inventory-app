import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/invitation.dart';
import '../teams/team_workspace_page.dart';
import 'invitation_dialog.dart';
import 'shared_inventory_page.dart';
import 'package:mobile/core/ui/app_text.dart';

/// One inbox across cold starts, sign-in, account creation and warm app links.
class InvitationHost extends StatefulWidget {
  const InvitationHost({
    super.key,
    required this.api,
    required this.navigatorKey,
    required this.ready,
    required this.child,
    this.incomingLinks,
    this.initialLink,
    this.inbox,
  });
  final ApiClient api;
  final GlobalKey<NavigatorState> navigatorKey;
  final bool ready;
  final Widget child;
  final Stream<Uri>? incomingLinks;
  final Future<Uri?> Function()? initialLink;
  final InvitationInbox? inbox;
  @override
  State<InvitationHost> createState() => _InvitationHostState();
}

class _InvitationHostState extends State<InvitationHost>
    with WidgetsBindingObserver {
  late final _inbox = widget.inbox ?? InvitationInbox();
  final _auth = Supabase.instance.client.auth;
  StreamSubscription<Uri>? _links;
  StreamSubscription<AuthState>? _session;
  DialogRoute<Map<String, dynamic>>? _dialog;
  bool _restored = false, _presenting = false;
  String? _dialogOwner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = _auth.onAuthStateChange.listen((_) {
      // Do not call an async auth method inside the SDK's auth callback.
      scheduleMicrotask(() {
        if (!mounted) return;
        if (_dialog != null && _auth.currentUser?.id != _dialogOwner) {
          widget.navigatorKey.currentState?.removeRoute(_dialog!);
        }
        _resume();
      });
    });
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _inbox.restore();
    } catch (_) {
      _notice('Could not restore your invitation. Tap the link again.');
    }
    if (!mounted) return;
    _restored = true;
    final links = widget.incomingLinks == null ? AppLinks() : null;
    _links = (widget.incomingLinks ?? links!.uriLinkStream).listen(
      _queue,
      onError: (_) =>
          _notice('Could not open the invitation. Tap the link again.'),
    );
    try {
      final initial = widget.initialLink != null
          ? await widget.initialLink!()
          : await links?.getInitialLink();
      if (initial != null) await _queue(initial);
    } catch (_) {
      _notice('Could not open the invitation. Tap the link again.');
    }
    await _resume(refresh: true);
  }

  Future<void> _queue(Uri uri) async {
    final invitation = Invitation.fromUri(uri);
    if (invitation == null) return;
    if (_presenting && _inbox.pending?.key == invitation.key) return;
    try {
      await _inbox.queue(invitation, owner: _auth.currentUser?.id);
    } catch (_) {
      _notice(
        'Keep your invitation link. It could not be saved on this phone.',
      );
    }
    _present();
  }

  Future<void> _resume({bool refresh = false}) async {
    if (!_restored || !mounted) return;
    final owner = _auth.currentUser?.id;
    if (owner == null) return;
    User? user = _auth.currentUser;
    if (refresh) {
      try {
        user = (await _auth.getUser()).user;
      } catch (_) {
        /* A saved device link still works; the API verifies access. */
      }
    }
    if (!mounted || _auth.currentUser?.id != owner || user?.id != owner) return;
    final saved = Invitation.fromData(
      user?.userMetadata?[Invitation.metadataKey],
    );
    if (saved != null && !_inbox.availableFor(owner)) {
      try {
        await _inbox.queue(saved, owner: owner);
      } catch (_) {
        _notice(
          'Keep your invitation link. It could not be saved on this phone.',
        );
      }
    }
    _present();
  }

  void _present() {
    if (!_restored || _presenting || !widget.ready || !mounted) return;
    final owner = _auth.currentUser?.id;
    if (owner == null || !_inbox.availableFor(owner)) return;
    _presenting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navigator = widget.navigatorKey.currentState;
      final invitation = _inbox.pending;
      if (!mounted ||
          navigator == null ||
          invitation == null ||
          _auth.currentUser?.id != owner) {
        _presenting = false;
        return;
      }
      var continueInbox = true;
      try {
        await _inbox.bind(owner);
        if (!mounted || _auth.currentUser?.id != owner) return;
        _dialogOwner = owner;
        final route = DialogRoute<Map<String, dynamic>>(
          context: navigator.context,
          barrierDismissible: false,
          builder: (_) => InvitationDialog(
            api: widget.api,
            invitation: invitation,
            userId: owner,
          ),
        );
        _dialog = route;
        final result = await navigator.push(route);
        _dialog = null;
        _dialogOwner = null;
        if (!mounted || _auth.currentUser?.id != owner) return;
        await _inbox.clear(invitation);
        // Clear only the exact handoff consumed by this user, not a newer link.
        final stored = Invitation.fromData(
          _auth.currentUser?.userMetadata?[Invitation.metadataKey],
        );
        if (stored?.key == invitation.key) {
          try {
            await _auth.updateUser(
              UserAttributes(data: {Invitation.metadataKey: null}),
            );
          } catch (_) {
            continueInbox = false;
            _notice(
              'The invitation could not be dismissed on your account. It may appear again.',
            );
          }
        }
        if (!mounted ||
            _auth.currentUser?.id != owner ||
            result == null ||
            result['accepted'] != true) {
          return;
        }
        if (invitation.kind == 'team') {
          final id = result['team_id']?.toString() ?? '';
          if (id.isEmpty) return;
          unawaited(
            navigator.push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    TeamWorkspacePage(api: widget.api, initialTeamId: id),
              ),
            ),
          );
        } else {
          final id = result['share_id']?.toString() ?? '';
          if (id.isEmpty) return;
          unawaited(
            navigator.push<void>(
              MaterialPageRoute(
                builder: (_) => SharedInventoryPage(
                  api: widget.api,
                  shareId: id,
                  shareName:
                      result['share_name']?.toString() ??
                      result['name'].toString(),
                  permission: result['permission']?.toString() ?? 'view',
                ),
              ),
            ),
          );
        }
      } catch (_) {
        continueInbox = false;
        _notice('Could not finish opening the invitation. Tap the link again.');
      } finally {
        _dialog = null;
        _dialogOwner = null;
        _presenting = false;
        if (continueInbox) _present();
      }
    });
    // Warm links and SDK auth callbacks do not necessarily schedule a Flutter
    // frame. Ensure the pending presentation actually gets its frame.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _notice(String text) {
    final context = widget.navigatorKey.currentContext;
    if (mounted && context != null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: AppText(text)));
    }
  }

  @override
  void didUpdateWidget(covariant InvitationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _present();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _resume(refresh: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _links?.cancel();
    _session?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
