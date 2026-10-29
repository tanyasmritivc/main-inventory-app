import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pending_world.dart';
import 'world_motion.dart';
export 'world_motion.dart' show WorldCamera, WorldModel;

class WorldScene extends StatefulWidget {
  const WorldScene({
    super.key,
    required this.setup,
    required this.camera,
    this.mini = false,
    this.personalMini = false,
    this.reduced = false,
    this.focused = false,
    this.morphFrom,
  });
  final PendingWorld setup;
  final WorldCamera camera;
  final WorldCamera? morphFrom;
  final bool mini, personalMini, reduced, focused;
  @override
  State<WorldScene> createState() => _WorldSceneState();
}

class _WorldSceneState extends State<WorldScene> with TickerProviderStateMixin {
  late final WorldModel _model;
  @override
  void initState() {
    super.initState();
    _model = WorldModel(
      this,
      widget.setup,
      widget.camera,
      mini: widget.mini,
      personalMini: widget.personalMini,
      reduced: widget.reduced,
    );
  }

  @override
  void didUpdateWidget(covariant WorldScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _model.update(
      widget.setup,
      widget.camera,
      reduce: widget.reduced,
      tileOrigin: widget.morphFrom,
      focused: widget.focused,
    );
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final tagWidth = math.max(
        44.0,
        math.min(300.0, constraints.maxWidth - 48),
      );
      return Semantics(
        image: true,
        hidden: !_model.shown,
        label:
            'Your world. ${_model.personal ? 'Personal' : 'Organization: ${_model.organization}'}. '
            '${_model.hasBlock ? 'Workspace: ${widget.setup.workspacePurpose}. ' : ''}'
            '${_model.hasTray ? 'Inventory: ${widget.setup.inventoryName}.' : ''}',
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: WorldPainter(_model)),
                ),
                if (!widget.mini) ...[
                  _tag(
                    0,
                    _model.organization,
                    _model.personal
                        ? const Color(0xFF838383)
                        : const Color(0xFF727272),
                    tagWidth,
                  ),
                  _tag(
                    1,
                    widget.setup.workspacePurpose,
                    const Color(0xFFB2B2B2),
                    tagWidth,
                  ),
                  _tag(
                    2,
                    widget.setup.inventoryName,
                    const Color(0xFFC5C5C5),
                    tagWidth,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget _tag(int level, String label, Color dot, double maxWidth) =>
      AnimatedBuilder(
        animation: _model,
        child: level == 0
            ? _TagContents(label: label, dot: dot, maxWidth: maxWidth)
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _TagContents(
                  key: ValueKey(label),
                  label: label,
                  dot: dot,
                  maxWidth: maxWidth,
                ),
              ),
        builder: (context, child) {
          final opacity =
              _model.opacity *
              switch (level) {
                0 => _model.organizationTagOpacity,
                1 => _model.hasTray ? 0.0 : _model.blockTagOpacity,
                _ => _model.trayTagOpacity,
              };
          final at = switch (level) {
            0 => _model.camera.project(100, 100, -6),
            1 => _model.camera.project(-20, -20, 110),
            _ => _model.camera.project(-20, -20, 150),
          };
          return Positioned(
            left: at.dx,
            top: at.dy,
            child: FractionalTranslation(
              translation: const Offset(-.5, -.5),
              child: Offstage(
                offstage: opacity <= 0 || label.isEmpty,
                child: Opacity(
                  opacity: label.isEmpty ? 0 : opacity.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            ),
          );
        },
      );
}

class _TagContents extends StatelessWidget {
  const _TagContents({
    super.key,
    required this.label,
    required this.dot,
    required this.maxWidth,
  });
  final String label;
  final Color dot;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: 30, maxWidth: maxWidth),
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .96),
      border: Border.all(color: const Color(0xFFE0E0E0)),
      borderRadius: BorderRadius.circular(40),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F111112),
          offset: Offset(0, 4),
          blurRadius: 12,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'CupertinoSystemText',
              color: Color(0xFF111112),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Native canvas geometry, built from the supplied projection and dimensions.
class WorldPainter extends CustomPainter {
  WorldPainter(this.model) : super(repaint: model);
  final WorldModel model;
  WorldCamera get camera => model.camera;
  bool get personal => model.personal;
  bool get mini => model.mini;
  bool get personalMini => model.personalMini;
  double get workspace => model.blockHeight;
  double get tray => model.trayHeight;
  double get ghost => model.ghostOpacity;
  double get itemsTime => model.itemsTime;
  Color visible(Color color) =>
      color.withValues(alpha: color.a * model.opacity);
  static const _blue = [
    Color(0xFFE6E6E6),
    Color(0xFFB7B7B7),
    Color(0xFFD1D1D1),
  ];
  static const _orange = [
    Color(0xFFE7E7E7),
    Color(0xFFA5A5A5),
    Color(0xFFC3C3C3),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    if (model.opacity <= 0) return;
    if (personalMini) {
      _box(canvas, 0, 0, 0, 90, 90, 40, _blue);
      return;
    }
    if (!mini) {
      final shadow = Rect.fromCenter(
        center: camera.project(0, 0, -18),
        width: 480 * camera.scale,
        height: 240 * camera.scale,
      );
      canvas.drawOval(
        shadow,
        Paint()
          ..shader = RadialGradient(
            colors: [
              visible(
                const Color(0x1A111112),
              ).withValues(alpha: .10 * model.opacity * model.shadowOpacity),
              const Color(0x00111112),
            ],
          ).createShader(shadow),
      );
    }
    final outline = personal
        ? const Color(0xFF838383)
        : const Color(0xFF727272);
    _box(
      canvas,
      0,
      0,
      0,
      200,
      200,
      22,
      personal
          ? const [Colors.white, Color(0xFFDCDCDC), Color(0xFFEBEBEB)]
          : const [Colors.white, Color(0xFFD1D1D1), Color(0xFFE3E3E3)],
    );
    final top = _polygon([
      (-100.0, -100.0, 22.0),
      (100.0, -100.0, 22.0),
      (100.0, 100.0, 22.0),
      (-100.0, 100.0, 22.0),
    ]);
    canvas.drawPath(
      top,
      Paint()
        ..color = visible(outline)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );
    final base = Path()
      ..moveTo(
        camera.project(-100, 100, 0).dx,
        camera.project(-100, 100, 0).dy,
      );
    for (final p in [
      camera.project(100, 100, 0),
      camera.project(100, -100, 0),
    ]) {
      base.lineTo(p.dx, p.dy);
    }
    base.close();
    canvas.drawPath(
      base,
      Paint()
        ..color = visible(outline.withValues(alpha: .35))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (ghost > 0) {
      for (final center in [const Offset(62, -50), const Offset(-50, 62)]) {
        final path = _polygon([
          (center.dx - 28, center.dy - 28, 22.5),
          (center.dx + 28, center.dy - 28, 22.5),
          (center.dx + 28, center.dy + 28, 22.5),
          (center.dx - 28, center.dy + 28, 22.5),
        ]);
        final paint = Paint()
          ..color = visible(
            const Color(0xFF878787).withValues(alpha: .6 * ghost),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        for (final metric in path.computeMetrics()) {
          for (double start = 0; start < metric.length; start += 8) {
            canvas.drawPath(
              metric.extractPath(start, math.min(start + 4, metric.length)),
              paint,
            );
          }
        }
      }
    }
    if (workspace <= 0) return;
    final blockTop = 22 + 46 * workspace;
    _box(canvas, -20, -20, 22, 110, 110, 46 * workspace, _blue);
    if (tray <= 0) return;
    _box(canvas, -20, -20, blockTop, 70, 70, 12 * tray, _orange);
    if (mini || itemsTime < 0) return;
    const cubes = [
      (-36.0, -38.0, 0),
      (-14.0, -40.0, 1),
      (-38.0, -14.0, 2),
      (-12.0, -16.0, 3),
      (-24.0, -2.0, 4),
      (0.0, -26.0, 0),
      (-2.0, -2.0, 2),
    ];
    const shades = [
      [Colors.white, Color(0xFFB8B8B8), Color(0xFFD9D9D9)],
      [Color(0xFF727272), Color(0xFF4B4B4B), Color(0xFF5F5F5F)],
      [Color(0xFFC5C5C5), Color(0xFF8F8F8F), Color(0xFFA9A9A9)],
      [Color(0xFFC9C9C9), Color(0xFF949494), Color(0xFFB0B0B0)],
      [Color(0xFFD1D1D1), Color(0xFF8B8B8B), Color(0xFFAFAFAF)],
    ];
    final order = List<int>.generate(7, (i) => i)
      ..sort(
        (a, b) =>
            (cubes[a].$1 + cubes[a].$2).compareTo(cubes[b].$1 + cubes[b].$2),
      );
    for (final index in order) {
      final progress = model.itemProgress(index);
      if (progress <= 0) continue;
      final dz = model.itemElevation(index);
      final edge = 12.0 + (index % 3) * 2;
      final cube = cubes[index];
      _box(
        canvas,
        cube.$1,
        cube.$2,
        blockTop + 12 * tray + dz,
        edge,
        edge,
        edge,
        shades[cube.$3]
            .map((c) => c.withValues(alpha: (progress * 3).clamp(0, 1)))
            .toList(),
      );
    }
  }

  Path _polygon(List<(double, double, double)> points) {
    final first = camera.project(
      points.first.$1,
      points.first.$2,
      points.first.$3,
    );
    final path = Path()..moveTo(first.dx, first.dy);
    for (final point in points.skip(1)) {
      final p = camera.project(point.$1, point.$2, point.$3);
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  void _box(
    Canvas canvas,
    double x,
    double y,
    double z,
    double width,
    double depth,
    double height,
    List<Color> colors,
  ) {
    final left = x - width / 2,
        right = x + width / 2,
        back = y - depth / 2,
        front = y + depth / 2,
        top = z + height;
    final faces = [
      [
        (left, front, z),
        (right, front, z),
        (right, front, top),
        (left, front, top),
      ],
      [
        (right, back, z),
        (right, front, z),
        (right, front, top),
        (right, back, top),
      ],
      [
        (left, back, top),
        (right, back, top),
        (right, front, top),
        (left, front, top),
      ],
    ];
    for (var i = 0; i < 3; i++) {
      canvas.drawPath(
        _polygon(faces[i]),
        Paint()..color = visible(colors[[1, 2, 0][i]]),
      );
    }
  }

  @override
  bool shouldRepaint(covariant WorldPainter old) => old.model != model;
}
