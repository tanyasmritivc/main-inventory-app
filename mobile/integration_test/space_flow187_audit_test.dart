import 'support/synthetic_host.dart';
// Synthetic APIs only; production always targets lib/main.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/chat_capture_card_test.dart' as capture;
import '../test/world_shell_test.dart' as world;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Assertions inspect Flutter sheet descendants; UIKit is checked separately.
  syntheticHostControls();
  group('Draft creation', capture.main);
  group('Shell', world.main);
}
