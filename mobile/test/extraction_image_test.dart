import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mobile/core/extraction_image.dart';

void main() {
  test('preserves detail up to 2048 and bounds portrait and landscape', () {
    for (final dimensions in [(2600, 1300), (1300, 2600), (1800, 1200)]) {
      final input = img.Image(width: dimensions.$1, height: dimensions.$2);
      final output = img.decodeJpg(
        prepareExtractionImage(img.encodePng(input)),
      )!;
      final scale = dimensions.$1 > 2048
          ? 2048 / dimensions.$1
          : dimensions.$2 > 2048
          ? 2048 / dimensions.$2
          : 1;
      expect(output.width, (dimensions.$1 * scale).round());
      expect(output.height, (dimensions.$2 * scale).round());
    }
  });
  test('rotates EXIF pixels once and strips metadata', () {
    final input = img.Image(width: 80, height: 40);
    input.exif.imageIfd.orientation = 6;
    final output = img.decodeJpg(prepareExtractionImage(img.encodeJpg(input)))!;
    expect((output.width, output.height), (40, 80));
    expect(output.exif.imageIfd.orientation, isNot(6));
  });
  test('leaves unsupported input for server validation', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    expect(prepareExtractionImage(bytes), bytes);
  });
}
