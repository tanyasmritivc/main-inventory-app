import 'package:flutter/material.dart';

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
    return const Color(0xFFA9ADB5);
  }

  Widget get _fallback => ColoredBox(
    color: _color,
    child: Center(
      child: Text(
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
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
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback,
              ),
      ),
    );
  }
}
