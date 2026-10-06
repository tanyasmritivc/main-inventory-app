import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/ui/findez_wordmark.dart';
import 'onboarding_graphics.dart';
import 'onboarding_prefs.dart';
import 'package:mobile/core/ui/app_text.dart';

/// An account-free introduction. Every example is local, not saved inventory.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    this.onFinished,
    this.isReplay = false,
    this.completionWriter,
  });

  final VoidCallback? onFinished;
  final bool isReplay;

  /// Lets isolated tests exercise failed/delayed writes without native storage.
  @visibleForTesting
  final Future<void> Function()? completionWriter;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  int _step = 0;
  int _object = 0;
  bool _captured = false;
  String _space = 'Garage';
  int _question = 0;
  bool _shared = false;
  bool _finishing = false;
  String? _error;

  bool get _reduceMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  Duration get _duration =>
      _reduceMotion ? Duration.zero : const Duration(milliseconds: 300);

  void _go(int index) {
    if (_finishing || index < 0 || index > 3) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_reduceMotion) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: _duration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _error = null;
    });
    try {
      // Replaying the tour must not clear signup flags or a pending Space.
      if (!widget.isReplay) {
        await (widget.completionWriter?.call() ??
            OnboardingPrefs.setCompleted(true));
      }
      if (mounted) widget.onFinished?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _finishing = false;
        _error = 'Could not save your progress. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.isReplay || _step == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_finishing) _go(_step - 1);
    },
    child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
                  child: Row(
                    children: [
                      if (_step > 0)
                        IconButton(
                          tooltip: 'Previous step',
                          onPressed: _finishing ? null : () => _go(_step - 1),
                          icon: const Icon(
                            CupertinoIcons.chevron_left,
                            size: 20,
                          ),
                        ),
                      const Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FindEZWordmark(width: 112),
                        ),
                      ),
                      if (MediaQuery.textScalerOf(context).scale(14) > 22)
                        IconButton(
                          key: const Key('onboarding-skip'),
                          tooltip: widget.isReplay
                              ? 'Close tour'
                              : 'Skip introduction',
                          onPressed: _finishing ? null : _finish,
                          icon: Icon(
                            widget.isReplay
                                ? CupertinoIcons.xmark
                                : CupertinoIcons.arrow_right_to_line,
                            size: 20,
                          ),
                        )
                      else
                        TextButton(
                          key: const Key('onboarding-skip'),
                          onPressed: _finishing ? null : _finish,
                          child: AppText(widget.isReplay ? 'Close' : 'Skip'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    key: const Key('onboarding-pages'),
                    controller: _pages,
                    physics: _finishing
                        ? const NeverScrollableScrollPhysics()
                        : const ClampingScrollPhysics(),
                    onPageChanged: (index) => setState(() => _step = index),
                    children: [
                      _slide(
                        index: 0,
                        eyebrow: 'AI MEMORY FOR THE PHYSICAL WORLD',
                        title: 'Your things.\nRemembered.',
                        description:
                            'Capture what you own. Keep track of where it lives. '
                            'Ask for it when you need it.',
                        demo: _welcome(),
                      ),
                      _slide(
                        index: 1,
                        eyebrow: 'CAPTURE + REVIEW',
                        title: 'One photo.\nLess typing.',
                        description:
                            'Take or choose a photo. FindEZ suggests items and '
                            'reads visible labels. Review uncertain details and '
                            'choose a Space.',
                        demo: _capture(),
                      ),
                      _slide(
                        index: 2,
                        eyebrow: 'ASK + FIND',
                        title: 'Ask naturally.\nFind what you need.',
                        description:
                            'Ask about your saved items, quantities and locations. '
                            'You can also attach a photo to identify an object or '
                            'check possible matches.',
                        demo: _ask(),
                      ),
                      _slide(
                        index: 3,
                        eyebrow: 'YOUR WORLD, CONNECTED',
                        title: 'A place for\neverything.',
                        description:
                            'Use Spaces for home, work or a team. Keep photos and '
                            'notes with items, track loans and check project parts. '
                            'Share access only with people you choose.',
                        demo: _world(),
                      ),
                    ],
                  ),
                ),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _slide({
    required int index,
    required String eyebrow,
    required String title,
    required String description,
    required Widget demo,
  }) => SingleChildScrollView(
    key: ValueKey('onboarding-slide-$index'),
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          eyebrow,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary(context),
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: AppText(
            title,
            style: TextStyle(
              fontSize: 34,
              height: 1.08,
              letterSpacing: -1.1,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary(context),
            ),
          ),
        ),
        const SizedBox(height: 14),
        AppText(
          description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.textSecondary(context),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 26),
        _DemoCard(child: demo),
        const SizedBox(height: 10),
        AppText(
          'Example only. Nothing is saved.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary(context),
          ),
        ),
      ],
    ),
  );

  Widget _welcome() {
    const objects = [
      ('Tools', 'Cordless drill', 'Garage', 'Ready for your next project.'),
      ('Everyday', 'USB-C cable', 'Office', 'Know what you already have.'),
      ('Supplies', 'AA batteries', 'Home', 'Keep an eye on quantities.'),
    ];
    final object = objects[_object];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DemoLabel('Tap to explore'),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: _duration,
          child: PhysicalMemoryGraphic(key: ValueKey(_object), object: _object),
        ),
        const SizedBox(height: 16),
        _choices(
          [for (final object in objects) object.$1],
          _object,
          (index) => setState(() => _object = index),
          'intro-object',
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: _duration,
          child: _ExampleItem(
            key: ValueKey('item-$_object'),
            icon: [
              CupertinoIcons.wrench,
              Icons.cable_outlined,
              CupertinoIcons.battery_100,
            ][_object],
            title: object.$2,
            detail: '${object.$3} / ${object.$4}',
          ),
        ),
      ],
    );
  }

  Widget _capture() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _DemoLabel('Sample capture'),
      const SizedBox(height: 12),
      CaptureGraphic(captured: _captured, duration: _duration),
      const SizedBox(height: 16),
      AnimatedSwitcher(
        duration: _duration,
        child: !_captured
            ? OutlinedButton.icon(
                key: const Key('try-sample-capture'),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _captured = true);
                },
                icon: const Icon(CupertinoIcons.camera, size: 20),
                label: const AppText('Try sample photo'),
              )
            : Column(
                key: const Key('sample-review'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _ExampleItem(
                    icon: CupertinoIcons.wrench,
                    title: 'Cordless drill',
                    detail: 'Suggested item / Review before saving',
                  ),
                  const SizedBox(height: 14),
                  AppText(
                    'Where does it live?',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _choices(
                    const ['Garage', 'Workshop', 'Home'],
                    const ['Garage', 'Workshop', 'Home'].indexOf(_space),
                    (index) => setState(
                      () => _space = ['Garage', 'Workshop', 'Home'][index],
                    ),
                    'sample-space',
                  ),
                  const SizedBox(height: 10),
                  AppText(
                    'Example location: $_space. You stay in control of the details.',
                    key: const Key('sample-location'),
                    style: TextStyle(color: AppTheme.textSecondary(context)),
                  ),
                ],
              ),
      ),
    ],
  );

  Widget _ask() {
    const questions = [
      'Where is my drill?',
      'How many cables?',
      'Do I own this?',
    ];
    final answer = switch (_question) {
      0 => ('Cordless drill', _space, '2 in this sample inventory'),
      1 => ('USB-C cables', 'Office', '3 in this sample inventory'),
      _ => (
        'Possible match',
        _space,
        'This sample photo resembles a saved drill. Check the match before deciding.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DemoLabel('Try a sample question'),
        const SizedBox(height: 12),
        _choices(
          questions,
          _question,
          (index) => setState(() => _question = index),
          'sample-question',
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: _duration,
          child: Column(
            key: ValueKey('answer-$_question-$_space'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(answer.$1, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(CupertinoIcons.location, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppText(
                      answer.$2,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AppText(
                answer.$3,
                style: TextStyle(color: AppTheme.textSecondary(context)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: Center(child: LocationGraphic(isCable: _question == 1)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppText(
          'Answers use what you have saved, not everything around you.',
          style: TextStyle(color: AppTheme.textSecondary(context)),
        ),
      ],
    );
  }

  Widget _world() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _DemoLabel('Make it personal. Or shared.'),
      const SizedBox(height: 14),
      _choices(
        const ['Personal', 'Shared'],
        _shared ? 1 : 0,
        (index) => setState(() => _shared = index == 1),
        'sample-world',
      ),
      const SizedBox(height: 18),
      ConnectedWorldGraphic(shared: _shared, duration: _duration),
      const SizedBox(height: 18),
      AnimatedSwitcher(
        duration: _duration,
        child: _ExampleItem(
          key: ValueKey(_shared),
          icon: _shared ? CupertinoIcons.person_2 : CupertinoIcons.house,
          title: _shared ? 'Team workshop' : 'My spaces',
          detail: _shared
              ? 'Invite people and choose view or edit access.'
              : 'Home, garage or office. Start with one Space.',
        ),
      ),
      const SizedBox(height: 16),
      AppText(
        'After sign-in, capture your first item or join a Space you have been invited to.',
        style: TextStyle(color: AppTheme.textSecondary(context)),
      ),
    ],
  );

  Widget _choices(
    List<String> labels,
    int selected,
    ValueChanged<int> choose,
    String prefix,
  ) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < labels.length; index++)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: ChoiceChip(
              key: ValueKey('$prefix-$index'),
              label: AppText(labels[index]),
              selected: index == selected,
              onSelected: _finishing ? null : (_) => choose(index),
              showCheckmark: false,
              selectedColor: AppTheme.surface2(context),
              backgroundColor: AppTheme.surface(context),
              labelStyle: TextStyle(color: AppTheme.textPrimary(context)),
              side: BorderSide(
                color: index == selected
                    ? AppTheme.textPrimary(context)
                    : AppTheme.border(context),
              ),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
      ],
    ),
  );

  Widget _footer() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Step ${_step + 1} of 4',
          child: ExcludeSemantics(
            child: Row(
              children: [
                for (var index = 0; index < 4; index++)
                  Expanded(
                    child: AnimatedContainer(
                      key: ValueKey('onboarding-progress-$index'),
                      duration: _duration,
                      margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: index <= _step
                            ? AppTheme.textPrimary(context)
                            : AppTheme.border(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          AppText(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(
          key: const Key('onboarding-next'),
          onPressed: _finishing
              ? null
              : () => _step < 3 ? _go(_step + 1) : _finish(),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
          child: AppText(
            _finishing
                ? 'Saving...'
                : _step < 3
                ? 'Next'
                : widget.isReplay
                ? 'Done'
                : 'Continue to sign in',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: AppTheme.border(context)),
    ),
    child: child,
  );
}

class _DemoLabel extends StatelessWidget {
  const _DemoLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) =>
      AppText(label, style: Theme.of(context).textTheme.titleSmall);
}

class _ExampleItem extends StatelessWidget {
  const _ExampleItem({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surface2(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            AppText(
              detail,
              style: TextStyle(color: AppTheme.textSecondary(context)),
            ),
          ],
        ),
      ),
    ],
  );
}
