import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import '../test/fluid_surfaces_test.dart' as surfaces;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  surfaces.fluidCapture = (name, bytes) async {
    final path = '${Directory.systemTemp.path}/fluid-$name.png';
    await File(path).writeAsBytes(bytes);
    debugPrint('FLUID_VISUAL $path');
  };
  surfaces.main();
}
