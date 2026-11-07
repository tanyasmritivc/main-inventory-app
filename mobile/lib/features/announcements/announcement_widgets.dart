import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const announcementCurve = Cubic(.32, .72, 0, 1);
bool _reduced(BuildContext context) =>
    MediaQuery.of(context).disableAnimations ||
    MediaQuery.of(context).accessibleNavigation;

class AnnouncementColors {
  AnnouncementColors(BuildContext context)
    : dark = Theme.of(context).brightness == Brightness.dark;
  final bool dark;
  Color get text => Color(dark ? 0xFFF4F4F5 : 0xFF0B0B0C);
  Color get secondary => Color(dark ? 0xFFA1A1A6 : 0xFF5C5C62);
  Color get tertiary => Color(dark ? 0xFF6B6B70 : 0xFF9A9AA0);
  Color get soft => Color(dark ? 0xFF1B1B1E : 0xFFF2F2F5);
  Color get ring => (dark ? Colors.white : Colors.black).withValues(alpha: .12);
  Color get hairline =>
      (dark ? Colors.white : Colors.black).withValues(alpha: .07);
  List<Color> get surface => dark
      ? [const Color(0xFF161618), const Color(0xFF121214)]
      : [Colors.white, const Color(0xFFF7F7F9)];
}

class AnnouncementTile extends StatelessWidget {
  const AnnouncementTile({super.key, this.size = 46});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .28),
      gradient: const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0xFF453349), Color(0xFF773F42), Color(0xFF996050)],
      ),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * .28),
            child: CustomPaint(painter: _Grain()),
          ),
        ),
        SvgPicture.asset(
          'assets/brand/findez-mark-white.svg',
          width: size * .4,
          height: size * .4,
        ),
      ],
    ),
  );
}

class _Grain extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(7);
    final paint = Paint()..color = Colors.white.withValues(alpha: .07);
    for (var i = 0; i < size.width * size.height / 5; i++) {
      canvas.drawCircle(
        Offset(r.nextDouble() * size.width, r.nextDouble() * size.height),
        .45,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Grain oldDelegate) => false;
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final c = AnnouncementColors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: c.ring),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: c.secondary,
        ),
      ),
    );
  }
}

class AnnouncementPlanRow extends StatelessWidget {
  const AnnouncementPlanRow({
    super.key,
    required this.access,
    this.onTap,
    this.current = false,
  });
  final Map<String, dynamic> access;
  final VoidCallback? onTap;
  final bool current;
  @override
  Widget build(BuildContext context) {
    final c = AnnouncementColors(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: c.surface),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: current ? c.hairline : c.ring),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  MediaQuery.textScalerOf(context).scale(16) > 24 ||
                  constraints.maxWidth < 250;
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    access['name'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    current ? 'Your plan right now' : 'Your plan',
                    style: TextStyle(fontSize: 13, color: c.secondary),
                  ),
                ],
              );
              final badge = access['badge'] is String
                  ? _Chip(access['badge'] as String)
                  : const SizedBox.shrink();
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AnnouncementTile(size: current ? 46 : 42),
                        const SizedBox(width: 12),
                        Flexible(child: badge),
                      ],
                    ),
                    const SizedBox(height: 12),
                    details,
                  ],
                );
              }
              return Row(
                children: [
                  AnnouncementTile(size: current ? 46 : 42),
                  const SizedBox(width: 12),
                  Expanded(child: details),
                  const SizedBox(width: 8),
                  badge,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class AnnouncementPlanBody extends StatelessWidget {
  const AnnouncementPlanBody({super.key, required this.access});
  final Map<String, dynamic> access;
  @override
  Widget build(BuildContext context) {
    final c = AnnouncementColors(context);
    final rows = (access['rows'] as List).cast<Map>();
    Widget value(String label) => label == 'Included'
        ? Semantics(label: 'Included', child: const _AnimatedCheck())
        : _Chip(label);
    Widget row(Widget label, Widget now, Widget free, {bool header = false}) =>
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            header ? 11 : 12,
            16,
            header ? 9 : 12,
          ),
          child: Row(
            children: [
              Expanded(child: label),
              SizedBox(width: 64, child: Center(child: now)),
              SizedBox(width: 84, child: Center(child: free)),
            ],
          ),
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            MediaQuery.textScalerOf(context).scale(14.5) > 19 ||
            constraints.maxWidth < 300;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnnouncementPlanRow(access: access, current: true),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.hairline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!stacked)
                    DefaultTextStyle(
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c.secondary,
                      ),
                      child: row(
                        const SizedBox.shrink(),
                        const Text('Now'),
                        const Text('Free plan'),
                        header: true,
                      ),
                    ),
                  for (var i = 0; i < rows.length; i++)
                    _Rise(
                      index: i,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: c.hairline)),
                        ),
                        child: stacked
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rows[i]['label'] as String,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        color: c.text,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Now: ${rows[i]['now']}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: c.secondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Free plan: ${rows[i]['free']}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: c.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : row(
                                Text(
                                  rows[i]['label'] as String,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    color: c.text,
                                  ),
                                ),
                                value(rows[i]['now'] as String),
                                value(rows[i]['free'] as String),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Rise extends StatelessWidget {
  const _Rise({required this.child, this.index = 0, this.banner = false});
  final Widget child;
  final int index;
  final bool banner;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: _reduced(context) ? 1 : 0, end: 1),
    duration: Duration(milliseconds: banner ? 600 : 450 + index * 50),
    curve: Interval(
      index * 50 / (450 + index * 50),
      1,
      curve: announcementCurve,
    ),
    builder: (_, v, child) => Opacity(
      opacity: v,
      child: Transform.translate(
        offset: Offset(0, (1 - v) * (banner ? -12 : 6)),
        child: child,
      ),
    ),
    child: child,
  );
}

class _AnimatedCheck extends StatelessWidget {
  const _AnimatedCheck();
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: _reduced(context) ? 1 : 0, end: 1),
    duration: const Duration(milliseconds: 700),
    builder: (_, v, _) => CustomPaint(
      size: const Size(17, 17),
      painter: _CheckPainter(v, AnnouncementColors(context).text),
    ),
  );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(2, 8)
      ..lineTo(6.5, 12)
      ..lineTo(15, 3.5);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      progress != old.progress || color != old.color;
}

class AnnouncementSheet extends StatelessWidget {
  const AnnouncementSheet({
    super.key,
    required this.title,
    this.line,
    required this.body,
    this.fine,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onClose,
  });
  final String title, primaryLabel;
  final String? line, fine;
  final Widget body;
  final VoidCallback onPrimary, onClose;
  @override
  Widget build(BuildContext context) {
    final c = AnnouncementColors(context);
    var pulled = 0.0;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height - 66,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: c.surface,
        ),
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: c.ring),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: c.dark ? .6 : .15),
            blurRadius: 70,
            offset: const Offset(0, -30),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: TextStyle(color: c.text, fontFamily: 'CupertinoSystemText'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 22,
                width: double.infinity,
                child: Center(
                  child: Container(
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(
                      color: c.tertiary.withValues(alpha: .5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification) pulled = 0;
                    if (notification is OverscrollNotification &&
                        notification.dragDetails != null &&
                        notification.overscroll < 0 &&
                        notification.metrics.pixels <=
                            notification.metrics.minScrollExtent) {
                      pulled -= notification.overscroll;
                      if (pulled > 60) {
                        pulled = double.negativeInfinity;
                        onClose();
                      }
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      4,
                      20,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    height: 1.15,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -.65,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: IconButton(
                                tooltip: 'Close announcement',
                                onPressed: onClose,
                                padding: const EdgeInsets.all(2),
                                icon: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: c.ring),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.xmark,
                                    size: 16,
                                    color: c.text,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (line != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              line!,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: c.secondary,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        body,
                        if (fine != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Text(
                              fine!,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.5,
                                color: c.secondary,
                              ),
                            ),
                          ),
                        const SizedBox(height: 22),
                        _Primary(label: primaryLabel, onTap: onPrimary),
                      ],
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

class _Primary extends StatefulWidget {
  const _Primary({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  State<_Primary> createState() => _PrimaryState();
}

class _PrimaryState extends State<_Primary> {
  bool down = false;
  @override
  Widget build(BuildContext context) {
    final c = AnnouncementColors(context);
    return Listener(
      onPointerDown: (_) => setState(() => down = true),
      onPointerUp: (_) => setState(() => down = false),
      onPointerCancel: (_) => setState(() => down = false),
      child: AnimatedScale(
        scale: down && !_reduced(context) ? .98 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: c.dark
                  ? [const Color(0xFFF4F4F5), const Color(0xFFD4D4D8)]
                  : [const Color(0xFF1C1C1F), const Color(0xFF0B0B0C)],
            ),
          ),
          child: TextButton(
            onPressed: widget.onTap,
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              foregroundColor: c.dark ? const Color(0xFF0B0B0C) : Colors.white,
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontFamily: 'CupertinoSystemText',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

class AnnouncementProductBody extends StatefulWidget {
  const AnnouncementProductBody({super.key});
  @override
  State<AnnouncementProductBody> createState() =>
      _AnnouncementProductBodyState();
}

class _AnnouncementProductBodyState extends State<AnnouncementProductBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduced(context)) {
      motion.stop();
      motion.value = .5;
    } else {
      motion.repeat();
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AnnouncementColors(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 150,
            child: AnimatedBuilder(
              animation: motion,
              builder: (_, _) => Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: const [
                            Color(0xFF2A2023),
                            Color(0xFF141418),
                            Color(0xFF151A24),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(-.9 + motion.value * .1, -.8),
                          radius: 1.2,
                          colors: [
                            const Color(0xFFE2864F).withValues(alpha: .7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(1, 1),
                          radius: 1,
                          colors: [
                            const Color(0xFF5E7FB8).withValues(alpha: .7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(child: CustomPaint(painter: _Grain())),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "What's new",
                        style: TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 150,
                      height: 104,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .22),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(
                              CupertinoIcons.photo,
                              size: 36,
                              color: Colors.white.withValues(alpha: .7),
                            ),
                          ),
                          Positioned(left: 18, top: 22, child: _box(42, 50)),
                          Positioned(right: 15, top: 40, child: _box(45, 42)),
                          if (!_reduced(context))
                            Positioned(
                              top: motion.value * 100,
                              left: 5,
                              right: 5,
                              child: Container(
                                height: 1,
                                color: Colors.white.withValues(alpha: .6),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final (icon, label) in [
          (CupertinoIcons.camera, 'Add a photo'),
          (CupertinoIcons.viewfinder, 'Auto Extract starts right away'),
          (CupertinoIcons.check_mark, 'Review, then save'),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.soft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: c.text),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 15, color: c.text),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _box(double w, double h) => Opacity(
    opacity: _reduced(context)
        ? 1
        : .35 + .65 * math.sin(motion.value * math.pi),
    child: Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(width: 1.5, color: Colors.white),
      ),
    ),
  );
}

class AnnouncementBanner extends StatelessWidget {
  const AnnouncementBanner({
    super.key,
    required this.planName,
    required this.onTap,
    required this.onDismiss,
  });
  final String planName;
  final VoidCallback onTap, onDismiss;
  @override
  Widget build(BuildContext context) {
    final c = AnnouncementColors(context);
    return _Rise(
      banner: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: c.surface.first,
          border: Border.all(color: c.ring),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .25),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            const AnnouncementTile(size: 32),
            const SizedBox(width: 9),
            Expanded(
              child: TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: c.text,
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: planName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      TextSpan(
                        text: ' · Free right now',
                        style: TextStyle(color: c.secondary),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss announcement banner',
              onPressed: onDismiss,
              icon: Icon(CupertinoIcons.xmark, size: 16, color: c.text),
            ),
          ],
        ),
      ),
    );
  }
}
