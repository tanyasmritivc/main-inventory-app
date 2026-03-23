import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'onboarding_prefs.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _ChatDemoSlide extends StatefulWidget {
  const _ChatDemoSlide();

  @override
  State<_ChatDemoSlide> createState() => _ChatDemoSlideState();
}

class _ChatDemoSlideState extends State<_ChatDemoSlide>
    with SingleTickerProviderStateMixin {
  static const _userText = 'Do I have milk?';
  static const _assistantText = 'You have 2 cartons in the fridge.';

  late final AnimationController _dots;

  Timer? _t1;
  Timer? _t2;
  Timer? _typingTick;

  bool _showAssistant = false;
  bool _assistantTyping = false;
  String _assistantSoFar = '';

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _t1 = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _assistantTyping = true;
        _showAssistant = true;
      });
    });

    _t2 = Timer(const Duration(milliseconds: 950), () {
      if (!mounted) return;
      setState(() {
        _assistantTyping = false;
        _assistantSoFar = '';
      });
      var i = 0;
      _typingTick = Timer.periodic(const Duration(milliseconds: 28), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        i++;
        final next = _assistantText.substring(0, i.clamp(0, _assistantText.length));
        setState(() => _assistantSoFar = next);
        if (i >= _assistantText.length) {
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _t1?.cancel();
    _t2?.cancel();
    _typingTick?.cancel();
    _dots.dispose();
    super.dispose();
  }

  Widget _bubble({required String text, required bool isUser, Widget? child}) {
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
        constraints: const BoxConstraints(maxWidth: 320),
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

  Widget _typingDots() {
    return AnimatedBuilder(
      animation: _dots,
      builder: (context, _) {
        final t = _dots.value;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _bubble(text: _userText, isUser: true),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: !_showAssistant
              ? const SizedBox.shrink()
              : _bubble(
                  text: _assistantSoFar,
                  isUser: false,
                  child: _assistantTyping
                      ? _typingDots()
                      : Text(
                          _assistantSoFar,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                height: 1.25,
                              ),
                        ),
                ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                'Try it',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanDemoSlide extends StatefulWidget {
  const _ScanDemoSlide();

  @override
  State<_ScanDemoSlide> createState() => _ScanDemoSlideState();
}

class _ScanDemoSlideState extends State<_ScanDemoSlide> {
  Timer? _t;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: !_done
          ? Row(
              key: const ValueKey('loading'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Scanning…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                ),
              ],
            )
          : Container(
              key: const ValueKey('result'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Cereal',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Location: Pantry',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DocsDemoSlide extends StatefulWidget {
  const _DocsDemoSlide();

  @override
  State<_DocsDemoSlide> createState() => _DocsDemoSlideState();
}

class _DocsDemoSlideState extends State<_DocsDemoSlide> {
  Timer? _t;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _show ? 1 : 0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              color: Colors.white.withValues(alpha: 0.80),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Receipt.pdf → Linked to ‘TV’',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  final _controller = PageController();
  int _index = 0;

  late final AnimationController _introController;
  late final Animation<double> _introFade;
  late final Animation<double> _introScale;

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
  }

  @override
  void dispose() {
    _introController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeAndGo() async {
    await OnboardingPrefs.setCompleted(true);
    if (!mounted) return;
    widget.onFinished?.call();
  }

  void _goTo(int i) {
    if (i < 0 || i > 2) return;
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: _glassCard(
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
            ),
          ),
          const SizedBox(height: 14),
          _PageDots(index: _index, total: 3),
          const SizedBox(height: 16),
          if (_index < 2)
            Row(
              children: [
                if (_index > 0)
                  OutlinedButton(
                    onPressed: () => _goTo(_index - 1),
                    child: const Text('Back'),
                  )
                else
                  const SizedBox.shrink(),
                const Spacer(),
                FilledButton(
                  onPressed: () => _goTo(_index + 1),
                  child: const Text('Next'),
                ),
              ],
            )
          else
            _GetStartedButton(
              onPressed: _completeAndGo,
              child: const Text('Get Started'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _introFade,
      child: ScaleTransition(
        scale: _introScale,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: const BoxDecoration(gradient: bgGradient),
            child: PageView(
              controller: _controller,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                _slide(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Talk to your inventory',
                  demo: const _ChatDemoSlide(),
                ),
                _slide(
                  icon: Icons.center_focus_strong_outlined,
                  title: 'Scan items instantly',
                  demo: const _ScanDemoSlide(),
                ),
                _slide(
                  icon: Icons.description_outlined,
                  title: 'Your documents, organized',
                  demo: const _DocsDemoSlide(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GetStartedButton extends StatefulWidget {
  const _GetStartedButton({required this.onPressed, required this.child});

  final Future<void> Function()? onPressed;
  final Widget child;

  static const _gradient = LinearGradient(
    colors: [
      Color(0xFF5EEAD4),
      Color(0xFF60A5FA),
      Color(0xFFC084FC),
      Color(0xFFF472B6),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  State<_GetStartedButton> createState() => _GetStartedButtonState();
}

class _GetStartedButtonState extends State<_GetStartedButton> {
  bool _pressed = false;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !_submitting;
    final fg = enabled ? Colors.white : Colors.white.withValues(alpha: 0.55);

    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      scale: _pressed && enabled ? 0.985 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            height: 54,
            decoration: BoxDecoration(
              color: enabled ? Colors.transparent : Colors.white.withValues(alpha: 0.06),
              gradient: enabled ? _GetStartedButton._gradient : null,
              borderRadius: BorderRadius.circular(18),
            ),
            child: InkWell(
              onTap: enabled
                  ? () async {
                      setState(() => _submitting = true);
                      try {
                        await widget.onPressed?.call();
                      } finally {
                        if (mounted) setState(() => _submitting = false);
                      }
                    }
                  : null,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              child: Center(
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: fg, letterSpacing: 0.2),
                  child: IconTheme.merge(
                    data: IconThemeData(color: fg),
                    child: _submitting
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text('Get Started'),
                            ],
                          )
                        : widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        total,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: i == index ? 18 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: i == index
                ? Colors.white.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
