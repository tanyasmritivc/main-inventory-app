import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ui/glass_card.dart';
import 'onboarding_prefs.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _controller = PageController();
  int _index = 0;

  late final _ChatDemoController _chatDemo;

  @override
  void initState() {
    super.initState();
    _chatDemo = _ChatDemoController()..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    _chatDemo.dispose();
    super.dispose();
  }

  void _goTo(int next) {
    if (next < 0 || next > 2) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    await OnboardingPrefs.setPostSignupPending(false);
    await OnboardingPrefs.setCompleted(true);
    if (!mounted) return;
    widget.onFinished?.call();
  }

  Widget _pageShell({required String title, required Widget child}) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (_index > 0)
                  IconButton(
                    onPressed: () => _goTo(_index - 1),
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                else
                  const SizedBox(width: 48),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _ProgressDots(index: _index, total: 3),
            const SizedBox(height: 14),
            Expanded(child: child),
            const SizedBox(height: 16),
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
                  onPressed: () {
                    if (_index < 2) return _goTo(_index + 1);
                    _finish();
                  },
                  child: Text(_index < 2 ? 'Next' : 'Start Organizing'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _slide1() {
    return _pageShell(
      title: 'Talk to your inventory',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ask things like:',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.black.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 10),
                const _BulletLine('“Do I have milk?”'),
                const _BulletLine('“Add batteries”'),
                const _BulletLine('“What’s running low?”'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(child: _ChatDemo(controller: _chatDemo)),
        ],
      ),
    );
  }

  Widget _slide2() {
    return _pageShell(
      title: 'Scan items instantly',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BulletLine('Take a photo'),
                const _BulletLine('Barcode scan'),
                const _BulletLine('AI extracts item info automatically'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: _PulsingIcon(
                icon: Icons.center_focus_strong_outlined,
                label: 'Scanning…',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slide3() {
    return _pageShell(
      title: 'Your documents, searchable',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BulletLine('Upload manuals'),
                const _BulletLine('Link documents to items'),
                const _BulletLine('Ask AI questions about them'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: _PulsingIcon(
                icon: Icons.description_outlined,
                label: 'Indexing…',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageView(
        controller: _controller,
        onPageChanged: (i) => setState(() => _index = i),
        physics: const BouncingScrollPhysics(),
        children: [_slide1(), _slide2(), _slide3()],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black.withValues(alpha: 0.85),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(
          total,
          (i) => Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: i == index
                  ? Colors.black.withValues(alpha: 0.85)
                  : Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${index + 1}/$total',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _ChatDemoController {
  _ChatDemoController();

  final ValueNotifier<int> phase = ValueNotifier<int>(0);
  Timer? _t;

  void start() {
    _t?.cancel();
    _t = Timer.periodic(const Duration(milliseconds: 950), (_) {
      phase.value = (phase.value + 1) % 6;
    });
  }

  void dispose() {
    _t?.cancel();
    phase.dispose();
  }
}

class _ChatDemo extends StatelessWidget {
  const _ChatDemo({required this.controller});

  final _ChatDemoController controller;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: ValueListenableBuilder<int>(
        valueListenable: controller.phase,
        builder: (context, p, _) {
          final showTyping = p == 1 || p == 4;
          final assistantText = p <= 2
              ? 'Yes — you have milk in your inventory.'
              : 'Low stock: batteries are running low.';
          final userText = p <= 2 ? 'Do I have milk?' : 'What’s running low?';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _Bubble(text: userText, isUser: true),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: showTyping
                      ? const _TypingBubble(key: ValueKey('typing'))
                      : _Bubble(
                          key: const ValueKey('text'),
                          text: assistantText,
                          isUser: false,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final bg = isUser
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const _TypingDots(),
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
    final base = Colors.black.withValues(alpha: 0.72);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        double dot(double phase) {
          final v = (t + phase) % 1.0;
          return 0.35 + (0.65 * (1.0 - (2.0 * (v - 0.5)).abs()));
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(opacity: dot(0.0), color: base),
            const SizedBox(width: 6),
            _Dot(opacity: dot(0.2), color: base),
            const SizedBox(width: 6),
            _Dot(opacity: dot(0.4), color: base),
          ],
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.opacity, required this.color});

  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
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
        final t = Curves.easeInOut.transform(_c.value);
        final scale = 0.96 + (0.06 * t);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 98,
                height: 98,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  size: 44,
                  color: Colors.black.withValues(alpha: 0.82),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black.withValues(alpha: 0.60),
              ),
            ),
          ],
        );
      },
    );
  }
}
