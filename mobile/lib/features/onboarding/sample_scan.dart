import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_client.dart';
import 'chat_onboarding_draft.dart';

const _orange = Color(0xFF111111);
const samplePhoto = 'assets/onboarding/sample_workbench.jpg';

/// Bundled, explicitly labelled demonstration, never an extraction result.
class TrialSample {
  TrialSample(this.space, this.rows, this.aspect);
  final String space;
  final List<Map<String, dynamic>> rows;
  final double aspect;
  static Future<TrialSample> load() async {
    final json =
        jsonDecode(
              await rootBundle.loadString(
                'assets/onboarding/sample_workbench.json',
                cache: false,
              ),
            )
            as Map<String, dynamic>;
    final size = (json['imageSize'] as List).cast<num>();
    return TrialSample(
      json['space'],
      (json['items'] as List)
          .map((row) => Map<String, dynamic>.from(row))
          .toList(),
      size[0] / size[1],
    );
  }

  List<TrialItem> newItems() => rows
      .map(
        (row) => TrialItem(
          ExtractedInventoryItem.fromJson({...row, 'category': ''}),
          row['spot'],
          detail: row['detail'],
        ),
      )
      .toList();
}

/// Reusable orange emphasis for the sample CTA and the first real camera tap.
class TrialCameraPulse extends StatefulWidget {
  const TrialCameraPulse({super.key, required this.child});
  final Widget child;
  @override
  State<TrialCameraPulse> createState() => _TrialCameraPulseState();
}

class _TrialCameraPulseState extends State<TrialCameraPulse>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAccessibilityFeatures() {
    _sync();
  }

  void _sync() {
    if (MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: _orange.withValues(alpha: .12 + .12 * _controller.value),
            blurRadius: 8 + 8 * _controller.value,
            spreadRadius: 2 * _controller.value,
          ),
        ],
      ),
      child: child,
    ),
  );
}

class SampleScanCard extends StatefulWidget {
  const SampleScanCard({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  State<SampleScanCard> createState() => _SampleScanCardState();
}

class _SampleScanCardState extends State<SampleScanCard>
    with TickerProviderStateMixin {
  late final _beam = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late final _brackets = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _beam.stop();
      _brackets.stop();
    } else {
      _beam.repeat();
      _brackets.repeat();
    }
  }

  @override
  void dispose() {
    _beam.dispose();
    _brackets.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Scan the sample photo',
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x264B4B4B),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: AspectRatio(
            aspectRatio: 1100 / 560,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  samplePhoto,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xB3000000)],
                      stops: [.35, 1],
                    ),
                  ),
                ),
                if (!MediaQuery.disableAnimationsOf(context))
                  AnimatedBuilder(
                    animation: _beam,
                    builder: (_, _) => CustomPaint(
                      painter: _BeamPainter(_beam.value, teaser: true),
                    ),
                  ),
                AnimatedBuilder(
                  animation: _brackets,
                  builder: (_, _) => CustomPaint(
                    painter: _BracketsPainter(
                      MediaQuery.disableAnimationsOf(context)
                          ? 1
                          : .85 + .15 * math.cos(_brackets.value * math.pi * 2),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'SAMPLE PHOTO',
                              style: TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 11.5,
                                letterSpacing: .8,
                              ),
                            ),
                            Text(
                              'A workbench',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      TrialCameraPulse(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: _orange,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.document_scanner_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Scan it',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
  );
}

class SampleScanPhoto extends StatefulWidget {
  const SampleScanPhoto({
    super.key,
    required this.sample,
    required this.scanning,
    required this.onFinished,
  });
  final TrialSample sample;
  final bool scanning;
  final VoidCallback onFinished;
  @override
  State<SampleScanPhoto> createState() => _SampleScanPhotoState();
}

class _SampleScanPhotoState extends State<SampleScanPhoto>
    with SingleTickerProviderStateMixin {
  late final _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  Timer? _delay;
  bool _started = false, _finished = false;
  @override
  void didUpdateWidget(covariant SampleScanPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.scanning && widget.scanning) {
      _scan.value = 0;
      _sync();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    if (!widget.scanning) {
      _scan.value = 1;
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _delay?.cancel();
      _scan.stop();
      _scan.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    } else if (!_started) {
      _started = true;
      _delay = Timer(const Duration(milliseconds: 350), () async {
        if (!mounted) return;
        await _scan.forward();
        _finish();
      });
    }
  }

  void _finish() {
    if (!mounted || _finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _delay?.cancel();
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 292,
    padding: const EdgeInsets.all(5),
    decoration: const BoxDecoration(
      color: Color(0xFF111112),
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(22),
        topRight: Radius.circular(22),
        bottomLeft: Radius.circular(22),
        bottomRight: Radius.circular(10),
      ),
    ),
    child: ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(17),
        topRight: Radius.circular(17),
        bottomLeft: Radius.circular(17),
        bottomRight: Radius.circular(5),
      ),
      child: AspectRatio(
        aspectRatio: widget.sample.aspect,
        child: AnimatedBuilder(
          animation: _scan,
          builder: (context, _) {
            final reduce = MediaQuery.disableAnimationsOf(context);
            final progress = Curves.easeInOut.transform(_scan.value);
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  samplePhoto,
                  fit: BoxFit.fill,
                  semanticLabel: 'Sample workbench photo',
                ),
                if (widget.scanning && !reduce)
                  const ColoredBox(color: Color(0x47000000)),
                if (widget.scanning && !reduce && _scan.value > 0)
                  CustomPaint(painter: _BeamPainter(progress)),
                LayoutBuilder(
                  builder: (_, bounds) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final row in widget.sample.rows)
                        if (!widget.scanning ||
                            reduce ||
                            progress >= (row['box']['y'] as num))
                          _box(
                            row['box'] as Map<String, dynamic>,
                            bounds,
                            progress,
                            reduce,
                          ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
  Widget _box(
    Map<String, dynamic> box,
    BoxConstraints size,
    double progress,
    bool reduce,
  ) {
    final y = (box['y'] as num).toDouble();
    final pop = reduce || !widget.scanning
        ? 1.0
        : 1 + .2 * (1 - ((progress - y) / .12).clamp(0, 1));
    return Positioned(
      left: box['x'] * size.maxWidth,
      top: y * size.maxHeight,
      width: box['w'] * size.maxWidth,
      height: box['h'] * size.maxHeight,
      child: Transform.scale(
        scale: pop,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: _orange, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: y < .09 && (box['w'] as num) > .2 ? null : -2,
                right: y < .09 && (box['w'] as num) > .2 ? 0 : null,
                top: y < .09 ? 0 : -15,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _orange,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    (box['label'] as String).split(' · ').first,
                    style: const TextStyle(
                      fontFamily: 'CupertinoSystemText',
                      fontSize: 8,
                      color: Colors.white,
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

class _BeamPainter extends CustomPainter {
  _BeamPainter(this.progress, {this.teaser = false});
  final double progress;
  final bool teaser;
  @override
  void paint(Canvas canvas, Size size) {
    final y = progress * size.height;
    final rect = Rect.fromLTWH(0, y - 45, size.width, 45);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            _orange.withValues(alpha: teaser ? .15 : .45),
          ],
        ).createShader(rect),
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = _orange.withValues(alpha: teaser ? .35 : 1)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_BeamPainter old) => old.progress != progress;
}

class _BracketsPainter extends CustomPainter {
  _BracketsPainter(this.opacity);
  final double opacity;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final r = Rect.fromLTRB(18, 18, size.width - 18, size.height - 60);
    for (final corner in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      final dx = corner.dx == r.left ? 18.0 : -18.0,
          dy = corner.dy == r.top ? 18.0 : -18.0;
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx, corner.dy + dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx + dx, corner.dy),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_BracketsPainter old) => old.opacity != opacity;
}
