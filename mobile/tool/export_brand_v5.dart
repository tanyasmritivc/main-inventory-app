import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

// Reproducible export of the supplied artwork; no shape or padding changes.
void main() {
  final icon = img.decodePng(
    File('assets/brand/findez-app-icon.png').readAsBytesSync(),
  )!;
  final mark = img.decodePng(
    File('assets/brand/findez-mark.png').readAsBytesSync(),
  )!;
  final directory = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
  final catalog =
      jsonDecode(File('${directory.path}/Contents.json').readAsStringSync())
          as Map<String, dynamic>;
  final sizes = <int>{};
  for (final entry in catalog['images'] as List) {
    final size =
        (double.parse((entry['size'] as String).split('x').first) *
                double.parse(
                  ((entry['scale'] ?? '1x') as String).replaceAll('x', ''),
                ))
            .round();
    final scaled = img.copyResize(
      icon,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );
    final opaque = img.Image(width: size, height: size, numChannels: 3);
    img.fill(opaque, color: img.ColorRgb8(14, 14, 16));
    img.compositeImage(opaque, scaled);
    File(
      '${directory.path}/${entry['filename']}',
    ).writeAsBytesSync(img.encodePng(opaque));
    sizes.add(size);
  }
  for (var scale = 1; scale <= 3; scale++) {
    final suffix = scale == 1 ? '' : '@${scale}x';
    File(
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png',
    ).writeAsBytesSync(
      img.encodePng(
        img.copyResize(
          mark,
          width: 96 * scale,
          height: 96 * scale,
          interpolation: img.Interpolation.cubic,
        ),
      ),
    );
  }
  stdout.writeln(
    'App icon pixels: ${sizes.toList()..sort()}; launch: 96, 192, 288.',
  );
}
