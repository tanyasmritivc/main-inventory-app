import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Host widget tests otherwise substitute Ahem for bundled app fonts. Load the
// production face so app-wide typography and large-text layout use real metrics.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await (FontLoader(
    'Inter',
  )..addFont(rootBundle.load('assets/fonts/inter/Inter.ttf'))).load();
  await testMain();
}
