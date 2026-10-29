import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_page.dart';
import 'onboarding_v5_store.dart';

const _ink = Color(0xFF0B0B0C);
const _secondary = Color(0xFF5E5F64);
const _tertiary = Color(0xFF9A9BA0);
const _line = Color(0xFFECEBE8);
const _soft = Color(0xFFF5F4F1);
const onboardingCurve = Cubic(.32, .72, 0, 1);

class _Choice {
  const _Choice(this.value, this.title, [this.subtitle, this.icon]);
  final String value, title;
  final String? subtitle;
  final IconData? icon;
}

const _keys = ['use_case', 'used_by', 'main_need', 'heard_from'];
const _titles = [
  'What are you organizing?',
  'Who will use FindEZ?',
  'What should FindEZ help with most?',
  'How did you hear about FindEZ?',
];
const _subtitles = [
  'FindEZ sets up the first space for it.',
  'Sharing is set up to match.',
  'Pick the one that matters most right now.',
  'This helps a small team know what works.',
];
const _labels = ['Organizing', 'Used by', 'Main need', 'Heard from'];
const _choices = [
  [
    _Choice('home', 'Home', 'Closets, garage, kitchen', Icons.home_outlined),
    _Choice(
      'workshop',
      'Workshop or garage',
      'Tools, parts, bins',
      Icons.build_outlined,
    ),
    _Choice(
      'robotics',
      'Robotics team',
      'Parts, kits, pit cart',
      Icons.precision_manufacturing_outlined,
    ),
    _Choice(
      'lab',
      'Lab or classroom',
      'Equipment and supplies',
      Icons.science_outlined,
    ),
    _Choice(
      'business',
      'Business',
      'Stock, supplies, assets',
      Icons.inventory_2_outlined,
    ),
  ],
  [
    _Choice('solo', 'Just me', 'A private inventory', Icons.person_outline),
    _Choice(
      'household',
      'Me and my household',
      'Family or roommates',
      Icons.home_outlined,
    ),
    _Choice(
      'team',
      'A team or class',
      'A club, lab, class or robotics team',
      Icons.people_outline,
    ),
    _Choice(
      'org',
      'A company or organization',
      'Shared across departments or sites',
      Icons.inventory_2_outlined,
    ),
  ],
  [
    _Choice('find', 'Finding things when I need them'),
    _Choice('counts', 'Knowing what is running low'),
    _Choice('shared', 'Keeping track of shared or borrowed items'),
    _Choice('dupes', 'Buying things I already own'),
    _Choice('setup', 'Getting started from scratch'),
  ],
  [
    _Choice('instagram', 'Instagram'),
    _Choice('tiktok', 'TikTok'),
    _Choice('appstore', 'App Store'),
    _Choice('friend', 'Friend or teammate'),
    _Choice('first', 'FIRST or robotics community'),
    _Choice('search', 'Search'),
    _Choice('other', 'Other'),
  ],
];

/// One persistent composition: only the content layers change, never routes.
class OnboardingV5Page extends StatefulWidget {
  const OnboardingV5Page({super.key, required this.onFinished, this.store});
  final VoidCallback onFinished;
  final OnboardingV5Store? store;
  @override
  State<OnboardingV5Page> createState() => _OnboardingV5PageState();
}

class _OnboardingV5PageState extends State<OnboardingV5Page>
    with SingleTickerProviderStateMixin {
  late final _store = widget.store ?? OnboardingV5Store();
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
    value: 1,
  );
  StreamSubscription<AuthState>? _auth;
  Timer? _hold;
  Map<String, dynamic> _answers = {};
  int _step = 0;
  int _answerEpoch = 0;
  String? _authMethod;
  String? _activeAuthUser;
  int _authEpoch = 0;
  int? _oldStep;
  bool _ready = false,
      _selecting = false,
      _existingSignIn = false,
      _finishing = false;
  bool _saved = true;
  String? _saveError;
  bool get _reduced =>
      MediaQuery.of(context).disableAnimations ||
      MediaQuery.of(context).accessibleNavigation;

  @override
  void initState() {
    super.initState();
    _load();
    _auth = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        final user = state.session?.user;
        if (user != null && !user.isAnonymous) {
          if (_finishing && _activeAuthUser != user.id) {
            _authEpoch++;
            _finishing = false;
          }
          unawaited(_authenticated(user));
        } else if (_finishing) {
          _authEpoch++;
          _finishing = false;
          _activeAuthUser = null;
          if (mounted) _go(0);
        }
      },
      onError: (Object _) {
        /* AuthPage presents actionable auth errors. */
      },
    );
  }

  Future<void> _load() async {
    final answers = await _store.read();
    if (!mounted) return;
    setState(() {
      _answers = answers;
      _ready = true;
    });
  }

  Future<void> _authenticated(User user) async {
    if (_finishing) return;
    _finishing = true;
    _activeAuthUser = user.id;
    final epoch = ++_authEpoch;
    bool isCurrent() =>
        mounted &&
        epoch == _authEpoch &&
        Supabase.instance.client.auth.currentUser?.id == user.id;
    if (_existingSignIn) {
      widget.onFinished();
      return;
    }
    try {
      final bound = await _store.bind(user);
      if (!isCurrent()) return;
      if (!bound) {
        await _store.discard();
        if (isCurrent()) widget.onFinished();
        return;
      }
      final method = await _store
          .sync(Supabase.instance.client)
          .timeout(const Duration(seconds: 15));
      if (method != null) {
        onboardingEvent('onboarding_completed', {'auth_method': method});
      }
    } catch (_) {
      _saved = false; // Keep the owner-bound receipt and be honest about retry.
    }
    if (!isCurrent()) return;
    _go(6);
    await Future<void>.delayed(const Duration(milliseconds: 2700));
    if (isCurrent()) widget.onFinished();
  }

  void _go(int step) {
    _hold?.cancel();
    _answerEpoch++;
    _selecting = false;
    if (step == 5) onboardingEvent('onboarding_signup_shown');
    setState(() {
      _oldStep = _reduced ? null : _step;
      _step = step;
      _saveError = null;
    });
    if (_reduced) {
      _motion.value = 1;
    } else {
      _motion.forward(from: 0);
    }
  }

  Future<void> _answer(String? value) async {
    if (_selecting || _motion.isAnimating || _step < 1 || _step > 4) return;
    final question = _step - 1;
    final epoch = ++_answerEpoch;
    final updated = {..._answers, _keys[question]: value, 'completed_at': null};
    setState(() {
      _selecting = true;
      _answers = updated;
      _saveError = null;
    });
    try {
      await _store.save(updated);
      onboardingEvent('onboarding_answer', {
        'question': _keys[question],
        'value': value ?? 'skipped',
      });
      if (!mounted || epoch != _answerEpoch) return;
      if (value == null || _reduced) {
        _go(_step + 1);
      } else {
        _hold = Timer(const Duration(milliseconds: 650), () {
          if (mounted) _go(_step + 1);
        });
      }
    } catch (_) {
      if (mounted && epoch == _answerEpoch) {
        setState(() {
          _selecting = false;
          _saveError = 'Your answer could not be saved. Please try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    _auth?.cancel();
    _motion.dispose();
    super.dispose();
  }

  Text _text(
    String value, {
    double size = 15,
    Color color = _ink,
    FontWeight weight = FontWeight.w400,
    TextAlign? align,
  }) => Text(
    value,
    textAlign: align,
    style: TextStyle(
      fontFamily: 'CupertinoSystemText',
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: size >= 32
          ? 1.08
          : size >= 26
          ? 1.14
          : 1.32,
      letterSpacing: size >= 26 ? -.9 : -.15,
    ),
  );

  Widget _animated(
    Widget child,
    int index,
    bool leaving, {
    bool pills = false,
  }) {
    if (_reduced) return child;
    return AnimatedBuilder(
      animation: _motion,
      child: child,
      builder: (_, child) {
        final elapsed = _motion.value * 1200;
        final delay = leaving ? index * 18 : 200 + index * (pills ? 35 : 55);
        final t = ((elapsed - delay) / (leaving ? 340 : 680)).clamp(0.0, 1.0);
        final eased = onboardingCurve.transform(t);
        final opacity = leaving ? 1 - eased : eased;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, leaving ? -10 * eased : 14 * (1 - eased)),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: leaving ? 4 * eased : 6 * (1 - eased),
                sigmaY: leaving ? 4 * eased : 6 * (1 - eased),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _button(
    String title,
    VoidCallback? action, {
    bool black = false,
    Widget? icon,
    bool busy = false,
  }) => SizedBox(
    width: double.infinity,
    height: math.max(54, MediaQuery.textScalerOf(context).scale(15) * 2 + 20),
    child: OutlinedButton(
      onPressed: action,
      style: OutlinedButton.styleFrom(
        backgroundColor: black ? _ink : Colors.white,
        foregroundColor: black ? Colors.white : _ink,
        disabledForegroundColor: black ? Colors.white : _ink,
        side: BorderSide(color: black ? _ink : _line),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'CupertinoSystemText',
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon, const SizedBox(width: 9)],
              Flexible(child: Text(title, textAlign: TextAlign.center)),
            ],
          ),
          Positioned(
            right: 0,
            child: AnimatedOpacity(
              opacity: busy ? 1 : 0,
              duration: Duration(milliseconds: _reduced ? 0 : 180),
              child: SizedBox(
                width: 16,
                height: 16,
                child: busy
                    ? CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: black ? Colors.white : _ink,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _header(AuthPresentation auth) => Positioned(
    top: 6,
    left: 20,
    right: 20,
    child: SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton.filled(
              tooltip: 'Back',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _ink,
              ),
              onPressed: auth.busy || _finishing
                  ? null
                  : () {
                      if (auth.showEmail) {
                        auth.closeEmail();
                      } else if (!_motion.isAnimating) {
                        _go(_step - 1);
                      }
                    },
              icon: const Icon(Icons.chevron_left, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (_step.clamp(1, 4)) / 4),
              duration: Duration(milliseconds: _reduced ? 0 : 800),
              curve: onboardingCurve,
              builder: (_, value, _) => Semantics(
                label: 'Setup progress',
                value: '${(value * 100).round()} percent',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 3,
                    color: _ink,
                    backgroundColor: _line,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 44,
            child: _step <= 4
                ? TextButton(
                    onPressed: _selecting || _motion.isAnimating
                        ? null
                        : () => _answer(null),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: _secondary,
                    ),
                    child: const Text('Skip'),
                  )
                : null,
          ),
        ],
      ),
    ),
  );

  Widget _choice(_Choice choice, int question) {
    final selected = _answers[_keys[question]] == choice.value;
    final other = _answers[_keys[question]] != null && !selected;
    final pills = question == 3;
    return AnimatedOpacity(
      opacity: other ? .4 : 1,
      duration: Duration(milliseconds: _reduced ? 0 : 250),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _selecting ? null : () => _answer(choice.value),
            borderRadius: BorderRadius.circular(pills ? 99 : 18),
            child: AnimatedContainer(
              duration: Duration(milliseconds: _reduced ? 0 : 250),
              curve: onboardingCurve,
              padding: EdgeInsets.symmetric(
                horizontal: pills ? 16 : 14,
                vertical: pills
                    ? 12
                    : choice.icon == null
                    ? 14
                    : 12,
              ),
              decoration: BoxDecoration(
                color: pills && selected ? _ink : Colors.white,
                border: Border.all(
                  color: selected ? _ink : _line,
                  width: selected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(pills ? 99 : 18),
              ),
              child: pills
                  ? _text(
                      choice.title,
                      size: 14,
                      color: selected ? Colors.white : _ink,
                      weight: FontWeight.w500,
                    )
                  : Row(
                      children: [
                        if (choice.icon != null) ...[
                          AnimatedContainer(
                            duration: Duration(
                              milliseconds: _reduced ? 0 : 250,
                            ),
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: selected ? _ink : _soft,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              choice.icon,
                              size: 20,
                              color: selected ? Colors.white : _ink,
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _text(
                                choice.title,
                                size: 15.5,
                                weight: FontWeight.w500,
                              ),
                              if (choice.subtitle != null) ...[
                                const SizedBox(height: 3),
                                _text(
                                  choice.subtitle!,
                                  size: 13,
                                  color: _secondary,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _DrawnCheck(
                          selected: selected,
                          reduced: _reduced,
                          size: 22,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(
    int step,
    bool leaving,
    AuthPresentation auth,
    double height,
  ) {
    Widget motion(Widget w, int i, {bool pills = false}) =>
        _animated(w, i, leaving, pills: pills);
    if (step == 0) {
      return LayoutBuilder(
        builder: (_, bounds) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: bounds.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
                child: Column(
                  children: [
                    const Spacer(flex: 4),
                    motion(
                      _text(
                        'Memory for\nphysical things.',
                        size: 34,
                        weight: FontWeight.w500,
                        align: TextAlign.center,
                      ),
                      0,
                    ),
                    const SizedBox(height: 16),
                    motion(
                      _text(
                        'A few quick questions, then FindEZ is set up for you.',
                        size: 15.5,
                        color: _secondary,
                        align: TextAlign.center,
                      ),
                      1,
                    ),
                    const Spacer(flex: 5),
                    const SizedBox(height: 36),
                    motion(
                      _button(
                        'Get started',
                        !_ready
                            ? null
                            : () {
                                onboardingEvent('onboarding_started');
                                _go(1);
                              },
                        black: true,
                      ),
                      2,
                    ),
                    const SizedBox(height: 14),
                    motion(
                      _text(
                        'Takes about 20 seconds.',
                        size: 12,
                        color: _tertiary,
                      ),
                      3,
                    ),
                    motion(
                      TextButton(
                        onPressed: () async {
                          await _store.discard();
                          if (mounted) {
                            setState(() {
                              _answers = {};
                              _existingSignIn = true;
                            });
                          }
                        },
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontFamily: 'CupertinoSystemText',
                              fontSize: 13,
                              color: _secondary,
                            ),
                            children: const [
                              TextSpan(text: 'Already have an account? '),
                              TextSpan(
                                text: 'Sign in',
                                style: TextStyle(
                                  color: _ink,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (step == 6) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              motion(
                _DrawnCheck(selected: true, reduced: _reduced, size: 56),
                0,
              ),
              const SizedBox(height: 18),
              motion(
                _text(
                  "You're all set",
                  size: 26,
                  weight: FontWeight.w500,
                  align: TextAlign.center,
                ),
                1,
              ),
              const SizedBox(height: 24),
              motion(
                _text(
                  _saved
                      ? 'Account created. Your answers were saved to it.'
                      : "Account created. Your answers are saved on this device. We'll retry saving them to your account next time.",
                  size: 15.5,
                  color: _secondary,
                  align: TextAlign.center,
                ),
                2,
              ),
            ],
          ),
        ),
      );
    }
    final signup = step == 5;
    final question = step - 1;
    final title = signup ? 'Create your account' : _titles[question];
    final subtitle = signup
        ? 'Your answers are saved to it.'
        : _subtitles[question];
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        motion(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Semantics(
              header: true,
              child: _text(title, size: 28, weight: FontWeight.w500),
            ),
          ),
          0,
        ),
        const SizedBox(height: 10),
        motion(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _text(subtitle, size: 15, color: _secondary),
          ),
          1,
        ),
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(1) > 1.3
              ? 26
              : !signup && question >= 2
              ? 24
              : 60,
        ),
        if (!signup && question != 3)
          for (var i = 0; i < _choices[question].length; i++) ...[
            motion(_choice(_choices[question][i], question), i + 2),
            const SizedBox(height: 8),
          ],
        if (!signup && question == 3)
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _choices[3].length; i++)
                motion(_choice(_choices[3][i], 3), i + 2, pills: true),
            ],
          ),
        if (signup && !auth.showEmail) ...[
          if (_keys.any((k) => _answers[k] != null)) motion(_summary(), 2),
          const Spacer(),
          const SizedBox(height: 36),
          if (Theme.of(context).platform == TargetPlatform.iOS) ...[
            motion(
              _button(
                'Continue with Apple',
                auth.busy ? null : auth.apple,
                black: true,
                icon: const Icon(Icons.apple, size: 20),
                busy:
                    auth.method == 'apple' ||
                    (_finishing && _authMethod == 'apple'),
              ),
              3,
            ),
            const SizedBox(height: 10),
          ],
          motion(
            _button(
              'Continue with Google',
              auth.busy ? null : auth.google,
              icon: const GoogleAuthLogo(size: 18),
              busy:
                  auth.method == 'google' ||
                  (_finishing && _authMethod == 'google'),
            ),
            4,
          ),
          const SizedBox(height: 10),
          motion(
            _button(
              'Continue with email',
              auth.busy ? null : auth.email,
              busy:
                  auth.method == 'email' ||
                  (_finishing && _authMethod == 'email'),
            ),
            5,
          ),
          if (auth.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _text(auth.error!, color: _secondary),
            ),
          const SizedBox(height: 14),
          motion(
            _text(
              'Free to start. Nothing is shared without permission.',
              size: 12,
              color: _tertiary,
              align: TextAlign.center,
            ),
            6,
          ),
        ],
        if (signup && auth.showEmail) auth.emailForm,
        if (_saveError != null)
          Semantics(
            liveRegion: true,
            child: _text(_saveError!, color: _secondary),
          ),
      ],
    );
    return SingleChildScrollView(
      key: ValueKey('step-$step'),
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 20),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: math.max(0, height - 92)),
        child: signup && !auth.showEmail
            ? IntrinsicHeight(child: content)
            : content,
      ),
    );
  }

  Widget _summary() {
    final rows = <Widget>[];
    for (var q = 0; q < 4; q++) {
      final value = _answers[_keys[q]];
      final choices = _choices[q].where((c) => c.value == value);
      if (choices.isEmpty) continue;
      if (rows.isNotEmpty) rows.add(const Divider(height: 1, color: _line));
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 94,
                child: _text(_labels[q], size: 14, color: _secondary),
              ),
              Expanded(
                child: _text(
                  choices.first.title,
                  size: 14,
                  weight: FontWeight.w500,
                  align: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      key: const ValueKey('onboarding-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .75),
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(children: rows),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_existingSignIn) {
      return AuthPage(
        onBackToSetup: () => setState(() => _existingSignIn = false),
      );
    }
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'CupertinoSystemText',
        platform: Theme.of(context).platform,
        colorScheme: const ColorScheme.light(
          primary: _ink,
          secondary: _ink,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _ink),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _line),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _ink,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      child: AuthPage(
        beforeAuth: (method, signup) async {
          _authMethod = method;
          await _store.beginAuth(method, signup);
        },
        onSignupUser: (u) async {
          await _store.bind(u);
        },
        presentationBuilder: (context, auth) =>
            AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.dark,
              child: PopScope(
                canPop: _step == 0,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop && !auth.busy && !_finishing) {
                    if (auth.showEmail) {
                      auth.closeEmail();
                    } else {
                      _go(_step - 1);
                    }
                  }
                },
                child: Scaffold(
                  resizeToAvoidBottomInset: true,
                  body: Stack(
                    children: [
                      Positioned.fill(
                        child: _Backdrop(step: _step, reduced: _reduced),
                      ),
                      SafeArea(
                        child: LayoutBuilder(
                          builder: (context, bounds) => AnimatedBuilder(
                            animation: _motion,
                            builder: (_, _) => Stack(
                              children: [
                                if (_oldStep != null && _motion.value < .5)
                                  Positioned.fill(
                                    child: ExcludeSemantics(
                                      child: IgnorePointer(
                                        child: _content(
                                          _oldStep!,
                                          true,
                                          auth,
                                          bounds.maxHeight,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    ignoring: _motion.isAnimating || _finishing,
                                    child: _content(
                                      _step,
                                      false,
                                      auth,
                                      bounds.maxHeight,
                                    ),
                                  ),
                                ),
                                if (_step > 0 && _step < 6) _header(auth),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

class _DrawnCheck extends StatelessWidget {
  const _DrawnCheck({
    required this.selected,
    required this.reduced,
    required this.size,
  });
  final bool selected, reduced;
  final double size;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: selected ? 1 : 0),
    duration: Duration(milliseconds: reduced ? 0 : 450),
    curve: onboardingCurve,
    builder: (_, t, _) =>
        CustomPaint(size: Size.square(size), painter: _CheckPainter(t)),
  );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      size.width / 2 - 1,
      Paint()..color = Color.lerp(Colors.white, _ink, t)!,
    );
    canvas.drawCircle(
      center,
      size.width / 2 - 1,
      Paint()
        ..color = Color.lerp(const Color(0xFFD8D7D4), _ink, t)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final path = Path()
      ..moveTo(size.width * .30, size.height * .51)
      ..lineTo(size.width * .44, size.height * .65)
      ..lineTo(size.width * .71, size.height * .36);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width > 30 ? 2.5 : 1.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.step, required this.reduced});
  final int step;
  final bool reduced;
  static const positions = [
    [0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, .6],
    [-60.0, -60.0, .55, 70.0, -40.0, .5, 0.0, 140.0, 0.0],
    [-20.0, -80.0, .5, 40.0, -10.0, .55, -40.0, 100.0, .15],
    [-80.0, -40.0, .5, 90.0, -60.0, .45, 20.0, 120.0, .1],
    [-40.0, -70.0, .55, 60.0, -20.0, .5, 0.0, 160.0, 0.0],
    [0.0, -20.0, .8, 20.0, 0.0, .8, 0.0, 40.0, .45],
  ];
  @override
  Widget build(BuildContext context) {
    final p = positions[step.clamp(0, 5)];
    final d = Duration(milliseconds: reduced ? 0 : 1400);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (_, bounds) => Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: Color(0xFFFBFAF8)),
              ),
              for (var i = 0; i < 3; i++)
                AnimatedPositioned(
                  duration: d,
                  curve: onboardingCurve,
                  left:
                      (i == 0
                          ? -90
                          : i == 1
                          ? bounds.maxWidth - 170
                          : 60) +
                      p[i * 3],
                  top:
                      (i == 0
                          ? -70
                          : i == 1
                          ? 40
                          : 420) +
                      p[i * 3 + 1],
                  width: (300 - i * 20).toDouble(),
                  height: (300 - i * 20).toDouble(),
                  child: AnimatedOpacity(
                    duration: d,
                    curve: onboardingCurve,
                    opacity: p[i * 3 + 2],
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 46, sigmaY: 46),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: [
                            const Color(0xFFE9C3A8),
                            const Color(0xFFB9C8DA),
                            const Color(0xFFD7CBDD),
                          ][i],
                        ),
                      ),
                    ),
                  ),
                ),
              const Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _GrainPainter()),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha: 0), Colors.white],
                      stops: const [.55, 1],
                    ),
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

class _GrainPainter extends CustomPainter {
  const _GrainPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(5);
    final paint = Paint()..color = _ink.withValues(alpha: .018);
    for (var i = 0; i < 3500; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        .45,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => false;
}
