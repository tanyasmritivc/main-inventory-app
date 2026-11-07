import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/api_client.dart';
import 'announcement_controller.dart';
import 'announcement_widgets.dart';

/// The root observer also sees UIKit bridge routes. The nested shell separately
/// checks its own route, so neither kind of presentation can be covered.
final announcementRoutes = AnnouncementRouteObserver();

class AnnouncementRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _routes = [];
  bool get homeVisible => _routes.isEmpty || _routes.last.isFirst;
  @override
  void didPush(Route route, Route? previousRoute) => _routes.add(route);
  @override
  void didPop(Route route, Route? previousRoute) => _routes.remove(route);
  @override
  void didRemove(Route route, Route? previousRoute) => _routes.remove(route);
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    final i = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (i >= 0) {
      if (newRoute == null) {
        _routes.removeAt(i);
      } else {
        _routes[i] = newRoute;
      }
    }
  }
}

class AnnouncementHost extends StatefulWidget {
  const AnnouncementHost({
    super.key,
    required this.api,
    required this.user,
    required this.child,
  });
  final ApiClient api;
  final User user;
  final Widget child;
  @override
  State<AnnouncementHost> createState() => _AnnouncementHostState();
}

class _AnnouncementHostState extends State<AnnouncementHost> {
  late final controller = AnnouncementController(
    api: ApiClient(
      baseUrl: widget.api.baseUrl,
      boundAccount: widget.user.id,
      isCurrent: () =>
          mounted &&
          Supabase.instance.client.auth.currentUser?.id == widget.user.id,
    ),
    accountId: widget.user.id,
    platform: Platform.isIOS ? 'ios' : 'android',
    isCurrent: () =>
        mounted &&
        Supabase.instance.client.auth.currentUser?.id == widget.user.id,
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnnouncementScope(controller: controller, child: widget.child);
}

class AnnouncementScope extends InheritedNotifier<AnnouncementController> {
  const AnnouncementScope({
    super.key,
    required AnnouncementController controller,
    required super.child,
  }) : super(notifier: controller);
  static AnnouncementController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AnnouncementScope>()?.notifier;
}

class AnnouncementGate extends StatefulWidget {
  const AnnouncementGate({
    super.key,
    required this.isSafe,
    this.clock,
    required this.onCapture,
    required this.child,
  });
  final bool Function() isSafe;
  final DateTime Function()? clock;
  final VoidCallback onCapture;
  final Widget child;
  @override
  State<AnnouncementGate> createState() => _AnnouncementGateState();
}

class _AnnouncementGateState extends State<AnnouncementGate>
    with WidgetsBindingObserver {
  Timer? _timer;
  AnnouncementController? _controller;
  late DateTime _lastInteraction;
  DateTime get _now => widget.clock?.call() ?? DateTime.now();
  bool _evaluating = false;
  Route<String>? _route;
  @override
  void initState() {
    super.initState();
    _lastInteraction = _now;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = AnnouncementScope.of(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastInteraction = _now;
  }

  bool get _safe =>
      mounted &&
      _controller?.current == true &&
      widget.isSafe() &&
      announcementRoutes.homeVisible &&
      (ModalRoute.of(context)?.isCurrent ?? false) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      MediaQuery.viewInsetsOf(context).bottom == 0 &&
      _now.difference(_lastInteraction) >= const Duration(seconds: 2);
  Future<void> _tick() async {
    final c = _controller;
    if (c == null || c.presented || _evaluating || !_safe) return;
    _evaluating = true;
    try {
      await c.evaluate();
      if (!mounted || !_safe || c.campaign == null || c.access == null) return;
      final campaign = c.campaign!;
      final expiry = DateTime.tryParse(
        campaign['expires_at']?.toString() ?? '',
      );
      if (expiry != null && !expiry.isAfter(DateTime.now())) {
        c.presented = true;
        return;
      }
      c.presented = true;
      final route = announcementRoute(context, campaign, c.access!);
      _route = route;
      final future = Navigator.of(context, rootNavigator: true).push(route);
      unawaited(_record(c, campaign['id'] as String, 'shown'));
      final result = await future;
      _route = null;
      if (!mounted || !c.current) return;
      unawaited(_record(c, campaign['id'] as String, result ?? 'dismissed'));
      if (mounted &&
          c.current &&
          result == 'clicked' &&
          campaign['action'] == 'capture') {
        widget.onCapture();
      }
    } catch (_) {
      // Optional read/claim failure leaves the app usable. Try next session;
      // never guess eligibility, entitlements, or claim a successful write.
    } finally {
      _evaluating = false;
    }
  }

  Future<void> _record(
    AnnouncementController c,
    String id,
    String event,
  ) async {
    var saved = false;
    var queued = true;
    try {
      saved = await c.record(id, event);
    } catch (_) {
      queued = false;
    }
    if (!saved && event != 'shown' && mounted && c.current) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            queued
                ? 'Announcement closed. Your preference will sync when connected.'
                : 'Announcement closed. Your preference could not be saved.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    final route = _route;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _lastInteraction = _now,
    child: widget.child,
  );
}

Route<String> announcementRoute(
  BuildContext context,
  Map<String, dynamic> campaign,
  Map<String, dynamic> access,
) {
  final c = AnnouncementColors(context);
  final reduced =
      MediaQuery.of(context).disableAnimations ||
      MediaQuery.of(context).accessibleNavigation;
  return _AnnouncementRoute(
    dark: c.dark,
    reduced: reduced,
    builder: (sheet) {
      final design = campaign['design'];
      return AnnouncementSheet(
        title: campaign['title'] as String,
        line: design == 'message' ? null : campaign['body'] as String?,
        body: design == 'access' || design == 'pricing'
            ? AnnouncementPlanBody(access: access)
            : design == 'whats_new'
            ? const AnnouncementProductBody()
            : Text(
                campaign['body'] as String? ?? '',
                style: TextStyle(fontSize: 15, height: 1.5, color: c.secondary),
              ),
        fine: design == 'access' || design == 'pricing'
            ? access['fine'] as String?
            : null,
        primaryLabel: campaign['cta'] as String? ?? 'Got it',
        onPrimary: () => Navigator.pop(
          sheet,
          campaign['action'] == 'capture' ? 'clicked' : 'acknowledged',
        ),
        onClose: () => Navigator.pop(sheet, 'dismissed'),
      );
    },
  );
}

class _AnnouncementRoute extends PopupRoute<String> {
  _AnnouncementRoute({
    required this.dark,
    required this.reduced,
    required this.builder,
  });
  final bool dark, reduced;
  final WidgetBuilder builder;
  @override
  Duration get transitionDuration =>
      Duration(milliseconds: reduced ? 160 : 600);
  @override
  bool get barrierDismissible => true;
  @override
  String get barrierLabel => 'Dismiss announcement';
  @override
  Color get barrierColor => Colors.black.withValues(alpha: dark ? .55 : .30);
  @override
  Curve get barrierCurve => const Interval(0, .667, curve: Curves.easeOut);
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => SafeArea(
    bottom: false,
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: builder(context),
        ),
      ),
    ),
  );
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => reduced
      ? FadeTransition(opacity: animation, child: child)
      : SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: announcementCurve),
          ),
          child: child,
        );
}

Future<void> openAnnouncementPlan(BuildContext context, ApiClient api) async {
  try {
    final owner = api.accountId;
    final access = await loadAnnouncementAccess(api);
    if (!context.mounted || owner != api.accountId) return;
    await Navigator.of(context, rootNavigator: true).push(
      announcementRoute(context, {
        'design': 'access',
        'title': access['pilot'] == true ? "You're in early." : 'Your plan',
        'cta': 'Got it',
        'action': 'dismiss',
      }, access),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Could not load your plan. Please try again.'),
        ),
      );
    }
  }
}

class AnnouncementSettingsRow extends StatefulWidget {
  const AnnouncementSettingsRow({super.key, required this.api});
  final ApiClient api;
  @override
  State<AnnouncementSettingsRow> createState() =>
      _AnnouncementSettingsRowState();
}

class _AnnouncementSettingsRowState extends State<AnnouncementSettingsRow> {
  late final access = loadAnnouncementAccess(widget.api);
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: access,
    builder: (context, snapshot) => snapshot.hasData
        ? AnnouncementPlanRow(
            access: snapshot.data!,
            onTap: () => openAnnouncementPlan(context, widget.api),
          )
        : ListTile(
            title: const Text('Your plan'),
            subtitle: Text(
              snapshot.hasError ? 'Tap to retry' : 'Loading access...',
            ),
            onTap: () => openAnnouncementPlan(context, widget.api),
          ),
  );
}
