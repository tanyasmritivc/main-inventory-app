import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/app_typography_test.dart' as typography;
import '../test/extract_photo_sheet_test.dart' as popup;
import '../test/voice_composer_test.dart' as voice;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  typography.typographyCapture = (tester, name) async {
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('typography-frame')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      final path = '${Directory.systemTemp.path}/typography-$name.png';
      await File(path).writeAsBytes(bytes);
      image.dispose();
      debugPrint('TYPOGRAPHY_IMAGE $path');
    });
  };
  popup.photoSheetCapture = (name, bytes) async {
    final path = '${Directory.systemTemp.path}/$name.png';
    await File(path).writeAsBytes(bytes);
    debugPrint('TYPOGRAPHY_IMAGE $path');
  };
  voice.voiceComposerCapture = (name, bytes) async {
    final path = '${Directory.systemTemp.path}/$name.png';
    await File(path).writeAsBytes(bytes);
    debugPrint('TYPOGRAPHY_IMAGE $path');
  };
  typography.main();
  popup.main();
  voice.main();
}
