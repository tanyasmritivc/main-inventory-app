import '../../core/app_theme.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../onboarding/onboarding_prefs.dart';
import 'package:mobile/core/ui/app_text.dart';

// ─── Keyboard helper ─────────────────────────────────────────────────────────

void _dismissKeyboard(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
}

// ─── Step configuration ───────────────────────────────────────────────────────

class _StepConfig {
  const _StepConfig({
    required this.pageIndex,
    required this.icon,
    this.secondIcon,
    required this.title,
    required this.body,
    this.cornerRadius = 16,
    this.targetKey,
    this.targetRectTransform,
  });

  /// PageView index to navigate to before showing this step. -1 = stay.
  final int pageIndex;
  final IconData icon;
  final IconData? secondIcon;
  final String title;
  final String body;
  final double cornerRadius;

  /// A GlobalKey whose RenderBox will be spotlighted.
  final GlobalKey? targetKey;
  final Rect Function(Rect)? targetRectTransform;
}

// ─── Singleton controller ─────────────────────────────────────────────────────

/// Central controller for the in-app guided tour.
///
/// Lifecycle:
///   1. Call [maybeStart] from MainShell after the user is authenticated.
///   2. Call [maybeShowSpaceStep] from a space-detail page in its initState.
///
/// The main tour points to six app controls. Space tools are introduced
/// separately the first time a Space is opened.
class TutorialController {
  TutorialController._();
  static final instance = TutorialController._();

  // GlobalKeys assigned by each target widget's page.
  static final GlobalKey inventoryIconKey = GlobalKey();
  static final GlobalKey scanTabKey = GlobalKey();
  static final GlobalKey assistTabKey = GlobalKey();
  static final GlobalKey teamsSegmentKey = GlobalKey();
  static final GlobalKey inventorySearchKey = GlobalKey();
  static final GlobalKey scanToggleKey = GlobalKey();
  static final GlobalKey firstSpaceCardKey = GlobalKey();
  static final GlobalKey projectsCardKey = GlobalKey();
  static final GlobalKey spaceDetailFabKey = GlobalKey();

  PageController? _pageController;
  OverlayEntry? _entry;
  BuildContext? _lastContext;
  String _userId = '';
  bool _active = false;
  bool _spaceStepShown = false;
  StreamSubscription<AuthState>? _authSub;

  // ── Step definitions ──────────────────────────────────────────────────────

  List<_StepConfig> get _mainSteps => [
    // Step 0 — Home is the product's physical-memory front door.
    _StepConfig(
      pageIndex: 0,
      icon: Icons.home_outlined,
      title: 'Start at Home',
      body: 'See recent items and anything waiting for your review.',
      cornerRadius: 14,
      targetKey: inventoryIconKey,
    ),
    // Step 1 — capture
    _StepConfig(
      pageIndex: 2,
      icon: Icons.qr_code_scanner,
      secondIcon: Icons.camera_alt_outlined,
      title: 'Capture an item',
      body:
          'Take a photo or scan a barcode. Review AI suggestions before saving.',
      cornerRadius: 99,
      targetKey: scanToggleKey,
    ),
    // Step 2 — Ask
    _StepConfig(
      pageIndex: 1,
      icon: Icons.auto_awesome,
      title: 'Ask about saved items',
      body: 'Ask where an item is or how many you have.',
      cornerRadius: 14,
      targetKey: assistTabKey,
    ),
    // Step 3 — Find
    _StepConfig(
      pageIndex: 3,
      icon: Icons.search_rounded,
      title: 'Search your inventory',
      body: 'Find saved items by name or location.',
      cornerRadius: 14,
      targetKey: inventorySearchKey,
    ),
    // Step 4 — first space card
    _StepConfig(
      pageIndex: 3,
      icon: Icons.folder_outlined,
      title: 'Open a Space',
      body: 'Keep items together by room, shelf, or workplace.',
      cornerRadius: 20,
      targetKey: firstSpaceCardKey,
    ),
    _StepConfig(
      pageIndex: 3,
      icon: Icons.groups_outlined,
      title: 'Work with others',
      body: 'Open Teams to share inventory, assign work, and manage access.',
      cornerRadius: 14,
      targetKey: teamsSegmentKey,
      targetRectTransform: (rect) =>
          Rect.fromLTRB(rect.center.dx, rect.top, rect.right, rect.bottom),
    ),
  ];

  List<_StepConfig> get _spaceSteps => [
    _StepConfig(
      pageIndex: -1,
      icon: Icons.inventory_2_outlined,
      title: 'Plan a project',
      body: 'Check required items and reserve what you need.',
      cornerRadius: 18,
      targetKey: projectsCardKey,
    ),
    _StepConfig(
      pageIndex: -1,
      icon: Icons.add_circle_outline,
      title: 'Add an item',
      body: 'Use + to add an item manually, take a photo, or scan a barcode.',
      cornerRadius: 30,
      targetKey: spaceDetailFabKey,
    ),
  ];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Call this from MainShell after the user is confirmed authenticated.
  Future<void> maybeStart({
    required String userId,
    required PageController pageController,
    required BuildContext context,
  }) async {
    _dismissKeyboard(context);
    if (_active) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('tutorial_done_$userId') ?? false) return;
    if (!context.mounted) return;

    _userId = userId;
    _pageController = pageController;
    _spaceStepShown = false;
    _active = true;

    // Listen for sign-out to reset the tutorial key.
    _authSub?.cancel();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((ev) {
      if (ev.event == AuthChangeEvent.signedOut) unawaited(_onSignOut());
    });

    // Ensure we start on the product's front door.
    await _navigateToPage(0);
    await _waitFrames(2);
    if (!context.mounted) {
      _active = false;
      return;
    }

    _dismissKeyboard(context);
    await Future.delayed(const Duration(milliseconds: 150));
    if (!context.mounted) {
      _active = false;
      return;
    }
    _showOverlay(context, steps: _mainSteps, isSpaceStep: false);
  }

  /// Call this from the space-detail page initState (via addPostFrameCallback).
  Future<void> maybeShowSpaceStep({required BuildContext context}) async {
    // Only show once per user, and only when the main tutorial isn't running.
    if (_active || _spaceStepShown) return;
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('space_discovery_done_$userId') ?? false) return;
    _spaceStepShown = true;

    await _waitFrames(2);
    if (!context.mounted) return;

    _userId = userId;
    _showOverlay(context, steps: _spaceSteps, isSpaceStep: true);
  }

  /// Forcefully dismisses the overlay without marking as complete.
  void dismiss() {
    final ctx = _lastContext;
    if (ctx != null) _dismissKeyboard(ctx);
    _removeOverlay();
    if (ctx != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ctx.mounted) _dismissKeyboard(ctx);
      });
    }
    _active = false;
    _authSub?.cancel();
    _authSub = null;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _showOverlay(
    BuildContext context, {
    required List<_StepConfig> steps,
    required bool isSpaceStep,
  }) {
    // Main-tab targets may not exist until their page is rendered. Space-page
    // targets must be live because no navigation occurs between those steps.
    final resolvedSteps = steps
        .where((s) => s.pageIndex >= 0 || s.targetKey?.currentContext != null)
        .toList();

    if (resolvedSteps.isEmpty) {
      // Nothing to point at — mark done so we don't reshow on every launch.
      if (!isSpaceStep && _userId.isNotEmpty) {
        SharedPreferences.getInstance().then(
          (prefs) => prefs.setBool('tutorial_done_$_userId', true),
        );
      }
      _active = false;
      _authSub?.cancel();
      _authSub = null;
      return;
    }

    _lastContext = context;
    _removeOverlay();
    _dismissKeyboard(context);
    _entry = OverlayEntry(
      builder: (_) => _TutorialOverlay(
        steps: resolvedSteps,
        onNavigate: _navigateToPage,
        onComplete: isSpaceStep ? _completeSpaceDiscovery : _onComplete,
        onDismiss: isSpaceStep ? _completeSpaceDiscovery : _skipMainTutorial,
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  Future<void> _onComplete() async {
    final ctx = _lastContext;
    if (ctx != null) _dismissKeyboard(ctx);
    _removeOverlay();
    if (ctx != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ctx.mounted) _dismissKeyboard(ctx);
      });
    }
    _active = false;
    _authSub?.cancel();
    _authSub = null;
    if (_userId.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tutorial_done_$_userId', true);
      await OnboardingPrefs.markCoachmarkSeen(_userId);
    }
  }

  void _skipMainTutorial() => unawaited(_onComplete());

  void _completeSpaceDiscovery() {
    _removeOverlay();
    _active = false;
    if (_userId.isNotEmpty) {
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setBool('space_discovery_done_$_userId', true),
      );
    }
  }

  Future<void> _onSignOut() async {
    dismiss();
    _spaceStepShown = false;
    if (_userId.isNotEmpty) {
      _userId = '';
    }
  }

  Future<void> _navigateToPage(int page) async {
    final ctrl = _pageController;
    if (ctrl == null || page < 0) return;
    if ((ctrl.page?.round() ?? -1) == page) return;
    ctrl.jumpToPage(page);
    await Future.delayed(const Duration(milliseconds: 140));
  }

  static Future<void> _waitFrames(int n) async {
    for (var i = 0; i < n; i++) {
      await WidgetsBinding.instance.endOfFrame;
    }
  }
}

// ─── Overlay widget ───────────────────────────────────────────────────────────

class _TutorialOverlay extends StatefulWidget {
  const _TutorialOverlay({
    required this.steps,
    required this.onNavigate,
    required this.onComplete,
    required this.onDismiss,
  });

  final List<_StepConfig> steps;
  final Future<void> Function(int pageIndex) onNavigate;
  final VoidCallback onComplete;
  final VoidCallback onDismiss;

  @override
  State<_TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<_TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  Rect? _holeRect;
  bool _transitioning = false;
  late final AnimationController _fade;

  bool get _reduceMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStep(0));
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  Rect? _findRect(int index) {
    final config = widget.steps[index];
    final target = config.targetKey?.currentContext;
    final box = target?.findRenderObject();
    final overlay = context.findRenderObject();
    if (box is! RenderBox ||
        overlay is! RenderBox ||
        !box.hasSize ||
        !box.attached)
      return null;
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    return (config.targetRectTransform?.call(rect) ?? rect).inflate(6);
  }

  Future<void> _showStep(int index, {int direction = 1}) async {
    if (!mounted || _transitioning) return;
    _transitioning = true;
    _dismissKeyboard(context);
    if (_reduceMotion) {
      _fade.value = 0;
    } else {
      await _fade.reverse();
    }
    if (!mounted) return;
    setState(() => _holeRect = null);
    var candidate = index;
    while (candidate >= 0 && candidate < widget.steps.length) {
      final config = widget.steps[candidate];
      if (config.pageIndex >= 0) await widget.onNavigate(config.pageIndex);
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final rect = _findRect(candidate);
      if (rect != null) {
        setState(() {
          _step = candidate;
          _holeRect = rect;
        });
        if (_reduceMotion) {
          _fade.value = 1;
        } else {
          await _fade.forward();
        }
        if (mounted) setState(() => _transitioning = false);
        return;
      }
      candidate += direction;
    }
    if (!mounted) return;
    _transitioning = false;
    if (direction > 0) widget.onComplete();
  }

  void _next() {
    if (_transitioning) return;
    if (_step == widget.steps.length - 1) {
      widget.onComplete();
    } else {
      unawaited(_showStep(_step + 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hole = _holeRect;
    if (hole == null) return const SizedBox.shrink();
    final config = widget.steps[_step];
    return BlockSemantics(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) widget.onDismiss();
        },
        child: Material(
          type: MaterialType.transparency,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: CustomPaint(
                      painter: _SpotlightPainter(
                        holeRect: hole,
                        cornerRadius: config.cornerRadius,
                        color: AppTheme.accentForeground(context),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomSingleChildLayout(
                    delegate: _TooltipLayout(
                      hole: hole,
                      safePad: MediaQuery.paddingOf(context),
                      minimumHeight:
                          190 *
                          (MediaQuery.textScalerOf(context).scale(14) / 14)
                              .clamp(1.0, 2.4),
                    ),
                    child: FadeTransition(
                      opacity: _fade,
                      child: _TooltipCard(
                        config: config,
                        step: _step,
                        totalSteps: widget.steps.length,
                        onNext: _transitioning ? null : _next,
                        onBack: _step == 0 || _transitioning
                            ? null
                            : () => _showStep(_step - 1, direction: -1),
                        onSkip: widget.onDismiss,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Position against the card's actual laid-out size, including text scaling.
class _TooltipLayout extends SingleChildLayoutDelegate {
  const _TooltipLayout({
    required this.hole,
    required this.safePad,
    required this.minimumHeight,
  });
  final Rect hole;
  final EdgeInsets safePad;
  final double minimumHeight;
  static const margin = 16.0;
  static const gap = 12.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final top = safePad.top + margin;
    final bottom = size.height - safePad.bottom - margin;
    final above = (hole.top - gap - top).clamp(0.0, bottom - top);
    final below = (bottom - hole.bottom - gap).clamp(0.0, bottom - top);
    final available = above > below ? above : below;
    final width = (size.width - 2 * margin).clamp(0.0, 360.0);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: available >= minimumHeight
          ? available
          : (bottom - top).clamp(0.0, size.height),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final top = safePad.top + margin;
    final bottom = size.height - safePad.bottom - margin;
    final above = hole.top - gap - top;
    final below = bottom - hole.bottom - gap;
    final putAbove =
        above >= childSize.height &&
        (hole.center.dy > size.height / 2 || below < childSize.height);
    var y = putAbove ? hole.top - gap - childSize.height : hole.bottom + gap;
    y = y.clamp(top, (bottom - childSize.height).clamp(top, bottom));
    final x = (hole.center.dx - childSize.width / 2).clamp(
      margin,
      (size.width - childSize.width - margin).clamp(margin, size.width),
    );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_TooltipLayout old) =>
      old.hole != hole ||
      old.safePad != safePad ||
      old.minimumHeight != minimumHeight;
}

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
    required this.config,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });
  final _StepConfig config;
  final int step, totalSteps;
  final VoidCallback? onNext, onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('tutorial-card'),
    color: AppTheme.surface(context),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: AppTheme.border(context)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  MediaQuery.textScalerOf(context).scale(12) > 20
                      ? '${step + 1} / $totalSteps'
                      : 'Step ${step + 1} of $totalSteps',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ),
              if (MediaQuery.textScalerOf(context).scale(14) > 22)
                IconButton(
                  onPressed: onSkip,
                  tooltip: 'Skip tour',
                  icon: const Icon(Icons.close_rounded),
                )
              else
                TextButton(onPressed: onSkip, child: const AppText('Skip')),
            ],
          ),
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: AppText(
                      config.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    config.body,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (step > 0) ...[
                IconButton(
                  onPressed: onBack,
                  tooltip: 'Previous step',
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  key: const Key('tutorial-next'),
                  onPressed: onNext,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: AppText(step == totalSteps - 1 ? 'Done' : 'Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.holeRect,
    required this.cornerRadius,
    required this.color,
  });
  final Rect holeRect;
  final double cornerRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      holeRect,
      Radius.circular(cornerRadius),
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(path, Paint()..color = const Color(0x99000000));
    canvas.drawRRect(
      hole,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.holeRect != holeRect ||
      old.cornerRadius != cornerRadius ||
      old.color != color;
}
