import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/space_directory_test.dart' as spaces;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  spaces.spaceAuditCapture = (name) async {
    final boundary =
        find
                .byKey(const ValueKey('spaces-audit-frame'))
                .evaluate()
                .single
                .renderObject!
            as RenderRepaintBoundary;
    final frame = await boundary.toImage(pixelRatio: 2);
    final bytes = (await frame.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    await File(
      '${Directory.systemTemp.path}/findez-spaces-$name.png',
    ).writeAsBytes(bytes);
    frame.dispose();
    debugPrint(
      'WORLD_QA_IMAGE ${Directory.systemTemp.path}/findez-spaces-$name.png',
    );
    await Future<void>.delayed(const Duration(seconds: 3));
  };
  spaces.main();
}
