import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import '../test/imported_item_details_test.dart' as details;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  details.importDetailsCapture = (tester, name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('import-details-frame')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      '${(await getTemporaryDirectory()).path}/import-details-$name.png',
    );
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    debugPrint('TYPOGRAPHY_IMAGE ${file.path}');
  };
  details.main();
}
