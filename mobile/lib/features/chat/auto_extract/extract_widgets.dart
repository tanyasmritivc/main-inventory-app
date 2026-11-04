import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../../founding_access/riso_art.dart';
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
    this.fit = BoxFit.cover,
  });
  final Uint8List? bytes;
  final String? url;
  final double? height, width;
  final double radius;
  final BoxFit fit;
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
              fit: fit,
              errorBuilder: (_, _, _) => _fallback(),
            )
          : url != null && url!.isNotEmpty
          ? PrivateImage(
              url!,
              height: height,
              width: width,
              fit: fit,
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
                              style: ExtractStyle.text(13.5).copyWith(
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

enum ExtractScanPhase {
  preparing('Preparing photo...', 'Getting your photo ready for analysis.'),
  scanning('Scanning photo...', 'Checking shapes and visual features.'),
  analyzing('Analyzing details...', 'Examining the photo and reading labels.'),
  review('Preparing your review...', 'Arranging the results for you to check.');

  const ExtractScanPhase(this.label, this.detail);
  final String label, detail;

  // Server copy can include provisional object counts. Present only known,
  // count-free phases and keep heartbeats from moving the UI backwards.
  ExtractScanPhase advance(String message) {
    final text = message.toLowerCase();
    final next = switch (text) {
      _ when text.contains('review') || text.contains('render') => review,
      _
          when text.contains('detail') ||
              text.contains('identif') ||
              text.contains('recogn') ||
              text.contains('analy') =>
        analyzing,
      _
          when text.contains('scan') ||
              text.contains('detect') ||
              text.contains('finding') ||
              text.contains('segment') ||
              text.contains('reading your photo') =>
        scanning,
      _ => this,
    };
    return next.index > index ? next : this;
  }
}

class ExtractScanning extends StatefulWidget {
  const ExtractScanning({
    super.key,
    required this.photo,
    required this.message,
    this.rows = const [],
    this.done = false,
    this.stopped = false,
    this.error,
    this.onToggle,
    this.onReview,
    this.onRetake,
    this.onRetry,
  });
  final Uint8List photo;
  final String message;
  final List<Map<String, dynamic>> rows;
  final bool done, stopped;
  final String? error;
  final ValueChanged<Map<String, dynamic>>? onToggle;
  final VoidCallback? onReview, onRetake, onRetry;
  @override
  State<ExtractScanning> createState() => _ExtractScanningState();
}

class _ExtractScanningState extends State<ExtractScanning>
    with TickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  // Presentation-only activity; the API does not report a measured percentage.
  late final _activity = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 35),
  );
  double _aspect = 1;
  ui.Image? _decoded;
  bool _reduce = false;
  bool get _active => !widget.done && !widget.stopped && widget.error == null;
  @override
  void initState() {
    super.initState();
    _readAspect();
  }

  Future<void> _readAspect() async {
    final bytes = widget.photo;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final ratio = frame.image.width / frame.image.height;
      codec.dispose();
      if (mounted && identical(bytes, widget.photo)) {
        _decoded?.dispose();
        setState(() {
          _aspect = ratio;
          _decoded = frame.image;
        });
      } else {
        frame.image.dispose();
      }
    } catch (_) {
      /* The existing image error fallback remains visible. */
    }
  }

  void _motion() {
    if (_active && !_reduce) {
      if (!_sweep.isAnimating) _sweep.repeat();
      if (!_activity.isAnimating && _activity.value < 1) _activity.forward();
    } else {
      _sweep.stop();
      _activity.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    _motion();
  }

  @override
  void didUpdateWidget(covariant ExtractScanning oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.photo, widget.photo)) {
      _readAspect();
      _activity.value = 0;
    }
    _motion();
  }

  @override
  void dispose() {
    _sweep.dispose();
    _activity.dispose();
    _decoded?.dispose();
    super.dispose();
  }

  TextStyle _text(
    double size, {
    Color color = ExtractStyle.white,
    FontWeight weight = FontWeight.w400,
  }) => ExtractStyle.text(size, color: color).copyWith(fontWeight: weight);
  Widget _chip(Widget child) => ClipRRect(
    borderRadius: BorderRadius.circular(15),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
        ),
        child: child,
      ),
    ),
  );
  Widget _photo({BoxFit fit = BoxFit.contain}) => Image.memory(
    widget.photo,
    fit: fit,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => const Center(
      child: Icon(CupertinoIcons.photo, color: ExtractStyle.tx2),
    ),
  );
  Widget _stage() {
    final count = widget.rows.where((r) => r['selected'] == true).length;
    return Semantics(
      label: widget.done
          ? '${widget.rows.length} items found'
          : 'Scanning your photo',
      child: SizedBox(
        height: 300,
        key: const Key('scan-photo-stage'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const TickerMode(enabled: false, child: RisoArt(radius: 22)),
              if (_decoded != null)
                CustomPaint(painter: _ScanPhotoBackdrop(_decoded!)),
              Padding(
                padding: const EdgeInsets.all(14),
                child: LayoutBuilder(
                  builder: (_, bounds) {
                    final size = applyBoxFit(
                      BoxFit.contain,
                      Size(_aspect, 1),
                      bounds.biggest,
                    ).destination;
                    return Center(
                      child: Container(
                        width: size.width,
                        height: size.height,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .45),
                              offset: const Offset(0, 18),
                              blurRadius: 50,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ExcludeSemantics(child: _photo()),
                              IgnorePointer(
                                child: AnimatedOpacity(
                                  opacity: _active ? 1 : 0,
                                  duration: const Duration(milliseconds: 350),
                                  child: ColoredBox(
                                    color: Colors.black.withValues(alpha: .18),
                                  ),
                                ),
                              ),
                              if (_active && !_reduce)
                                IgnorePointer(
                                  child: FutureBuilder<ui.Image>(
                                    future: RisoTile.image(
                                      RisoPalette.plumRust,
                                    ),
                                    builder: (_, art) => art.data == null
                                        ? const SizedBox.shrink()
                                        : AnimatedBuilder(
                                            animation: _sweep,
                                            builder: (_, _) => CustomPaint(
                                              painter: _ScanSweep(
                                                art.data!,
                                                _sweep.value,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: .12,
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
                  },
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!widget.done) ...[
                            AnimatedBuilder(
                              animation: _sweep,
                              builder: (_, _) => Opacity(
                                opacity: _reduce
                                    ? 1
                                    : .55 +
                                          .45 *
                                              (1 -
                                                  (_sweep.value * 2 - 1).abs()),
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox(width: 8, height: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                          ],
                          Text(
                            widget.done ? 'Done' : 'Scanning',
                            style: _text(13, weight: FontWeight.w400),
                          ),
                        ],
                      ),
                    ),
                    _chip(
                      Text(
                        widget.done
                            ? '$count of ${widget.rows.length} selected'
                            : '${widget.rows.length} found',
                        style: _text(13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> row, int index) {
    final selected = row['selected'] == true;
    final item = row['item'] as Map;
    final name = extractName(row);
    final url = item['image_url'] as String?;
    return _ScanArrival(
      index: index,
      child: Semantics(
        button: widget.onToggle != null,
        onTap: widget.onToggle == null ? null : () => widget.onToggle!(row),
        selected: selected,
        label: '${index + 1}, $name, ${selected ? 'included' : 'left out'}',
        child: ExcludeSemantics(
          child: AnimatedOpacity(
            opacity: selected ? 1 : .4,
            duration: const Duration(milliseconds: 250),
            child: SizedBox(
              width: 76,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onToggle == null
                    ? null
                    : () => widget.onToggle!(row),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 76,
                      width: 76,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: url != null && url.isNotEmpty
                                ? ExtractPhoto(
                                    url: url,
                                    radius: 16,
                                    height: 76,
                                    width: 76,
                                  )
                                : RisoTile(
                                    palette: RisoPalette.forCategory(
                                      '${item['category'] ?? ''}',
                                      name,
                                    ),
                                    radius: 16,
                                    child: const Center(
                                      child: Icon(
                                        CupertinoIcons.cube,
                                        color: Colors.white70,
                                        size: 27,
                                      ),
                                    ),
                                  ),
                          ),
                          Positioned(
                            left: 5,
                            top: 5,
                            child: Container(
                              width: 18,
                              height: 18,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: ExtractStyle.white,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: _text(
                                  10.5,
                                  color: ExtractStyle.ink,
                                  weight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(12, weight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _sweep,
      builder: (_, _) => SizedBox(
        width: 76,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 76,
              decoration: BoxDecoration(
                color: Color.lerp(
                  const Color(0xFF1B1B1E),
                  const Color(0xFF29292D),
                  _reduce ? 0 : 1 - (_sweep.value * 2 - 1).abs(),
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: .07)),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 8,
              width: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1E),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final selected = widget.rows.where((r) => r['selected'] == true).length;
    final names = widget.rows
        .map(extractName)
        .map((s) => s.toLowerCase())
        .toList();
    final found = names.length < 2
        ? names.join()
        : '${names.take(names.length - 1).join(', ')} and ${names.last}';
    final terminal = widget.stopped || widget.error != null;
    final content = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF161618), Color(0xFF121214)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: terminal
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 10),
              child: Column(
                children: [
                  Text(
                    widget.stopped
                        ? 'Scan stopped'
                        : "Couldn't read this photo",
                    textAlign: TextAlign.center,
                    style: _text(
                      22,
                    ).copyWith(fontFamily: 'CupertinoSystemText'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.stopped ? 'Nothing was saved.' : widget.error!,
                    textAlign: TextAlign.center,
                    style: _text(14, color: ExtractStyle.tx2),
                  ),
                  const SizedBox(height: 16),
                  _ScanButton(
                    label: widget.stopped ? 'Scan again' : 'Try again',
                    onTap: widget.onRetry,
                    height: 44,
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _stage(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          widget.done
                              ? '${widget.rows.length} ${widget.rows.length == 1 ? 'item' : 'items'} found'
                              : 'Looking at your photo',
                          key: const Key('extraction-status'),
                          style: _text(26).copyWith(
                            fontFamily: 'CupertinoSystemText',
                            letterSpacing: -.52,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.done
                            ? 'Tap an item to leave it out, then review and save.'
                            : names.isEmpty
                            ? 'Checking shapes and labels…'
                            : 'Found $found so far',
                        style: _text(14.5, color: ExtractStyle.tx2),
                      ),
                      if (_active)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Semantics(
                            label: 'Photo analysis in progress',
                            child: ExcludeSemantics(
                              child: AnimatedBuilder(
                                animation: _activity,
                                builder: (_, _) => ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value:
                                        .14 +
                                        .76 *
                                            Curves.easeOut.transform(
                                              _activity.value,
                                            ),
                                    minHeight: 3,
                                    color: ExtractStyle.white,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: .08,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 2),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < widget.rows.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _tile(widget.rows[i], i),
                          ),
                        if (_active)
                          for (
                            var i = 0;
                            i < (widget.rows.length < 2 ? 3 : 1);
                            i++
                          )
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _placeholder(),
                            ),
                      ],
                    ),
                  ),
                ),
                if (widget.done)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: LayoutBuilder(
                      builder: (_, bounds) {
                        final review = _ScanButton(
                          label: selected == 0
                              ? 'Select items'
                              : 'Review $selected ${selected == 1 ? 'item' : 'items'}',
                          primary: true,
                          onTap: selected == 0 ? null : widget.onReview,
                        );
                        final retake = _ScanButton(
                          label: 'Retake',
                          onTap: widget.onRetake,
                        );
                        return bounds.maxWidth < 270 ||
                                MediaQuery.textScalerOf(context).scale(15.5) >
                                    22
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  review,
                                  const SizedBox(height: 8),
                                  retake,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(flex: 16, child: review),
                                  const SizedBox(width: 8),
                                  Expanded(flex: 10, child: retake),
                                ],
                              );
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          CupertinoIcons.lock,
                          size: 14,
                          color: ExtractStyle.tx3,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Nothing is saved until you review and approve.',
                          style: _text(12.5, color: ExtractStyle.tx3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: ExtractStyle.curve,
      child: content,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, _reduce ? 0 : 10 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}

// These blend into the existing photograph/art instead of covering it with
// an opaque strip. They use the same shared grain raster as the app's riso tiles.
class _ScanPhotoBackdrop extends CustomPainter {
  const _ScanPhotoBackdrop(this.image);
  final ui.Image image;
  @override
  void paint(Canvas canvas, Size size) {
    final source = Size(image.width.toDouble(), image.height.toDouble());
    final fit = applyBoxFit(BoxFit.cover, source, size);
    canvas.drawImageRect(
      image,
      Alignment.center.inscribe(fit.source, Offset.zero & source),
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.luminosity
        ..color = Colors.white.withValues(alpha: .28)
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanPhotoBackdrop old) => old.image != image;
}

class _ScanSweep extends CustomPainter {
  const _ScanSweep(this.image, this.value);
  final ui.Image image;
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    final t = const Cubic(.45, 0, .55, 1).transform(value);
    final band = Rect.fromLTWH(
      0,
      size.height * (t * 1.42 - .42),
      size.width,
      size.height * .42,
    );
    canvas.saveLayer(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.screen
        ..color = Colors.white.withValues(alpha: .95),
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      band,
      Paint(),
    );
    canvas.drawRect(
      band,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0, .35, .84, 1],
        ).createShader(band),
    );
    final line = Rect.fromLTWH(0, band.bottom - 10, size.width, 2);
    canvas.drawRect(
      line,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRect(line, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScanSweep old) =>
      old.value != value || old.image != image;
}

class _ScanButton extends StatefulWidget {
  const _ScanButton({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.height = 50,
  });
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final double height;
  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed && !MediaQuery.disableAnimationsOf(context) ? .98 : 1,
    duration: const Duration(milliseconds: 100),
    child: Opacity(
      opacity: widget.onTap == null ? .4 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: widget.primary
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF4F4F5), Color(0xFFD4D4D8)],
                )
              : null,
          border: Border.all(
            color: Colors.white.withValues(alpha: widget.primary ? .6 : .12),
          ),
          boxShadow: widget.primary
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .35),
                    offset: const Offset(0, 8),
                    blurRadius: 24,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(25),
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: widget.height,
                minWidth: 44,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Center(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: ExtractStyle.text(
                      15.5,
                      color: widget.primary
                          ? ExtractStyle.ink
                          : ExtractStyle.white,
                    ).copyWith(fontWeight: FontWeight.w400),
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

class _ScanArrival extends StatefulWidget {
  const _ScanArrival({required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  State<_ScanArrival> createState() => _ScanArrivalState();
}

class _ScanArrivalState extends State<_ScanArrival>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  Timer? _delay;
  bool _reduce = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    _delay ??= Timer(
      Duration(milliseconds: _reduce ? 0 : widget.index * 120),
      () {
        if (mounted) _animation.forward();
      },
    );
  }

  @override
  void dispose() {
    _delay?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    child: widget.child,
    builder: (_, child) => IgnorePointer(
      ignoring: _animation.value == 0,
      child: Opacity(
        opacity: _animation.value,
        child: Transform.translate(
          offset: Offset(
            _reduce
                ? 0
                : 16 * (1 - ExtractStyle.curve.transform(_animation.value)),
            0,
          ),
          child: child,
        ),
      ),
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
