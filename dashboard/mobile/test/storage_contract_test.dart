import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:findez_dashboard/main.dart';

void main() {
  for (final scale in [1.0, 1.6]) {
    testWidgets('storage snapshot works in existing app at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data =
          jsonDecode(
                File('test/fixtures/storage-health.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      await tester.pumpWidget(
        MaterialApp(
          theme: dashboardTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(body: InfrastructurePage(data: data)),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('Space available for uploads'), 300);
      await tester.pumpAndSettle();
      expect(find.text('Space available for uploads'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Automatic cache cleanup'),
        300,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Automatic cache cleanup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Automatic cache cleanup'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Active releases, photos, inventory'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
