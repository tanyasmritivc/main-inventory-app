import 'package:integration_test/integration_test.dart';
import '../test/chat_onboarding_test.dart' as trial;

// Native offline sample/list/describe checks with synthetic auth and save peers.
// Real provider consent and the post-demo camera require device acceptance.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  trial.main();
}
