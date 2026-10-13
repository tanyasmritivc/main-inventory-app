import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

// Simple local illustrations with explicit theme roles and no remote images.
class PhysicalMemoryGraphic extends StatelessWidget {
  const PhysicalMemoryGraphic({super.key, required this.object});
  final int object;
  @override
  Widget build(BuildContext context) => _Illustration(
    icon: [
      CupertinoIcons.hammer,
      Icons.cable_outlined,
      CupertinoIcons.cube_box,
    ][object],
    label: [
      'Illustration of a tool',
      'Illustration of a cable',
      'Illustration of lab supplies',
    ][object],
  );
}

class CaptureGraphic extends StatelessWidget {
  const CaptureGraphic({
    super.key,
    required this.captured,
    required this.duration,
  });
  final bool captured;
  final Duration duration;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: duration,
    child: _Illustration(
      key: ValueKey(captured),
      icon: captured ? Icons.fact_check_outlined : CupertinoIcons.camera,
      label: captured
          ? 'Sample photo ready for review'
          : 'Sample photo capture',
    ),
  );
}

class ConnectedWorldGraphic extends StatelessWidget {
  const ConnectedWorldGraphic({
    super.key,
    required this.shared,
    required this.duration,
  });
  final bool shared;
  final Duration duration;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: duration,
    child: _Illustration(
      key: ValueKey(shared),
      icon: shared ? CupertinoIcons.person_2 : CupertinoIcons.house,
      label: shared
          ? 'Illustration of shared inventory'
          : 'Illustration of personal inventory',
    ),
  );
}

class _Illustration extends StatelessWidget {
  const _Illustration({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: ExcludeSemantics(
      child: SizedBox(
        height: 116,
        child: Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppTheme.action.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              icon,
              size: 46,
              color: AppTheme.accentForeground(context),
            ),
          ),
        ),
      ),
    ),
  );
}
