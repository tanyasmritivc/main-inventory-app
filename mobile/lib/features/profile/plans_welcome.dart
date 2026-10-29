import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_theme.dart';
import '../../core/plan_introduction.dart';
import '../../core/ui/app_text.dart';
import 'plan_widgets.dart';
import '../../core/plan_catalog.dart';

/// Tree-owned modal: account changes dispose the popup with its account, so an
/// old user's dialog can never remain on the Navigator over a different user.
class PlansWelcomeGate extends StatefulWidget {
  const PlansWelcomeGate({
    super.key,
    required this.user,
    required this.child,
    this.store,
  });
  final User user;
  final Widget child;
  final PlanIntroductionStore? store;
  @override
  State<PlansWelcomeGate> createState() => _PlansWelcomeGateState();
}

class _PlansWelcomeGateState extends State<PlansWelcomeGate> {
  final _focusScope = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  late final _store = widget.store ?? PlanIntroductionStore();
  bool _open = false;
  int _generation = 0;
  @override
  void dispose() {
    _focusScope.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant PlansWelcomeGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      _open = false;
      unawaited(_load());
    } else if (oldWidget.user.emailConfirmedAt !=
        widget.user.emailConfirmedAt) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final show = await _store.shouldShow(widget.user);
      if (!mounted || generation != _generation) return;
      if (show) FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _open = show);
    } catch (_) {
      // Optional plan information never blocks authentication or onboarding.
    }
  }

  void _close() {
    if (!_open) return;
    final user = widget.user;
    ++_generation;
    setState(() => _open = false);
    unawaited(
      _store.dismiss(user).then((synced) {
        if (!synced) {
          debugPrint('Plan introduction closed locally; server sync pending.');
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ExcludeFocus(
        excluding: _open,
        child: ExcludeSemantics(excluding: _open, child: widget.child),
      ),
      if (_open)
        Positioned.fill(
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _close();
            },
            child: BlockSemantics(
              child: Stack(
                children: [
                  ModalBarrier(
                    dismissible: true,
                    onDismiss: _close,
                    color: Colors.black54,
                    semanticsLabel: 'Close plans',
                  ),
                  SafeArea(
                    child: FocusScope(
                      autofocus: true,
                      node: _focusScope,
                      child: CallbackShortcuts(
                        bindings: {
                          const SingleActivator(LogicalKeyboardKey.escape):
                              _close,
                        },
                        child: PlansWelcomeDialog(onClose: _close),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class PlansWelcomeDialog extends StatefulWidget {
  const PlansWelcomeDialog({super.key, required this.onClose});
  final VoidCallback onClose;
  @override
  State<PlansWelcomeDialog> createState() => _PlansWelcomeDialogState();
}

class _PlansWelcomeDialogState extends State<PlansWelcomeDialog> {
  bool _annual = false;
  int _plan = 0;
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppTheme.surface(context),
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: AppText(
                      'A plan for your world.',
                      style: TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close plans',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Free during early access. No plan limits or automatic charges.',
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  PlanPeriodSelector(
                    annual: _annual,
                    onChanged: (value) => setState(() => _annual = value),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: List.generate(
                      findEZPlans.length,
                      (index) => ChoiceChip(
                        label: AppText(findEZPlans[index].name),
                        selected: _plan == index,
                        selectedColor: const Color(0xFFEBEBEB),
                        labelStyle: TextStyle(
                          color: _plan == index ? BluePlanSurface.ink : null,
                        ),
                        checkmarkColor: BluePlanSurface.ink,
                        onSelected: (_) => setState(() => _plan = index),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PlanCard(plan: findEZPlans[_plan], annual: _annual),
                  const SizedBox(height: 12),
                  AppText(
                    'Planned prices in USD. Allowances start when subscriptions launch.',
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style:
                        FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDBDBDB),
                          foregroundColor: BluePlanSurface.ink,
                          minimumSize: const Size(0, 48),
                        ).copyWith(
                          // The app-wide glass builder paints over this blue fill.
                          // Keep the local Material fill for readable dark-mode ink.
                          backgroundBuilder: (context, states, child) =>
                              child ?? const SizedBox.shrink(),
                        ),
                    onPressed: widget.onClose,
                    child: const AppText('Continue with Free'),
                  ),
                ),
                TextButton(
                  onPressed: widget.onClose,
                  child: const AppText('Skip for now'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
