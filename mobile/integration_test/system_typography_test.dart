import 'support/synthetic_host.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/app_typography_test.dart' as typography;
import '../test/inventory_chat_test.dart' as chat;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  syntheticHostControls();
  typography.typographyCapture = (tester, name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('system-font-frame')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final path = '${Directory.systemTemp.path}/system-font-$name.png';
    await File(path).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
    debugPrint('SYSTEM_FONT_VISUAL $path');
  };
  typography.main();
  chat.main();
}
