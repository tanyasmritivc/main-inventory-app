import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/profile/plans_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final brightness in Brightness.values) {
    testWidgets('plan comparison on iOS in ${brightness.name}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(brightness),
          home: const PlansPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(plansNotice), findsOneWidget);
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('\$99/year'), 200);
      expect(find.text('\$99/year'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('\$299/year'), 200);
      expect(find.text('\$299/year'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('How the planned limits work'),
        200,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
