import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    this.fallbackRect,
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

  /// Used when targetKey is null or its context is not yet available.
  final Rect Function(BuildContext)? fallbackRect;
}

// ─── Singleton controller ─────────────────────────────────────────────────────

/// Central controller for the liquid-glass walkthrough tutorial.
///
/// Lifecycle:
///   1. Call [maybeStart] from MainShell after the user is authenticated.
///   2. Call [maybeShowSpaceStep] from a space-detail page in its initState.
///
/// Steps 0-3 are shown sequentially via the main tutorial overlay.
/// Step 4 (space detail FAB) is triggered independently the first time any
/// space is opened in a session.
class TutorialController {
  TutorialController._();
  static final instance = TutorialController._();

  // GlobalKeys assigned by each target widget's page.
  static final GlobalKey inventoryIconKey = GlobalKey();
  static final GlobalKey scanToggleKey = GlobalKey();
  static final GlobalKey firstSpaceCardKey = GlobalKey();
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
    // Step 0 — chat input bar (no GlobalKey; use screen-size fallback)
    _StepConfig(
      pageIndex: 1,
      icon: Icons.mic_rounded,
      secondIcon: Icons.keyboard_rounded,
      title: 'Ask anything',
      body:
          'Type or speak — FindEZ AI finds anything in your inventory instantly.',
      cornerRadius: 26,
      fallbackRect: (ctx) {
        final s = MediaQuery.sizeOf(ctx);
        final pad = MediaQuery.paddingOf(ctx);
        return Rect.fromLTWH(
          16,
          s.height - pad.bottom - 94,
          s.width - 32,
          72,
        );
      },
    ),
    // Step 1 — scan mode toggle
    _StepConfig(
      pageIndex: 2,
      icon: Icons.qr_code_scanner,
      secondIcon: Icons.camera_alt_outlined,
      title: 'Two ways to add items',
      body:
          'Scan a barcode or snap a photo. AI extracts and adds it automatically.',
      cornerRadius: 99,
      targetKey: scanToggleKey,
    ),
    // Step 2 — inventory icon in AppBar
    _StepConfig(
      pageIndex: -1,
      icon: Icons.inventory_2_outlined,
      title: 'Your spaces',
      body: 'All your inventory lives in spaces. Tap here to see them.',
      cornerRadius: 14,
      targetKey: inventoryIconKey,
    ),
    // Step 3 — first space card
    _StepConfig(
      pageIndex: 3,
      icon: Icons.folder_outlined,
      title: 'Spaces = your locations',
      body: 'Each space holds your items. Tap a space to open it.',
      cornerRadius: 20,
      targetKey: firstSpaceCardKey,
    ),
  ];

  _StepConfig get _spaceStepConfig => _StepConfig(
    pageIndex: -1,
    icon: Icons.add_circle_outline,
    title: 'Everything is here',
    body:
        'Add items, scan, share, print labels — all inside this button.',
    cornerRadius: 30,
    targetKey: spaceDetailFabKey,
  );

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

    // Ensure we start on the chat page.
    await _navigateToPage(1);
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
    // Only show once per session, and only when the main tutorial isn't running.
    if (_active || _spaceStepShown) return;
    _spaceStepShown = true;

    await _waitFrames(2);
    if (!context.mounted) return;

    _showOverlay(context, steps: [_spaceStepConfig], isSpaceStep: true);
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
    // Drop steps whose target cannot be located and have no fallback.
    // A step is resolvable if it has a fallbackRect OR its key is live.
    final resolvedSteps = steps
        .where((s) =>
            s.fallbackRect != null || s.targetKey?.currentContext != null)
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
        onComplete: isSpaceStep ? _removeOverlay : _onComplete,
        onDismiss: dismiss,
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
    }
  }

  Future<void> _onSignOut() async {
    dismiss();
    _spaceStepShown = false;
    if (_userId.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('tutorial_done_$_userId');
      _userId = '';
    }
  }

  Future<void> _navigateToPage(int page) async {
    final ctrl = _pageController;
    if (ctrl == null || page < 0) return;
    if ((ctrl.page?.round() ?? -1) == page) return;
    await ctrl.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    await Future.delayed(const Duration(milliseconds: 250));
  }

  static Future<void> _waitFrames(int n) async {
    for (var i = 0; i < n; i++) {
      final c = Completer<void>();
      SchedulerBinding.instance.addPostFrameCallback((_) => c.complete());
      await c.future;
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
    with TickerProviderStateMixin {
  int _step = 0;
  Rect? _holeRect;
  bool _transitioning = false;

  late final AnimationController _fadeCtrl;
  late final AnimationController _holeEntryCtrl;
  late final AnimationController _bounceCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _holeEntryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _enterStep();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _holeEntryCtrl.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  // ── Position helpers ──────────────────────────────────────────────────────

  Rect? _findRect() {
    final config = widget.steps[_step];
    final key = config.targetKey;
    if (key != null) {
      final ctx = key.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final pos = box.localToGlobal(Offset.zero);
          // Inflate 8px so the spotlight has breathing room around the widget.
          return (pos & box.size).inflate(8);
        }
      }
    }
    return config.fallbackRect?.call(context);
  }

  // ── Step transitions ──────────────────────────────────────────────────────

  /// Animate into the current step (called on init and after each advance).
  void _enterStep() {
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final rect = _findRect();
      if (rect == null) {
        // Target does not exist on this screen (e.g. the first-space
        // card when the user has no spaces). Skip rather than showing
        // an empty blocking scrim.
        if (_step < widget.steps.length - 1) {
          unawaited(_advance());
        } else {
          widget.onDismiss();
        }
        return;
      }
      if (mounted) setState(() => _holeRect = rect);
      await _holeEntryCtrl.forward(from: 0);
      if (mounted) await _fadeCtrl.forward();

      // Re-measure after layout settles — the chat input resizes when
      // the keyboard dismisses, which happens after the first frame.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      final settled = _findRect();
      if (settled != null && settled != _holeRect) {
        setState(() => _holeRect = settled);
      }
    });
  }

  Future<void> _advance() async {
    if (_transitioning) return;
    _dismissKeyboard(context);
    if (_step >= widget.steps.length - 1) {
      widget.onComplete();
      return;
    }
    _transitioning = true;

    // 1. Fade out tooltip and collapse hole simultaneously.
    await Future.wait([
      _fadeCtrl.reverse(),
      _holeEntryCtrl.reverse(),
    ]);
    if (!mounted) { _transitioning = false; return; }

    // 2. Switch step and clear hole during transition.
    final nextStep = _step + 1;
    final nextConfig = widget.steps[nextStep];
    if (mounted) setState(() { _step = nextStep; _holeRect = null; });

    // 3. Navigate page if the next step is on a different page.
    if (nextConfig.pageIndex >= 0) {
      await widget.onNavigate(nextConfig.pageIndex);
    } else {
      await Future.delayed(const Duration(milliseconds: 80));
    }
    if (!mounted) { _transitioning = false; return; }

    // 4. Find the new target rect (retry up to 5 times in case it's not
    //    rendered yet after the page animation).
    Rect? newRect;
    for (var attempt = 0; attempt < 5; attempt++) {
      newRect = _findRect();
      if (newRect != null) break;
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) { _transitioning = false; return; }
    }

    // 5. Animate into new step.
    if (mounted) setState(() => _holeRect = newRect);
    await _holeEntryCtrl.forward(from: 0);
    if (mounted) await _fadeCtrl.forward();
    _transitioning = false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Never render a blocking scrim with no spotlight to point at.
    if (_holeRect == null) return const SizedBox.shrink();

    final screen = MediaQuery.sizeOf(context);
    final safePad = MediaQuery.paddingOf(context);
    final config = widget.steps[_step];
    final hole = _holeRect;
    final isLast = _step == widget.steps.length - 1;
    final isMultiStep = widget.steps.length > 1;

    final holeScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _holeEntryCtrl, curve: Curves.easeOut),
    );
    final bounceOffset = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: const Offset(0, 0.4),
    ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut));

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dark scrim with spotlit hole.
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: holeScale,
                builder: (_, __) => CustomPaint(
                  painter: _SpotlightPainter(
                    holeRect: hole,
                    holeScale: holeScale.value,
                    cornerRadius: config.cornerRadius,
                  ),
                ),
              ),
            ),
          ),

          // Tooltip card + animated arrow.
          if (hole != null)
            ..._buildTooltipAndArrow(
              screen: screen,
              safePad: safePad,
              hole: hole,
              config: config,
              isLast: isLast,
              isMultiStep: isMultiStep,
              bounceOffset: bounceOffset,
            ),
        ],
      ),
    );
  }

  List<Widget> _buildTooltipAndArrow({
    required Size screen,
    required EdgeInsets safePad,
    required Rect hole,
    required _StepConfig config,
    required bool isLast,
    required bool isMultiStep,
    required Animation<Offset> bounceOffset,
  }) {
    const tooltipWidth = 280.0;
    const tooltipHeight = 208.0;
    const arrowSize = 28.0;
    const gap = 10.0;

    final inBottomHalf = hole.center.dy > screen.height / 2;

    double tooltipTop;
    double arrowTop;

    if (inBottomHalf) {
      // Spotlight is low on screen → tooltip above it, arrow points DOWN.
      tooltipTop = hole.top - gap - arrowSize - tooltipHeight;
      arrowTop = hole.top - gap - arrowSize;
    } else {
      // Spotlight is high → tooltip below it, arrow points UP.
      arrowTop = hole.bottom + gap;
      tooltipTop = arrowTop + arrowSize + gap;
    }

    // Clamp vertically so tooltip never bleeds off screen.
    tooltipTop = tooltipTop.clamp(
      safePad.top + 56.0,
      screen.height - safePad.bottom - tooltipHeight - 12.0,
    );

    // Center tooltip on hole horizontally, clamped to screen edges.
    double tooltipLeft = hole.center.dx - tooltipWidth / 2;
    tooltipLeft =
        tooltipLeft.clamp(12.0, screen.width - tooltipWidth - 12.0);

    // Center arrow on hole horizontally.
    double arrowLeft = hole.center.dx - arrowSize / 2;
    arrowLeft = arrowLeft.clamp(12.0, screen.width - arrowSize - 12.0);

    return [
      Positioned(
        left: tooltipLeft,
        top: tooltipTop,
        width: tooltipWidth,
        child: FadeTransition(
          opacity: _fadeCtrl,
          child: _TooltipCard(
            config: config,
            step: _step,
            totalSteps: widget.steps.length,
            isLast: isLast,
            isMultiStep: isMultiStep,
            onNext: _advance,
            onSkip: () {
              _dismissKeyboard(context);
              widget.onDismiss();
            },
          ),
        ),
      ),
      Positioned(
        left: arrowLeft,
        top: arrowTop,
        width: arrowSize,
        height: arrowSize,
        child: FadeTransition(
          opacity: _fadeCtrl,
          child: SlideTransition(
            position: bounceOffset,
            child: Icon(
              inBottomHalf
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: const Color(0xFF00BCD4),
              size: arrowSize,
            ),
          ),
        ),
      ),
    ];
  }
}

// ─── Tooltip card ─────────────────────────────────────────────────────────────

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
    required this.config,
    required this.step,
    required this.totalSteps,
    required this.isLast,
    required this.isMultiStep,
    required this.onNext,
    this.onSkip,
  });

  final _StepConfig config;
  final int step;
  final int totalSteps;
  final bool isLast;
  final bool isMultiStep;
  final VoidCallback onNext;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.20),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26009CB4), // teal at 15% opacity
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon(s)
              Row(
                children: [
                  Icon(config.icon, color: const Color(0xFF00BCD4), size: 28),
                  if (config.secondIcon != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      config.secondIcon,
                      color: const Color(0xFF00BCD4),
                      size: 22,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Title
              Text(
                config.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              // Body
              Text(
                config.body,
                style: const TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              // Footer: step counter + skip + action button
              Row(
                children: [
                  if (isMultiStep)
                    Text(
                      '${step + 1} of $totalSteps',
                      style: const TextStyle(
                        color: Color(0x61FFFFFF),
                        fontSize: 12,
                      ),
                    ),
                  if (isMultiStep && !isLast && onSkip != null) ...[
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onSkip,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: onNext,
                    child: isLast
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00BCD4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Got it ✓',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF00BCD4)
                                        .withValues(alpha: 0.70),
                                  ),
                                ),
                                child: const Text(
                                  'Next →',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Spotlight painter ────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.holeRect,
    required this.holeScale,
    required this.cornerRadius,
  });

  final Rect? holeRect;
  final double holeScale;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    // saveLayer is required for BlendMode.clear to punch a transparent hole.
    canvas.saveLayer(Offset.zero & size, Paint());

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x99000000),
    );

    final hole = holeRect;
    if (hole != null && holeScale > 0) {
      final scaledHole = Rect.fromCenter(
        center: hole.center,
        width: hole.width * holeScale,
        height: hole.height * holeScale,
      );
      final radius = (cornerRadius * holeScale).clamp(0.0, 120.0);

      canvas.drawRRect(
        RRect.fromRectAndRadius(scaledHole, Radius.circular(radius)),
        Paint()..blendMode = BlendMode.clear,
      );

      canvas.restore();

      // Teal border painted after restore so it sits above the scrim.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          scaledHole.inflate(1.5),
          Radius.circular(radius + 1.5),
        ),
        Paint()
          ..color = const Color(0xFF00BCD4).withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    } else {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.holeRect != holeRect ||
      old.holeScale != holeScale ||
      old.cornerRadius != cornerRadius;
}
