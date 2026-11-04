import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import '../test/photo_scan_card_test.dart' as scan;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  scan.photoScanCapture = (name, bytes) async {
    final path = '${Directory.systemTemp.path}/$name.png';
    await File(path).writeAsBytes(bytes);
    debugPrint('PHOTO_SCAN_IMAGE $path');
  };
  scan.main();
}
