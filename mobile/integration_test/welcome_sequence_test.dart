import 'package:integration_test/integration_test.dart';
import '../test/launch_notification_permission_test.dart' as permission;
import '../test/native_account_menu_test.dart' as settings;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  permission.main();
  settings.main();
}
