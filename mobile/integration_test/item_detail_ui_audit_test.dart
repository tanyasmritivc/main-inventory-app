import 'support/synthetic_host.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import '../test/item_detail_sheet_test.dart' as detail;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  syntheticHostControls();
  detail.itemDetailCapture = (name, bytes) async {
    final path = '${Directory.systemTemp.path}/fluid-$name.png';
    await File(path).writeAsBytes(bytes);
    debugPrint('FLUID_VISUAL $path');
  };
  detail.main();
}
