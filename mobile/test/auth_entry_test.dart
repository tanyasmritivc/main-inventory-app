import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/auth/auth_page.dart';

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('account entry keeps signup to the essential fields', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(theme: theme, home: const AuthPage()),
      );

      expect(find.text('Sign in to open your inventory.'), findsNothing);
      final signup = find.text('Need an account? Sign up');
      await tester.ensureVisible(signup);
      await tester.tap(signup);
      await tester.pumpAndSettle();

      expect(
        find.text('Create an account to start your inventory.'),
        findsNothing,
      );
      expect(find.byType(TextField), findsNWidgets(4));
      expect(find.text('Role (optional)'), findsNothing);
      expect(find.text('Organization (optional)'), findsNothing);
    });
  }
}
