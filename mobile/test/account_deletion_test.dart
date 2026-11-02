import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/account_deletion.dart';
import 'package:mobile/core/last_place.dart';

void main() {
  var status = 200;
  Map<String, dynamic> body = {};
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://auth.test',
      anonKey: 'test',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((r) async {
        if (r.url.path.endsWith('delete-user')) {
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
}
