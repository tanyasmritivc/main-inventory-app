import 'package:integration_test/integration_test.dart';
import '../test/chat_onboarding_test.dart' as onboarding;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  onboarding.main();
}
