import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/account_deletion.dart';
import 'package:mobile/core/last_place.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var status = 200;
  var apple = false;
  var cancelApple = false;
  final deletionBodies = <String>[];
  const appleChannel = MethodChannel(
    'com.aboutyou.dart_packages.sign_in_with_apple',
  );
  Map<String, dynamic> body = {};
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://auth.test',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((r) async {
        if (r.url.path.endsWith('delete-user')) {
          deletionBodies.add(r.body);
          return http.Response(
            jsonEncode(body),
            status,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'access_token':
                '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode('{"sub":"actor","exp":9999999999}'))}.signature',
            'refresh_token': 'test',
            'expires_in': 3600,
            'token_type': 'bearer',
            'user': {
              'id': 'actor',
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'actor@example.test',
              'created_at': '2026-01-01T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
              'identities': apple
                  ? [
                      {
                        'id': 'apple-actor',
                        'user_id': 'actor',
                        'provider': 'apple',
                        'identity_data': {'sub': 'apple-actor'},
                        'created_at': '2026-01-01T00:00:00Z',
                        'last_sign_in_at': '2026-01-01T00:00:00Z',
                        'updated_at': '2026-01-01T00:00:00Z',
                      },
                    ]
                  : [],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'actor@example.test',
      password: 'test',
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() async {
    status = 200;
    body = {};
    apple = false;
    cancelApple = false;
    deletionBodies.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appleChannel, (call) async {
          if (cancelApple) {
            throw PlatformException(
              code: 'authorization-error/canceled',
              message: 'cancelled',
            );
          }
          return {
            'type': 'appleid',
            'authorizationCode': 'fresh-code',
            'identityToken': 'test-token',
          };
        });
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'actor@example.test',
      password: 'test',
    );
    await LastPlaceStore(
      'actor',
    ).save(const LastPlace.workspace('ftc'), isCurrent: () => true);
  });
  test('unconfirmed response keeps local place and login', () async {
    await expectLater(requestAccountDeletion(), throwsFormatException);
    expect((await LastPlaceStore('actor').read()).id, 'ftc');
    expect(Supabase.instance.client.auth.currentUser?.id, 'actor');
  });
  test('ownership error is actionable and does not clear state', () async {
    status = 409;
    body = {
      'code': 'OWNERSHIP_REQUIRED',
      'error': 'Transfer the organization before deleting your account.',
    };
    await expectLater(
      requestAccountDeletion(),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Transfer the organization'),
        ),
      ),
    );
    expect((await LastPlaceStore('actor').read()).id, 'ftc');
  });
  test('only confirmed deletion clears the saved place', () async {
    body = {'success': true};
    await requestAccountDeletion();
    expect((await LastPlaceStore('actor').read()).isPersonal, true);
  });
  test(
    'Apple accounts send fresh native authorization for server revocation',
    () async {
      apple = true;
      await Supabase.instance.client.auth.signInWithPassword(
        email: 'actor@example.test',
        password: 'test',
      );
      body = {'success': true};
      await requestAccountDeletion();
      expect(jsonDecode(deletionBodies.single), {
        'apple_authorization_code': 'fresh-code',
        'apple_client_id': 'com.findez.app',
      });
    },
  );
  test('cancelled Apple authorization sends no deletion request', () async {
    apple = true;
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'actor@example.test',
      password: 'test',
    );
    cancelApple = true;
    await expectLater(
      requestAccountDeletion(),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('cancelled'),
        ),
      ),
    );
    expect(deletionBodies, isEmpty);
    expect((await LastPlaceStore('actor').read()).id, 'ftc');
  });
  test(
    'Apple revocation failure leaves the account and saved place intact',
    () async {
      status = 503;
      body = {
        'code': 'APPLE_REVOCATION_UNAVAILABLE',
        'error':
            'Apple authorization could not be revoked. No account data was deleted.',
      };
      await expectLater(
        requestAccountDeletion(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('could not be revoked'),
          ),
        ),
      );
      expect(Supabase.instance.client.auth.currentUser?.id, 'actor');
      expect((await LastPlaceStore('actor').read()).id, 'ftc');
    },
  );
}
