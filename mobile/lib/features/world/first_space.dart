import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

enum FirstSpaceAction { extract, spreadsheet, chat }

class _Arrival extends StatelessWidget {
  const _Arrival(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 250),
    builder: (_, value, content) => Opacity(opacity: value, child: content),
    child: child,
  );
}

class FirstSpaceAskLanding extends StatelessWidget {
  const FirstSpaceAskLanding({
    super.key,
    required this.composer,
    required this.onStart,
    required this.height,
    this.composerLift,
  });
  final Widget composer;
  final VoidCallback onStart;
  final double height;
  final double? composerLift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final base = dark ? const Color(0xff151515) : theme.colorScheme.surface;
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ComposerAnchor(
                viewportHeight: height,
                lift: composerLift,
                child: composer,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _Arrival(
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, .6, 1],
                        colors: [
                          base,
                          base.withValues(alpha: .6),
                          base.withValues(alpha: 0),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: height < 530 ? 8 : 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Create your first space',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Snap a shelf. FindEZ does the rest.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 15,
                              color: dark
                                  ? const Color(0xff8e8e93)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _StartButton(onStart: onStart),
                        ],
                      ),
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

// Lift the composer into the available space above the onboarding card.
// Its existing bottom padding supplies the gap between the two.
class _ComposerAnchor extends SingleChildRenderObjectWidget {
  const _ComposerAnchor({
    required this.viewportHeight,
    required this.lift,
    required super.child,
  });
  final double viewportHeight;
  final double? lift;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _CenteredComposer(viewportHeight, lift);
  @override
  void updateRenderObject(
    BuildContext context,
    _CenteredComposer renderObject,
  ) {
    if (renderObject.viewportHeight != viewportHeight ||
        renderObject.lift != lift) {
      renderObject.viewportHeight = viewportHeight;
      renderObject.lift = lift;
      renderObject.markNeedsLayout();
    }
  }
}

class _CenteredComposer extends RenderShiftedBox {
  _CenteredComposer(this.viewportHeight, this.lift) : super(null);
  double viewportHeight;
  double? lift;
  @override
  void performLayout() {
    final box = child!;
    box.layout(constraints, parentUsesSize: true);
    final freeHeight = math.max(0.0, viewportHeight - box.size.height);
    final top = math.max(
      0.0,
      freeHeight / 2 - (lift ?? math.min(36.0, freeHeight * .12)),
    );
    (box.parentData! as BoxParentData).offset = Offset(0, top);
    size = constraints.constrain(
      Size(box.size.width, top + box.size.height - 20),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onStart, this.wide = false});
  final VoidCallback onStart;
  final bool wide;
  @override
  Widget build(BuildContext context) => Material(
    color: wide ? const Color(0xff1f1f1f) : Colors.white,
    borderRadius: BorderRadius.circular(wide ? 25 : 21),
    child: InkWell(
      onTap: onStart,
      borderRadius: BorderRadius.circular(wide ? 25 : 21),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: wide ? 50 : 44),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 28, vertical: 8),
          child: Center(
            widthFactor: wide ? null : 1,
            heightFactor: 1,
            child: Text(
              'Start now',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: wide ? Colors.white : Colors.black,
                fontSize: wide ? 17 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class FirstSpaceDirectory extends StatelessWidget {
  const FirstSpaceDirectory({super.key, required this.onStart});
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final end = theme.scaffoldBackgroundColor.a == 0
        ? (dark ? Colors.black : Colors.white)
        : theme.scaffoldBackgroundColor;
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0, .55, 1],
        colors: [
          dark ? const Color(0xff1b1b1b) : theme.colorScheme.surfaceContainer,
          dark ? const Color(0xff141414) : theme.colorScheme.surface,
          end.withValues(alpha: 0),
        ],
      ),
    );
    Widget column(int top) => Expanded(
      child: Column(
        children: [
          Expanded(
            flex: top,
            child: Container(decoration: decoration),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 100 - top,
            child: Container(decoration: decoration),
          ),
        ],
      ),
    );
    return _Arrival(
      LayoutBuilder(
        builder: (context, box) => Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: Row(
                  children: [column(40), const SizedBox(width: 12), column(58)],
                ),
              ),
            ),
            Positioned.fill(
              top: math.min(90, box.minHeight * .22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, .32, 1],
                    colors: [
                      end.withValues(alpha: 0),
                      end.withValues(alpha: .82),
                      end.withValues(alpha: .90),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: box.minHeight * .39),
              child: Column(
                children: [
                  Text(
                    'Nothing here yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      color: dark
                          ? const Color(0xff636366)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first space',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Snap a shelf. FindEZ lists every part.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      color: dark
                          ? const Color(0xffa1a1a1)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: math.min(310, box.maxWidth - 40),
                    child: _StartButton(onStart: onStart, wide: true),
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

Future<FirstSpaceAction?> showFirstSpaceSheet(BuildContext context) {
  final reduce = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<FirstSpaceAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: reduce
        ? Duration.zero
        : const Duration(milliseconds: 160),
    transitionBuilder: (_, _, _, child) => child,
    pageBuilder: (ctx, animation, _) {
      final theme = Theme.of(ctx);
      void close([FirstSpaceAction? action]) {
        if (ModalRoute.of(ctx)?.isCurrent == true) Navigator.pop(ctx, action);
      }

      Widget tile(
        FirstSpaceAction action,
        String label,
        IconData icon, {
        bool primary = false,
      }) {
        final color = primary ? Colors.black : Colors.white;
        final children = [
          Icon(icon, size: primary ? 22 : 24, color: color),
          SizedBox(width: primary ? 10 : 0, height: primary ? 0 : 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontSize: primary ? 17 : 15,
                fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ];
        return Material(
          color: primary ? Colors.white : Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => close(action),
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height:
                  (primary ? 60.0 : 88.0) *
                  math.max(1.0, MediaQuery.textScalerOf(ctx).scale(15) / 15),
              child: primary
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: children,
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: children,
                    ),
            ),
          ),
        );
      }

      Widget present(Widget panel) {
        if (reduce) return panel;
        return SlideTransition(
          position: animation.drive(
            Tween(
              begin: const Offset(0, .08),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: panel,
        );
      }

      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onTap: () => close(),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: const ColoredBox(color: Color(0x66000000)),
              ),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: present(
                Dismissible(
                  key: const ValueKey('first-space-sheet'),
                  direction: DismissDirection.down,
                  onDismissed: (_) => close(),
                  child: Material(
                    clipBehavior: Clip.antiAlias,
                    color: const Color(0xff1e1e1e),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(36),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .07),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .22),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Add your first items',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: () => close(),
                                icon: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: .10,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.xmark,
                                    size: 12,
                                    color: Color(0xffc7c7cc),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          tile(
                            FirstSpaceAction.extract,
                            'Auto extract',
                            CupertinoIcons.camera,
                            primary: true,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: tile(
                                  FirstSpaceAction.spreadsheet,
                                  'Spreadsheet',
                                  CupertinoIcons.table,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: tile(
                                  FirstSpaceAction.chat,
                                  'Chat',
                                  CupertinoIcons.chat_bubble,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
