import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/onboarding/onboarding_v5_page.dart';
import 'package:mobile/features/onboarding/onboarding_v5_store.dart';

void main({Future<void> Function(WidgetTester, String)? capture}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  var captureEnabled = false;
  Future<void> captureFrame(WidgetTester t, String name) async {
    if (captureEnabled) await capture?.call(t, name);
  }

  var userId = 'new-onboarding-user';
  var createdAt = DateTime.now().toUtc().toIso8601String();
  var failWrite = false, verifyEmail = false;
  final updates = <Map<String, dynamic>>[];
  var metadata = <String, dynamic>{};
  Map<String, dynamic> user() => {
    'id': userId,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'onboarding@example.test',
    'email_confirmed_at': createdAt,
    'created_at': createdAt,
    'app_metadata': {},
    'user_metadata': metadata,
    'identities': [
      {
        'id': userId,
        'user_id': userId,
        'identity_id': userId,
        'provider': 'email',
        'created_at': createdAt,
        'identity_data': {},
      },
    ],
  };
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://onboarding.test',
      publishableKey: 'synthetic',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/signup')) {
          createdAt = DateTime.now().toUtc().toIso8601String();
        }
        if (request.method == 'PUT' && path.endsWith('/user')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if ((body['data'] as Map?)?.containsKey('onboarding') ?? false) {
            updates.add(body);
            if (failWrite) {
              return http.Response('{"message":"Unavailable"}', 503);
            }
          }
          metadata = {...metadata, ...?body['data'] as Map<String, dynamic>?};
        }
        String encode(Object value) => base64Url
            .encode(utf8.encode(jsonEncode(value)))
            .replaceAll('=', '');
        final token =
            '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': userId, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.signature';
        final Object response = path.endsWith('/signup') && verifyEmail
            ? user()
            : path.endsWith('/token') || path.endsWith('/signup')
            ? {
                'access_token': token,
                'refresh_token': 'synthetic-refresh',
                'expires_in': 3600,
                'token_type': 'bearer',
                'user': user(),
              }
            : path.endsWith('/user')
            ? user()
            : path.contains('/rest/v1/')
            ? []
            : {};
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  setUp(() async {
    await Supabase.instance.client.auth.signOut();
    Supabase.instance.client.auth.stopAutoRefresh();
    SharedPreferences.setMockInitialValues({});
    userId = 'new-onboarding-user';
    createdAt = DateTime.now().toUtc().toIso8601String();
    failWrite = false;
    verifyEmail = false;
    updates.clear();
    captureEnabled = false;
    metadata = {};
  });
  tearDownAll(() async => Supabase.instance.dispose());

  Future<void> settle(WidgetTester t, [int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 50; i++) {
      await t.pump(const Duration(milliseconds: 50));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
    }
  }

  Future<void> launch(
    WidgetTester t, {
    bool reduced = false,
    Size size = const Size(390, 844),
    double scale = 1,
    VoidCallback? finished,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            padding: const EdgeInsets.only(top: 59, bottom: 34),
            viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: OnboardingV5Page(onFinished: finished ?? () {}),
      ),
    );
    await settle(t);
    await captureFrame(t, 'welcome');
  }

  Future<void> tap(WidgetTester t, String text, [int ms = 2000]) async {
    final f = find.text(text).last;
    await t.ensureVisible(f);
    await t.tap(f);
    await settle(t, ms);
  }

  Future<void> questions(WidgetTester t, {bool skip = false}) async {
    await tap(t, 'Get started');
    await captureFrame(t, 'question-1');
    var questionNumber = 1;
    for (final answer in [
      'Robotics team',
      'A team or class',
      'Finding things when I need them',
      'FIRST or robotics community',
    ]) {
      await tap(t, skip ? 'Skip' : answer);
      await captureFrame(t, 'step-${++questionNumber}');
    }
  }

  Future<void> email(WidgetTester t) async {
    await tap(t, 'Continue with email');
    for (final e in {
      'First name': 'Test',
      'Last name': 'Person',
      'Email': 'onboarding@example.test',
      'Password': 'synthetic-password',
    }.entries) {
      final f = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == e.key,
      );
      await t.ensureVisible(f);
      await t.enterText(f, e.value);
    }
    final legal = find.byType(CheckboxListTile);
    await t.ensureVisible(legal);
    await t.tap(legal);
    await t.pump();
    await tap(t, 'Create account', 2000);
    await captureFrame(t, 'signup-result');
  }

  testWidgets(
    'all questions persist, back retains selection and summary matches',
    (t) async {
      await launch(t);
      await tap(t, 'Get started');
      await tap(t, 'Robotics team');
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.text('What are you organizing?'), findsOneWidget);
      expect((await OnboardingV5Store().read())['use_case'], 'robotics');
      await tap(t, 'Workshop or garage');
      await tap(t, 'Just me');
      await tap(t, 'Knowing what is running low');
      await tap(t, 'Search');
      expect(find.byKey(const ValueKey('onboarding-summary')), findsOneWidget);
      expect(find.text('Workshop or garage'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with email'), findsOneWidget);
      expect(
        await OnboardingV5Store().read(),
        containsPair('heard_from', 'search'),
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'all skipped hides summary and signup writes metadata then clears local draft',
    (t) async {
      var finished = false;
      await launch(t, finished: () => finished = true);
      await questions(t, skip: true);
      expect(find.byKey(const ValueKey('onboarding-summary')), findsNothing);
      await email(t);
      expect(find.text("You're all set"), findsOneWidget);
      await settle(t, 3000);
      expect(finished, isTrue);
      expect(updates, hasLength(1));
      expect(metadata['onboarding'], containsPair('use_case', null));
      expect(metadata['onboarding'], contains('completed_at'));
      expect(await OnboardingV5Store().read(), isEmpty);
      expect(await OnboardingV5Store().hasPending(userId), isFalse);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('signup saves the exact selected answers to the new account', (
    t,
  ) async {
    captureEnabled = true;
    await launch(t);
    await questions(t);
    await email(t);
    await settle(t, 3000);
    expect(metadata['onboarding'], containsPair('use_case', 'robotics'));
    expect(metadata['onboarding'], containsPair('used_by', 'team'));
    expect(metadata['onboarding'], containsPair('main_need', 'find'));
    expect(metadata['onboarding'], containsPair('heard_from', 'first'));
    expect(await OnboardingV5Store().read(), isEmpty);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'welcome sign in discards answers without an account metadata write',
    (t) async {
      await OnboardingV5Store().save({'use_case': 'home'});
      await launch(t);
      await t.tap(
        find.text('Already have an account? Sign in', findRichText: true),
      );
      await settle(t);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(await OnboardingV5Store().read(), isEmpty);
      expect(updates, isEmpty);
    },
  );
  testWidgets(
    'reduced motion advances instantly and small large-text layouts scroll',
    (t) async {
      await launch(t, reduced: true, size: const Size(320, 568), scale: 1.6);
      await tap(t, 'Get started', 50);
      await tap(t, 'Business', 50);
      expect(find.text('Who will use FindEZ?'), findsOneWidget);
      await tap(t, 'A company or organization', 50);
      await tap(t, 'Keeping track of shared or borrowed items', 50);
      await tap(t, 'Other', 50);
      expect(find.text('Create your account'), findsOneWidget);
      await t.ensureVisible(find.text('Continue with email'));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'email verification keeps an owner-bound receipt until confirmation',
    (t) async {
      verifyEmail = true;
      await launch(t);
      await questions(t);
      await email(t);
      expect(
        find.text('Check your email to confirm your account.'),
        findsOneWidget,
      );
      expect(await OnboardingV5Store().hasPending(userId), isTrue);
      expect(updates, isEmpty);
      await t.runAsync(
        () => Supabase.instance.client.auth.signInWithPassword(
          email: 'onboarding@example.test',
          password: 'synthetic-password',
        ),
      );
      await settle(t, 4000);
      expect(metadata['onboarding'], containsPair('use_case', 'robotics'));
      expect(await OnboardingV5Store().read(), isEmpty);
    },
  );
  testWidgets(
    'failed metadata write is retained and retries only for its owner',
    (t) async {
      failWrite = true;
      await launch(t);
      await questions(t);
      await email(t);
      await settle(t, 3000);
      expect(await OnboardingV5Store().hasPending(userId), isTrue);
      expect(await OnboardingV5Store().read(), isNotEmpty);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() async {
        await Supabase.instance.client.auth.signOut();
        userId = 'different-user';
        await Supabase.instance.client.auth.signInWithPassword(
          email: 'other@example.test',
          password: 'synthetic',
        );
        expect(
          await OnboardingV5Store().sync(Supabase.instance.client),
          isNull,
        );
        userId = 'new-onboarding-user';
        await Supabase.instance.client.auth.signOut();
        await Supabase.instance.client.auth.signInWithPassword(
          email: 'onboarding@example.test',
          password: 'synthetic',
        );
        failWrite = false;
        expect(
          await OnboardingV5Store().sync(Supabase.instance.client),
          'email',
        );
      });
      expect(await OnboardingV5Store().read(), isEmpty);
      expect(await OnboardingV5Store().hasPending(userId), isFalse);
    },
  );
  testWidgets(
    'Back cancels a pending selection advance and Skip clears a restored answer',
    (t) async {
      await launch(t);
      await tap(t, 'Get started');
      await t.tap(find.text('Home'));
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.byTooltip('Back'));
      await settle(t, 2000);
      expect(find.text('Memory for\nphysical things.'), findsOneWidget);
      await tap(t, 'Get started');
      expect((await OnboardingV5Store().read())['use_case'], 'home');
      await tap(t, 'Skip');
      expect((await OnboardingV5Store().read())['use_case'], isNull);
      expect(find.text('Who will use FindEZ?'), findsOneWidget);
    },
  );

  test('old users cannot acquire an unbound signup draft', () async {
    final store = OnboardingV5Store();
    await store.save({'use_case': 'home'});
    await store.beginAuth('google', true);
    createdAt = '2025-01-01T00:00:00Z';
    expect(
      await store.bind(User.fromJson(jsonDecode(jsonEncode(user())))!),
      isFalse,
    );
    expect(updates, isEmpty);
  });
}
