import 'package:integration_test/integration_test.dart';
import '../test/retained_tab_transition_test.dart' as motion;
import '../test/world_composer_test.dart' as composer;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  motion.main();
  composer.main();
}
