import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/world_composer_test.dart' as composer;
import '../test/scan_tips_test.dart' as tips;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('composer', composer.main);
  group('tips', tips.main);
}
