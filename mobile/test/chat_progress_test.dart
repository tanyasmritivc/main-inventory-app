import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/chat_progress.dart';

void main() {
  Widget host(String message, {bool reduce = true}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reduce,
        textScaler: TextScaler.linear(2),
      ),
      child: Scaffold(
        body: SizedBox(width: 300, child: ChatProgress(message: message)),
      ),
    ),
  );
  testWidgets('real stages expand and retain updates at large text', (
    tester,
  ) async {
    await tester.pumpWidget(host('Finding objects…'));
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.pumpWidget(host('Checking confidence…'));
    expect(find.text('Finding objects…'), findsOneWidget);
    expect(find.text('Checking confidence…'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(find.text('Finding objects…'), findsNothing);
  });
  testWidgets('reduce motion shows readable static text; animation disposes', (
    tester,
  ) async {
    await tester.pumpWidget(host('Preparing your draft…'));
    expect(find.byType(ShaderMask), findsNothing);
    await tester.pumpWidget(host('Preparing your draft…', reduce: false));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ShaderMask), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
