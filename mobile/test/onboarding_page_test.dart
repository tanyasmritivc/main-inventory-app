import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/features/onboarding/onboarding_page.dart';
import 'package:mobile/features/onboarding/onboarding_prefs.dart';

void main() {
  testWidgets('interactive onboarding completes the guided path', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var finished = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: OnboardingPage(onFinished: () => finished = true),
      ),
    );

    expect(find.text('Know what you have.\nFind it fast.'), findsOneWidget);
    await tester.tap(find.text('Start the tour'));
    await tester.pumpAndSettle();

    expect(find.text('Tap + to create a Space.'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('New Space'), findsOneWidget);
    await tester.tap(find.text('Create Space'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Sample: M4 bolts'), findsOneWidget);
    await tester.tap(find.text('Sample: M4 bolts'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to save'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Send the sample inventory question.'), findsOneWidget);
    await tester.tap(find.text('Where are the M4 bolts?'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('24 M4 bolts are in Parts Room.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text('Everything the team needs stays connected.'),
      findsOneWidget,
    );
    expect(find.text('Spaces'), findsOneWidget);
    expect(find.text('Board'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    await tester.tap(find.text('Finish tour'));
    await tester.pumpAndSettle();

    expect(find.text('You know the flow.'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(finished, isTrue);
    expect(await OnboardingPrefs.isCompleted(), isTrue);
    expect(await OnboardingPrefs.getPendingFirstSpaceName(), 'Parts Room');
  });
}
