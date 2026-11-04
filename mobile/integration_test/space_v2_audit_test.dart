import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/space_v2_test.dart' as audit;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('SPACE_PROFILE')) {
    audit.spacePolishProfile = (action) async {
      await binding.watchPerformance(action, reportKey: 'space_300_scroll');
      debugPrint('SPACE_PROFILE_RESULT ${jsonEncode(binding.reportData)}');
    };
    audit.main();
    return;
  }
  audit.spaceV2Capture = (name) async {
    final boundary =
        find
                .byKey(const ValueKey('space-v2-frame'))
                .evaluate()
                .single
                .renderObject!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    final path = '${Directory.systemTemp.path}/findez-space-v2-$name.png';
    await File(path).writeAsBytes(bytes);
    image.dispose();
    debugPrint('SPACE_V2_IMAGE $path');
    await Future<void>.delayed(const Duration(seconds: 1));
  };
  audit.main();
}
