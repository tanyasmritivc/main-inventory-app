import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/ui/app_text.dart';
import '../../core/ui/findez_wordmark.dart';
import 'onboarding_answers.dart';
import 'onboarding_prefs.dart';
import 'onboarding_visuals.dart';

/// Optional four-question setup. No sample inventory or automatic Team writes.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    this.onFinished,
    this.isReplay = false,
    this.completionWriter,
    this.api,
  });
  final VoidCallback? onFinished;
  final bool isReplay;
  final ApiClient? api;
  @visibleForTesting
  final Future<void> Function()? completionWriter;
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  final _useOther = TextEditingController();
  final _inventoryOther = TextEditingController();
  int _step = 0;
  String? _useCase, _goal, _collaboration;
  final Set<String> _types = {};
  bool _finishing = false,
      _loading = false,
      _completed = false,
      _moving = false;
  String? _error;
  String? _owner;

  static const _uses = {
    'household': 'Home',
    'business': 'Business',
    'laboratory': 'Lab or research',
    'education': 'School or education',
    'robotics': 'Robotics',
    'manufacturing': 'Manufacturing',
    'warehouse': 'Warehouse or logistics',
    'other': 'Other',
  };
  static const _inventory = {
    'tools': 'Tools',
    'equipment': 'Equipment',
    'parts': 'Parts and components',
    'supplies': 'Supplies',
    'products': 'Products or stock',
    'household_items': 'Household items',
    'other': 'Other',
  };
  static const _goals = {
    'find_items': 'Find things faster',
    'identify_items': 'Identify items from photos',
    'track_stock': 'Keep track of quantities',
    'organize_spaces': 'Organize my Spaces',
    'share_inventory': 'Share inventory with others',
  };

  bool get _valid => switch (_step) {
    0 =>
      _useCase != null &&
          (_useCase != 'other' || _useOther.text.trim().isNotEmpty),
    1 =>
      _types.isNotEmpty &&
          (!_types.contains('other') || _inventoryOther.text.trim().isNotEmpty),
    2 => _goal != null,
    _ => _collaboration != null,
  };
  bool get _reduceMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  @override
  void initState() {
    super.initState();
    _owner = widget.api?.accountId;
    if (widget.isReplay && _owner != null) _loadAnswers();
  }

  Future<void> _loadAnswers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cached = await OnboardingAnswerStore.cachedFor(_owner!);
      if (cached != null && mounted && widget.api!.accountId == _owner) {
        _apply(cached);
      }
      final json = await widget.api!.getOnboardingAnswers();
      if (!mounted || widget.api!.accountId != _owner) return;
      if (json != null) _apply(OnboardingAnswers.fromJson(json));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not load your saved answers. You can retry or enter them again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(OnboardingAnswers a) => setState(() {
    _useCase = a.useCase;
    _useOther.text = a.useCaseOther ?? '';
    _types
      ..clear()
      ..addAll(a.inventoryTypes);
    _inventoryOther.text = a.inventoryOther ?? '';
    _goal = a.primaryGoal;
    _collaboration = a.collaboration;
  });
  Future<void> _go(int index) async {
    if (_finishing || _moving || index < 0 || index > 3) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_reduceMotion) {
      _pages.jumpToPage(index);
    } else {
      setState(() => _moving = true);
      try {
        await _pages.animateToPage(
          index,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
        );
      } finally {
        if (mounted) setState(() => _moving = false);
      }
    }
  }

  Future<void> _finish({bool skip = false}) async {
    if (_finishing || (!skip && !_valid)) return;
    setState(() {
      _finishing = true;
      _error = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      if (!skip) {
        final answers = OnboardingAnswers(
          useCase: _useCase!,
          inventoryTypes: _types.toList(),
          primaryGoal: _goal!,
          collaboration: _collaboration!,
          useCaseOther: _useCase == 'other' ? _useOther.text.trim() : null,
          inventoryOther: _types.contains('other')
              ? _inventoryOther.text.trim()
              : null,
        );
        if (widget.api != null && _owner != null) {
          if (widget.api!.accountId != _owner) {
            throw StateError('Account changed');
          }
          await OnboardingAnswerStore.saveDraft(answers, accountId: _owner);
          final synced = await OnboardingAnswerStore.sync(widget.api!);
          if (!synced || widget.api!.accountId != _owner) {
            throw StateError('Setup was not saved');
          }
        } else if (!widget.isReplay) {
          await OnboardingAnswerStore.saveDraft(answers);
        }
      }
      if (!widget.isReplay) {
        await (widget.completionWriter?.call() ??
            OnboardingPrefs.setCompleted(true));
      }
      if (mounted) {
        setState(() => _completed = true);
        widget.onFinished?.call();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _finishing = false;
          _error =
              'Could not save your setup. Please try again. Your answers are still here.';
        });
      }
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _useOther.dispose();
    _inventoryOther.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_finishing && (widget.isReplay || _step == 0),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _go(_step - 1);
    },
    child: Scaffold(
      body: SetupBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        if (_step > 0)
                          IconButton(
                            tooltip: 'Previous step',
                            onPressed: _finishing || _moving
                                ? null
                                : () => _go(_step - 1),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        const Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: FindEZWordmark(width: 104),
                            ),
                          ),
                        ),
                        if (MediaQuery.textScalerOf(context).scale(14) > 22)
                          IconButton(
                            key: const Key('onboarding-skip'),
                            tooltip: widget.isReplay
                                ? 'Close setup'
                                : 'Skip setup',
                            onPressed: _finishing
                                ? null
                                : () => _finish(skip: true),
                            icon: const Icon(Icons.close_rounded),
                          )
                        else
                          TextButton(
                            key: const Key('onboarding-skip'),
                            onPressed: _finishing
                                ? null
                                : () => _finish(skip: true),
                            child: AppText(widget.isReplay ? 'Close' : 'Skip'),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                    child: Semantics(
                      label: 'Question ${_step + 1} of 4',
                      child: ExcludeSemantics(
                        child: Row(
                          children: List.generate(
                            4,
                            (index) => Expanded(
                              child: AnimatedContainer(
                                duration: Duration(
                                  milliseconds: _reduceMotion ? 0 : 320,
                                ),
                                curve: Curves.easeInOutCubic,
                                height: 4,
                                margin: EdgeInsets.only(
                                  right: index == 3 ? 0 : 6,
                                ),
                                decoration: BoxDecoration(
                                  color: index <= _step
                                      ? AppTheme.accentForeground(context)
                                      : AppTheme.textMuted(
                                          context,
                                        ).withValues(alpha: .22),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_loading) const LinearProgressIndicator(),
                  Expanded(
                    child: PageView(
                      key: const Key('onboarding-pages'),
                      controller: _pages,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() => _step = i),
                      children: [
                        _question(
                          0,
                          'What will you use FindEZ for?',
                          'Choose one. Your answers help us improve FindEZ.',
                          [
                            _choices(
                              _uses,
                              _useCase,
                              (key) => setState(() => _useCase = key),
                              group: 'use',
                            ),
                            if (_useCase == 'other')
                              _otherField(
                                _useOther,
                                'Your use',
                                'e.g. Costume department',
                              ),
                          ],
                        ),
                        _question(
                          1,
                          'What do you manage?',
                          'Select all that apply.',
                          [
                            _choices(
                              _inventory,
                              null,
                              (key) => setState(() {
                                if (!_types.add(key)) _types.remove(key);
                              }),
                              multiple: true,
                              group: 'inventory',
                            ),
                            if (_types.contains('other'))
                              _otherField(
                                _inventoryOther,
                                'Other inventory',
                                'e.g. Fabric and props',
                              ),
                          ],
                        ),
                        _question(
                          2,
                          'What would help you most?',
                          'Choose your main goal.',
                          [
                            _choices(
                              _goals,
                              _goal,
                              (key) => setState(() => _goal = key),
                              group: 'goal',
                            ),
                          ],
                        ),
                        _question(
                          3,
                          'Who will use this inventory?',
                          'Sharing is always your choice.',
                          [
                            _choices(
                              const {
                                'solo': 'Just me',
                                'others': 'With others',
                              },
                              _collaboration,
                              (key) => setState(() => _collaboration = key),
                              group: 'collaboration',
                            ),
                            const SizedBox(height: 24),
                            AppText(
                              'A good place to start',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            AppText(
                              switch (_goal) {
                                'identify_items' =>
                                  'Take a photo, review the suggestions, and save an item to a Space.',
                                'track_stock' =>
                                  'Add an item and its quantity. Set a low-stock threshold when you need a reminder.',
                                'organize_spaces' =>
                                  'Create a Space for a room, shelf, or work area, then add your items.',
                                'share_inventory' =>
                                  'Start with a Space, then choose who can view or edit it.',
                                _ =>
                                  'Add an item to a Space, then search its name or ask where it is.',
                              },
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                            if (_owner == null && !widget.isReplay) ...[
                              const SizedBox(height: 16),
                              AppText(
                                'Your answers will be saved after you sign in.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Semantics(
                              liveRegion: true,
                              child: Column(
                                children: [
                                  AppText(
                                    _error!,
                                    style: TextStyle(
                                      color: AppTheme.danger,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (_step == 0 &&
                                      widget.isReplay &&
                                      _owner != null)
                                    TextButton(
                                      onPressed: _loadAnswers,
                                      child: const AppText('Retry'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const Key('onboarding-next'),
                            onPressed:
                                _finishing || _loading || _moving || !_valid
                                ? null
                                : () {
                                    if (_step < 3) {
                                      _go(_step + 1);
                                    } else {
                                      _finish();
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 52),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                            ),
                            child: _finishing && !_completed
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : AppText(
                                    _step == 3 && _owner != null
                                        ? 'Save'
                                        : 'Continue',
                                  ),
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
  );

  Widget _question(
    int index,
    String title,
    String subtitle,
    List<Widget> children,
  ) => SingleChildScrollView(
    key: ValueKey('onboarding-slide-$index'),
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: AppText(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              height: 1.12,
              letterSpacing: -.4,
              color: AppTheme.textPrimary(context),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AppText(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: AppTheme.textSecondary(context),
          ),
        ),
        const SizedBox(height: 20),
        ...children,
      ],
    ),
  );
  static IconData _choiceIcon(String key) => switch (key) {
    'household' || 'household_items' => Icons.home_outlined,
    'business' => Icons.storefront_outlined,
    'laboratory' => Icons.science_outlined,
    'education' => Icons.school_outlined,
    'robotics' => Icons.smart_toy_outlined,
    'manufacturing' => Icons.precision_manufacturing_outlined,
    'warehouse' => Icons.warehouse_outlined,
    'tools' => Icons.handyman_outlined,
    'equipment' => Icons.settings_outlined,
    'parts' => Icons.memory_outlined,
    'supplies' => Icons.layers_outlined,
    'products' => Icons.inventory_2_outlined,
    'find_items' => Icons.search_rounded,
    'identify_items' => Icons.photo_camera_outlined,
    'track_stock' => Icons.bar_chart_rounded,
    'organize_spaces' => Icons.grid_view_outlined,
    'share_inventory' || 'others' => Icons.group_outlined,
    'solo' => Icons.person_outline_rounded,
    _ => Icons.edit_outlined,
  };

  Widget _choices(
    Map<String, String> options,
    String? chosen,
    ValueChanged<String> onChoose, {
    required String group,
    bool multiple = false,
  }) => BackdropGroup(
    child: Column(
      children: options.entries.map((entry) {
        final selected = multiple
            ? _types.contains(entry.key)
            : chosen == entry.key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: MergeSemantics(
            child: Semantics(
              key: Key('setup-$group-${entry.key}'),
              label: entry.value,
              button: true,
              selected: selected,
              enabled: !_finishing && !_moving,
              onTap: _finishing || _moving ? null : () => onChoose(entry.key),
              inMutuallyExclusiveGroup: !multiple,
              child: ExcludeSemantics(
                child: SetupGlassPanel(
                  selected: selected,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _finishing || _moving
                          ? null
                          : () => onChoose(entry.key),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 66),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _choiceIcon(entry.key),
                                size: 26,
                                color: selected
                                    ? AppTheme.accentForeground(context)
                                    : AppTheme.textSecondary(context),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: AppText(
                                  entry.value,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    height: 1.35,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ExcludeSemantics(
                                child: AnimatedOpacity(
                                  opacity: selected ? 1 : 0,
                                  duration: Duration(
                                    milliseconds: _reduceMotion ? 0 : 160,
                                  ),
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: AppTheme.accentForeground(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
  Widget _otherField(
    TextEditingController controller,
    String label,
    String hint,
  ) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextField(
      controller: controller,
      maxLength: 80,
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );
}
