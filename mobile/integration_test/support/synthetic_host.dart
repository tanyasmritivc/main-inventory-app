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
  setUp(() {
    debugNativePresentationOverride = false;
    debugNativeBottomTabsOverride = false;
    debugNativeScanProgressOverride = false;
    debugAssistantHttpClientFactory = http.Client.new;
  });
  tearDown(() {
    debugNativePresentationOverride = null;
    debugNativeBottomTabsOverride = null;
    debugNativeScanProgressOverride = null;
    debugAssistantHttpClientFactory = null;
  });
}
