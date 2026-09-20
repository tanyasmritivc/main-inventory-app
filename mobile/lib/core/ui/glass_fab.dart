import 'package:flutter/material.dart';

import 'app_colors.dart';

class GlassFab extends StatelessWidget {
  const GlassFab({
    super.key,
    required this.onPressed,
    this.heroTag,
    this.icon = Icons.add_rounded,
    this.label,
  });

  final VoidCallback? onPressed;
  final Object? heroTag;
  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(label == null ? 28 : 18),
      side: const BorderSide(color: AppColors.borderStrong, width: 1),
    );
    if (label != null) {
      return FloatingActionButton.extended(
        heroTag: heroTag,
        onPressed: onPressed,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.surfaceRaised,
        elevation: 6,
        highlightElevation: 8,
        shape: shape,
        icon: Icon(icon, color: Colors.white, size: 22),
        label: Text(label!),
      );
    }
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      foregroundColor: Colors.white,
      backgroundColor: AppColors.surfaceRaised,
      elevation: 6,
      highlightElevation: 8,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.borderStrong, width: 1),
      ),
      child: Icon(icon, color: Colors.white, size: 25),
    );
  }
}
