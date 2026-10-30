import 'package:flutter/material.dart';

/// UUID-based distribution keeps the four supplied textures stable across devices,
/// renames and rebuilds, without changing the Space API or storing extra metadata.
int spaceTextureIndex(String identity) {
  var hash = 0x811c9dc5;
  for (final unit in identity.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash % 4;
}

class SpaceTexture extends StatelessWidget {
  const SpaceTexture({super.key, required this.identity, this.size = 52});
  final String identity;
  final double size;

  @override
  Widget build(BuildContext context) {
    final index = spaceTextureIndex(identity);
    // Crop via layout, leaving the original artwork intact. Each 600x360 region
    // excludes the atlas captions, palette swatches, labels and white dividers.
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox.square(
          dimension: size,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 600,
              height: 360,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: index.isOdd ? -780 : -20,
                    top: index >= 2 ? -535 : -20,
                    width: 1536,
                    height: 1024,
                    child: Image.asset(
                      'assets/brand/space-textures.png',
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
