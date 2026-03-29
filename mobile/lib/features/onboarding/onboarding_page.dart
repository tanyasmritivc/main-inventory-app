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

class _AddItemInteractionSlide extends StatefulWidget {
  const _AddItemInteractionSlide();

  @override
  State<_AddItemInteractionSlide> createState() => _AddItemInteractionSlideState();
}

class _AddItemInteractionSlideState extends State<_AddItemInteractionSlide> {
  static const _suggestion = 'add 2 pencils';
  static const _assistantText = 'Added 2 pencils to your inventory.';

  late final TextEditingController _input;

  Timer? _debounce;
  Timer? _typingDelay;
  Timer? _typingTick;

  bool _showUser = false;
  bool _showAssistant = false;
  bool _assistantTyping = false;
  String _userText = '';
  String _assistantSoFar = '';

  @override
  void initState() {
    super.initState();
    _input = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _typingDelay?.cancel();
    _typingTick?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _startDemo(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _typingDelay?.cancel();
    _typingTick?.cancel();

    setState(() {
      _userText = trimmed;
      _showUser = true;
      _showAssistant = true;
      _assistantTyping = true;
      _assistantSoFar = '';
    });

    _typingDelay = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _assistantTyping = false;
        _assistantSoFar = '';
      });
      var i = 0;
      _typingTick = Timer.periodic(const Duration(milliseconds: 24), (t) {
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

  Widget _suggestionChip() {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          _input.text = _suggestion;
          _input.selection = TextSelection.fromPosition(
            TextPosition(offset: _input.text.length),
          );
          _startDemo(_suggestion);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Text(
            'Try typing: $_suggestion',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _input,
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 420), () {
              if (!mounted) return;
              _startDemo(v);
            });
          },
          onSubmitted: _startDemo,
          decoration: const InputDecoration(
            hintText: 'Try typing: add 2 pencils',
            prefixIcon: Icon(Icons.add_rounded),
          ),
        ),
        const SizedBox(height: 12),
        _suggestionChip(),
        const SizedBox(height: 14),
        Flexible(
          fit: FlexFit.loose,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.98, end: 1.0).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: !_showUser
                    ? const SizedBox.shrink()
                    : _ChatBubble(
                        key: const ValueKey('user'),
                        text: _userText,
                        isUser: true,
                      ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.98, end: 1.0).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: !_showAssistant
                    ? const SizedBox.shrink()
                    : _ChatBubble(
                        key: const ValueKey('assistant'),
                        text: _assistantSoFar,
                        isUser: false,
                        child: _assistantTyping
                            ? const _TypingDots()
                            : Text(
                                _assistantSoFar,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.92),
                                      height: 1.25,
                                    ),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FindItemsInteractionSlide extends StatefulWidget {
  const _FindItemsInteractionSlide();

  @override
  State<_FindItemsInteractionSlide> createState() => _FindItemsInteractionSlideState();
}

class _FindItemsInteractionSlideState extends State<_FindItemsInteractionSlide> {
  static const _question = 'Where are my cables?';
  static const _assistantText = 'You have cables in the office.';

  Timer? _typingDelay;
  Timer? _typingTick;
  bool _show = false;
  bool _assistantTyping = false;
  String _assistantSoFar = '';

  @override
  void dispose() {
    _typingDelay?.cancel();
    _typingTick?.cancel();
    super.dispose();
  }

  void _run() {
    _typingDelay?.cancel();
    _typingTick?.cancel();

    setState(() {
      _show = true;
      _assistantTyping = true;
      _assistantSoFar = '';
    });

    _typingDelay = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _assistantTyping = false;
        _assistantSoFar = '';
      });
      var i = 0;
      _typingTick = Timer.periodic(const Duration(milliseconds: 24), (t) {
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

  Widget _mockInventory() {
    Widget row(String name, String location) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 18,
              color: Colors.white.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.90),
                    ),
              ),
            ),
            Text(
              location,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.60),
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row('Cables', 'Office'),
        const SizedBox(height: 10),
        row('Batteries', 'Drawer'),
        const SizedBox(height: 10),
        row('Pencils', 'Desk'),
      ],
    );
  }

  Widget _questionChip() {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _run,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Text(
            _question,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _mockInventory(),
        const SizedBox(height: 14),
        _questionChip(),
        const SizedBox(height: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.98, end: 1.0).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: !_show
                    ? const SizedBox.shrink()
                    : _ChatBubble(
                        key: const ValueKey('find_user'),
                        text: _question,
                        isUser: true,
                      ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.98, end: 1.0).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: !_show
                    ? const SizedBox.shrink()
                    : _ChatBubble(
                        key: const ValueKey('find_assistant'),
                        text: _assistantSoFar,
                        isUser: false,
                        child: _assistantTyping
                            ? const _TypingDots()
                            : Text(
                                _assistantSoFar,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.92),
                                      height: 1.25,
                                    ),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScanSimulationSlide extends StatefulWidget {
  const _ScanSimulationSlide();

  @override
  State<_ScanSimulationSlide> createState() => _ScanSimulationSlideState();
}

class _ScanSimulationSlideState extends State<_ScanSimulationSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanLine;
  Timer? _doneTimer;
  bool _scanning = false;
  bool _detected = false;

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
    _doneTimer?.cancel();
    _scanLine.dispose();
    super.dispose();
  }

  void _startScan() {
    if (_scanning) return;
    _doneTimer?.cancel();
    setState(() {
      _scanning = true;
      _detected = false;
    });
    _scanLine.repeat();
    _doneTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _scanLine.stop();
      setState(() {
        _scanning = false;
        _detected = true;
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

  Widget _detectedCard() {
    return AnimatedSlide(
      offset: _detected ? Offset.zero : const Offset(0, 0.08),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _detected ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: Container(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              if (_scanning) _scanLineWidget(),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: FilledButton(
                  onPressed: _startScan,
                  child: Text(_scanning ? 'Scanning…' : 'Scan'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _detectedCard(),
      ],
    );
  }
}

class _NotesInteractionSlide extends StatefulWidget {
  const _NotesInteractionSlide();

  @override
  State<_NotesInteractionSlide> createState() => _NotesInteractionSlideState();
}

class _NotesInteractionSlideState extends State<_NotesInteractionSlide> {
  late final TextEditingController _noteController;
  bool _editing = false;
  bool _saving = false;
  final List<String> _notes = <String>[];
  bool _animateNewest = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final text = _noteController.text.trim();
    if (text.isEmpty) return;

    if (!mounted) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    setState(() {
      _notes.insert(0, text);
      _noteController.clear();
      _saving = false;
      _editing = false;
      _animateNewest = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _animateNewest = false);
    });
  }

  Widget _noteRow(String text, {required bool animateIn}) {
    return AnimatedSlide(
      offset: animateIn ? const Offset(0, 0.08) : Offset.zero,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.note_outlined,
              size: 18,
              color: Colors.white.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.90),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: _saving
              ? null
              : () {
                  setState(() => _editing = true);
                },
          child: const Text('New Note'),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) {
            return FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1.0).animate(anim),
                child: child,
              ),
            );
          },
          child: !_editing
              ? const SizedBox.shrink()
              : Column(
                  key: const ValueKey('editor'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _noteController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Type a note…',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save'),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _notes.isEmpty
                ? Center(
                    child: Text(
                      'Your notes will show up here.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.70),
                          ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _notes.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final animateIn = i == 0 && _animateNewest;
                      return _noteRow(_notes[i], animateIn: animateIn);
                    },
                  ),
          ),
        ),
      ],
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
    if (i < 0 || i > 4) return;
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
          _ProgressBar(index: _index, total: 5),
          const SizedBox(height: 16),
          if (_index < 4)
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
              child: const Text('Start organizing'),
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
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Add items by typing',
                  demo: const _AddItemInteractionSlide(),
                ),
                _slide(
                  icon: Icons.search_rounded,
                  title: 'Find things fast',
                  demo: const _FindItemsInteractionSlide(),
                ),
                _slide(
                  icon: Icons.center_focus_strong_outlined,
                  title: 'Scan to detect items',
                  demo: const _ScanSimulationSlide(),
                ),
                _slide(
                  icon: Icons.note_alt_outlined,
                  title: 'Keep notes with your docs',
                  demo: const _NotesInteractionSlide(),
                ),
                _slide(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Ready to organize?',
                  demo: Center(
                    child: Text(
                      'Start organizing in seconds.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                            height: 1.25,
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

class _GetStartedButtonState extends State<_GetStartedButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  bool _submitting = false;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !_submitting;
    final fg = enabled ? Colors.white : Colors.white.withValues(alpha: 0.55);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        final pulseScale = enabled ? (1.0 + (0.012 * t)) : 1.0;
        final pressScale = _pressed && enabled ? 0.985 : 1.0;
        return Transform.scale(
          scale: pulseScale * pressScale,
          child: child,
        );
      },
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
                      if (!mounted) return;
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
