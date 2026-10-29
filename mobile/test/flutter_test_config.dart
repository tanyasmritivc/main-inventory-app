import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Host tests have no platform font resolution. Use the installed Apple system
// face on macOS, with a deterministic open-source metric fixture on Linux CI.
// Neither face is bundled for SF Pro; native iOS tests use the OS font directly.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final systemFont = File('/System/Library/Fonts/SFNS.ttf');
  final fixture = systemFont.existsSync()
      ? systemFont
      : File('assets/fonts/Geist-Regular.ttf');
  await (FontLoader('CupertinoSystemText')..addFont(
        Future.value(ByteData.sublistView(await fixture.readAsBytes())),
      ))
      .load();
  await testMain();
}
