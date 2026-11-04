import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/founding_access_test.dart' as audit;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  audit.foundingCapture = (name) async {
    final boundary =
        find
                .byKey(const ValueKey('founding-frame'))
                .evaluate()
                .single
                .renderObject!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final path = '${Directory.systemTemp.path}/findez-founding-$name.png';
    await File(path).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
    debugPrint('FOUNDING_IMAGE $path');
  };
  audit.main();
}
