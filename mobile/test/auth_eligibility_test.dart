import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/auth_page.dart';

void main() {
  testWidgets(
    'email, Apple and Google signup require an explicit acknowledgment',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: const AuthPage(),
        ),
      );
      await tester.ensureVisible(find.text('New here? Create account'));
      await tester.tap(find.text('New here? Create account'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );

      for (final label in [
        'Create account',
        'Continue with Apple',
        'Continue with Google',
      ]) {
        final button = label == 'Create account'
            ? find.widgetWithText(FilledButton, label)
            : find.text(label);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Confirm your eligibility and accept the Terms of Service to create an account.',
          ),
          findsOneWidget,
          reason: label,
        );
      }

      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      final submit = find.widgetWithText(FilledButton, 'Create account');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Enter your first and last name.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
