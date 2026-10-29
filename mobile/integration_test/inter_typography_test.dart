import 'package:integration_test/integration_test.dart';
import '../test/app_typography_test.dart' as typography;
import '../test/inventory_chat_test.dart' as chat;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  typography.main();
  chat.main();
}
