import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> session(
  String refresh, {
  bool expired = false,
  String id = 'member',
}) {
  final expires =
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + (expired ? -3600 : 3600);
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
    'access_token':
        '${encode({'alg': 'HS256'})}.${encode({'sub': id, 'exp': expires})}.signature',
    'refresh_token': refresh,
    'expires_in': expired ? -3600 : 3600,
    'token_type': 'bearer',
    'user': {
      'id': id,
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
      'app_metadata': {},
      'user_metadata': {},
    },
  };
}

http.Response response(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'expired persisted session restores after the app has been closed',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SharedPreferencesLocalStorage(
        persistSessionKey: 'session-qa',
      );
      await storage.initialize();
      await storage.persistSession(
        jsonEncode(session('old-refresh', expired: true)),
      );
      var refreshes = 0;
      final client = GoTrueClient(
        url: 'https://auth.test',
        httpClient: MockClient((request) async {
          expect(jsonDecode(request.body)['refresh_token'], 'old-refresh');
          refreshes++;
          return response(session('rotated-refresh'));
        }),
      );
      client.stopAutoRefresh();
      addTearDown(client.dispose);
      final events = <AuthChangeEvent>[];
      final subscription = client.onAuthStateChange.listen(
        (state) => events.add(state.event),
      );
      addTearDown(subscription.cancel);
      final saved = (await storage.accessToken())!;
      await client.setInitialSession(saved);
      await client.recoverSession(saved);
      expect(client.currentSession!.isExpired, isFalse);
      expect(client.currentSession!.refreshToken, 'rotated-refresh');
      expect(refreshes, 1);
      expect(events, isNot(contains(AuthChangeEvent.signedOut)));
      await storage.persistSession(jsonEncode(client.currentSession!.toJson()));
      expect(
        jsonDecode((await storage.accessToken())!)['refresh_token'],
        'rotated-refresh',
      );
    },
  );

  test(
    'late startup recovery does not reuse the already rotated saved token',
    () async {
      var requests = 0;
      final client = GoTrueClient(
        url: 'https://auth.test',
        httpClient: MockClient((_) async {
          requests++;
          return response({
            'code': 'refresh_token_not_found',
            'msg': 'Invalid Refresh Token',
          }, 400);
        }),
      );
      client.stopAutoRefresh();
      addTearDown(client.dispose);
      await client.setInitialSession(jsonEncode(session('new-refresh')));
      await client.recoverSession(
        jsonEncode(session('old-refresh', expired: true)),
      );
      expect(requests, 0);
      expect(client.currentSession!.refreshToken, 'new-refresh');
    },
  );

  test('failed refresh cannot sign out a newer account session', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final client = GoTrueClient(
      url: 'https://auth.test',
      httpClient: MockClient((request) async {
        if (request.url.queryParameters['grant_type'] == 'refresh_token') {
          started.complete();
          return pending.future;
        }
        return response(session('other-refresh', id: 'other-member'));
      }),
    );
    client.stopAutoRefresh();
    addTearDown(client.dispose);
    final subscription = client.onAuthStateChange.listen(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    addTearDown(subscription.cancel);
    await client.setInitialSession(
      jsonEncode(session('old-refresh', expired: true)),
    );
    final refresh = client.refreshSession();
    final failure = expectLater(refresh, throwsA(isA<AuthException>()));
    await started.future;
    await client.signInWithPassword(
      email: 'other@example.test',
      password: 'test-only',
    );
    pending.complete(
      response({
        'code': 'refresh_token_not_found',
        'msg': 'Invalid Refresh Token',
      }, 400),
    );
    await failure;
    expect(client.currentUser!.id, 'other-member');
    expect(client.currentSession!.refreshToken, 'other-refresh');
  });

  test('a genuinely revoked session still requires sign-in', () async {
    final client = GoTrueClient(
      url: 'https://auth.test',
      httpClient: MockClient(
        (_) async => response({
          'code': 'refresh_token_not_found',
          'msg': 'Invalid Refresh Token',
        }, 400),
      ),
    );
    client.stopAutoRefresh();
    addTearDown(client.dispose);
    final subscription = client.onAuthStateChange.listen(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    addTearDown(subscription.cancel);
    await client.setInitialSession(
      jsonEncode(session('revoked-refresh', expired: true)),
    );
    await expectLater(client.refreshSession(), throwsA(isA<AuthException>()));
    expect(client.currentSession, isNull);
  });
}
