// Native rendering with synthetic APIs. Never writes customer inventory.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/world_shell_test.dart' as world;
import '../test/chat_item_action_test.dart' as actions;
import '../test/ask_page_test.dart' as chat;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('World creation and navigation', world.main);
  group('Action receipts', actions.main);
  group('Chat history and retry', chat.main);
}
