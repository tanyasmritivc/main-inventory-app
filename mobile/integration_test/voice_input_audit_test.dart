import 'package:integration_test/integration_test.dart';
import '../test/ask_page_test.dart' as chat;
import '../test/voice_capture_test.dart' as voice;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  voice.main();
  chat.main();
}
