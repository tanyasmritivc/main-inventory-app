import 'dart:io';
import 'package:image/image.dart' as image;

// Asset export only: preserve the supplied artwork/padding, filling its
// transparent rounded corners with brand orange. iOS applies its own icon mask.
void main(List<String> args) {
  if (args.length != 1) throw ArgumentError('Supply the original 1024px PNG.');
  final source = image.decodePng(File(args.single).readAsBytesSync());
  if (source == null || source.width != 1024 || source.height != 1024) {
    throw ArgumentError('Expected a 1024x1024 PNG.');
  }
  final opaque = image.Image(width: 1024, height: 1024, numChannels: 3);
  image.fill(opaque, color: image.ColorRgb8(232, 89, 12));
  image.compositeImage(opaque, source);
  File('assets/brand/findez-app-icon.png')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(image.encodePng(opaque));
}
