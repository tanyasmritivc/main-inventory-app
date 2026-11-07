import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/plan_introduction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User signupUser(
  String id, {
  Map<String, dynamic>? metadata,
  DateTime? created,
  DateTime? signedIn,
  bool verified = true,
  bool anonymous = false,
}) {
  final now = DateTime.now().toUtc();
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: metadata,
    aud: 'authenticated',
    createdAt: (created ?? now.subtract(const Duration(seconds: 2)))
        .toIso8601String(),
    lastSignInAt: (signedIn ?? now).toIso8601String(),
    emailConfirmedAt: verified ? now.toIso8601String() : null,
    isAnonymous: anonymous,
  );
}

Session sessionFor(User user) => Session(
  accessToken: 'test-only-${user.id}',
  tokenType: 'bearer',
  user: user,
  expiresIn: 3600,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('new OAuth, pending email, ordinary login and web dismissal differ', () {
    final now = DateTime.now().toUtc();
    expect(isNewPlanSignup(signupUser('new'), now), isTrue);
    expect(
      isNewPlanSignup(
        signupUser('returning', created: now.subtract(const Duration(days: 4))),
        now,
      ),
      isFalse,
    );
    expect(
      isNewPlanSignup(
        signupUser(
          'delayed-email',
          created: now.subtract(const Duration(days: 4)),
          metadata: {'findez_mobile_plan_intro_pending': true},
        ),
        now,
      ),
      isTrue,
    );
    expect(
      isNewPlanSignup(
        signupUser(
          'unverified',
          verified: false,
          metadata: {'findez_mobile_plan_intro_pending': true},
        ),
        now,
      ),
      isFalse,
    );
    expect(
      isNewPlanSignup(signupUser('anonymous', anonymous: true), now),
      isFalse,
    );
    expect(
      isNewPlanSignup(
        signupUser(
          'web-dismissed',
          metadata: {
            'findez_plan_intro_version': 1,
            'findez_mobile_plan_intro_pending': true,
          },
        ),
        now,
      ),
      isFalse,
    );
  });
  test(
    'dismissal writes only UI metadata with the captured account token',
    () async {
      final user = signupUser('persist');
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.path, '/auth/v1/user');
        expect(request.method, 'PUT');
        expect(request.headers['Authorization'], 'Bearer test-only-persist');
        expect(jsonDecode(request.body), {
          'data': {
            'findez_plan_intro_version': 1,
            'findez_mobile_plan_intro_pending': false,
          },
        });
        return http.Response(
          jsonEncode({
            'id': user.id,
            'user_metadata': {'findez_plan_intro_version': 1},
          }),
          200,
        );
      });
      final store = PlanIntroductionStore(
        client: client,
        session: () => sessionFor(user),
        url: 'https://test.invalid',
        anonKey: 'test',
      );
      expect(await store.shouldShow(user), isTrue);
      expect(await store.dismiss(user), isTrue);
      expect(await store.shouldShow(user), isFalse);
      expect(calls, 2); // stale session metadata retries, without reopening.
    },
  );
  test('offline dismissal survives a new store and retries safely', () async {
    final user = signupUser('offline');
    final client = MockClient((_) async => http.Response('offline', 503));
    PlanIntroductionStore make() => PlanIntroductionStore(
      client: client,
      session: () => sessionFor(user),
      url: 'https://test.invalid',
      anonKey: 'test',
    );
    expect(await make().dismiss(user), isFalse);
    expect(await make().shouldShow(user), isFalse);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'findez_plan_intro_v1:offline',
      ),
      'dismissed',
    );
  });
  test(
    'another user cannot receive a dismissal and foreign receipts fail',
    () async {
      final a = signupUser('isolated-a'), b = signupUser('isolated-b');
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'id': b.id,
            'user_metadata': {'findez_plan_intro_version': 1},
          }),
          200,
        );
      });
      final wrongSession = PlanIntroductionStore(
        client: client,
        session: () => sessionFor(b),
        url: 'https://test.invalid',
      );
      expect(await wrongSession.dismiss(a), isFalse);
      expect(calls, 0);
      final store = PlanIntroductionStore(
        client: client,
        session: () => sessionFor(a),
        url: 'https://test.invalid',
      );
      expect(await store.dismiss(a), isFalse);
      expect(await store.shouldShow(b), isTrue);
    },
  );
  test('pending new signup survives a delayed next launch', () async {
    final user = signupUser('delayed');
    final store = PlanIntroductionStore(session: () => null);
    expect(await store.shouldShow(user), isTrue);
    final older = signupUser(
      'delayed',
      created: DateTime.now().subtract(const Duration(days: 7)),
    );
    expect(await store.shouldShow(older), isTrue);
  });
}
