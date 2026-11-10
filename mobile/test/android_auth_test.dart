import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/auth_page.dart';

void main() {
  testWidgets('Android without Google configuration keeps email available', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: const AuthPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Google sign-in is not configured'),
      findsWidgets,
    );
    expect(find.text('Continue with Apple'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('auth-more-options')));
    await tester.tap(find.byKey(const Key('auth-more-options')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth-email-option')));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
