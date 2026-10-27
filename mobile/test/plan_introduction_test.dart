import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/plan_introduction.dart';
import 'package:mobile/features/profile/plans_welcome.dart';
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

class FakePlanStore extends PlanIntroductionStore {
  FakePlanStore({this.result = true, this.pending});
  final bool result;
  final Completer<bool>? pending;
  final dismissed = <String>[];
  @override
  Future<bool> shouldShow(User user) async => pending?.future ?? result;
  @override
  Future<bool> dismiss(User user) async {
    dismissed.add(user.id);
    return true;
  }
}

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
  for (final action in ['Continue with Free', 'Skip for now', 'Close plans']) {
    testWidgets('$action closes once without replacing chat', (tester) async {
      final store = FakePlanStore();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(Brightness.dark),
          home: PlansWelcomeGate(
            user: signupUser(action),
            store: store,
            child: const Scaffold(body: Text('Existing chat')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlansWelcomeDialog), findsOneWidget);
      await tester.tap(
        action == 'Close plans' ? find.byTooltip(action) : find.text(action),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlansWelcomeDialog), findsNothing);
      expect(find.text('Existing chat'), findsOneWidget);
      expect(store.dismissed, [action]);
    });
  }
  testWidgets('disposed account cannot open a late popup', (tester) async {
    final ready = Completer<bool>();
    final store = FakePlanStore(pending: ready);
    await tester.pumpWidget(
      MaterialApp(
        home: PlansWelcomeGate(
          key: const ValueKey('a'),
          user: signupUser('late-a'),
          store: store,
          child: const Scaffold(body: Text('A')),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PlansWelcomeGate(
          key: const ValueKey('b'),
          user: signupUser('late-b'),
          store: FakePlanStore(result: false),
          child: const Scaffold(body: Text('B')),
        ),
      ),
    );
    ready.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(PlansWelcomeDialog), findsNothing);
    expect(find.text('B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'popup remains scrollable and dismissible at large text $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var closed = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2.6),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: PlansWelcomeDialog(onClose: () => closed = true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Team'), 150);
        await tester.tap(find.text('Team'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('10 people included'), 200);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Continue with Free'));
        await tester.pumpAndSettle();
        expect(closed, isTrue);
      },
    );
  }
}
