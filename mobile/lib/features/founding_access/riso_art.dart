import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum RisoPalette {
  blueSlate([
    Color(0xFF97A6B1),
    Color(0xFF748193),
    Color(0xFF4B556F),
    Color(0xFF222236),
  ]),
  terracotta([
    Color(0xFFAB5D44),
    Color(0xFFAC7A52),
    Color(0xFF757067),
    Color(0xFFD3B19E),
  ]),
  plumRust([
    Color(0xFF453349),
    Color(0xFF773F42),
    Color(0xFF996050),
    Color(0xFFB69D9F),
  ]),
  sageOlive([
    Color(0xFF576B5B),
    Color(0xFF6C7F6D),
    Color(0xFF84947F),
    Color(0xFFAAB3A9),
  ]);

  const RisoPalette(this.colors);
  final List<Color> colors;
}

class RisoArt extends StatefulWidget {
  const RisoArt({
    super.key,
    this.palette = RisoPalette.plumRust,
    required this.radius,
    this.child,
  });
  final RisoPalette palette;
  final double radius;
  final Widget? child;
  @override
  State<RisoArt> createState() => _RisoArtState();
}

class _RisoArtState extends State<RisoArt> with SingleTickerProviderStateMixin {
  late final _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );
  ui.Image? _grain;
  @override
  void initState() {
    super.initState();
    _loadGrain();
  }

  Future<void> _loadGrain() async {
    final data = await rootBundle.load('assets/textures/grain.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _grain = frame.image);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    if (media.disableAnimations || media.accessibleNavigation) {
      _drift.stop();
      _drift.value = 0;
    } else if (!_drift.isAnimating) {
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    _grain?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(widget.radius),
    child: LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -constraints.maxWidth * .12,
            right: -constraints.maxWidth * .12,
            top: -constraints.maxHeight * .12,
            bottom: -constraints.maxHeight * .12,
            child: AnimatedBuilder(
              animation: _drift,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_drift.value);
                return Transform.translate(
                  offset: Offset(
                    constraints.maxWidth * .05 * t,
                    -constraints.maxHeight * .04 * t,
                  ),
                  child: Transform.scale(
                    scale: 1 + .06 * t,
                    child: CustomPaint(
                      painter: _RisoPainter(widget.palette, _grain),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.child != null) widget.child!,
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                border: Border.all(color: Colors.white.withValues(alpha: .10)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RisoPainter extends CustomPainter {
  const _RisoPainter(this.palette, this.grain);
  final RisoPalette palette;
  final ui.Image? grain;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final colors = palette.colors;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-.5, -.866),
          end: const Alignment(.5, .866),
          colors: colors.take(3).toList(),
          stops: const [0, .55, 1],
        ).createShader(rect),
    );
    const blobs = [
      (.12, .70, .50, .60),
      (.55, .60, .55, .55),
      (.92, .10, .40, .45),
      (.25, .05, .35, .35),
    ];
    for (var i = 0; i < blobs.length; i++) {
      final b = blobs[i];
      canvas.save();
      canvas.translate(size.width * b.$1, size.height * b.$2);
      canvas.scale(size.width * b.$3, size.height * b.$4);
      canvas.drawRect(
        const Rect.fromLTRB(-2, -2, 2, 2),
        Paint()
          ..shader = ui.Gradient.radial(Offset.zero, .72, [
            colors[i],
            colors[i].withValues(alpha: 0),
          ]),
      );
      canvas.restore();
    }
    final noise = grain;
    if (noise == null) return;
    // Blend both tiled passes directly into the same gradient layer.
    for (final pass in [
      (180.0, .95, BlendMode.overlay),
      (120.0, .80, BlendMode.softLight),
    ]) {
      final matrix = Matrix4.diagonal3Values(
        pass.$1 / noise.width,
        pass.$1 / noise.height,
        1,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ImageShader(
            noise,
            TileMode.repeated,
            TileMode.repeated,
            matrix.storage,
          )
          // The supplied PNG spans pure black to white; the HTML's fractal
          // noise is centered around gray. Match that tonal range at render
          // time while retaining the original tile, blend modes and opacity.
          ..colorFilter = const ColorFilter.matrix([
            .30,
            0,
            0,
            0,
            89.6,
            0,
            .30,
            0,
            0,
            89.6,
            0,
            0,
            .30,
            0,
            89.6,
            0,
            0,
            0,
            1,
            0,
          ])
          ..filterQuality = FilterQuality.low
          ..color = Colors.white.withValues(alpha: pass.$2)
          ..blendMode = pass.$3,
      );
    }
  }

  @override
  bool shouldRepaint(_RisoPainter old) =>
      old.palette != palette || old.grain != grain;
}
