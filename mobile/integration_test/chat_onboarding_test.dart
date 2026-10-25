import 'package:integration_test/integration_test.dart';
import '../test/chat_onboarding_test.dart' as trial;

// Native layout/lifecycle checks with synthetic extraction/auth/API peers.
// Real camera permissions and provider consent still require device acceptance.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  trial.main();
}
