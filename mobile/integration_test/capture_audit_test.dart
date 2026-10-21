import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/chat_capture_card_test.dart' as capture;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  capture.captureAuditCapture = (name) async {
    final boundary =
        find
                .byKey(const ValueKey('capture-audit-frame'))
                .evaluate()
                .single
                .renderObject!
            as RenderRepaintBoundary;
    final frame = await boundary.toImage(pixelRatio: 2);
    final bytes = (await frame.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    await File(
      '${Directory.systemTemp.path}/findez-capture-$name.png',
    ).writeAsBytes(bytes);
    frame.dispose();
    debugPrint(
      'WORLD_QA_IMAGE ${Directory.systemTemp.path}/findez-capture-$name.png',
    );
    await Future<void>.delayed(const Duration(seconds: 3));
  };
  capture.main();
}
