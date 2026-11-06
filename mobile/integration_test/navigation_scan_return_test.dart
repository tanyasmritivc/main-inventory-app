// Runs existing user-flow fixtures on iOS and retains frames for visual review.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/ui/native_presentation.dart';
import 'package:mobile/features/world/native_bottom_tabs.dart';
import 'package:path_provider/path_provider.dart';

import '../test/ask_page_test.dart' as ask;
import '../test/world_shell_test.dart' as world;

Future<void> retainFrame(String name, Uint8List bytes) async {
  final documents = await getApplicationDocumentsDirectory();
  final directory = Directory('${documents.path}/navigation192');
  await directory.create(recursive: true);
  final file = File('${directory.path}/$name.png');
  await file.writeAsBytes(bytes, flush: true);
  debugPrint('NAVIGATION_FRAME ${file.path}');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Flutter taps exercise shell/cancellation. Actual UIKit bar taps are checked
  // separately with tool/native_tabs_visual.dart on the simulator.
  debugNativePresentationOverride = false;
  debugNativeBottomTabsOverride = false;
  world.worldAuditCapture = (name) async {
    final boundary =
        find
                .byKey(const ValueKey('world-audit-frame'))
                .evaluate()
                .single
                .renderObject!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await retainFrame(name, data!.buffer.asUint8List());
    image.dispose();
  };
  ask.previewAuditCapture = (name, bytes) =>
      retainFrame(name, Uint8List.fromList(bytes));
  group('World', world.main);
  group('Ask', ask.main);
}
