import '../../core/ui/photo_scan_hint.dart';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'scan_region.dart';
import 'activity_label.dart';

const scanMotion = Cubic(.32, .72, 0, 1);

double scanProgressValue(String message, List<ScanRegion> regions) {
  final match = RegExp(
    r'checked\s+(\d+)\s+of\s+(\d+)',
    caseSensitive: false,
  ).firstMatch(message);
  final checked = match == null ? null : int.tryParse(match[1]!);
  final total = match == null ? null : int.tryParse(match[2]!);
  final status = message.toLowerCase();
  final done = regions
      .where(
        (r) =>
            r.phase == ScanRegionPhase.checked ||
            r.phase == ScanRegionPhase.unreadable,
      )
      .length;
  var progress =
      status.contains('finding objects') || status.contains('extracting')
      ? .25
      : 0.0;
  if (regions.isNotEmpty) {
    progress = .5 + .25 * done / regions.length;
  }
  if (total != null && total > 0 && checked != null) {
    progress = .5 + .25 * (checked / total).clamp(0.0, 1.0);
  }
  if (status.contains('reading details')) progress = math.max(progress, .5);
  if (status.contains('confidence') ||
      status.contains('preparing your review')) {
    progress = .875;
  }
  return progress;
}

/// The image's actual rectangle, excluding the letterbox margins.
Rect containedScanRect(Size image, Size frame) {
  if (image.isEmpty || frame.isEmpty) return Rect.zero;
  final scale = math.min(
    frame.width / image.width,
    frame.height / image.height,
  );
  return Rect.fromCenter(
    center: frame.center(Offset.zero),
    width: image.width * scale,
    height: image.height * scale,
  );
}

/// Maps normalized image coordinates, never the surrounding letterbox.
Rect scanBoxRect(Rect normalized, Size image, Size frame) {
  final photo = containedScanRect(image, frame);
  return Rect.fromLTRB(
    photo.left + normalized.left * photo.width,
    photo.top + normalized.top * photo.height,
    photo.left + normalized.right * photo.width,
    photo.top + normalized.bottom * photo.height,
  );
}

/// Reuses the selected image's provider/cache. No network work or scan state.
class ScanPhotoFrame extends StatefulWidget {
  const ScanPhotoFrame({
    super.key,
    required this.image,
    required this.height,
    required this.scanning,
    this.regions = const [],
  });
  final ImageProvider image;
  final double height;
  final bool scanning;
  final List<ScanRegion> regions;
  @override
  State<ScanPhotoFrame> createState() => _ScanPhotoFrameState();
}

class _ScanPhotoFrameState extends State<ScanPhotoFrame>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _size;
  bool get _reduced => MediaQuery.disableAnimationsOf(context);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
    _motion();
  }

  @override
  void didUpdateWidget(ScanPhotoFrame old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) {
      _size = null;
      _resolve();
    }
    _motion();
  }

  void _motion() {
    if (widget.scanning &&
        widget.regions.isEmpty &&
        !_reduced &&
        TickerMode.valuesOf(context).enabled) {
      if (!_sweep.isAnimating) _sweep.repeat();
    } else {
      _sweep.stop();
    }
  }

  void _resolve() {
    final next = widget.image.resolve(createLocalImageConfiguration(context));
    if (next.key == _stream?.key) return;
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = next;
    _listener = ImageStreamListener((info, synchronous) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (mounted && size != _size) {
        if (synchronous) {
          _size = size;
        } else {
          setState(() => _size = size);
        }
      }
      info.dispose();
    }, onError: (Object error, StackTrace? stack) {});
    next.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    key: const Key('scan-photo-frame'),
    duration: _reduced ? Duration.zero : const Duration(milliseconds: 600),
    curve: scanMotion,
    height: widget.height,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xff0e0e10)
          : const Color(0xffececf0),
    ),
    child: LayoutBuilder(
      builder: (context, bounds) {
        final rect = containedScanRect(_size ?? bounds.biggest, bounds.biggest);
        return Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: widget.image,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              semanticLabel: 'Photo being reviewed',
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.image_not_supported_outlined)),
            ),
            if (widget.scanning &&
                widget.regions.isEmpty &&
                !_reduced &&
                _size != null)
              Positioned.fromRect(
                rect: rect,
                child: ClipRect(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _sweep,
                      builder: (context, _) => CustomPaint(
                        painter: _ScanSweep(scanMotion.transform(_sweep.value)),
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.scanning && _size != null)
              for (final region in widget.regions)
                Positioned.fromRect(
                  key: ValueKey('scan-region-${region.id}'),
                  rect: scanBoxRect(region.box, _size!, bounds.biggest),
                  child: IgnorePointer(
                    child: Semantics(
                      label: 'Object ${region.id + 1}, ${region.status}',
                      child: AnimatedContainer(
                        duration: _reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: region.phase == ScanRegionPhase.checking
                              ? Colors.white.withValues(alpha: .10)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: .5),
                            width: region.phase == ScanRegionPhase.checking
                                ? 3
                                : 2,
                          ),
                        ),
                        foregroundDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: region.phase == ScanRegionPhase.checking
                                  ? 1
                                  : .55,
                            ),
                            width: region.phase == ScanRegionPhase.checking
                                ? 2
                                : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            if (widget.scanning && _size != null)
              for (final region in widget.regions)
                Positioned(
                  left: scanBoxRect(
                    region.box,
                    _size!,
                    bounds.biggest,
                  ).left.clamp(rect.left, math.max(rect.left, rect.right - 22)),
                  top: scanBoxRect(
                    region.box,
                    _size!,
                    bounds.biggest,
                  ).top.clamp(rect.top, math.max(rect.top, rect.bottom - 20)),
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Container(
                        key: ValueKey('scan-region-badge-${region.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: region.phase == ScanRegionPhase.checking
                              ? Colors.white
                              : const Color(0xffdddddf),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${region.id + 1}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    ),
  );
}

class _ScanSweep extends CustomPainter {
  const _ScanSweep(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final y = (size.height + 90) * progress - 90;
    final band = Rect.fromLTWH(0, y, size.width, 90);
    canvas.drawRect(
      band,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0x38ffffff), Color(0x90ffffff)],
        ).createShader(band),
    );
  }

  @override
  bool shouldRepaint(_ScanSweep old) => old.progress != progress;
}

/// Stage completion advances only on received activity, never a looping timer.
class ExtractionProgressPanel extends StatefulWidget {
  const ExtractionProgressPanel({
    super.key,
    required this.message,
    this.regions = const [],
  });
  final String message;
  final List<ScanRegion> regions;
  @override
  State<ExtractionProgressPanel> createState() =>
      _ExtractionProgressPanelState();
}

class _ExtractionProgressPanelState extends State<ExtractionProgressPanel> {
  final _steps = <String>[];
  bool _expanded = false;
  double _completedProgress = 0;
  void _record() {
    final message = widget.message.trim();
    if (message.isNotEmpty && (_steps.isEmpty || _steps.last != message)) {
      _steps.add(message);
      if (_steps.length > 30) _steps.removeAt(0);
    }
  }

  @override
  void initState() {
    super.initState();
    _record();
  }

  @override
  void didUpdateWidget(ExtractionProgressPanel old) {
    super.didUpdateWidget(old);
    _record();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? const Color(0xff98989f) : const Color(0xff6c6c70);
    final progress = scanProgressValue(widget.message, widget.regions);
    _completedProgress = math.max(_completedProgress, progress);
    final stage = _completedProgress >= .75
        ? 4
        : _completedProgress >= .5
        ? 3
        : _completedProgress >= .25
        ? 2
        : 1;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CupertinoActivityIndicator(
                radius: 8,
                animating: !reduced,
                color: secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: ActivityLabel(
                    widget.message,
                    builder: (text) => Text(
                      text,
                      style: const TextStyle(fontSize: 14, height: 1.3),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  foregroundColor: secondary,
                  padding: const EdgeInsets.only(left: 8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Steps', style: TextStyle(fontSize: 12)),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_expanded)
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      i == _steps.length - 1 ? Icons.more_horiz : Icons.check,
                      size: 14,
                      color: secondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _steps[i],
                        style: TextStyle(fontSize: 13, color: secondary),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: _completedProgress,
            semanticsLabel: 'Scan stages. Stage $stage of 4',
            minHeight: 3,
            color: dark ? Colors.white : Colors.black,
            backgroundColor: secondary.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 12),
          const PhotoScanHint(tips: false),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(width: 220, child: ScanPlaceholders()),
          ),
          const SizedBox(height: 8),
          Text(
            'Nothing is saved until you review and approve.',
            style: TextStyle(
              fontSize: 12.5,
              color: dark ? const Color(0xff636366) : const Color(0xffaeaeb2),
            ),
          ),
        ],
      ),
    );
  }
}
