import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/auth/auth_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final appleRequests = <Map<dynamic, dynamic>>[];
  final tokenRequests = <Map<String, dynamic>>[];
  const channel = MethodChannel(
    'com.aboutyou.dart_packages.sign_in_with_apple',
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'performAuthorizationRequest') {
            appleRequests.add(
              Map<dynamic, dynamic>.from((call.arguments as List).single),
            );
            return {
              'type': 'appleid',
              'authorizationCode': 'test-code',
              'identityToken': 'test-token',
            };
          }
          return true;
        });
    await Supabase.initialize(
      url: 'https://auth.test',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          tokenRequests.add(jsonDecode(request.body) as Map<String, dynamic>);
        }
        // Stop before creating a session; this exercises the real native/auth
        // request boundary without any provider account or profile writes.
        return http.Response(
          '{"msg":"Test provider rejected token"}',
          400,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await Supabase.instance.dispose();
  });

  testWidgets(
    'Apple and Supabase receive a matching fresh nonce on every attempt',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: const AuthPage(),
        ),
      );
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.ensureVisible(find.text('Continue with Apple'));
        await tester.tap(find.text('Continue with Apple'));
        await tester.pumpAndSettle();
        expect(appleRequests.length, attempt + 1);
        expect(tokenRequests.length, attempt + 1);
        final rawNonce = tokenRequests.last['nonce'] as String;
        expect(base64Url.decode(rawNonce).length, greaterThanOrEqualTo(16));
        expect(
          appleRequests.last['nonce'],
          sha256.convert(utf8.encode(rawNonce)).toString(),
        );
        expect(tokenRequests.last['provider'], 'apple');
        expect(tokenRequests.last['id_token'], 'test-token');
        expect(tester.takeException(), isNull);
      }
      expect(tokenRequests.first['nonce'], isNot(tokenRequests.last['nonce']));
    },
  );
}
