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
  });
  final Uint8List photo;
  final String message;
  @override
  State<ExtractScanning> createState() => _ExtractScanningState();
}

class _ExtractScanningState extends State<ExtractScanning> {
  late ExtractScanPhase _phase = ExtractScanPhase.preparing.advance(
    widget.message,
  );

  @override
  void didUpdateWidget(covariant ExtractScanning oldWidget) {
    super.didUpdateWidget(oldWidget);
    _phase = _phase.advance(widget.message);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final photoHeight = (MediaQuery.sizeOf(context).height * .28).clamp(
      120.0,
      240.0,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ExtractStyle.bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              _phase.label,
              key: const Key('extraction-status'),
              style: ExtractStyle.text(18),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _phase.detail,
            style: ExtractStyle.text(14, color: ExtractStyle.tx2),
          ),
          const SizedBox(height: 16),
          ExtractPhoto(
            bytes: widget.photo,
            width: double.infinity,
            height: photoHeight,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          if (reduceMotion)
            const Align(
              alignment: Alignment.centerLeft,
              child: CupertinoActivityIndicator(animating: false),
            )
          else
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(2)),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: ExtractStyle.white,
                backgroundColor: ExtractStyle.s2,
                semanticsLabel: 'Photo analysis in progress',
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Nothing is saved until you review and approve.',
            style: ExtractStyle.text(13, color: ExtractStyle.tx2),
          ),
        ],
      ),
    );
  }
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
