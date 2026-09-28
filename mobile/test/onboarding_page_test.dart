import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/onboarding/onboarding_page.dart';
import 'package:mobile/features/onboarding/onboarding_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OnboardingApi extends ApiClient {
  _OnboardingApi() : super(baseUrl: 'https://invalid.test');
}

void main() {
  testWidgets('onboarding offers inventory before the optional photograph', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OnboardingPage(api: _OnboardingApi()),
      ),
    );
    await tester.pump();

    expect(find.text('Welcome to FindEZ.'), findsOneWidget);
    expect(find.text('Open inventory'), findsOneWidget);
    expect(find.text('Capture first photo'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Sample'), findsNothing);
    expect(find.textContaining('Parts Room'), findsNothing);
  });

  testWidgets('opening inventory completes onboarding without a photo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OnboardingPage(
          api: _OnboardingApi(),
          onFinished: () => finished = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open inventory'));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
    expect(await OnboardingPrefs.isCompleted(), isTrue);
    expect(await OnboardingPrefs.isPostSignupPending(), isFalse);
  });
}
