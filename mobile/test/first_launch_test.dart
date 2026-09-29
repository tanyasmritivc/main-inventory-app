import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/onboarding/first_launch_page.dart';
import 'package:mobile/features/onboarding/onboarding_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'first launch appears once, while an existing install skips it',
    () async {
      SharedPreferences.setMockInitialValues({});
      expect(await OnboardingPrefs.shouldShowFirstLaunch(), isTrue);
      await OnboardingPrefs.markFirstLaunchSeen();
      expect(await OnboardingPrefs.shouldShowFirstLaunch(), isFalse);

      SharedPreferences.setMockInitialValues({'capture_mode': 'photo'});
      expect(await OnboardingPrefs.shouldShowFirstLaunch(), isFalse);
    },
  );

  testWidgets('first launch gives direct account choices', (tester) async {
    bool? selectedAccount;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FirstLaunchPage(
          onContinue: ({required bool createAccount}) async {
            selectedAccount = createAccount;
          },
        ),
      ),
    );
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    await tester.tap(find.text('Create account'));
    expect(selectedAccount, isTrue);
  });
}
