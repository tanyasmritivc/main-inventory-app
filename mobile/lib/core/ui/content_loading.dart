import 'package:flutter/material.dart';

/// A quiet status for pending inventory data, without placeholder rows or motion.
class ContentLoading extends StatelessWidget {
  const ContentLoading({super.key, this.label = 'Loading...'});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Semantics(
        liveRegion: true,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );
}
