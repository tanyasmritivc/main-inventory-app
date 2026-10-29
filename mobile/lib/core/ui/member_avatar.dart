import 'package:flutter/material.dart';
import 'package:mobile/core/ui/app_text.dart';

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.colorHex,
    this.size = 40,
  });

  final String name;
  final String? photoUrl;
  final String? colorHex;
  final double size;

  Color get _color {
    final hex = (colorHex ?? '').replaceAll('#', '');
    if (hex.length == 6) {
      final value = int.tryParse('FF$hex', radix: 16);
      if (value != null) return Color(value);
    }
    return const Color(0xFFADADAD);
  }

  Widget get _fallback => ColoredBox(
    color: _color,
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(size * 0.1),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: AppText(
            name.trim().isNotEmpty
                ? name.trim().characters.first.toUpperCase()
                : '?',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final url = (photoUrl ?? '').trim();
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: url.isEmpty
            ? _fallback
            : Image.network(
                key: ValueKey(url),
                url,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                frameBuilder: (_, child, frame, loaded) =>
                    frame == null && !loaded ? _fallback : child,
                errorBuilder: (_, _, _) => _fallback,
              ),
      ),
    );
  }
}
