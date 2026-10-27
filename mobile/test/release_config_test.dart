import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/config.dart';

void main() {
  test(
    'submission build has production HTTPS endpoints and an anonymous key',
    () {
      expect(AppConfig.validate, returnsNormally);
      final api = Uri.parse(AppConfig.apiBaseUrl);
      final auth = Uri.parse(AppConfig.supabaseUrl);
      expect(api.scheme, 'https');
      expect(auth.scheme, 'https');
      expect(api.host, 'findez.openstack.ftctools.com');
      expect(auth.host, 'findez-db.openstack.ftctools.com');
      final payload =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(
                    base64Url.normalize(
                      AppConfig.supabaseAnonKey.split('.')[1],
                    ),
                  ),
                ),
              )
              as Map<String, dynamic>;
      expect(
        payload['role'],
        'anon',
        reason: 'Never package a service credential.',
      );
    },
    skip: !const bool.fromEnvironment('VERIFY_RELEASE_CONFIG'),
  );
}
