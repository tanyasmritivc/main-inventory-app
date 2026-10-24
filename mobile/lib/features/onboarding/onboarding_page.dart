import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/ui/findez_wordmark.dart';
import '../auth/auth_page.dart';
import 'onboarding_prefs.dart';
import 'pending_world.dart';
import 'world_scene.dart';
import 'world_transitions.dart';
import 'world_motion.dart' show phase;

const worldBackground = Color(0xFFF7F7F6);
const worldInk = Color(0xFF111112);
const worldSecondary = Color(0xFF6B6965);
const worldHint = Color(0xFF8A8782);
const worldOrange = Color(0xFFE8590C);
const worldBorder = Color(0xFFE3E0DA);

ThemeData worldTheme(BuildContext context) => Theme.of(context).copyWith(
  brightness: Brightness.light,
  scaffoldBackgroundColor: worldBackground,
  colorScheme: ColorScheme.fromSeed(
    seedColor: worldOrange,
    brightness: Brightness.light,
  ),
  textTheme: Theme.of(
    context,
  ).textTheme.apply(fontFamily: 'PlusJakartaSans', bodyColor: worldInk),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: worldOrange,
    selectionColor: Color(0x44E8590C),
    selectionHandleColor: worldOrange,
  ),
  filledButtonTheme: const FilledButtonThemeData(),
  textButtonTheme: const TextButtonThemeData(),
  outlinedButtonTheme: const OutlinedButtonThemeData(),
);

/// First-run setup advances from real selections and keyboard Done actions.
/// Local progress is saved before leaving each step.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    this.onFinished,
    this.onExistingAccount,
    this.isReplay = false,
    this.initialSetup,
  });
  final VoidCallback? onFinished, onExistingAccount;
  final bool isReplay;
  @visibleForTesting
  final PendingWorld? initialSetup;
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  PendingWorld _setup = const PendingWorld();
  final _organization = TextEditingController();
  final _custom = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _intro, _introFade, _exit;
  final _canvasKey = GlobalKey();
  final _worldKey = GlobalKey();
  GlobalKey _personalMiniKey = GlobalKey(), _teamMiniKey = GlobalKey();
  final _hiddenMini = ValueNotifier<String?>(null);
  WorldCamera? _morphOrigin;
  bool _goingBack = false, _leavingIntro = false;
  Timer? _introTimer;
  bool _loaded = false, _busy = false, _customizing = false, _exiting = false;
  String? _error;
  double _edgeDistance = 0;
  bool _edge = false;
  late ThemeData _theme;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _theme = worldTheme(context);
  }

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _introFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: 1,
    );
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      final saved =
          widget.initialSetup ??
          (widget.isReplay ? null : await WorldSetupStore.draft()) ??
          const PendingWorld();
      if (!mounted) return;
      _setup = saved.step == WorldStep.auth
          ? saved.copyWith(step: WorldStep.world)
          : saved;
      _organization.text = _setup.orgName;
      setState(() => _loaded = true);
      if (_setup.step == WorldStep.intro) {
        _intro.forward();
        _introTimer = Timer(
          const Duration(seconds: 3),
          () => unawaited(_leaveIntro()),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Your setup could not be loaded. Try again.');
      }
    }
  }

  Future<bool> _persist(PendingWorld value) async {
    try {
      if (!widget.isReplay) await WorldSetupStore.saveDraft(value);
      if (mounted && _error != null) setState(() => _error = null);
      return true;
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Your setup could not be saved. Try again.');
      }
      return false;
    }
  }

  void _answer(PendingWorld value) {
    setState(() => _setup = value);
    unawaited(_persist(value));
  }

  Future<void> _select(PendingWorld value) async {
    if (_busy) return;
    _goingBack = false;
    if (_setup.step == WorldStep.choose) {
      final icon =
          (value.isTeam ? _teamMiniKey : _personalMiniKey).currentContext
                  ?.findRenderObject()
              as RenderBox?;
      final canvas =
          _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      if (icon != null && canvas != null) {
        final origin = canvas.globalToLocal(
          icon.localToGlobal(icon.size.center(Offset.zero)),
        );
        _morphOrigin = WorldCamera(origin.dx, origin.dy, .36);
      }
    }
    _answer(value);
    if (!MediaQuery.disableAnimationsOf(context)) {
      setState(() => _busy = true);
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      setState(() => _busy = false);
    }
    await _next();
  }

  Future<void> _go(WorldStep next) async {
    if (_busy) return;
    setState(() => _busy = true);
    final value = _setup.copyWith(step: next);
    if (await _persist(value) && mounted) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        if (_setup.step == WorldStep.choose && next != WorldStep.choose) {
          _hiddenMini.value = _setup.path;
        } else if (next == WorldStep.choose) {
          _hiddenMini.value = null;
        }
        _setup = value;
        _customizing = false;
      });
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _leaveIntro() async {
    if (!_loaded || _setup.step != WorldStep.intro || _leavingIntro) return;
    _leavingIntro = true;
    _introTimer?.cancel();
    if (!MediaQuery.disableAnimationsOf(context)) await _introFade.reverse();
    if (!mounted) return;
    await _go(WorldStep.choose);
  }

  Future<void> _next() async {
    if (_busy || !_valid) return;
    _goingBack = false;
    final next = switch (_setup.step) {
      WorldStep.choose =>
        _setup.isTeam ? WorldStep.organization : WorldStep.workspace,
      WorldStep.organization => WorldStep.workspace,
      WorldStep.workspace => WorldStep.inventory,
      WorldStep.inventory => WorldStep.world,
      _ => WorldStep.auth,
    };
    if (next != WorldStep.auth) {
      await _go(next);
      return;
    }
    setState(() => _busy = true);
    final value = _setup.copyWith(step: WorldStep.auth);
    if (!await _persist(value) || !mounted) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    try {
      if (!widget.isReplay) await OnboardingPrefs.setCompleted(true);
      if (!mounted) return;
      if (widget.isReplay) {
        widget.onFinished?.call();
        return;
      }
      setState(() => _exiting = true);
      if (!MediaQuery.disableAnimationsOf(context)) await _exit.forward();
      if (mounted) widget.onFinished?.call();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Your setup could not be saved. Try again.';
        });
      }
    }
  }

  Future<void> _existing() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!widget.isReplay) {
        await WorldSetupStore.skipDraft();
        await OnboardingPrefs.setCompleted(true);
      }
      if (mounted) (widget.onExistingAccount ?? widget.onFinished)?.call();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Your setup could not be saved. Try again.';
        });
      }
    }
  }

  void _back() {
    if (_busy || _exiting) return;
    if (_customizing) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _customizing = false);
      return;
    }
    final previous = switch (_setup.step) {
      WorldStep.organization => WorldStep.choose,
      WorldStep.workspace =>
        _setup.isTeam ? WorldStep.organization : WorldStep.choose,
      WorldStep.inventory => WorldStep.workspace,
      WorldStep.world => WorldStep.inventory,
      _ => null,
    };
    if (previous != null) {
      _goingBack = true;
      unawaited(_go(previous));
    }
  }

  bool get _valid => switch (_setup.step) {
    WorldStep.choose => _setup.path != null,
    WorldStep.organization => PendingWorld.validName(_setup.orgName, 60),
    WorldStep.workspace =>
      !_customizing && PendingWorld.validName(_setup.workspacePurpose, 40),
    WorldStep.inventory =>
      !_customizing && PendingWorld.validName(_setup.inventoryName, 40),
    WorldStep.world => true,
    _ => false,
  };
  String get _title => switch (_setup.step) {
    WorldStep.choose => "Who's FindEZ for?",
    WorldStep.organization => 'Name your\norganization',
    WorldStep.workspace => "What's this\nworkspace for?",
    WorldStep.inventory => 'Create your first\ninventory',
    _ => 'This is your world.',
  };
  String get _subtitle => switch (_setup.step) {
    WorldStep.choose => 'Pick one to start. You can change it later.',
    WorldStep.organization => 'Use the name of your company, lab or team.',
    WorldStep.workspace =>
      _setup.isTeam
          ? 'Each purpose gets its own dashboard.'
          : 'Your personal space. Only you can see it.',
    WorldStep.inventory =>
      _setup.isTeam
          ? 'Group your things by team, like hardware or software.'
          : 'Group your things, like tools or electronics.',
    _ =>
      'Add more workspaces and inventories anytime. Spaces like a parts wall go inside each inventory.',
  };
  @override
  void dispose() {
    _introTimer?.cancel();
    _intro.dispose();
    _introFade.dispose();
    _hiddenMini.dispose();
    _exit.dispose();
    _organization.dispose();
    _custom.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: _theme,
    child: Builder(
      builder: (context) => Scaffold(
        backgroundColor: worldBackground,
        resizeToAvoidBottomInset: false,
        body: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back();
          },
          child: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (details) {
                _edge = details.globalPosition.dx <= 24;
                _edgeDistance = 0;
              },
              onHorizontalDragUpdate: (details) {
                if (_edge) _edgeDistance += details.delta.dx;
              },
              onHorizontalDragEnd: (details) {
                if (_edge &&
                    (_edgeDistance > 60 ||
                        (details.primaryVelocity ?? 0) > 300)) {
                  _back();
                }
                _edge = false;
              },
              child: !_loaded
                  ? Center(
                      child: _error == null
                          ? const CircularProgressIndicator(color: worldInk)
                          : TextButton(
                              onPressed: _restore,
                              child: Text(_error!),
                            ),
                    )
                  : _setup.step == WorldStep.intro
                  ? _introView(context)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final reduced = MediaQuery.disableAnimationsOf(context);
                        final scaledText =
                            MediaQuery.textScalerOf(context).scale(15) / 15;
                        final keyboard = MediaQuery.viewInsetsOf(
                          context,
                        ).bottom;
                        if (scaledText > 1.35 ||
                            constraints.maxHeight < 700 ||
                            constraints.maxWidth < 350) {
                          return _flowLayout(
                            context,
                            constraints.maxWidth,
                            reduced,
                            keyboard,
                          );
                        }
                        final scale = math.min(constraints.maxWidth, 460) / 390;
                        return Center(
                          child: SizedBox(
                            width: 390 * scale,
                            height: constraints.maxHeight,
                            child: FittedBox(
                              alignment: Alignment.topLeft,
                              fit: BoxFit.fill,
                              child: SizedBox(
                                key: _canvasKey,
                                width: 390,
                                height: constraints.maxHeight / scale,
                                child: _referenceLayout(
                                  context,
                                  390,
                                  constraints.maxHeight / scale,
                                  reduced,
                                  keyboard / scale,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _introView(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: 'FindEZ. Everything you own, remembered. Continue to setup.',
      child: GestureDetector(
        onTap: _leaveIntro,
        behavior: HitTestBehavior.opaque,
        child: FadeTransition(
          opacity: _introFade,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _IntroPainter(_intro, reduced)),
                ),
              ),
              Align(
                alignment: const Alignment(0, -.04),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _intro,
                      child: const FindEZWordmark(width: 208),
                      builder: (context, child) {
                        final progress = reduced
                            ? 1.0
                            : Curves.easeOutCubic.transform(
                                phase(_intro.value * 3000, 300, 800),
                              );
                        return Opacity(
                          opacity: progress,
                          child: Transform.translate(
                            offset: Offset(0, 18 * (1 - progress)),
                            child: child,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    AnimatedBuilder(
                      animation: _intro,
                      child: const Text(
                        'Everything you own, remembered.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 16,
                          color: worldSecondary,
                        ),
                      ),
                      builder: (context, child) => Opacity(
                        opacity: reduced
                            ? 1
                            : phase(_intro.value * 3000, 1000, 600),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(bool reduced) => Column(
    key: ValueKey(_setup.step),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(
          _title,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 34,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.19,
            height: 1.04,
            color: worldInk,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        _subtitle,
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 15,
          height: 1.45,
          color: worldSecondary,
        ),
      ),
    ],
  );

  double _textHeight(
    BuildContext context,
    String text,
    TextStyle style,
    double width,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: math.max(1, width));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  double _tagHeight(BuildContext context, double width) =>
      [
        _setup.isTeam ? _setup.orgName : 'Personal',
        _setup.workspacePurpose,
        _setup.inventoryName,
      ].fold(
        30.0,
        (height, label) => math.max(
          height,
          12 +
              _textHeight(
                context,
                label,
                const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                math.min(300, width - 48) - 38,
              ),
        ),
      );

  double _chipsHeight(BuildContext context, double width) {
    var rows = 1;
    var used = 0.0;
    for (final label in _choices) {
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final chip = math.min(width, math.max(44.0, text.width + 40));
      text.dispose();
      if (used > 0 && used + 8 + chip > width) {
        rows++;
        used = 0;
      }
      used += (used == 0 ? 0 : 8) + chip;
    }
    return rows * 44 + (rows - 1) * 2.0;
  }

  double _legendHeight(BuildContext context, double width) =>
      [
        _setup.isTeam ? _setup.orgName : 'Only you',
        _setup.workspacePurpose,
        _setup.inventoryName,
      ].fold(
        0.0,
        (height, label) =>
            height +
            17 +
            44 +
            _textHeight(
              context,
              label,
              const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -.24,
              ),
              width,
            ),
      );

  // Reserve the platform's front label and the highest falling cube before
  // choosing a scale. Safe-area and keyboard space are already excluded.
  WorldCamera _fitCamera(
    WorldCamera preferred,
    Rect area, {
    required double modelTop,
    required double tagHalf,
  }) {
    final scale = math.max(
      .02,
      math.min(
        preferred.scale,
        math.min(
          area.width / 346.5,
          (area.height - 2 * tagHalf) / (106 - modelTop),
        ),
      ),
    );
    final low = area.top - modelTop * scale + tagHalf;
    final high = area.bottom - 106 * scale - tagHalf;
    return WorldCamera(
      preferred.x,
      high < low ? (low + high) / 2 : preferred.y.clamp(low, high),
      scale,
    );
  }

  Widget _referenceLayout(
    BuildContext context,
    double width,
    double height,
    bool reduced,
    double keyboard,
  ) {
    final naming = _setup.step == WorldStep.organization || _customizing;
    final focused = naming && _focus.hasFocus;
    const headingTop = 32.0;
    final headingBottom =
        headingTop +
        _textHeight(
          context,
          _title,
          const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 34,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.19,
            height: 1.04,
          ),
          width - 48,
        ) +
        12 +
        _textHeight(
          context,
          _subtitle,
          const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, height: 1.45),
          width - 48,
        );
    final inputHeight =
        64 +
        48 +
        (_setup.step == WorldStep.organization
            ? 8 +
                  _textHeight(
                    context,
                    'Your team will see this. You can change it later.',
                    const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      height: 1.35,
                    ),
                    width - 56,
                  )
            : 0);
    final inputTop = math.min(
      height - 219,
      height - keyboard - inputHeight - 12,
    );
    final chipsBottom = math.min(96.0, height * .12);
    final controlsTop = naming
        ? inputTop
        : height - chipsBottom - _chipsHeight(context, width - 48);
    final desired = switch (_setup.step) {
      WorldStep.organization => const WorldCamera(195, 500, .8),
      WorldStep.workspace => const WorldCamera(195, 490, .9),
      WorldStep.inventory => const WorldCamera(195, 480, 1),
      _ => const WorldCamera(112, 520, .62),
    };
    final tagHalf = _tagHeight(context, width) / 2;
    final modelTop = switch (_setup.step) {
      WorldStep.organization => -122.0,
      WorldStep.workspace => -145.0,
      _ => -230.0,
    };
    final area = Rect.fromLTRB(
      24,
      headingBottom + 24,
      width - 24,
      controlsTop - 24,
    );
    final fitted = _fitCamera(
      WorldCamera(
        desired.x,
        desired.y + height - 844,
        focused ? .6 : desired.scale,
      ),
      area,
      modelTop: modelTop,
      tagHalf: tagHalf,
    );
    final legendHeight = _legendHeight(context, 126);
    final legendTop = math.max(
      headingBottom + 36,
      math.min(330.0, height - 136 - legendHeight),
    );
    if (_setup.step == WorldStep.world &&
        legendTop + legendHeight > height - 136) {
      return _flowLayout(context, width, reduced, keyboard);
    }
    final camera = _exiting
        ? const WorldCamera(150, 120, .12)
        : _setup.step == WorldStep.choose
        ? _morphOrigin ?? const WorldCamera(292, 474, .36)
        : _setup.step == WorldStep.world
        ? WorldCamera(112, legendTop + legendHeight / 2, .62)
        : fitted;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: WorldScene(
              key: _worldKey,
              setup: _exiting ? _setup.copyWith(step: WorldStep.auth) : _setup,
              camera: camera,
              morphFrom: _morphOrigin,
              reduced: reduced,
              focused: focused,
            ),
          ),
        ),
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: reduced ? 200 : 350),
            reverseDuration: Duration(milliseconds: reduced ? 200 : 350),
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [
                ...previous.map((child) => IgnorePointer(child: child)),
                if (current != null) current,
              ],
            ),
            transitionBuilder: (child, animation) => AnimatedBuilder(
              animation: animation,
              child: child,
              builder: (context, child) =>
                  animation.status == AnimationStatus.reverse
                  ? Opacity(
                      opacity: Curves.easeInOutCubic.transform(animation.value),
                      child: child,
                    )
                  : child!,
            ),
            child: _exiting
                ? const SizedBox.shrink(key: ValueKey('exiting'))
                : Stack(
                    key: ValueKey(_setup.step),
                    children: [
                      Positioned(
                        top: headingTop,
                        left: 24,
                        right: 24,
                        child: WorldEntrance(
                          key: ValueKey('${_setup.step}-heading'),
                          duration: _setup.step == WorldStep.choose ? 600 : 500,
                          backwards: _goingBack,
                          child: _heading(reduced),
                        ),
                      ),
                      if (_setup.step == WorldStep.choose) ...[
                        Positioned(
                          left: 24,
                          right: 24,
                          top: 250,
                          child: WorldEntrance(
                            delay: 250,
                            duration: 600,
                            distance: 26,
                            child: _tile('personal'),
                          ),
                        ),
                        Positioned(
                          left: 24,
                          right: 24,
                          top: 396,
                          child: WorldEntrance(
                            delay: 400,
                            duration: 600,
                            distance: 26,
                            child: _tile('team'),
                          ),
                        ),
                        const Positioned(
                          left: 24,
                          right: 24,
                          top: 548,
                          child: WorldEntrance(
                            delay: 700,
                            child: Text(
                              'Starting solo? You can add an organization anytime.',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13.5,
                                height: 1.4,
                                color: worldHint,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: 28,
                          child: WorldPress(
                            child: TextButton(
                              key: const Key('onboarding-skip'),
                              onPressed: _busy ? null : _existing,
                              child: const Text(
                                'I already have an account',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 15,
                                  color: worldSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (naming)
                        Positioned(
                          top: inputTop,
                          left: 24,
                          right: 24,
                          child: _input(),
                        ),
                      if (!naming &&
                          [
                            WorldStep.workspace,
                            WorldStep.inventory,
                          ].contains(_setup.step))
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: chipsBottom,
                          child: WorldEntrance(
                            key: ValueKey('${_setup.step}-chips'),
                            delay: 300,
                            backwards: _goingBack,
                            child: _chips(),
                          ),
                        ),
                      if (_setup.step == WorldStep.world)
                        Positioned(
                          left: 240,
                          right: 24,
                          top: legendTop,
                          child: _legend(),
                        ),
                      if (keyboard == 0 && _setup.step == WorldStep.world)
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: 56,
                          child: WorldEntrance(child: _continue()),
                        ),
                      if (_error != null)
                        Positioned(
                          left: 24,
                          right: 24,
                          top: 54,
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFB42318),
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        if (_exiting)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _exit,
                child: const AuthPage(fromOnboarding: true),
                builder: (context, child) {
                  final progress = reduced
                      ? 1.0
                      : Curves.easeOutCubic.transform(
                          phase(_exit.value * 900, 200, 600),
                        );
                  return Opacity(
                    opacity: progress,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - progress)),
                      child: child,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _flowLayout(
    BuildContext context,
    double width,
    bool reduced,
    double keyboard,
  ) => Padding(
    padding: EdgeInsets.only(bottom: keyboard),
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        math.max(MediaQuery.paddingOf(context).top, 24),
        24,
        36,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(reduced),
          const SizedBox(height: 28),
          if (_setup.step == WorldStep.choose) ...[
            _tile('personal', flow: true),
            const SizedBox(height: 14),
            _tile('team', flow: true),
            const SizedBox(height: 20),
            const Text(
              'Starting solo? You can add an organization anytime.',
              style: TextStyle(color: worldSecondary, fontSize: 13.5),
            ),
          ],
          SizedBox(
            height: _setup.step == WorldStep.choose
                ? 0
                : 320 + math.max(0, _tagHeight(context, width - 48) - 30),
            child: WorldScene(
              key: _worldKey,
              setup: _setup,
              camera: WorldCamera((width - 48) / 2, 220, .68),
              reduced: reduced,
            ),
          ),
          if (_setup.step != WorldStep.choose) ...[
            if (_setup.step == WorldStep.world) _legend(),
            if (_setup.step == WorldStep.organization || _customizing)
              _input()
            else if (_setup.step != WorldStep.world)
              _chips(),
          ],
          const SizedBox(height: 24),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
          if (_setup.step == WorldStep.world) _continue(),
          if (_setup.step == WorldStep.choose)
            TextButton(
              key: const Key('onboarding-skip'),
              onPressed: _busy ? null : _existing,
              child: const Text(
                'I already have an account',
                style: TextStyle(color: worldSecondary),
              ),
            ),
        ],
      ),
    ),
  );
  Widget _tile(String path, {bool flow = false}) {
    final selected = _setup.path == path;
    final personal = path == 'personal';
    final miniKey = GlobalKey();
    if (personal) {
      _personalMiniKey = miniKey;
    } else {
      _teamMiniKey = miniKey;
    }
    return WorldPress(
      child: Semantics(
        button: true,
        selected: selected,
        label: personal
            ? 'Just me. Home, garage, desk or dorm.'
            : 'My team. A company, lab or team.',
        excludeSemantics: true,
        onTap: _busy
            ? null
            : () => unawaited(_select(_setup.copyWith(path: path))),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('world-path-$path'),
            onTap: _busy
                ? null
                : () => unawaited(_select(_setup.copyWith(path: path))),
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFFF8F3) : Colors.white,
                border: Border.all(
                  color: selected ? worldOrange : worldBorder,
                  width: selected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              height: flow ? null : 132,
              child: Stack(
                children: [
                  if (!flow)
                    Positioned(
                      right: 0,
                      top: 14,
                      width: 148,
                      height: 128,
                      child: SizedBox(
                        key: miniKey,
                        child: ValueListenableBuilder<String?>(
                          valueListenable: _hiddenMini,
                          builder: (context, hidden, _) => Opacity(
                            opacity: hidden == path ? 0 : 1,
                            child: WorldScene(
                              setup: PendingWorld(path: path),
                              camera: const WorldCamera(74, 64, .36),
                              mini: true,
                              personalMini: personal,
                              reduced: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (flow)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
                      child: _tileText(personal),
                    )
                  else
                    Positioned(
                      left: 22,
                      right: 22,
                      bottom: 20,
                      child: _tileText(personal),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tileText(bool personal) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        personal ? 'Just me' : 'My team',
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -.44,
          height: 1.2,
          color: worldInk,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        personal ? 'Home, garage, desk or dorm.' : 'A company, lab or team.',
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 14,
          height: 1.25,
          color: worldSecondary,
        ),
      ),
    ],
  );

  Widget _input() {
    final organization = _setup.step == WorldStep.organization;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: Key(organization ? 'world-organization' : 'world-custom'),
          controller: organization ? _organization : _custom,
          focusNode: _focus,
          enabled: !_busy,
          maxLength: organization ? 60 : 40,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          onChanged: (text) {
            if (organization) {
              _answer(_setup.copyWith(orgName: text));
            } else {
              setState(() {});
            }
          },
          onSubmitted: (_) {
            if (organization) {
              if (_valid) unawaited(_next());
            } else {
              _confirmCustom();
            }
          },
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: worldInk,
          ),
          cursorColor: worldOrange,
          decoration: InputDecoration(
            counterText: '',
            hintText: organization
                ? 'e.g. FindEZ AI'
                : _setup.step == WorldStep.workspace
                ? 'e.g. Field service'
                : 'e.g. Lab supplies',
            hintStyle: const TextStyle(color: Color(0xFFB3B0A9)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: worldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: worldOrange, width: 2),
            ),
          ),
        ),
        if (organization)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'Your team will see this. You can change it later.',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                height: 1.35,
                color: worldHint,
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy
                ? null
                : organization
                ? (_valid ? _next : null)
                : (PendingWorld.validName(_custom.text, 40)
                      ? _confirmCustom
                      : null),
            child: const Text('Done', style: TextStyle(color: worldSecondary)),
          ),
        ),
      ],
    );
  }

  void _confirmCustom() {
    if (!PendingWorld.validName(_custom.text, 40)) return;
    final name = _custom.text.trim();
    _focus.unfocus();
    _answer(
      _setup.step == WorldStep.workspace
          ? _setup.copyWith(workspacePurpose: name)
          : _setup.copyWith(inventoryName: name),
    );
    setState(() => _customizing = false);
    unawaited(_next());
  }

  List<String> get _choices {
    final workspace = _setup.step == WorldStep.workspace;
    final choices = workspace
        ? (_setup.isTeam
              ? ['R&D', 'Production', 'Competition']
              : ['Home', 'Workshop', 'Studio'])
        : (_setup.isTeam
              ? ['Hardware', 'Electronics', 'Software']
              : ['Tools', 'Electronics', 'Household']);
    final selected = workspace ? _setup.workspacePurpose : _setup.inventoryName;
    if (selected.isNotEmpty && !choices.contains(selected)) {
      choices.add(selected);
    }
    return [...choices, '+ Custom'];
  }

  Widget _chips() {
    final workspace = _setup.step == WorldStep.workspace;
    final selected = workspace ? _setup.workspacePurpose : _setup.inventoryName;
    return Wrap(
      spacing: 8,
      runSpacing: 2,
      children: [
        for (final label in _choices)
          Semantics(
            button: true,
            selected: label == selected,
            child: WorldPress(
              child: SizedBox(
                height: 44,
                child: Center(
                  widthFactor: 1,
                  child: TextButton(
                    key: ValueKey('world-chip-$label'),
                    onPressed: _busy
                        ? null
                        : () {
                            if (label == '+ Custom') {
                              _custom.text = selected;
                              setState(() => _customizing = true);
                              _focus.requestFocus();
                            } else {
                              unawaited(
                                _select(
                                  workspace
                                      ? _setup.copyWith(workspacePurpose: label)
                                      : _setup.copyWith(inventoryName: label),
                                ),
                              );
                            }
                          },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      backgroundColor: label == selected
                          ? worldOrange
                          : Colors.white,
                      foregroundColor: label == selected
                          ? Colors.white
                          : const Color(0xFF3F3D39),
                      shape: StadiumBorder(
                        side: label == selected
                            ? BorderSide.none
                            : const BorderSide(color: worldBorder),
                      ),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _legend() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final entry in [
        (
          _setup.isTeam ? 'ORGANIZATION' : 'PERSONAL',
          _setup.isTeam ? _setup.orgName : 'Only you',
        ),
        ('WORKSPACE', _setup.workspacePurpose),
        ('INVENTORY', _setup.inventoryName),
      ]) ...[
        WorldEntrance(
          delay:
              800 +
              300 *
                  (_setup.isTeam
                          ? ['ORGANIZATION', 'WORKSPACE', 'INVENTORY']
                          : ['PERSONAL', 'WORKSPACE', 'INVENTORY'])
                      .indexOf(entry.$1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.$1,
                style: const TextStyle(
                  fontFamily: 'GeistMono',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: .84,
                  color: Color(0xFF9A978F),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                entry.$2,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.24,
                  color: worldInk,
                ),
              ),
              const SizedBox(height: 44),
            ],
          ),
        ),
      ],
    ],
  );
  Widget _continue() => WorldPress(
    child: FilledButton(
      key: const Key('onboarding-next'),
      onPressed: _valid && !_busy ? _next : null,
      style: FilledButton.styleFrom(
        backgroundColor: worldInk,
        foregroundColor: Colors.white,
        disabledBackgroundColor: worldBorder,
        disabledForegroundColor: const Color(0xFF9A978F),
        minimumSize: const Size(double.infinity, 56),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              'Open my dashboard',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -.17,
              ),
            ),
    ),
  );
}

class _IntroPainter extends CustomPainter {
  _IntroPainter(this.animation, this.reduced) : super(repaint: animation);
  final Animation<double> animation;
  final bool reduced;
  @override
  void paint(Canvas canvas, Size size) {
    const dots = [
      Offset(.18, .21),
      Offset(.77, .18),
      Offset(.54, .26),
      Offset(.87, .47),
      Offset(.13, .56),
      Offset(.82, .71),
      Offset(.31, .76),
      Offset(.49, .83),
    ];
    final time = reduced ? 3000.0 : animation.value * 3000;
    final sweep = Curves.easeInOutCubic.transform(phase(time, 300, 1300));
    final scanY = size.height * sweep;
    for (var index = 0; index < dots.length; index++) {
      final point = dots[index];
      final at = Offset(point.dx * size.width, point.dy * size.height);
      final fade = Curves.easeOutCubic.transform(phase(time, index * 80, 500));
      // Invert the sweep curve to get the exact time this dot is passed.
      double low = 0, high = 1;
      for (var i = 0; i < 16; i++) {
        final middle = (low + high) / 2;
        if (Curves.easeInOutCubic.transform(middle) < point.dy) {
          low = middle;
        } else {
          high = middle;
        }
      }
      final detection = Curves.easeOutCubic.transform(
        phase(time, 300 + high * 1300, 250),
      );
      canvas.drawCircle(
        at,
        3,
        Paint()
          ..color = (detection > 0 ? worldOrange : const Color(0xFFC8C5BE))
              .withValues(alpha: fade),
      );
      if (detection > 0) {
        final edge = 18 * (1.4 - .4 * detection);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: at, width: edge, height: edge),
            const Radius.circular(3),
          ),
          Paint()
            ..color = worldOrange.withValues(alpha: detection)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
    if (!reduced && time >= 300 && time <= 1600) {
      canvas.drawLine(
        Offset(0, scanY),
        Offset(size.width, scanY),
        Paint()
          ..color = worldOrange.withValues(alpha: .8)
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _IntroPainter old) =>
      old.animation != animation || old.reduced != reduced;
}
