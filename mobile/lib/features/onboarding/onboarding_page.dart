import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/ui/primary_gradient_button.dart';
import '../scan/scan_page.dart';
import 'onboarding_prefs.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.child,
  });

  final String text;
  final bool isUser;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final bg = isUser
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.06);
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(isUser ? 14 : 6),
      bottomRight: Radius.circular(isUser ? 6 : 14),
    );

    return Align(
      alignment: align,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: child ??
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.25,
                  ),
            ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        double dot(double phase) {
          final v = (t + phase) % 1.0;
          return 0.25 + (0.75 * (1.0 - (2.0 * (v - 0.5)).abs()));
        }

        Widget d(double o) {
          return Opacity(
            opacity: o,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            d(dot(0.0)),
            const SizedBox(width: 6),
            d(dot(0.2)),
            const SizedBox(width: 6),
            d(dot(0.4)),
          ],
        );
      },
    );
  }
}

class _StartHookSlide extends StatefulWidget {
  const _StartHookSlide({
    required this.onScan,
    required this.onSkip,
  });

  final VoidCallback? onScan;
  final VoidCallback? onSkip;

  @override
  State<_StartHookSlide> createState() => _StartHookSlideState();
}

class _StartHookSlideState extends State<_StartHookSlide> {
  static const _options = <String>[
    'Tools',
    'Home items',
    'Plants',
    'Everything',
  ];

  String? _selected;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final existing = await OnboardingPrefs.getPersona();
    if (!mounted) return;
    setState(() => _selected = existing);
  }

  Future<void> _choose(String label) async {
    HapticFeedback.selectionClick();
    setState(() => _selected = label);
    await OnboardingPrefs.setPersona(label);
  }

  void _tap(VoidCallback? cb) {
    if (cb == null) return;
    HapticFeedback.lightImpact();
    cb();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.72),
          height: 1.25,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('What do you want to track?', style: subtitle),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in _options)
              ChoiceChip(
                label: Text(opt),
                selected: _selected == opt,
                onSelected: (_) => unawaited(_choose(opt)),
                selectedColor: Colors.white.withValues(alpha: 0.16),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                shape: StadiumBorder(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryGradientButton(
          onPressed: widget.onScan == null ? null : () => _tap(widget.onScan),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined, size: 18),
              SizedBox(width: 10),
              Text('Scan your first item'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: widget.onSkip == null ? null : () => _tap(widget.onSkip),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.92),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: const Text('Skip for now'),
        ),
      ],
    );
  }
}

class _AssistDemoSlide extends StatefulWidget {
  const _AssistDemoSlide({required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<_AssistDemoSlide> createState() => _AssistDemoSlideState();
}

class _AssistDemoSlideState extends State<_AssistDemoSlide> {
  static const _q = 'Do I have a hammer?';
  static const _a1 = 'Yes — it\'s in your garage.';
  static const _a2 = 'You have 3 bolts left.';

  Timer? _t1;
  Timer? _t2;
  Timer? _t3;
  Timer? _t4;

  bool _started = false;
  bool _done = false;

  bool _showUser = false;
  bool _typing = false;
  bool _showA1 = false;
  bool _showA2 = false;

  @override
  void dispose() {
    _t1?.cancel();
    _t2?.cancel();
    _t3?.cancel();
    _t4?.cancel();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    HapticFeedback.selectionClick();
    setState(() {
      _started = true;
      _done = false;
      _showUser = false;
      _typing = false;
      _showA1 = false;
      _showA2 = false;
    });

    _t1 = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _showUser = true);
    });
    _t2 = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      setState(() => _typing = true);
    });
    _t3 = Timer(const Duration(milliseconds: 940), () {
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        _typing = false;
        _showA1 = true;
      });
    });
    _t4 = Timer(const Duration(milliseconds: 1380), () {
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        _showA2 = true;
        _done = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget bubble(Widget child) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (c, anim) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: c,
            ),
          );
        },
        child: child,
      );
    }

    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.72),
          height: 1.25,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ask anything. Get answers fast.', style: muted),
        const SizedBox(height: 14),
        bubble(
          !_showUser
              ? const SizedBox.shrink()
              : const _ChatBubble(
                  key: ValueKey('assist_user'),
                  text: _q,
                  isUser: true,
                ),
        ),
        const SizedBox(height: 10),
        bubble(
          !_typing
              ? const SizedBox.shrink()
              : const _ChatBubble(
                  key: ValueKey('assist_typing'),
                  text: '',
                  isUser: false,
                  child: _TypingDots(),
                ),
        ),
        const SizedBox(height: 10),
        bubble(
          !_showA1
              ? const SizedBox.shrink()
              : const _ChatBubble(
                  key: ValueKey('assist_a1'),
                  text: _a1,
                  isUser: false,
                ),
        ),
        const SizedBox(height: 10),
        bubble(
          !_showA2
              ? const SizedBox.shrink()
              : const _ChatBubble(
                  key: ValueKey('assist_a2'),
                  text: _a2,
                  isUser: false,
                ),
        ),
        const SizedBox(height: 16),
        PrimaryGradientButton(
          onPressed: _done
              ? widget.onContinue
              : (_started ? null : _start),
          child: Text(_done ? 'Continue' : 'Ask anything'),
        ),
      ],
    );
  }
}

class _MagicMomentSlide extends StatefulWidget {
  const _MagicMomentSlide({required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<_MagicMomentSlide> createState() => _MagicMomentSlideState();
}

class _MagicMomentSlideState extends State<_MagicMomentSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanLine;
  Timer? _t1;
  Timer? _t2;
  Timer? _t3;
  Timer? _t4;

  bool _running = false;
  bool _saved = false;
  final List<String> _found = <String>[];

  @override
  void initState() {
    super.initState();
    _scanLine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _t1?.cancel();
    _t2?.cancel();
    _t3?.cancel();
    _t4?.cancel();
    _scanLine.dispose();
    super.dispose();
  }

  void _clearTimers() {
    _t1?.cancel();
    _t2?.cancel();
    _t3?.cancel();
    _t4?.cancel();
  }

  void _tryIt() {
    if (_running) return;
    _clearTimers();
    HapticFeedback.lightImpact();
    setState(() {
      _running = true;
      _saved = false;
      _found
        ..clear()
        ..add('Scanning…');
    });
    _scanLine.repeat();

    _t1 = Timer(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        _found
          ..clear()
          ..addAll(['Hammer']);
      });
    });
    _t2 = Timer(const Duration(milliseconds: 820), () {
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() => _found.add('Bolts'));
    });
    _t3 = Timer(const Duration(milliseconds: 1120), () {
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() => _found.add('Plants'));
    });
    _t4 = Timer(const Duration(milliseconds: 1460), () {
      if (!mounted) return;
      _scanLine.stop();
      setState(() {
        _running = false;
        _saved = true;
      });
    });
  }

  Widget _cameraFrame({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: child,
      ),
    );
  }

  Widget _scanLineWidget() {
    return AnimatedBuilder(
      animation: _scanLine,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_scanLine.value);
        return Align(
          alignment: Alignment(0, -1 + (2 * t)),
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.25),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.72),
          height: 1.25,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cameraFrame(
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 44,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              if (_running) _scanLineWidget(),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: PrimaryGradientButton(
                  onPressed: _saved || _running ? null : _tryIt,
                  child: Text(_running ? 'Scanning…' : (_saved ? 'Saved' : 'Try it')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _saved ? 'Saved to your inventory ✔' : 'Found:',
          style: muted,
          textAlign: TextAlign.left,
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _found.isEmpty
              ? const SizedBox.shrink()
              : Wrap(
                  key: ValueKey('${_found.length}|$_saved|$_running'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in _found)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Text(
                          f,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        PrimaryGradientButton(
          onPressed: _saved
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onContinue();
                }
              : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _SpacesSlide extends StatefulWidget {
  const _SpacesSlide({required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<_SpacesSlide> createState() => _SpacesSlideState();
}

class _SpacesSlideState extends State<_SpacesSlide> {
  static const _spaces = <({String name, IconData icon, int count, List<String> items})>[
    (
      name: 'Garage',
      icon: Icons.garage_outlined,
      count: 18,
      items: ['Hammer', 'Bolts', 'Tape', 'Gloves', 'Wrench', 'Ladder'],
    ),
    (
      name: 'Garden',
      icon: Icons.local_florist_outlined,
      count: 9,
      items: ['Seeds', 'Soil', 'Pots', 'Shears', 'Fertilizer'],
    ),
    (
      name: 'Kitchen',
      icon: Icons.kitchen_outlined,
      count: 24,
      items: ['Rice', 'Pasta', 'Cereal', 'Spices', 'Olive oil', 'Tea'],
    ),
  ];

  int? _selected;

  void _pick(int i) {
    HapticFeedback.selectionClick();
    setState(() => _selected = i);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.72),
          height: 1.25,
        );

    Widget card(int i) {
      final s = _spaces[i];
      final selected = _selected == i;

      return AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: selected ? 1.02 : 1.0,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _pick(i),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: selected ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: selected ? 0.22 : 0.12)),
            ),
            child: Row(
              children: [
                Icon(s.icon, color: Colors.white.withValues(alpha: 0.92)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                  ),
                ),
                Text(
                  '${s.count}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget expanded() {
      if (_selected == null) return const SizedBox.shrink();
      final s = _spaces[_selected!];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Text('Everything is organized automatically', style: muted),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Wrap(
              key: ValueKey('space_${s.name}'),
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in s.items)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.90),
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tap a space to preview.', style: muted),
        const SizedBox(height: 14),
        card(0),
        const SizedBox(height: 10),
        card(1),
        const SizedBox(height: 10),
        card(2),
        expanded(),
        const SizedBox(height: 16),
        PrimaryGradientButton(
          onPressed: _selected == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  widget.onContinue();
                },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  final _controller = PageController();
  int _index = 0;

  late final AnimationController _introController;
  late final Animation<double> _introFade;
  late final Animation<double> _introScale;

  late final AnimationController _bg;

  late final ApiClient _api;
  bool _finishing = false;

  static const bgGradient = LinearGradient(
    colors: [
      Color(0xFF020617),
      Color(0xFF0F172A),
      Color(0xFF020617),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accent = LinearGradient(
    colors: [
      Color(0xFF5EEAD4),
      Color(0xFF60A5FA),
      Color(0xFFC084FC),
      Color(0xFFF472B6),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _introFade = CurvedAnimation(parent: _introController, curve: Curves.easeOut);
    _introScale = Tween<double>(begin: 0.992, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );
    _introController.forward();

    _bg = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);

    _api = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  }

  @override
  void dispose() {
    _introController.dispose();
    _bg.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeAndGo() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await OnboardingPrefs.setCompleted(true);
    if (!mounted) return;
    widget.onFinished?.call();
  }

  Future<void> _openScanThenComplete() async {
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanPage(
          api: _api,
          onSaved: () {},
        ),
      ),
    );
    if (!mounted) return;
    await _completeAndGo();
  }

  void _goTo(int i) {
    if (i < 0 || i > 3) return;
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _slide({
    required IconData icon,
    required String title,
    required Widget demo,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        _glassCard(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: ShaderMask(
                                  shaderCallback: (rect) => accent.createShader(rect),
                                  blendMode: BlendMode.srcIn,
                                  child: Icon(icon, size: 56, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 14),
                              demo,
                            ],
                          ),
                        ),
                      ],
                    )
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _introFade,
      child: ScaleTransition(
        scale: _introScale,
        child: Container(
          decoration: const BoxDecoration(gradient: bgGradient),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _bg,
                    builder: (context, _) {
                      final t = Curves.easeInOut.transform(_bg.value);
                      return Opacity(
                        opacity: 0.9,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(-0.4 + (0.8 * t), -0.3),
                                radius: 1.15,
                                colors: [
                                  const Color(0xFF60A5FA).withValues(alpha: 0.18),
                                  const Color(0xFFC084FC).withValues(alpha: 0.12),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.55, 1.0],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Scaffold(
                backgroundColor: Colors.transparent,
                body: SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView(
                          controller: _controller,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: (i) => setState(() => _index = i),
                          children: [
                            _slide(
                              icon: Icons.auto_awesome_rounded,
                              title: 'Meet your smart inventory',
                              demo: _MagicMomentSlide(onContinue: () => _goTo(1)),
                            ),
                            _slide(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: 'Assist demo',
                              demo: _AssistDemoSlide(onContinue: () => _goTo(2)),
                            ),
                            _slide(
                              icon: Icons.grid_view_outlined,
                              title: 'Spaces',
                              demo: _SpacesSlide(onContinue: () => _goTo(3)),
                            ),
                            _slide(
                              icon: Icons.rocket_launch_outlined,
                              title: 'Let\'s get started',
                              demo: _StartHookSlide(
                                onScan: _finishing ? null : () => unawaited(_openScanThenComplete()),
                                onSkip: _finishing ? null : () => unawaited(_completeAndGo()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 14),
                            _ProgressBar(index: _index, total: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final value = total <= 0 ? 0.0 : ((index + 1) / total).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.14),
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${index + 1}/$total',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
              ),
        ),
      ],
    );
  }
}
