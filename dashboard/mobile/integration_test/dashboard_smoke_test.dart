import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:findez_dashboard/main.dart';
import 'package:findez_dashboard/dashboard_api.dart';
import '../test/dashboard_test.dart'
    show FakeApi, MemoryVault, SignInApi, sessionFixture, fixture;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native expired session recovery, first snapshot and canceled unlock',
    (tester) async {
      final snapshot = Completer<http.Response>();
      var requests = 0;
      final vault = MemoryVault()
        ..saved = jsonEncode({...sessionFixture(), 'expires_at': 0});
      final api = SignInApi(
        vault: vault,
        client: MockClient((request) async {
          if (request.url.queryParameters['grant_type'] == 'refresh_token') {
            return http.Response(
              '{"msg":"Invalid refresh token: refresh token not found"}',
              400,
            );
          }
          if (request.url.path.endsWith('/auth/v1/token')) {
            return http.Response(jsonEncode(sessionFixture()), 200);
          }
          requests++;
          return requests == 1
              ? snapshot.future
              : http.Response(jsonEncode(fixture()), 200);
        }),
      );
      await tester.pumpWidget(FounderApp(api: api));
      await tester.pumpAndSettle();
      expect(find.text('Your session expired. Sign in again.'), findsOneWidget);
      expect(vault.saved, isNull);
      await binding.takeScreenshot('expired-session-signin-fixture');
      await tester.enterText(
        find.byType(TextField).last,
        'isolated-fixture-password',
      );
      await tester.ensureVisible(find.text('Open dashboard'));
      await tester.tap(find.text('Open dashboard'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(requests, 1);
      expect(find.text('Loading your dashboard...'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot('startup-loading-fixture');
      snapshot.complete(http.Response(jsonEncode(fixture()), 200));
      await tester.pumpAndSettle();
      expect(find.text('Registered users').hitTestable(), findsOneWidget);
      await binding.takeScreenshot('startup-loaded-fixture');
      api.lock();
      await tester.pumpAndSettle();
      vault.authenticate = () async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        return false;
      };
      await tester.tap(find.text('Unlock dashboard'));
      await tester.pumpAndSettle();
      expect(
        find.text('Unlock was canceled. Try again.').hitTestable(),
        findsOneWidget,
      );
      await binding.takeScreenshot('unlock-canceled-fixture');
      vault.authenticate = () async => true;
      await tester.tap(find.text('Return to dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Registered users').hitTestable(), findsOneWidget);
      await binding.takeScreenshot('unlock-loaded-fixture');
      expect(tester.takeException(), isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('private dashboard native journey with isolated test fixtures', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(boldText: true);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final vault = SessionVault();
    await vault.write('isolated-fixture');
    expect(await vault.read(), 'isolated-fixture');
    await vault.clear();
    expect(await vault.read(), isNull);
    final api = FakeApi()
      ..restoring = false
      ..session = {'access_token': 'isolated-test-fixture'}
      ..data = fixture();
    await tester.pumpWidget(FounderApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Registered users'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('Registered users'))).brightness,
      Brightness.light,
    );
    expect(
      MediaQuery.boldTextOf(tester.element(find.text('Registered users'))),
      isFalse,
    );
    await binding.takeScreenshot('overview-fixture');
    await tester.tap(find.text('Issues').last);
    await tester.pumpAndSettle();
    expect(find.text('One place for issues'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New issue'), findsOneWidget);
    await binding.takeScreenshot('issue-editor-fixture');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customers').last);
    await tester.pumpAndSettle();
    expect(find.text('Search email or user ID'), findsOneWidget);
    await binding.takeScreenshot('customers-fixture');
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('navigation-fixture');
    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Payments and subscriptions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
