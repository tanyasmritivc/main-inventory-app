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
  for (final dark in [false, true]) {
    testWidgets(
      'welcome shimmer ${dark ? 'dark' : 'light'} pauses, respects Reduce Motion and disposes',
      (tester) async {
        Widget heading({bool reduce = false}) => MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: reduce,
              textScaler: TextScaler.linear(3.2),
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 300,
                  child: ShinyStatusText(
                    "Find what's in your world.",
                    heading: true,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, height: 1.25),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(heading());
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(ShaderMask), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 4));
        expect(tester.binding.hasScheduledFrame, isFalse);
        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(ShaderMask), findsOneWidget);
        await tester.pumpWidget(heading(reduce: true));
        expect(find.byType(ShaderMask), findsNothing);
        expect(find.text("Find what's in your world."), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 10));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
