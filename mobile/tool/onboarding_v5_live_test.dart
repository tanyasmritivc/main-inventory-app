// Opt-in approved disposable-account verification. Never run in the normal suite.
// The remote helper creates only a tagged QA user; it never returns service keys.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/onboarding/onboarding_v5_page.dart';
import 'package:mobile/features/onboarding/onboarding_v5_store.dart';

class _LiveHttp extends HttpOverrides {}

Future<Map<String, dynamic>> qa(String action) async {
  final result = await Process.run('ssh', [
    'findez',
    'python3 /tmp/findez-onboarding-v5-live-qa.py $action',
  ]);
  if (result.exitCode != 0) {
    throw StateError('QA helper failed ($action); inspect server privately');
  }
  return jsonDecode(result.stdout as String) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const approved = bool.fromEnvironment('APPROVED_DISPOSABLE_ONBOARDING_QA');
  testWidgets(
    'approved disposable account receives answers and clears the local copy',
    (tester) async {
      // This tool is explicitly an opt-in test, outside the default test directory.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      final config = await tester.runAsync(() => qa('config'));
      final client = IOClient(
        HttpOverrides.runWithHttpOverrides(() => HttpClient(), _LiveHttp()),
      );
      await tester.runAsync(
        () => Supabase.initialize(
          url: config!['url'] as String,
          publishableKey: config['anon'] as String,
          httpClient: client,
          authOptions: const FlutterAuthClientOptions(
            localStorage: EmptyLocalStorage(),
            detectSessionInUri: false,
            autoRefreshToken: false,
          ),
        ),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = OnboardingV5Store();
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingV5Page(
            store: store,
            onFinished: () => finished = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(String label) async {
        await tester.tap(find.text(label));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();
      }

      await tap('Get started');
      for (final label in [
        'Robotics team',
        'A team or class',
        'Finding things when I need them',
        'FIRST or robotics community',
      ]) {
        await tap(label);
      }
      expect(find.text('Create your account'), findsOneWidget);
      await store.beginAuth('email', true);
      Map<String, dynamic>? created;
      try {
        // Admin provisioning avoids sending verification mail for a throwaway user.
        // Native email signup/verification itself is covered by the iOS HTTP fixture suite.
        created = await tester.runAsync(() => qa('create'));
        await tester.runAsync(
          () => Supabase.instance.client.auth.signInWithPassword(
            email: created!['email'] as String,
            password: created['password'] as String,
          ),
        );
        for (var i = 0; i < 60 && !finished; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        final response = await tester.runAsync(
          () => Supabase.instance.client.auth.getUser(),
        );
        final answers = response!.user!.userMetadata!['onboarding'];
        expect(response.user!.id, created!['id']);
        expect(answers['use_case'], 'robotics');
        expect(answers['used_by'], 'team');
        expect(answers['main_need'], 'find');
        expect(answers['heard_from'], 'first');
        expect(answers['completed_at'], isNotNull);
        expect(await store.read(), isEmpty);
        expect(await store.hasPending(created['id'] as String), isFalse);
        expect(finished, isTrue);
        debugPrint(
          'LIVE_ONBOARDING_QA verified: real auth metadata, local clear, account-bound receipt clear',
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(
          () =>
              Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
        );
        await tester.runAsync(() => Supabase.instance.dispose());
        if (created != null) {
          final cleanup = await tester.runAsync(() => qa('cleanup'));
          expect(cleanup!['removed_approved_qa_account'], isTrue);
          debugPrint('LIVE_ONBOARDING_QA disposable account removed');
        }
      }
    },
    skip: !approved,
  );
}
