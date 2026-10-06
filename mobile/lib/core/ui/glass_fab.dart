import '../../core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/ui/app_text.dart';

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
      side: BorderSide(
        color: AppTheme.adaptive(context, Color(0x33FFFFFF)),
        width: 1,
      ),
    );
    if (label != null) {
      return FloatingActionButton.extended(
        heroTag: heroTag,
        onPressed: onPressed,
        foregroundColor: AppTheme.adaptive(context, Colors.white),
        backgroundColor: AppTheme.adaptive(context, const Color(0xCC2C2C2E)),
        elevation: 6,
        highlightElevation: 8,
        shape: shape,
        icon: Icon(
          icon,
          color: AppTheme.foreground(context, Colors.white),
          size: 22,
        ),
        label: AppText(label!),
      );
    }
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      foregroundColor: AppTheme.adaptive(context, Colors.white),
      backgroundColor: AppTheme.adaptive(context, const Color(0xCC2C2C2E)),
      elevation: 6,
      highlightElevation: 8,
      shape: CircleBorder(
        side: BorderSide(
          color: AppTheme.adaptive(context, Color(0x33FFFFFF)),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: AppTheme.foreground(context, Colors.white),
        size: 25,
      ),
    );
  }
}
