import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import '../test/ask_page_test.dart' as chat;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  chat.previewAuditCapture = (name, bytes) async {
    final path = '${Directory.systemTemp.path}/$name.png';
    await File(path).writeAsBytes(bytes);
    debugPrint('EXTRACTION_AUDIT_IMAGE $path');
    binding.reportData ??= <String, dynamic>{};
    binding.reportData!['screenshots'] ??= <dynamic>[];
    (binding.reportData!['screenshots'] as List<dynamic>).add({
      'screenshotName': name,
      'bytes': bytes,
    });
  };
  chat.main();
}
