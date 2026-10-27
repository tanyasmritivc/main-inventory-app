import 'package:integration_test/integration_test.dart';
import '../test/store_screen_matrix_test.dart' as screens;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Capture the native Flutter render tree, independent of the test runner's
  // platform splash surface when using synthetic viewport sizes.
  screens.main(
    capture: (name, bytes) async {
      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['screenshots'] ??= <dynamic>[];
      (binding.reportData!['screenshots'] as List<dynamic>).add({
        'screenshotName': name,
        'bytes': bytes,
      });
    },
  );
}
