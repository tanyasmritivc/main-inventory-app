import 'package:flutter/material.dart';

const photoScanTiming = 'Crowded photos can take around 4 minutes.';
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
