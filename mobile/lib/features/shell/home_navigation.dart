import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'dart:math' as math;
import '../../core/app_theme.dart';
import '../../core/ui/frosted_surface.dart';

class HomeNavigation extends StatefulWidget {
  const HomeNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.destinationKeys = const {},
    this.monochrome = false,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Map<int, Key> destinationKeys;
  final bool monochrome;
  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation>
    with SingleTickerProviderStateMixin {
  static const _destinationCount = 4;
  static const duration = Duration(milliseconds: 350);
  late final AnimationController _motion;
  late double _from, _to;
  double _fromScale = 1, _fromStretch = 1, _fromBias = 0;
  bool _reduced = false;
  static final _slide = SpringSimulation(
    const SpringDescription(mass: 1, stiffness: 500, damping: 28),
    0,
    1,
    0,
  );
  static final _rise = SpringSimulation(
    const SpringDescription(mass: 1, stiffness: 650, damping: 30),
    0,
    1,
    0,
  );
  static final _settle = SpringSimulation(
    const SpringDescription(mass: 1, stiffness: 650, damping: 30),
    1,
    0,
    0,
  );

  double get _progress =>
      _motion.value == 1 ? 1 : _slide.x(_motion.value * .35) / _slide.x(.35);
  double get _position =>
      (_from + (_to - _from) * _progress).clamp(0, _destinationCount - 1);
  double get _bias {
    final travel = _progress.clamp(0.0, 1.0);
    return _fromBias * (1 - travel) + (_to >= _from ? 1 : -1) * travel;
  }

  double get _stretch {
    if (_reduced || !_motion.isAnimating || _from == _to) return 1;
    final travel = _progress.clamp(0.0, 1.0);
    return (1 +
            (_fromStretch - 1) * (1 - travel) +
            .4 * math.sin(math.pi * travel))
        .clamp(1, 1.4);
  }

  double get _scale {
    if (_reduced || !_motion.isAnimating) return 1;
    final t = _motion.value;
    if (t < .24) {
      final rise = _rise.x(t / .24 * .084) / _rise.x(.084);
      return _fromScale + (1.06 - _fromScale) * rise;
    }
    final end = _settle.x(.266);
    final settle = (_settle.x((t - .24) / .76 * .266) - end) / (1 - end);
    return 1 + .06 * settle;
  }

  @override
  void initState() {
    super.initState();
    _from = _to = widget.selectedIndex.toDouble();
    _motion = AnimationController(vsync: this, duration: duration, value: 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (reduced != _reduced && _motion.isAnimating) {
      _motion.stop();
      _motion.value = 1;
      _from = _to;
    }
    _reduced = reduced;
  }

  @override
  void didUpdateWidget(covariant HomeNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _animate(widget.selectedIndex);
    }
  }

  void _animate(int index) {
    final position = _position, scale = _scale, stretch = _stretch;
    _fromBias = _bias;
    _from = _reduced ? _to : position;
    _fromScale = scale;
    _fromStretch = stretch;
    _to = index.toDouble();
    _motion.duration = _reduced ? const Duration(milliseconds: 180) : duration;
    _motion.forward(from: 0);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Widget _pill(
    BuildContext context,
    double index,
    double opacity,
    double width,
  ) {
    const diameter = 36.0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final physicalIndex = rtl ? _destinationCount - 1 - index : index;
    final center = 1 + (width - 2) / _destinationCount * (physicalIndex + .5);
    return Positioned(
      left: center - diameter / 2,
      top: 11,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          key: const Key('nav-selection-stretch'),
          scaleX: _stretch,
          scaleY: 1,
          alignment: Alignment(rtl ? _bias : -_bias, 0),
          child: Container(
            key: ValueKey('nav-selection-$index'),
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              color: widget.monochrome
                  ? AppTheme.textPrimary(context).withValues(alpha: .1)
                  : AppTheme.navigationTintFor(Theme.of(context).brightness),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.textPrimary(context).withValues(alpha: .025),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
      child: SizedBox(
        key: const Key('nav-frame'),
        height: 58,
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: _motion,
            builder: (context, icons) => Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Transform.scale(
                    key: const Key('nav-surface-scale'),
                    scale: _scale,
                    child: const FrostedSurface(
                      radius: 30,
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: ExcludeSemantics(
                    child: SizedBox.expand(
                      child: Stack(
                        children: [
                          if (_reduced &&
                              _motion.isAnimating &&
                              _from != _to) ...[
                            _pill(
                              context,
                              _from,
                              1 - _motion.value,
                              constraints.maxWidth,
                            ),
                            _pill(
                              context,
                              _to,
                              _motion.value,
                              constraints.maxWidth,
                            ),
                          ] else
                            _pill(
                              context,
                              _reduced ? _to : _position,
                              1,
                              constraints.maxWidth,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: icons!,
                  ),
                ),
              ],
            ),
            child: NavigationBar(
              height: 56,
              animationDuration: Duration.zero,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
              backgroundColor: Colors.transparent,
              indicatorColor: Colors.transparent,
              indicatorShape: const CircleBorder(),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: (index) {
                if (index == widget.selectedIndex) _animate(index);
                widget.onSelected(index);
              },
              destinations: [
                NavigationDestination(
                  icon: Icon(
                    CupertinoIcons.house,
                    key: widget.destinationKeys[0],
                  ),
                  selectedIcon: Icon(
                    CupertinoIcons.house_fill,
                    color: widget.monochrome
                        ? AppTheme.textPrimary(context)
                        : null,
                  ),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(
                    CupertinoIcons.barcode_viewfinder,
                    key: widget.destinationKeys[1],
                  ),
                  selectedIcon: Icon(
                    CupertinoIcons.barcode_viewfinder,
                    color: widget.monochrome
                        ? AppTheme.textPrimary(context)
                        : null,
                  ),
                  label: 'Capture',
                ),
                NavigationDestination(
                  icon: Icon(
                    CupertinoIcons.chat_bubble,
                    key: widget.destinationKeys[2],
                  ),
                  selectedIcon: Icon(
                    CupertinoIcons.chat_bubble_fill,
                    color: widget.monochrome
                        ? AppTheme.textPrimary(context)
                        : null,
                  ),
                  label: 'Ask',
                ),
                NavigationDestination(
                  icon: const Icon(CupertinoIcons.search),
                  selectedIcon: Icon(
                    CupertinoIcons.search_circle_fill,
                    color: widget.monochrome
                        ? AppTheme.textPrimary(context)
                        : null,
                  ),
                  label: 'Find',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
