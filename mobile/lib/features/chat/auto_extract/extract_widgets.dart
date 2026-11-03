import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/private_image.dart';
import 'extract_style.dart';

String extractName(Map row) {
  final raw = '${(row['item'] as Map)['name'] ?? 'Item'}'
      .split('(')
      .first
      .trim();
  return raw.isEmpty ? 'Item' : '${raw[0].toUpperCase()}${raw.substring(1)}';
}

bool extractUncertain(Map row) {
  final item = row['item'] as Map;
  final confidence =
      item['confidence'] ??
      (item['scan_evidence'] as Map?)?['identity_confidence'];
  return confidence is num && confidence < .6;
}

class ExtractPhoto extends StatelessWidget {
  const ExtractPhoto({
    super.key,
    this.bytes,
    this.url,
    this.height,
    this.width,
    this.radius = 18,
  });
  final Uint8List? bytes;
  final String? url;
  final double? height, width;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: ColoredBox(
      color: Colors.black,
      child: bytes != null
          ? Image.memory(
              bytes!,
              height: height,
              width: width,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(),
            )
          : url != null && url!.isNotEmpty
          ? PrivateImage(
              url!,
              height: height,
              width: width,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(),
            )
          : _fallback(),
    ),
  );
  Widget _fallback() => SizedBox(
    height: height ?? 120,
    width: width,
    child: const Center(
      child: Icon(CupertinoIcons.photo, color: ExtractStyle.tx3),
    ),
  );
}

class ExtractTiles extends StatelessWidget {
  const ExtractTiles({
    super.key,
    required this.rows,
    required this.onToggle,
    required this.onEdit,
    required this.quantityMissing,
    this.highlight,
  });
  final List<Map<String, dynamic>> rows;
  final ValueChanged<Map<String, dynamic>>? onToggle, onEdit;
  final bool Function(Map<String, dynamic>) quantityMissing;
  final int? highlight;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final single =
          bounds.maxWidth < 250 ||
          MediaQuery.textScalerOf(context).scale(14) > 22;
      final width = single ? bounds.maxWidth : (bounds.maxWidth - 8) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final row in rows)
            SizedBox(
              width: width,
              child: ExtractReveal(
                key: ValueKey(row['index']),
                index: row['index'] as int,
                child: _tile(row),
              ),
            ),
        ],
      );
    },
  );
  Widget _tile(Map<String, dynamic> row) {
    final selected = row['selected'] == true;
    final name = extractName(row);
    final item = row['item'] as Map;
    return Semantics(
      button: true,
      selected: selected,
      label: '${selected ? 'Leave out' : 'Include'} $name',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 350),
        opacity: selected ? 1 : .42,
        child: Material(
          color: ExtractStyle.s1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: highlight == row['index']
                  ? ExtractStyle.white
                  : ExtractStyle.line,
              width: highlight == row['index'] ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onToggle == null ? null : () => onToggle!(row),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ExtractPhoto(
                            url: item['image_url'] as String?,
                            height: 46,
                            width: 46,
                            radius: 11,
                          ),
                          Positioned(
                            left: -5,
                            top: -5,
                            child: Container(
                              width: 18,
                              height: 18,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: ExtractStyle.white,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${(row['index'] as int) + 1}',
                                style: ExtractStyle.text(
                                  10,
                                  color: ExtractStyle.ink,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  ExtractStyle.text(
                                    13.5,
                                    weight: FontWeight.w600,
                                  ).copyWith(
                                    height: 1.2,
                                    decoration: selected
                                        ? null
                                        : TextDecoration.lineThrough,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              quantityMissing(row)
                                  ? 'Quantity needed'
                                  : '×${item['quantity'] ?? '?'}${extractUncertain(row) ? ' · not sure' : ''}',
                              style: ExtractStyle.text(
                                12,
                                color: ExtractStyle.tx2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    tooltip: 'Edit $name',
                    onPressed: onEdit == null ? null : () => onEdit!(row),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: const EdgeInsets.only(left: 20, bottom: 20),
                    icon: const Icon(
                      CupertinoIcons.pencil,
                      size: 14,
                      color: ExtractStyle.tx3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ExtractScanning extends StatefulWidget {
  const ExtractScanning({
    super.key,
    required this.photo,
    required this.message,
  });
  final Uint8List photo;
  final String message;
  @override
  State<ExtractScanning> createState() => _ExtractScanningState();
}

class _ExtractScanningState extends State<ExtractScanning>
    with TickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _motion.stop();
      _dots.stop();
      _shimmer.stop();
    } else {
      _motion.repeat();
      _dots.repeat();
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    _dots.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExtractReply(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Looking at your photo',
                style: ExtractStyle.text(15.5),
              ),
            ),
            AnimatedBuilder(
              animation: _dots,
              builder: (_, _) => Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Opacity(
                        opacity:
                            .25 +
                            .75 *
                                (1 -
                                    ((_dots.value - i * .125) % 1 - .5).abs() *
                                        2),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: ExtractStyle.tx2,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          widget.message,
          style: ExtractStyle.text(13.5, color: ExtractStyle.tx2),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              ExtractPhoto(bytes: widget.photo, width: double.infinity),
              if (!MediaQuery.disableAnimationsOf(context) &&
                  !MediaQuery.accessibleNavigationOf(context))
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _motion,
                      builder: (_, _) => LayoutBuilder(
                        builder: (_, b) => Stack(
                          children: [
                            Positioned(
                              top:
                                  (-.45 +
                                      1.45 *
                                          Curves.easeInOut.transform(
                                            _motion.value,
                                          )) *
                                  b.maxHeight,
                              left: 0,
                              right: 0,
                              height: b.maxHeight * .45,
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0x00ffffff),
                                      Color(0x38ffffff),
                                      Color(0xccffffff),
                                    ],
                                    stops: [0, .85, 1],
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        const LinearProgressIndicator(
          minHeight: 3,
          color: ExtractStyle.white,
          backgroundColor: ExtractStyle.s2,
          value: .08,
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _shimmer,
          builder: (context, _) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(-3 + _shimmer.value * 6, 0),
              end: Alignment(-2 + _shimmer.value * 6, 0),
              colors: const [
                Color(0x00ffffff),
                Color(0x0fffffff),
                Color(0x00ffffff),
              ],
            ).createShader(rect),
            child: Row(
              children: [
                for (var i = 0; i < 2; i++)
                  Expanded(
                    child: Container(
                      height: 62,
                      margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
                      decoration: BoxDecoration(
                        color: ExtractStyle.s1,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class ExtractReveal extends StatefulWidget {
  const ExtractReveal({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  State<ExtractReveal> createState() => _ExtractRevealState();
}

class _ExtractRevealState extends State<ExtractReveal> {
  Timer? _timer;
  bool _visible = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timer != null || _visible) return;
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _visible = true;
      return;
    }
    _timer = Timer(Duration(milliseconds: widget.index.clamp(0, 12) * 120), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !_visible,
    child: AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 350),
      curve: ExtractStyle.curve,
      child: widget.child,
    ),
  );
}
