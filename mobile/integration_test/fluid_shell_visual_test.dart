import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/world_shell_test.dart' as world;
import '../test/space_directory_test.dart' as spaces;
import '../test/space_scroll_test.dart' as scroll;

Future<void> capture(String key, String name) async {
  final boundary =
      find.byKey(ValueKey(key)).evaluate().single.renderObject!
          as RenderRepaintBoundary;
  final frame = await boundary.toImage(pixelRatio: 2);
  final bytes = (await frame.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
  final path = '${Directory.systemTemp.path}/findez-fluid-$name.png';
  await File(path).writeAsBytes(bytes);
  frame.dispose();
  debugPrint('FLUID_VISUAL $path');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  world.worldAuditCapture = (name) => capture('world-audit-frame', name);
  spaces.spaceAuditCapture = (name) => capture('spaces-audit-frame', name);
  scroll.spaceScrollCapture = (name) => capture('space-scroll-frame', name);
  group('World', world.main);
  group('Spaces', spaces.main);
  group('Detail', scroll.main);
}
