import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import '../test/extract_photo_sheet_test.dart' as popup;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  popup.photoSheetCapture = (name, bytes) async {
    final path = '${Directory.systemTemp.path}/$name.png';
    await File(path).writeAsBytes(bytes);
    debugPrint('PHOTO_SHEET_IMAGE $path');
  };
  popup.main();
}
