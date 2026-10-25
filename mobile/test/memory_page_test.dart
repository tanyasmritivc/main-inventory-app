import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/memory_page.dart';
import 'package:mobile/core/app_theme.dart';
import 'memory_controller_test.dart' show MemoryApi;

void main() {
  testWidgets(
    'memory screen loads controls, opt in persists, forget needs confirmation',
    (tester) async {
      final api = MemoryApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(Brightness.light),
          home: MemoryPage(api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Use personalization'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(api.record['enabled'], true);
      await tester.scrollUntilVisible(find.text('Forget personalization'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forget personalization'));
      await tester.pumpAndSettle();
      expect(find.text('Forget personalization?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.writes.length, 1);
    },
  );
  testWidgets(
    'offline screen provides refresh and does not show saved controls',
    (tester) async {
      final api = MemoryApi()..fail = true;
      await tester.pumpWidget(MaterialApp(home: MemoryPage(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Use personalization'), findsNothing);
      api.fail = false;
      await tester.tap(find.byTooltip('Refresh memory'));
      await tester.pumpAndSettle();
      expect(find.text('Use personalization'), findsOneWidget);
    },
  );
  testWidgets('large text and dark appearance remain scrollable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(3.2)),
          child: child!,
        ),
        home: MemoryPage(api: MemoryApi()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Forget personalization'), 300);
    expect(tester.takeException(), isNull);
  });
}
