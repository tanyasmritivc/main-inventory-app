import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/config.dart';

void main() {
  const verifyReleaseConfig = bool.fromEnvironment('VERIFY_RELEASE_CONFIG');

  test(
    'release launch configuration is compiled into the app',
    () {
      AppConfig.validate(release: true);
      expect(Uri.parse(AppConfig.supabaseUrl).host, isNotEmpty);
      expect(Uri.parse(AppConfig.apiBaseUrl).host, isNotEmpty);
    },
    skip: verifyReleaseConfig ? false : 'Run with production dart defines.',
  );
}
