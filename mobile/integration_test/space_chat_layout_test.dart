import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/space_chat_layout_test.dart' as layout;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  layout.layoutCapture = (name) async {
    final boundary =
        find
                .byKey(const ValueKey('layout-frame'))
                .evaluate()
                .single
                .renderObject!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    final path = '${Directory.systemTemp.path}/findez-chat-layout-$name.png';
    await File(path).writeAsBytes(bytes);
    image.dispose();
    debugPrint('LAYOUT_QA_IMAGE $path');
    await Future<void>.delayed(const Duration(seconds: 3));
  };
  layout.main();
}
