import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/chat_sources_test.dart' as sources;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  sources.sourceAuditCapture = (name) async {
    final boundary =
        find
                .byKey(const ValueKey('sources-audit-frame'))
                .evaluate()
                .single
                .renderObject!
            as RenderRepaintBoundary;
    final frame = await boundary.toImage(pixelRatio: 2);
    final bytes = (await frame.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    final path = '${Directory.systemTemp.path}/findez-sources-$name.png';
    await File(path).writeAsBytes(bytes);
    frame.dispose();
    debugPrint('WORLD_QA_IMAGE $path');
    await Future<void>.delayed(const Duration(seconds: 2));
  };
  sources.main();
}
