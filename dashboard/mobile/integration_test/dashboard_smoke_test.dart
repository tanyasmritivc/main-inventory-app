import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:findez_dashboard/main.dart';
import 'package:findez_dashboard/dashboard_api.dart';
import '../test/dashboard_test.dart' show FakeApi, fixture;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
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
