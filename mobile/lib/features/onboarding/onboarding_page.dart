import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'onboarding_prefs.dart';

// ---------------------------------------------------------------------------
// Root
// ---------------------------------------------------------------------------

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageCtrl = PageController();
  int _page = 0;

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

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _page = i),
                physics: const BouncingScrollPhysics(),
                children: const [
                  _ChatPage(),
                  _ScanPage(),
                  _TeamsPage(),
                ],
              ),
            ),
            _BottomNav(
              page: _page,
              onSkip: _finish,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom nav
// ---------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.page,
    required this.onSkip,
    required this.onNext,
  });

  final int page;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Row(
        children: [
          // Skip (hidden on last page)
          SizedBox(
            width: 60,
            child: page < 2
                ? GestureDetector(
                    onTap: onSkip,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Color(0x8AFFFFFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  )
                : null,
          ),
          // Dots
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: i == page
                        ? const Color(0xFF0A84FF)
                        : const Color(0x3DFFFFFF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          // Next / Get Started
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onNext,
                child: page < 2
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0x14FFFFFF),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFF0A84FF).withValues(alpha: 0.6),
                                width: 1.0,
                              ),
                            ),
                            child: const Text(
                              'Next →',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A84FF),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 1 — AI Chat
// ---------------------------------------------------------------------------

class _ChatPage extends StatefulWidget {
  const _ChatPage();

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // 4 bubbles × 300ms each, 400ms stagger → total 1900ms
  static const _totalMs = 1900.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs.toInt()),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Animation<double> _fade(double startMs, double endMs) =>
      Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl,
        curve: Interval(startMs / _totalMs, endMs / _totalMs,
            curve: Curves.easeOut),
      ));

  Animation<Offset> _slideX(double startMs, double endMs, double dx) =>
      Tween<Offset>(begin: Offset(dx, 0), end: Offset.zero).animate(
          CurvedAnimation(
        parent: _ctrl,
        curve: Interval(startMs / _totalMs, endMs / _totalMs,
            curve: Curves.easeOut),
      ));

  Widget _bubble(Animation<double> fade, Animation<Offset> slide, String text,
      bool isUser) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Align(
          alignment:
              isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? const Color(0x1AFFFFFF)
                  : const Color(0xFF171717),
              borderRadius: isUser
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    )
                  : const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
              border: isUser
                  ? null
                  : Border.all(
                      color: const Color(0x1AFFFFFF), width: 0.5),
            ),
            child: Text(
              text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.45),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f1 = _fade(0, 300);
    final s1 = _slideX(0, 300, 0.4);
    final f2 = _fade(400, 700);
    final s2 = _slideX(400, 700, -0.4);
    final f3 = _fade(800, 1100);
    final s3 = _slideX(800, 1100, 0.4);
    final f4 = _fade(1200, 1500);
    final s4 = _slideX(1200, 1500, -0.4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ask anything.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your inventory, answered instantly.',
            style: TextStyle(
              color: Color(0x8AFFFFFF),
              fontSize: 16,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0x14FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: const Color(0x26FFFFFF), width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _bubble(f1, s1, 'Where are my ethernet cables?', true),
                      const SizedBox(height: 10),
                      _bubble(
                        f2,
                        s2,
                        'You have 5 in your Supplies space, last updated yesterday.',
                        false,
                      ),
                      const SizedBox(height: 10),
                      _bubble(f3, s3, 'Am I running low on anything?', true),
                      const SizedBox(height: 10),
                      _bubble(
                        f4,
                        s4,
                        'Your Power Strips are at Qty 1 — might be worth restocking.',
                        false,
                      ),
                      const Spacer(),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0A84FF).withValues(alpha: 0.22),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            color: Color(0xFF0A84FF),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2 — Scan & Upload
// ---------------------------------------------------------------------------

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _cardCtrl;
  Timer? _cardTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _cardTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) _cardCtrl.forward();
    });
  }

  @override
  void dispose() {
    _cardTimer?.cancel();
    _pulseCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  Widget _glassButton(String label) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF0A84FF).withValues(alpha: 0.5),
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pulseAnim = Tween<double>(begin: 0.93, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    final cardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut),
    );
    final cardSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add items instantly.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan a barcode or snap a photo —\nAI does the rest.',
            style: TextStyle(
              color: Color(0x8AFFFFFF),
              fontSize: 16,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Camera viewfinder
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0x1AFFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: const Color(0x26FFFFFF), width: 0.8),
                  ),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: pulseAnim,
                      builder: (context, _) => Transform.scale(
                        scale: pulseAnim.value,
                        child: SizedBox(
                          width: 150,
                          height: 150,
                          child: CustomPaint(painter: _DashedFramePainter()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Detected item card
          FadeTransition(
            opacity: cardFade,
            child: SlideTransition(
              position: cardSlide,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0x26FFFFFF), width: 0.8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Color(0xFF0A84FF), size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ethernet Cable Cat6 25ft',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Added to Supplies → Qty 1',
                                style: TextStyle(
                                  color: Color(0x8AFFFFFF),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _glassButton('📷  Take Photo')),
              const SizedBox(width: 10),
              Expanded(child: _glassButton('⬛  Scan Barcode')),
            ],
          ),
        ],
      ),
    );
  }
}

// Dashed teal scanning frame
class _DashedFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const teal = Color(0xFF0A84FF);
    final paint = Paint()
      ..color = teal.withValues(alpha: 0.75)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const cornerLen = 22.0;
    const r = 12.0;

    // Draw just the 4 corner L-brackets instead of a full dashed rect —
    // cleaner scanner look
    void corner(Offset origin, double sx, double sy) {
      final path = Path();
      // horizontal arm
      path.moveTo(origin.dx + sx * (r + cornerLen), origin.dy);
      path.lineTo(origin.dx + sx * r, origin.dy);
      path.arcToPoint(
        Offset(origin.dx, origin.dy + sy * r),
        radius: const Radius.circular(r),
        clockwise: sx * sy < 0,
      );
      // vertical arm
      path.lineTo(origin.dx, origin.dy + sy * (r + cornerLen));
      canvas.drawPath(path, paint);
    }

    corner(Offset(0, 0), 1, 1);
    corner(Offset(size.width, 0), -1, 1);
    corner(Offset(0, size.height), 1, -1);
    corner(Offset(size.width, size.height), -1, -1);

    // Center crosshair dot
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      3,
      Paint()..color = teal.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_DashedFramePainter old) => false;
}

// ---------------------------------------------------------------------------
// Page 3 — Team Spaces
// ---------------------------------------------------------------------------

class _TeamsPage extends StatefulWidget {
  const _TeamsPage();

  @override
  State<_TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<_TeamsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _timer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Widget _avatar(String initial, {Color? bg, List<BoxShadow>? shadows}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg ?? const Color(0x33FFFFFF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x26FFFFFF), width: 1),
        boxShadow: shadows,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, {required bool isTeal}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isTeal
                ? const Color(0xFF0A84FF).withValues(alpha: 0.1)
                : const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isTeal
                  ? const Color(0xFF0A84FF).withValues(alpha: 0.6)
                  : const Color(0x4DFFFFFF),
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isTeal ? const Color(0xFF0A84FF) : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    final slideAnim =
        Tween<Offset>(begin: const Offset(0.6, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Built for teams.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Share spaces, collaborate in real time.',
            style: TextStyle(
              color: Color(0x8AFFFFFF),
              fontSize: 16,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Space card
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: const Color(0x26FFFFFF), width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.construction_rounded,
                            color: Color(0x8AFFFFFF), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Workshop',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Avatar row
                    Row(
                      children: [
                        _avatar('T'),
                        const SizedBox(width: 8),
                        _avatar('A'),
                        const SizedBox(width: 8),
                        _avatar('R'),
                        const SizedBox(width: 8),
                        // 4th avatar slides in from the right
                        FadeTransition(
                          opacity: fadeAnim,
                          child: SlideTransition(
                            position: slideAnim,
                            child: _avatar(
                              '+1',
                              bg: const Color(0xFF0A84FF).withValues(alpha: 0.28),
                              shadows: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF0A84FF).withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        FadeTransition(
                          opacity: fadeAnim,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFF0A84FF).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    const Color(0xFF0A84FF).withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Text(
                              '+1 joined',
                              style: TextStyle(
                                color: Color(0xFF0A84FF),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '3 members · 47 items',
                      style: TextStyle(
                        color: Color(0x8AFFFFFF),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _badge('Owner', isTeal: false),
              const SizedBox(width: 10),
              _badge('Can edit', isTeal: true),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
