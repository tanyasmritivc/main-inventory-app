import 'dart:ui';

import 'package:flutter/material.dart';

import 'onboarding_prefs.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

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
  void dispose() {
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
    required String description,
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
                    const SizedBox(height: 10),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                    ),
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
    return Scaffold(
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
              description:
                  'Ask FindEZ what you own, where things are stored, and what you might be missing.',
            ),
            _slide(
              icon: Icons.center_focus_strong_outlined,
              title: 'Scan items instantly',
              description:
                  'Use your camera to scan barcodes or photos and automatically add items to your inventory.',
            ),
            _slide(
              icon: Icons.description_outlined,
              title: 'Your documents, organized',
              description:
                  'Upload manuals, receipts, and documents. FindEZ connects them to your items so everything stays organized.',
            ),
          ],
        ),
      ),
    );
  }
}

class _GetStartedButton extends StatefulWidget {
  const _GetStartedButton({required this.onPressed, required this.child});

  final VoidCallback? onPressed;
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

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
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
              onTap: widget.onPressed,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              child: Center(
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: fg, letterSpacing: 0.2),
                  child: IconTheme.merge(
                    data: IconThemeData(color: fg),
                    child: widget.child,
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
