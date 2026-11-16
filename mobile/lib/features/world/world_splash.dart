import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const worldBackground = Color(0xff171e36);

/// Bundled pixel lettering avoids a font download or a flash of another typeface.
class WorldSplash extends StatelessWidget {
  const WorldSplash({super.key, this.rotate = false});

  final bool rotate;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: worldBackground,
    child: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SvgPicture.asset(
                  'assets/brand/find-world.svg',
                  width: 420,
                  semanticsLabel: 'FIND world',
                ),
              ),
              if (rotate) ...[
                const SizedBox(height: 28),
                const Icon(Icons.screen_rotation, color: Color(0xfff3f0e8)),
                const SizedBox(height: 12),
                const Text(
                  'Rotate to landscape to play',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xfff3f0e8)),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
