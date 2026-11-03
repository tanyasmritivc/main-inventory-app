import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'riso_art.dart';
import 'founding_access_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const foundingCurve = Cubic(.32, .72, 0, 1);
const _text = Color(0xFFF4F4F5),
    _secondary = Color(0xFFA1A1A6),
    _tertiary = Color(0xFF6B6B70);
const _soft = Color(0xFF1B1B1E), _ink = Color(0xFF0B0B0C);
const _background = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF161618), Color(0xFF121214)],
);

TextStyle _style(
  double size, {
  Color color = _text,
  FontWeight weight = FontWeight.w400,
  double height = 1.4,
}) => TextStyle(
  inherit: false,
  fontFamily: 'VoiceInter',
  letterSpacing: 0,
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: height,
);

Future<void> showFoundingAccess(BuildContext context) {
  String? accountId;
  try {
    accountId = Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    // Isolated previews have no auth client.
  }
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) => FoundingAccessSheet(
      fromSettings: true,
      onDismiss: accountId == null
          ? null
          : () => unawaited(FoundingAccessStore.instance.dismiss(accountId!)),
      onClosed: () => Navigator.of(context).pop(),
    ),
  );
}

/// A purely informational row. No plan lookup, purchase or entitlement change.
class FoundingAccessPlanRow extends StatelessWidget {
  const FoundingAccessPlanRow({super.key});
  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      key: const ValueKey('founding-access-plan-row'),
      onTap: () => unawaited(showFoundingAccess(context)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Expanded(child: Text('Your plan')),
              const SizedBox(width: 12),
              const Flexible(
                child: Text('Founding Access', textAlign: TextAlign.right),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Tree-owned at signup, route-owned from Settings. The same modal and content
/// serve both entry points; account disposal removes the signup overlay too.
class FoundingAccessSheet extends StatefulWidget {
  const FoundingAccessSheet({
    super.key,
    required this.onClosed,
    this.onDismiss,
    this.fromSettings = false,
  });
  final VoidCallback onClosed;
  final VoidCallback? onDismiss;
  final bool fromSettings;
  @override
  State<FoundingAccessSheet> createState() => _FoundingAccessSheetState();
}

class _FoundingAccessSheetState extends State<FoundingAccessSheet>
    with SingleTickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
    reverseDuration: const Duration(milliseconds: 300),
  );
  final _focus = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  late bool _details = widget.fromSettings;
  bool _started = false, _closing = false, _reduce = false;
  double _drag = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _reduce = media.disableAnimations || media.accessibleNavigation;
    if (!_started) {
      _started = true;
      _entrance.forward();
    }
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    widget.onDismiss?.call();
    _entrance.reverse().then((_) {
      if (mounted) widget.onClosed();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _focus.dispose();
    super.dispose();
  }

  Widget _reveal(Widget child, int delay, {bool logo = false}) =>
      AnimatedBuilder(
        animation: _entrance,
        child: child,
        builder: (context, child) {
          final duration = logo ? 800 : 450;
          final t =
              ((_entrance.value * 1000 - (_reduce ? 0 : delay)) /
                      (_reduce ? 250 : duration))
                  .clamp(0.0, 1.0);
          final eased = foundingCurve.transform(t);
          return Opacity(
            opacity: eased,
            child: Transform.translate(
              offset: Offset(0, _reduce || logo ? 0 : 8 * (1 - eased)),
              child: Transform.scale(
                scale: logo && !_reduce ? .75 + .25 * eased : 1,
                child: child,
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: BlockSemantics(
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        label: 'Founding Access',
        explicitChildNodes: true,
        child: Material(
          type: MaterialType.transparency,
          child: FocusScope(
            node: _focus,
            autofocus: true,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): _close,
              },
              child: LayoutBuilder(
                builder: (context, bounds) => Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _entrance,
                        builder: (context, _) {
                          final t = (_entrance.value / .4).clamp(0.0, 1.0);
                          return ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 4 * t,
                                sigmaY: 4 * t,
                              ),
                              child: ModalBarrier(
                                key: const ValueKey('founding-backdrop'),
                                color: Colors.black.withValues(alpha: .55 * t),
                                dismissible: true,
                                semanticsLabel: 'Close Founding Access',
                                onDismiss: _close,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedBuilder(
                        animation: _entrance,
                        builder: (context, child) {
                          final t = foundingCurve.transform(
                            (_entrance.value / .6).clamp(0.0, 1.0),
                          );
                          return Opacity(
                            opacity: _reduce
                                ? (_entrance.value / .3).clamp(0.0, 1.0)
                                : 1,
                            child: FractionalTranslation(
                              translation: Offset(0, _reduce ? 0 : 1 - t),
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 520,
                              maxHeight: bounds.maxHeight * .9,
                            ),
                            child: Container(
                              key: const ValueKey('founding-sheet-surface'),
                              foregroundDecoration: const _TopEdgeDecoration(
                                38,
                                .045,
                              ),
                              decoration: BoxDecoration(
                                gradient: _background,
                                borderRadius: BorderRadius.circular(38),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: .08),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    offset: const Offset(0, -30),
                                    blurRadius: 70,
                                    color: Colors.black.withValues(alpha: .6),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(38),
                                child: _resize(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onVerticalDragStart: (_) => _drag = 0,
                                        onVerticalDragUpdate: (d) =>
                                            _drag += d.delta.dy,
                                        onVerticalDragEnd: (d) {
                                          if (_drag > 36 ||
                                              (d.primaryVelocity ?? 0) > 450) {
                                            _close();
                                          }
                                        },
                                        child: Semantics(
                                          label: 'Swipe down to close',
                                          child: SizedBox(
                                            key: const ValueKey(
                                              'founding-grab-handle',
                                            ),
                                            height: 27,
                                            width: double.infinity,
                                            child: Align(
                                              alignment: Alignment.topCenter,
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                  top: 10,
                                                ),
                                                width: 38,
                                                height: 5,
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: .18),
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        child: SingleChildScrollView(
                                          key: ValueKey(
                                            'founding-scroll-$_details',
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                          ),
                                          child: AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 450,
                                            ),
                                            reverseDuration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            switchInCurve: foundingCurve,
                                            switchOutCurve: Curves.easeOut,
                                            layoutBuilder:
                                                (current, previous) => Stack(
                                                  alignment: Alignment.topLeft,
                                                  children: [
                                                    ...previous.map(
                                                      (w) => Positioned.fill(
                                                        child: IgnorePointer(
                                                          child:
                                                              ExcludeSemantics(
                                                                child: w,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                    if (current != null)
                                                      current,
                                                  ],
                                                ),
                                            transitionBuilder:
                                                (
                                                  child,
                                                  animation,
                                                ) => FadeTransition(
                                                  opacity: animation,
                                                  child: AnimatedBuilder(
                                                    animation: animation,
                                                    child: child,
                                                    builder: (context, child) =>
                                                        Transform.translate(
                                                          offset: Offset(
                                                            _reduce
                                                                ? 0
                                                                : (_details
                                                                          ? 24
                                                                          : -24) *
                                                                      (1 -
                                                                          animation
                                                                              .value),
                                                            0,
                                                          ),
                                                          child: child,
                                                        ),
                                                  ),
                                                ),
                                            child: _details
                                                ? _detailsView()
                                                : _welcome(),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          20,
                                          16,
                                          20,
                                          22 +
                                              MediaQuery.paddingOf(
                                                context,
                                              ).bottom,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _FoundingButton(
                                              label: _details
                                                  ? 'Got it'
                                                  : 'Get started',
                                              onTap: _close,
                                            ),
                                            if (!_details) ...[
                                              const SizedBox(height: 8),
                                              _FoundingButton(
                                                label: "See what's included",
                                                primary: false,
                                                onTap: () => setState(
                                                  () => _details = true,
                                                ),
                                              ),
                                            ],
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
  );

  Widget _resize({required Widget child}) => _reduce
      ? child
      : AnimatedSize(
          duration: const Duration(milliseconds: 450),
          curve: foundingCurve,
          alignment: Alignment.bottomCenter,
          child: child,
        );

  Widget _welcome() => Column(
    key: const ValueKey('founding-welcome'),
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        height: 168,
        width: double.infinity,
        child: RisoArt(
          radius: 26,
          child: Stack(
            children: [
              Positioned(
                top: 14,
                left: 14,
                child: _glass(
                  radius: 14,
                  blur: 12,
                  opacity: .14,
                  ring: .22,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    child: Text(
                      'Founding Access',
                      style: _style(12.5, weight: FontWeight.w500, height: 1.3),
                    ),
                  ),
                ),
              ),
              Center(
                child: _reveal(
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          offset: const Offset(0, 14),
                          blurRadius: 40,
                          color: Colors.black.withValues(alpha: .25),
                        ),
                      ],
                    ),
                    child: _glass(
                      radius: 18,
                      blur: 14,
                      opacity: .12,
                      ring: .24,
                      child: Center(child: _mark(30)),
                    ),
                  ),
                  200,
                  logo: true,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        "You're in early.",
        style: _style(
          34,
          height: 1.08,
        ).copyWith(fontFamily: 'Inter Tight', letterSpacing: -.68),
      ),
      const SizedBox(height: 8),
      Text(
        "FindEZ is free while we get ready for launch. Here's how it works.",
        style: _style(15.5, color: _secondary, height: 1.45),
      ),
      const SizedBox(height: 18),
      _reveal(
        _point(
          Icons.verified_user_outlined,
          'Your inventory stays yours',
          'Everything you save stays in your account, even if you never subscribe.',
        ),
        300,
      ),
      const SizedBox(height: 14),
      _reveal(
        _point(
          Icons.search,
          'Always find what you saved',
          'Opening, searching and exporting your items stays free.',
        ),
        400,
      ),
      const SizedBox(height: 14),
      _reveal(
        _point(
          Icons.add,
          'Adding more will need a plan later',
          "When paid plans launch, you'll get a small free allowance. Adding more will need a subscription.",
        ),
        500,
      ),
      const SizedBox(height: 18),
      Text(
        "We'll tell you before anything changes. You can find this anytime in Settings.",
        style: _style(12.5, color: _tertiary, height: 1.5),
      ),
    ],
  );

  Widget _detailsView() => Column(
    key: const ValueKey('founding-details'),
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              tooltip: 'Back',
              style: IconButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: .12)),
                padding: EdgeInsets.zero,
              ),
              onPressed: widget.fromSettings
                  ? _close
                  : () => setState(() => _details = false),
              icon: const Icon(Icons.chevron_left, color: _text, size: 24),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.fromSettings ? 'Your plan' : "What's included",
              style: _style(17, weight: FontWeight.w500),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _card(
        LayoutBuilder(
          builder: (context, constraints) {
            final large =
                MediaQuery.textScalerOf(context).scale(16) > 22 ||
                constraints.maxWidth < 290;
            final art = SizedBox(
              width: 46,
              height: 46,
              child: RisoArt(radius: 13, child: Center(child: _mark(18))),
            );
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Founding Access',
                  style: _style(16, weight: FontWeight.w500),
                ),
                Text(
                  'Your plan right now',
                  style: _style(13, color: _secondary),
                ),
              ],
            );
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: large
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            art,
                            const Spacer(),
                            _chip('Free', ring: .12),
                          ],
                        ),
                        const SizedBox(height: 12),
                        title,
                      ],
                    )
                  : Row(
                      children: [
                        art,
                        const SizedBox(width: 12),
                        Expanded(child: title),
                        const SizedBox(width: 8),
                        _chip('Free', ring: .12),
                      ],
                    ),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
      _card(
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
            final large = scale > 1.4;
            final nowWidth = constraints.maxWidth < 300 ? 44.0 : 64.0;
            final freeWidth = constraints.maxWidth < 300 ? 76.0 : 84.0;
            Widget value(String? future) => future == null
                ? const Icon(
                    Icons.check,
                    color: _text,
                    size: 17,
                    semanticLabel: 'Included in free plan',
                  )
                : _chip(
                    future,
                    ring: future == 'Plan' ? .18 : 0,
                    color: future == 'Plan' ? _text : _secondary,
                  );
            Widget heading(String text) => Text(
              text,
              textAlign: TextAlign.center,
              style: _style(12, color: _tertiary, weight: FontWeight.w500),
            );
            Widget row(String label, String? future, {bool header = false}) {
              if (header && large) return const SizedBox.shrink();
              return Container(
                decoration: BoxDecoration(
                  border: header
                      ? null
                      : Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: .07),
                          ),
                        ),
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  header ? 11 : 12,
                  16,
                  header ? 9 : 12,
                ),
                child: large
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: _style(14.5)),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    heading('Now'),
                                    const SizedBox(height: 6),
                                    const Icon(
                                      Icons.check,
                                      color: _text,
                                      size: 17,
                                      semanticLabel: 'Included now',
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    heading('Free plan'),
                                    const SizedBox(height: 6),
                                    value(future),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: Text(label, style: _style(14.5))),
                          SizedBox(
                            width: nowWidth,
                            child: Center(
                              child: header
                                  ? heading('Now')
                                  : const Icon(
                                      Icons.check,
                                      color: _text,
                                      size: 17,
                                      semanticLabel: 'Included now',
                                    ),
                            ),
                          ),
                          SizedBox(
                            width: freeWidth,
                            child: Center(
                              child: header
                                  ? heading('Free plan')
                                  : value(future),
                            ),
                          ),
                        ],
                      ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                row('', null, header: true),
                row('Open and search items', null),
                row('See item details', null),
                row('Export your inventory', null),
                row('Ask FindEZ', 'Limited'),
                row('Add new items', 'Limited'),
                row('Snap a shelf', 'Limited'),
                row('Import a spreadsheet', 'Plan'),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 18),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Free plan',
              style: _style(12.5, color: _secondary, height: 1.5),
            ),
            const TextSpan(
              text:
                  " is what you keep without subscribing once paid plans launch. Prices and the date aren't set yet. We'll message you before anything changes, and nothing you've saved is ever deleted.",
            ),
          ],
        ),
        style: _style(12.5, color: _tertiary, height: 1.5),
      ),
    ],
  );

  Widget _mark(double size) => SvgPicture.asset(
    'assets/brand/findez-mark-white.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
  Widget _point(IconData icon, String title, String body) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Icon(icon, size: 18, color: _text),
      ),
      const SizedBox(width: 13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _style(15.5, weight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(body, style: _style(14, color: _secondary)),
          ],
        ),
      ),
    ],
  );
  Widget _glass({
    required Widget child,
    required double radius,
    required double blur,
    required double opacity,
    required double ring,
  }) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: ring)),
        ),
        child: child,
      ),
    ),
  );
  Widget _card(Widget child) => Container(
    foregroundDecoration: const _TopEdgeDecoration(20, .045),
    decoration: BoxDecoration(
      gradient: _background,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: .07)),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
  Widget _chip(String text, {double ring = 0, Color color = _text}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: text == 'Plan' ? null : _soft,
          borderRadius: BorderRadius.circular(13),
          border: ring == 0
              ? null
              : Border.all(color: Colors.white.withValues(alpha: ring)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: _style(12, color: color, weight: FontWeight.w500),
        ),
      );
}

class _FoundingButton extends StatefulWidget {
  const _FoundingButton({
    required this.label,
    required this.onTap,
    this.primary = true,
  });
  final String label;
  final VoidCallback onTap;
  final bool primary;
  @override
  State<_FoundingButton> createState() => _FoundingButtonState();
}

class _FoundingButtonState extends State<_FoundingButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed && !MediaQuery.disableAnimationsOf(context) ? .98 : 1,
    duration: const Duration(milliseconds: 120),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: widget.primary
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_text, Color(0xFFD4D4D8)],
              )
            : null,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(alpha: widget.primary ? .6 : .12),
        ),
        boxShadow: widget.primary
            ? [
                BoxShadow(
                  offset: const Offset(0, 8),
                  blurRadius: 24,
                  color: Colors.black.withValues(alpha: .35),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 52,
              minWidth: double.infinity,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: _style(
                    16,
                    color: widget.primary ? _ink : _text,
                    weight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The highlight follows the upper rounded edge without brightening the card.
class _TopEdgeDecoration extends Decoration {
  const _TopEdgeDecoration(this.radius, this.opacity);
  final double radius, opacity;
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _TopEdgePainter(radius, opacity);
}

class _TopEdgePainter extends BoxPainter {
  _TopEdgePainter(this.radius, this.opacity);
  final double radius, opacity;
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(offset.dx, offset.dy, size.width, radius));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (offset & size).deflate(.5),
        Radius.circular(radius),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: opacity),
    );
    canvas.restore();
  }
}
