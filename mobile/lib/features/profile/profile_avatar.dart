import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.url,
    this.radius = 24,
  });

  final String name;
  final String url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final fallback = Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      color: t.raised,
      child: Text(
        name.isEmpty ? '' : name.characters.first.toUpperCase(),
        style: TextStyle(color: t.ink, fontSize: radius * .65),
      ),
    );
    return ClipOval(
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : fallback,
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
    );
  }
}
