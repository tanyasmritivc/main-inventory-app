import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/onboarding_v5_test.dart' as onboarding;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var count = 0;
  onboarding.main(
    capture: const bool.fromEnvironment('ONBOARDING_V5_EVIDENCE')
        ? (tester, name) async {
            await tester.pumpAndSettle();
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byType(RepaintBoundary).first,
            );
            final frame = await boundary.toImage(pixelRatio: 2);
            final bytes = (await frame.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List();
            final file = File(
              '${Directory.systemTemp.path}/onboarding-v5-${count++}-$name.png',
            );
            await file.writeAsBytes(bytes);
            debugPrint('ONBOARDING_V5_IMAGE ${file.path}');
            frame.dispose();
          }
        : null,
  );
}
