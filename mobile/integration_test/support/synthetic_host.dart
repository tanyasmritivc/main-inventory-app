import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/background_http.dart';
import 'package:mobile/core/ui/native_presentation.dart';
import 'package:mobile/features/chat/native_scan_progress.dart';
import 'package:mobile/features/world/native_bottom_tabs.dart';

/// Imported widget assertions cannot discover embedded UIKit descendants.
/// Keep real iOS rendering while using discoverable Flutter controls and the
/// fixture's zone-scoped HTTP client. Dedicated native suites test UIKit itself.
void syntheticHostControls() {
  var ownsTextInput = false;
  setUp(() {
    // Imported widget tests inject editing values and keyboard insets. A real
    // IME both races those values and reports physical pixels to their logical
    // test viewports. Native keyboard acceptance belongs to device testing.
    final input = TestWidgetsFlutterBinding.instance.testTextInput;
    ownsTextInput = !input.isRegistered;
    if (ownsTextInput) input.register();
    debugNativePresentationOverride = false;
    debugNativeBottomTabsOverride = false;
    debugNativeScanProgressOverride = false;
    debugAssistantHttpClientFactory = http.Client.new;
  });
  tearDown(() {
    if (ownsTextInput) {
      TestWidgetsFlutterBinding.instance.testTextInput.unregister();
    }
    debugNativePresentationOverride = null;
    debugNativeBottomTabsOverride = null;
    debugNativeScanProgressOverride = null;
    debugAssistantHttpClientFactory = null;
  });
}
