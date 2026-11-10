import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/auth/auth_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final profiles = <Map<String, dynamic>>[];
  var metadata = <String, dynamic>{};
  const apple = MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');
  const google = MethodChannel('plugins.flutter.io/google_sign_in');
  Map<String, dynamic> user() => {
    'id': 'provider-user',
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'person@example.test',
    'created_at': '2026-01-01T00:00:00Z',
    'app_metadata': {},
    'user_metadata': metadata,
  };
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://auth.test',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((request) async {
        Object result = {};
        if (request.url.path.endsWith('/token')) {
          final token =
              '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'provider-user', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.signature';
          result = {
            'access_token': token,
            'refresh_token': 'test',
            'expires_in': 3600,
            'token_type': 'bearer',
            'user': user(),
          };
        } else if (request.url.path.endsWith('/user')) {
          if (request.method == 'PUT') {
            metadata.addAll(
              Map<String, dynamic>.from(
                jsonDecode(request.body)['data'] as Map,
              ),
            );
          }
          result = user();
        } else if (request.url.path.endsWith('/profiles')) {
          profiles.add(
            Map<String, dynamic>.from(jsonDecode(request.body) as Map),
          );
          result = <Object>[];
        }
        return http.Response(
          jsonEncode(result),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() async {
    await Supabase.instance.client.auth.signOut();
    profiles.clear();
    metadata = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          apple,
          (_) async => {
            'type': 'appleid',
            'userIdentifier': 'apple-user',
            'givenName': 'Alex',
            'familyName': 'Rivera',
            'identityToken': 'apple-token',
            'authorizationCode': 'code',
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(google, (call) async {
          if (call.method == 'signIn') {
            return {
              'id': 'google-user',
              'email': 'person@example.test',
              'displayName': 'Sam Chen',
              'idToken': 'google-token',
            };
          }
          if (call.method == 'getTokens') {
            return {'accessToken': 'google-access', 'idToken': 'google-token'};
          }
          return null;
        });
  });
  tearDown(() {
    for (final channel in [apple, google]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });
  for (final provider in ['Apple', 'Google']) {
    testWidgets('$provider signup saves provider name without typed names', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: const AuthPage(initialMethod: 'email'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('New here? Create account'));
      await tester.tap(find.text('New here? Create account'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue with $provider'));
      await tester.tap(find.text('Continue with $provider'));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
      }
      expect(find.text('Enter your first and last name.'), findsNothing);
      expect(profiles, hasLength(1));
      expect(
        profiles.single['display_name'],
        provider == 'Apple' ? 'Alex Rivera' : 'Sam Chen',
      );
      if (provider == 'Apple') expect(metadata['full_name'], 'Alex Rivera');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
