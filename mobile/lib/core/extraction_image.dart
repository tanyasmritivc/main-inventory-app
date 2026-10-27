import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Run in a worker isolate. Preserve label pixels and normalize portrait EXIF.
Uint8List prepareExtractionImage(Uint8List bytes) {
  if (bytes.length < 8) return bytes;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final oriented = img.bakeOrientation(decoded);
  final longest = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  final resized = longest > 2048
      ? img.copyResize(
          oriented,
          width: (oriented.width * 2048 / longest).round(),
          height: (oriented.height * 2048 / longest).round(),
        )
      : oriented;
  resized.exif.clear();
  return img.encodeJpg(resized, quality: 92);
}
