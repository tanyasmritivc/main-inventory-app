import 'support/synthetic_host.dart';
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

import '../test/fluid_surfaces_test.dart' as surfaces;
import '../test/item_detail_sheet_test.dart' as details;
import '../test/world_shell_test.dart' as world;

Future<void> retainFrame(String name, Uint8List bytes) async {
  final documents = await getApplicationDocumentsDirectory();
  final directory = Directory('${documents.path}/contrast191');
  await directory.create(recursive: true);
  final file = File('${directory.path}/$name.png');
  await file.writeAsBytes(bytes, flush: true);
  debugPrint('CONTRAST_FRAME ${file.path}');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  syntheticHostControls();
  // Flutter's test driver cannot tap embedded UIKit controls. Their native
  // presentation is unchanged; this audit exercises the changed Flutter surfaces.
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
  details.itemDetailCapture = retainFrame;
  surfaces.fluidCapture = retainFrame;
  group('World', world.main);
  group('Item', details.main);
  group('Surfaces', surfaces.main);
}
