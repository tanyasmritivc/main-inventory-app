import '../../core/app_theme.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../onboarding/onboarding_prefs.dart';
import 'package:mobile/core/ui/app_text.dart';
import '../../core/ui/frosted_surface.dart';

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
}

// ─── Singleton controller ─────────────────────────────────────────────────────

/// Central controller for the in-app guided tour.
///
/// Lifecycle:
///   1. Call [maybeStart] from MainShell after the user is authenticated.
///   2. The installation gets one automatic attempt, consumed before display.
///
/// The tour points to six app controls. Opening Spaces never starts another tour.
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
  bool _starting = false;
  int _generation = 0;
  StreamSubscription<AuthState>? _authSub;

  // ── Step definitions ──────────────────────────────────────────────────────

  List<_StepConfig> get _mainSteps => [
    // Step 0 - Home is the product's physical-memory front door.
    _StepConfig(
      pageIndex: 0,
      icon: Icons.home_outlined,
      title: 'Start at Home',
      body: 'Review recent photos and items needing attention.',
      cornerRadius: 14,
      targetKey: inventoryIconKey,
    ),
    // Step 1 - capture
    _StepConfig(
      pageIndex: 2,
      icon: Icons.qr_code_scanner,
      secondIcon: Icons.camera_alt_outlined,
      title: 'Capture an item',
      body: 'Take a photo or scan a barcode, then review the results.',
      cornerRadius: 99,
      targetKey: scanToggleKey,
    ),
    // Step 2 - Ask
    _StepConfig(
      pageIndex: 1,
      icon: Icons.auto_awesome,
      title: 'Ask about saved items',
      body: 'Find a saved item or check its quantity.',
      cornerRadius: 14,
      targetKey: assistTabKey,
    ),
    // Step 3 - Find
    _StepConfig(
      pageIndex: 3,
      icon: Icons.search_rounded,
      title: 'Search your inventory',
      body: 'Search saved items by name or place.',
      cornerRadius: 14,
      targetKey: inventorySearchKey,
    ),
    // Step 4 - first space card
    _StepConfig(
      pageIndex: 3,
      icon: Icons.folder_outlined,
      title: 'Open a Space',
      body: 'Group items by room, shelf, or work area.',
      cornerRadius: 20,
      targetKey: firstSpaceCardKey,
    ),
    _StepConfig(
      pageIndex: 3,
      icon: Icons.groups_outlined,
      title: 'Choose your inventory',
      body: 'Switch your workspace and inventory from the context at the top.',
      cornerRadius: 14,
      targetKey: teamsSegmentKey,
    ),
  ];

  /// Only a fresh installation can claim its first automatic display.
  Future<void> maybeStart({
    required String userId,
    required PageController pageController,
    required BuildContext context,
  }) async {
    if (_active || _starting || userId.isEmpty || !context.mounted) return;
    final generation = ++_generation;
    _starting = true;
    try {
      final allowed = await OnboardingPrefs.claimGuidedTour();
      if (!allowed || !context.mounted || generation != _generation) return;
      _userId = userId;
      _pageController = pageController;
      _active = true;
      _authSub?.cancel();
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
        event,
      ) {
        final account = event.session?.user.id;
        if (event.event == AuthChangeEvent.signedOut ||
            (account != null && account != userId)) {
          dismiss();
        }
      });
      _dismissKeyboard(context);
      await _navigateToPage(0);
      await _waitFrames(2);
      if (!context.mounted || generation != _generation) return;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!context.mounted || generation != _generation) return;
      _showOverlay(context, steps: _mainSteps);
    } catch (_) {
      if (generation == _generation) dismiss();
      debugPrint('Could not start the one-time guided tour');
    } finally {
      if (generation == _generation) _starting = false;
    }
  }

  /// Dismiss without re-arming this installation, including pending launches.
  void dismiss() {
    _generation++;
    _starting = false;
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
    _userId = '';
    _pageController = null;
    _lastContext = null;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _showOverlay(BuildContext context, {required List<_StepConfig> steps}) {
    // Main-tab targets may not exist until their page is rendered.
    final resolvedSteps = steps
        .where((s) => s.pageIndex >= 0 || s.targetKey?.currentContext != null)
        .toList();

    if (resolvedSteps.isEmpty) {
      unawaited(_onComplete());
      return;
    }

    _lastContext = context;
    _removeOverlay();
    _dismissKeyboard(context);
    _entry = OverlayEntry(
      builder: (_) => _TutorialOverlay(
        steps: resolvedSteps,
        onNavigate: _navigateToPage,
        onComplete: _onComplete,
        onDismiss: _skipMainTutorial,
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  Future<void> _onComplete() async {
    final userId = _userId;
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
    if (userId.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('tutorial_done_$userId', true);
        await OnboardingPrefs.markCoachmarkSeen(userId);
      } catch (_) {
        // The installation claim already prevents an automatic replay.
        debugPrint('Could not save legacy tour completion');
      }
    }
  }

  void _skipMainTutorial() => unawaited(_onComplete());

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
        !box.attached) {
      return null;
    }
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    return rect.inflate(6);
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
                        scrim: Colors.black.withValues(
                          alpha: MediaQuery.highContrastOf(context)
                              ? .24
                              : AppTheme.isDark(context)
                              ? .18
                              : .08,
                        ),
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
                          145 *
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
    final width = (size.width - 2 * margin).clamp(0.0, 320.0);
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
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(14) > 23;
    final next = FrostedSurface(
      radius: 16,
      shadow: false,
      tint: AppTheme.accentTint(context),
      border: AppTheme.accentForeground(context).withValues(alpha: .2),
      child: TextButton(
        key: const Key('tutorial-next'),
        onPressed: onNext,
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.accentForeground(context),
          minimumSize: const Size(76, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: AppText(step == totalSteps - 1 ? 'Done' : 'Next')),
            if (!large) ...[
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, size: 16),
            ],
          ],
        ),
      ),
    );
    return FrostedSurface(
      key: const Key('tutorial-card'),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppText(
                      '${step + 1} / $totalSteps',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textPrimary(
                          context,
                        ).withValues(alpha: .75),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onSkip,
                    tooltip: 'Skip tour',
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppText(
                        config.body,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: AppTheme.textPrimary(
                            context,
                          ).withValues(alpha: .82),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (step > 0)
                    IconButton(
                      onPressed: onBack,
                      tooltip: 'Previous step',
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    ),
                  if (large) ...[
                    const SizedBox(width: 8),
                    Expanded(child: next),
                  ] else ...[
                    const Spacer(),
                    next,
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.holeRect,
    required this.cornerRadius,
    required this.color,
    required this.scrim,
  });
  final Rect holeRect;
  final double cornerRadius;
  final Color color;
  final Color scrim;

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
    canvas.drawPath(path, Paint()..color = scrim);
    canvas.drawRRect(
      hole,
      Paint()
        ..color = color.withValues(alpha: .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.holeRect != holeRect ||
      old.cornerRadius != cornerRadius ||
      old.color != color ||
      old.scrim != scrim;
}
