import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/profile/plans_page.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('planned prices stay readable at large text in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.6)),
            child: child!,
          ),
          home: const PlansPage(),
        ),
      );
      expect(
        find.text(
          'Paid plans are coming soon. Current access is unchanged. No payment will be taken.',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('Yearly'), 160);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Yearly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('\$149/year'), 220);
      expect(find.text('\$149/year'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
