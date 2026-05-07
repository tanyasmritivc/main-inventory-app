import 'dart:async';

import 'package:flutter/material.dart';

import 'onboarding_prefs.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  late final PageController _pageCtrl;
  int _page = 0;

  /// Page 1 — phone mock + item rows + checkmark (looping)
  late final AnimationController _c1;

  /// Page 2 — chat bubbles
  late final AnimationController _c2;

  /// Page 3 — insight cards
  late final AnimationController _c3;

  Timer? _loopTimer;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();

    _c1 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    _c2 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500));
    _c3 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));

    _c1.addStatusListener((s) {
      if (s == AnimationStatus.completed && _page == 0 && mounted) {
        _loopTimer?.cancel();
        _loopTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && _page == 0) _c1.forward(from: 0);
        });
      }
    });

    _c1.forward();
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    _loopTimer?.cancel();
    setState(() => _page = i);
    if (i == 0) _c1.forward(from: 0);
    if (i == 1) _c2.forward(from: 0);
    if (i == 2) _c3.forward(from: 0);
  }

  Future<void> _finish() async {
    await OnboardingPrefs.setPostSignupPending(false);
    await OnboardingPrefs.setCompleted(true);
    if (!mounted) return;
    widget.onFinished?.call();
  }

  void _next() {
    if (_page < 2) {
      _pageCtrl.animateToPage(
        _page + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? Colors.white : const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  PageView(
                    controller: _pageCtrl,
                    onPageChanged: _onPageChanged,
                    children: [
                      _Page1(ctrl: _c1),
                      _Page2(ctrl: _c2),
                      _Page3(ctrl: _c3),
                    ],
                  ),
                  if (_page < 2)
                    Positioned(
                      top: 8,
                      right: 16,
                      child: TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0x59FFFFFF),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDots(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: TextButton(
                      onPressed: _next,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _page < 2 ? 'Continue' : 'Get started',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 1 — "Everything you own, organized automatically."
// ---------------------------------------------------------------------------

class _Page1 extends StatelessWidget {
  const _Page1({required this.ctrl});

  final AnimationController ctrl;

  Animation<double> _f(double i0, double i1) =>
      Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: ctrl, curve: Interval(i0, i1, curve: Curves.easeOut)),
      );

  Animation<Offset> _sy(double i0, double i1) =>
      Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(
            parent: ctrl, curve: Interval(i0, i1, curve: Curves.easeOut)),
      );

  @override
  Widget build(BuildContext context) {
    final f1 = _f(0.15, 0.35);
    final s1 = _sy(0.15, 0.35);
    final f2 = _f(0.35, 0.55);
    final s2 = _sy(0.35, 0.55);
    final f3 = _f(0.55, 0.75);
    final s3 = _sy(0.55, 0.75);
    final ckFade = _f(0.75, 0.92);
    final ckScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: ctrl,
          curve: const Interval(0.75, 0.95, curve: Curves.elasticOut)),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: SizedBox(
                width: 204,
                height: 372,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _PhonePainter()),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 46, 10, 38),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _itemRow(f1, s1, 'Kirkland Nut Bars', 'Food'),
                          const SizedBox(height: 7),
                          _itemRow(f2, s2, 'Machine Screws', 'Supplies'),
                          const SizedBox(height: 7),
                          _itemRow(f3, s3, 'The Stranger', 'Books'),
                        ],
                      ),
                    ),
                    Center(
                      child: FadeTransition(
                        opacity: ckFade,
                        child: ScaleTransition(
                          scale: ckScale,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_outline_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Text(
            'Everything you own,\norganized automatically.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Just scan or photograph anything. FindEZ identifies it, names it, and files it away — no manual entry.',
            style: TextStyle(
              color: Color(0x73FFFFFF),
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _itemRow(
    Animation<double> fade,
    Animation<Offset> slide,
    String name,
    String cat,
  ) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0x33FFFFFF),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  cat,
                  style: const TextStyle(
                    color: Color(0x73FFFFFF),
                    fontSize: 9,
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

// ---------------------------------------------------------------------------
// Page 2 — "Just ask. Your AI knows the answer."
// ---------------------------------------------------------------------------

class _Page2 extends StatelessWidget {
  const _Page2({required this.ctrl});

  final AnimationController ctrl;

  Animation<double> _f(double i0, double i1) =>
      Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: ctrl, curve: Interval(i0, i1, curve: Curves.easeOut)),
      );

  Animation<Offset> _sx(double i0, double i1, double dx) =>
      Tween<Offset>(begin: Offset(dx, 0), end: Offset.zero).animate(
        CurvedAnimation(
            parent: ctrl, curve: Interval(i0, i1, curve: Curves.easeOut)),
      );

  @override
  Widget build(BuildContext context) {
    final f1 = _f(0.11, 0.26);
    final s1 = _sx(0.11, 0.26, 1.0);
    final f2 = _f(0.34, 0.49);
    final s2 = _sx(0.34, 0.49, -1.0);
    final f3 = _f(0.63, 0.77);
    final s3 = _sx(0.63, 0.77, 1.0);
    final f4 = _f(0.86, 1.0);
    final s4 = _sx(0.86, 1.0, -1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _bubble(f1, s1, 'Do I have any AA batteries?', true),
                const SizedBox(height: 10),
                _bubble(f2, s2,
                    'Yes — you have 2 packs of Duracell AA in the Garage.',
                    false),
                const SizedBox(height: 10),
                _bubble(f3, s3, 'What\'s running low?', true),
                const SizedBox(height: 10),
                _bubble(
                    f4,
                    s4,
                    '3 items are low:\nDish soap · Kitchen\nPaper towels · Garage\nCoffee · Office',
                    false),
              ],
            ),
          ),
          const Text(
            'Just ask.\nYour AI knows the answer.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Ask in plain English. FindEZ searches your entire inventory instantly and responds like it knows your home.',
            style: TextStyle(
              color: Color(0x73FFFFFF),
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _bubble(
    Animation<double> fade,
    Animation<Offset> slide,
    String text,
    bool isUser,
  ) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Align(
          alignment:
              isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? const Color(0x1AFFFFFF)
                  : const Color(0x0AFFFFFF),
              borderRadius: isUser
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    )
                  : const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
              border: isUser
                  ? null
                  : Border.all(
                      color: const Color(0x14FFFFFF), width: 0.5),
            ),
            child: Text(
              text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 3 — "Proactive. Not just reactive."
// ---------------------------------------------------------------------------

class _Page3 extends StatelessWidget {
  const _Page3({required this.ctrl});

  final AnimationController ctrl;

  Animation<double> _f(double i0, double i1) =>
      Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: ctrl, curve: Interval(i0, i1, curve: Curves.easeOut)),
      );

  Animation<Offset> _sy(double i0, double i1) =>
      Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(
            parent: ctrl, curve: Interval(i0, i1, curve: Curves.easeOut)),
      );

  @override
  Widget build(BuildContext context) {
    final f1 = _f(0.18, 0.47);
    final s1 = _sy(0.18, 0.47);
    final f2 = _f(0.41, 0.71);
    final s2 = _sy(0.41, 0.71);
    final f3 = _f(0.65, 0.94);
    final s3 = _sy(0.65, 0.94);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _card(
                  f1,
                  s1,
                  Icons.warning_amber_outlined,
                  'Low stock alert',
                  'You\'re almost out of coffee. You usually restock every 3 weeks.',
                ),
                const SizedBox(height: 10),
                _card(
                  f2,
                  s2,
                  Icons.content_copy_outlined,
                  'Duplicate detected',
                  'You have 2 entries for \'White thermos\'. Want to merge them?',
                ),
                const SizedBox(height: 10),
                _card(
                  f3,
                  s3,
                  Icons.lightbulb_outline,
                  'Smart suggestion',
                  'Based on your garage items, you might need more storage bins.',
                ),
              ],
            ),
          ),
          const Text(
            'Proactive.\nNot just reactive.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'FindEZ notices patterns, spots duplicates, and reminds you before you run out — without you asking.',
            style: TextStyle(
              color: Color(0x73FFFFFF),
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _card(
    Animation<double> fade,
    Animation<Offset> slide,
    IconData icon,
    String title,
    String body,
  ) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: const TextStyle(
                        color: Color(0x73FFFFFF),
                        fontSize: 13,
                        height: 1.4,
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
}

// ---------------------------------------------------------------------------
// Phone outline painter (Page 1)
// ---------------------------------------------------------------------------

class _PhonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = const Color(0x4DFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(28),
      ),
      border,
    );

    final fill = Paint()
      ..color = const Color(0x26FFFFFF)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width / 2 - 18, 14, 36, 4),
        const Radius.circular(2),
      ),
      fill,
    );
  }

  @override
  bool shouldRepaint(_PhonePainter old) => false;
}

