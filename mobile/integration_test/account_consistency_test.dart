import 'package:integration_test/integration_test.dart';
import '../test/space_live_refresh_test.dart' as spaces;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  spaces.main();
}
