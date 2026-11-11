import 'support/synthetic_host.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import '../test/voice_composer_test.dart' as composer;
import '../test/ask_page_test.dart' as chat;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  syntheticHostControls();
  composer.voiceComposerCapture = (name, bytes) async {
    final path = '${Directory.systemTemp.path}/voice-composer-$name.png';
    await File(path).writeAsBytes(bytes);
    debugPrint('VOICE_COMPOSER_VISUAL $path');
  };
  composer.main();
  chat.main();
}
