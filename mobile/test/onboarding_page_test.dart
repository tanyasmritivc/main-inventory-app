import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/onboarding/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OnboardingApi extends ApiClient {
  _OnboardingApi() : super(baseUrl: 'https://invalid.test');
}

void main() {
  testWidgets('onboarding starts with the photograph, before any form', (
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

    expect(
      find.text('FindEZ gives the physical world a memory.'),
      findsOneWidget,
    );
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('I have an invitation'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Sample'), findsNothing);
    expect(find.textContaining('Parts Room'), findsNothing);
  });
}
