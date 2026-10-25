import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Owns exactly one root route; closing it never pops a newer sheet or page.
class PipExtractLoaderHandle {
  PipExtractLoaderHandle._(this._navigator, this._onStop);

  final NavigatorState _navigator;
  final VoidCallback? _onStop;
  final _count = ValueNotifier<int?>(null);
  late final RawDialogRoute<void> _route;
  Timer? _successTimer;
  Completer<void>? _success;
  bool _closed = false;

  Future<void> succeed(int count) {
    if (_closed) return Future<void>.value();
    if (_success != null) return _success!.future;
    _success = Completer<void>();
    _count.value = count;
    _successTimer = Timer(const Duration(milliseconds: 600), dismiss);
    return _success!.future;
  }

  void stop() {
    if (_closed) return;
    _onStop?.call();
    dismiss();
  }

  void dismiss() {
    if (_closed) return;
    _closed = true;
    _successTimer?.cancel();
    if (_navigator.mounted && _route.isActive) {
      _navigator.removeRoute(_route);
    }
    if (_success?.isCompleted == false) _success!.complete();
  }
}

PipExtractLoaderHandle showPipExtractLoader(
  BuildContext context, {
  VoidCallback? onStop,
}) {
  final handle = PipExtractLoaderHandle._(
    Navigator.of(context, rootNavigator: true),
    onStop,
  );
  final reduceMotion =
      MediaQuery.disableAnimationsOf(context) ||
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .reduceMotion;
  handle._route = RawDialogRoute<void>(
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration(milliseconds: reduceMotion ? 0 : 350),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (_, _, _) => ValueListenableBuilder<int?>(
      valueListenable: handle._count,
      builder: (_, count, _) => PipExtractLoader(
        foundCount: count,
        onStop: onStop == null ? null : handle.stop,
      ),
    ),
  );
  unawaited(handle._navigator.push<void>(handle._route));
  unawaited(
    handle._route.completed.then((_) {
      handle.dismiss();
      handle._count.dispose();
    }),
  );
  return handle;
}

/// Presentation only. Timed captions are not model telemetry; no invented finds.
class PipExtractLoader extends StatefulWidget {
  const PipExtractLoader({super.key, this.foundCount, this.onStop});

  final int? foundCount;
  final VoidCallback? onStop;

  @override
  State<PipExtractLoader> createState() => _PipExtractLoaderState();
}

class _PipExtractLoaderState extends State<PipExtractLoader>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _lines = [
    'Pip is looking...',
    'Reading labels...',
    'Counting items...',
    'Matching model numbers...',
    'Still working...',
  ];
  late final _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  Timer? _steps;
  Timer? _seeds;
  int _step = 0;
  int _nextSeed = 0;
  final _seedIds = <int>[];
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _steps = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (_step == _lines.length - 1 || widget.foundCount != null) {
        timer.cancel();
        return;
      }
      setState(() => _step++);
      if (_step == _lines.length - 1) timer.cancel();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion;
    _syncMotion();
  }

  @override
  void didChangeAccessibilityFeatures() {
    setState(() {
      _reduceMotion =
          MediaQuery.disableAnimationsOf(context) ||
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .reduceMotion;
      _syncMotion();
    });
  }

  void _syncMotion() {
    _seeds?.cancel();
    if (_reduceMotion || widget.foundCount != null) {
      _bob.stop();
      _progress.stop();
      _seedIds.clear();
      if (_reduceMotion) _pop.stop();
    } else {
      if (!_bob.isAnimating) _bob.repeat();
      if (!_progress.isAnimating) _progress.repeat();
      _seeds = Timer.periodic(const Duration(milliseconds: 1400), (_) {
        setState(() => _seedIds.add(_nextSeed++));
      });
    }
  }

  @override
  void didUpdateWidget(PipExtractLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.foundCount != oldWidget.foundCount) {
      _steps?.cancel();
      _syncMotion();
      if (!_reduceMotion && widget.foundCount != null) _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _steps?.cancel();
    _seeds?.cancel();
    _bob.dispose();
    _progress.dispose();
    _pop.dispose();
    super.dispose();
  }

  // y, scaleX, scaleY, rotation. Each segment uses the reference easing.
  List<double> _pose(double t) {
    const times = [0.0, .45, .55, .85, 1.0];
    const frames = [
      [0.0, 1.0, 1.0, 0.0],
      [-8.0, .98, 1.02, -2.0],
      [-8.0, .98, 1.02, 2.0],
      [0.0, 1.03, .97, 0.0],
      [0.0, 1.0, 1.0, 0.0],
    ];
    final i = times.indexWhere((end) => end > t).clamp(1, 4);
    final f = Curves.easeInOut.transform(
      ((t - times[i - 1]) / (times[i] - times[i - 1])).clamp(0, 1),
    );
    return List.generate(
      4,
      (j) => lerpDouble(frames[i - 1][j], frames[i][j], f)!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.foundCount;
    final status = count == null
        ? _lines[_step]
        : 'Found $count ${count == 1 ? 'item' : 'items'}';
    final statusText = Text(
      status,
      key: ValueKey(status),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: Colors.white,
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onStop?.call();
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: const ColoredBox(color: Color(0xB3111112)),
            ),
            SafeArea(
              child: Align(
                alignment: const Alignment(0, -.08),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 210,
                        width: 300,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.bottomCenter,
                          children: [
                            RepaintBoundary(
                              child: AnimatedBuilder(
                                animation: Listenable.merge([_bob, _pop]),
                                child: _PipArt(success: count != null),
                                builder: (_, child) {
                                  final pose = _pose(
                                    _reduceMotion || count != null
                                        ? 0
                                        : _bob.value,
                                  );
                                  final pop = _reduceMotion
                                      ? 1.0
                                      : 1 +
                                            .08 *
                                                math.sin(math.pi * _pop.value);
                                  return Transform(
                                    alignment: const Alignment(0, .84),
                                    transform: Matrix4.identity()
                                      ..translateByDouble(0, pose[0], 0, 1)
                                      ..rotateZ(pose[3] * math.pi / 180)
                                      ..scaleByDouble(
                                        pose[1] * pop,
                                        pose[2] * pop,
                                        1,
                                        1,
                                      ),
                                    child: child,
                                  );
                                },
                              ),
                            ),
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: ExcludeSemantics(
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      for (final id in _seedIds)
                                        _Seed(
                                          key: ValueKey(id),
                                          id: id,
                                          onDone: () {
                                            if (mounted) {
                                              setState(
                                                () => _seedIds.remove(id),
                                              );
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Semantics(
                        liveRegion: true,
                        label: status,
                        child: ExcludeSemantics(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _reduceMotion
                                ? statusText
                                : AnimatedSwitcher(
                                    duration: Duration(
                                      milliseconds: _reduceMotion ? 0 : 350,
                                    ),
                                    transitionBuilder: (child, animation) =>
                                        AnimatedBuilder(
                                          animation: animation,
                                          child: child,
                                          builder: (_, child) => Opacity(
                                            opacity: animation.value,
                                            child: Transform.translate(
                                              offset: Offset(
                                                0,
                                                (animation.status ==
                                                            AnimationStatus
                                                                .reverse
                                                        ? -14
                                                        : 14) *
                                                    (1 - animation.value),
                                              ),
                                              child: child,
                                            ),
                                          ),
                                        ),
                                    child: statusText,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        count == null
                            ? 'Looking through your photo'
                            : '$count found',
                        style: const TextStyle(
                          fontFamily: 'GeistMono',
                          fontSize: 12,
                          color: Color(0xD1FFFFFF),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 180,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 4,
                            child: ColoredBox(
                              color: const Color(0x47FFFFFF),
                              child: AnimatedBuilder(
                                animation: _progress,
                                builder: (_, _) => Align(
                                  alignment: Alignment(
                                    _reduceMotion || count != null
                                        ? -1
                                        : -1 +
                                              2 *
                                                  Curves.easeInOut.transform(
                                                    _progress.value,
                                                  ),
                                    0,
                                  ),
                                  child: FractionallySizedBox(
                                    widthFactor: count != null ? 1 : .34,
                                    child: const ColoredBox(
                                      color: Colors.white,
                                      child: SizedBox.expand(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.onStop != null) ...[
                        const SizedBox(height: 24),
                        OutlinedButton(
                          onPressed: widget.onStop,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize: const Size(120, 44),
                            side: const BorderSide(color: Color(0x99FFFFFF)),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Stop extraction'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PipArt extends StatelessWidget {
  const _PipArt({required this.success});
  final bool success;

  @override
  Widget build(BuildContext context) {
    final asset = 'assets/mascot/${success ? 'pip-found-it' : 'pip'}.svg';
    // The supplied SVG already includes a ground shadow. Adding a second
    // silhouette or oval makes Pip look doubled on light backgrounds.
    return SizedBox(
      width: 170,
      height: 170,
      child: ExcludeSemantics(child: SvgPicture.asset(asset)),
    );
  }
}

class _Seed extends StatefulWidget {
  const _Seed({super.key, required this.id, required this.onDone});
  final int id;
  final VoidCallback onDone;

  @override
  State<_Seed> createState() => _SeedState();
}

class _SeedState extends State<_Seed> with SingleTickerProviderStateMixin {
  late final _animation =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2200),
        )
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onDone();
        })
        ..forward();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (_, _) {
      final t = _animation.value;
      final enter = Curves.easeOut.transform((t / .18).clamp(0, 1));
      final leave = Curves.easeIn.transform(((t - .75) / .25).clamp(0, 1));
      final x = (40 + widget.id % 4 * 10) * (widget.id.isEven ? -1 : 1);
      return Positioned(
        left: 150 + x - 7,
        bottom: 140 + enter * 20 + leave * 46,
        child: Opacity(
          opacity: enter * (1 - leave),
          child: Transform.scale(
            scale: .6 + .4 * enter,
            child: Container(
              width: 14,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFFE8590C),
                borderRadius: BorderRadius.circular(7),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x291E3C64),
                    offset: Offset(0, 8),
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
