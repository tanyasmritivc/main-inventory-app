import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/world_shell_test.dart' as world;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  world.worldAuditCapture = (name) async {
    final boundary =
        find
                .byKey(const ValueKey('world-audit-frame'))
                .evaluate()
                .single
                .renderObject!
            as RenderRepaintBoundary;
    final frame = await boundary.toImage(pixelRatio: 2);
    final bytes = (await frame.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    await File(
      '${Directory.systemTemp.path}/findez-world-$name.png',
    ).writeAsBytes(bytes);
    frame.dispose();
    debugPrint(
      'WORLD_QA_IMAGE ${Directory.systemTemp.path}/findez-world-$name.png',
    );
    await Future<void>.delayed(const Duration(seconds: 3));
  };
  world.main();
}
