import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/profile/plans_page.dart';

void main() {
  testWidgets('monthly and yearly prices remain informational', (tester) async {
    tester.view.physicalSize = const Size(1000, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(Brightness.light),
        home: const PlansPage(),
      ),
    );
    for (final name in ['Free', 'Plus', 'Team']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Pro'), findsNothing);
    expect(find.text('Business'), findsNothing);
    expect(find.text('Enterprise'), findsNothing);
    expect(find.text('\$9.99/month'), findsOneWidget);
    expect(find.text('\$29/month'), findsOneWidget);
    expect(find.text('100 saved item records'), findsOneWidget);
    expect(find.text('5 people included'), findsOneWidget);
    expect(
      find.text('200 photo extractions per month, shared'),
      findsOneWidget,
    );
    expect(find.text('Unlimited Spaces'), findsNWidgets(3));
    final buttons = tester.widgetList<OutlinedButton>(
      find.byType(OutlinedButton),
    );
    expect(buttons.length, 2);
    expect(buttons.every((button) => button.onPressed == null), isTrue);
    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();
    expect(find.text('\$99/year'), findsOneWidget);
    expect(find.text('\$299/year'), findsOneWidget);
    expect(find.text('About \$8.25/month, billed yearly'), findsOneWidget);
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.text('\$9.99/month'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
      await tester.scrollUntilVisible(find.text('\$99/year'), 220);
      expect(find.text('\$99/year'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
