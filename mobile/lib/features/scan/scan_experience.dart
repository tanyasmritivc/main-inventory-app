import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../onboarding/sample_scan.dart' show samplePhoto;

class ScanExperience {
  ScanExperience(this.account, this.world);
  final String account, world;
  String get _key => 'findez.scan-experience.$account.$world.v1';
  String get _seenKey => 'findez.scan-experience.$account.seen.v1';
  bool scanned = false;
  int asked = 0;
  List<String> names = [];
  String? location;
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    scanned = prefs.getBool(_seenKey) == true;
    final value = jsonDecode(prefs.getString(_key) ?? '{}') as Map;
    names = (value['names'] as List? ?? []).cast<String>();
    asked = value['asked'] as int? ?? 0;
    location = value['location'] as String?;
  }

  Future<void> saved(List<String> items, String? space) async {
    if (items.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_seenKey, true)) {
      throw StateError('Could not retain scan introduction');
    }
    scanned = true;
    names = items.take(3).toList();
    location = space;
    await _persist();
  }

  Future<void> replaceSuggestions(List<String> items) async {
    names = items.take(3).toList();
    await _persist();
  }

  List<String> get questions => asked >= 3
      ? []
      : names.take(3).map((name) => 'Where is my $name?').toList();
  Future<void> used() async {
    asked++;
    await _persist();
  }

  Future<void> _persist() async {
    if (!await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode({'names': names, 'location': location, 'asked': asked}),
    )) {
      throw StateError('Could not retain scan suggestions');
    }
  }
}

/// This bundled preview never constructs a camera or requests permissions.
class ScanWelcomeWindow extends StatefulWidget {
  const ScanWelcomeWindow({super.key, required this.onTap});
  final VoidCallback? onTap;
  @override
  State<ScanWelcomeWindow> createState() => _ScanWelcomeWindowState();
}

class _ScanWelcomeWindowState extends State<ScanWelcomeWindow>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  Timer? _pause;
  bool _enabled = false;
  void _animate() {
    if (!mounted || !_enabled) return;
    _sweep.forward(from: 0).then((_) {
      if (mounted && _enabled) {
        _pause = Timer(const Duration(seconds: 1), _animate);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (enabled == _enabled) return;
    _enabled = enabled;
    _pause?.cancel();
    if (_enabled) {
      _animate();
    } else {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _pause?.cancel();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    onTap: widget.onTap,
    label: 'Scan a shelf. Example photo. Opens camera.',
    child: ExcludeSemantics(
      child: Material(
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: SizedBox(
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(samplePhoto, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CustomPaint(painter: _Brackets()),
                  ),
                ),
                AnimatedBuilder(
                  animation: _sweep,
                  builder: (_, _) => Align(
                    alignment: Alignment(0, -1 + 2 * _sweep.value),
                    child: Container(
                      height: 2,
                      color: Colors.white.withValues(alpha: .6),
                    ),
                  ),
                ),
                const Positioned(
                  top: 12,
                  right: 14,
                  child: Text(
                    'Example photo',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                const Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan a shelf',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Find items, brands and counts in a photo',
                        style: TextStyle(color: Colors.white, fontSize: 12),
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

class _Brackets extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final point in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      final dx = point.dx == 0 ? 1 : -1, dy = point.dy == 0 ? 1 : -1;
      canvas.drawPath(
        Path()
          ..moveTo(point.dx, point.dy + 16 * dy)
          ..lineTo(point.dx, point.dy)
          ..lineTo(point.dx + 16 * dx, point.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
