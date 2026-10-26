// Native controls, synthetic API only. No production feedback or inventory writes.
import 'package:integration_test/integration_test.dart';
import '../test/message_actions_test.dart' as feedback;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  feedback.main();
}
