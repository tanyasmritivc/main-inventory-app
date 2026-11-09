import 'dart:async';
import 'package:flutter/material.dart';

const photoScanTiming = 'Overly crowded photos can take around 4 minutes.';
const photoScanTip = 'For quicker results, photograph smaller groups of items.';

class PhotoScanHint extends StatelessWidget {
  const PhotoScanHint({super.key, this.tips = true});
  final bool tips;

  @override
  Widget build(BuildContext context) => Text(
    tips ? '$photoScanTiming $photoScanTip' : photoScanTiming,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.5,
    ),
  );
}

/// Product tips, shared by the UIKit and Flutter active-scan surfaces.
const scanTips = [
  photoScanTiming,
  'You can switch apps while scanning. Keep FindEZ open in the background and return here for the result.',
  'Scan from inside a Space to save new items directly to that Space.',
  'You can save scan results as-is and edit the details later.',
  'Not sure of a quantity? Leave it uncounted instead of guessing.',
  'Try asking “Where did I put my drill?” You can search in everyday language.',
  'Import Excel, CSV or JSON to bring an existing inventory into FindEZ.',
  'Set a low-quantity threshold on an item to help spot what needs restocking.',
  'One photo can become several item records, each with its own crop.',
  'For clearer results, spread items out and keep labels facing the camera.',
];

class RotatingScanHint extends StatefulWidget {
  const RotatingScanHint({super.key});
  @override
  State<RotatingScanHint> createState() => _RotatingScanHintState();
}

class _RotatingScanHintState extends State<RotatingScanHint>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _index = 0;
  bool _active = true;
  bool _enabled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.accessibleNavigationOf(context);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!_active || !_enabled) return;
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) setState(() => _index = (_index + 1) % scanTips.length);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.5,
    );
    return Stack(
      children: [
        // Reserve the tallest tip, so rotation never moves the scan controls.
        for (final tip in scanTips)
          ExcludeSemantics(
            child: Opacity(opacity: 0, child: Text(tip, style: style)),
          ),
        if (MediaQuery.disableAnimationsOf(context))
          Text(scanTips[_index], key: ValueKey(_index), style: style)
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(scanTips[_index], key: ValueKey(_index), style: style),
          ),
      ],
    );
  }
}
