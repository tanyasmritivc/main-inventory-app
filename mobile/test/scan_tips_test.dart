import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/ui/photo_scan_hint.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'scan tips rotate without shifting controls, reduced=$reduced',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                disableAnimations: reduced,
                textScaler: const TextScaler.linear(2.6),
              ),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: 320,
                    child: Column(
                      children: [RotatingScanHint(), Text('Save position')],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final top = tester.getTopLeft(find.text('Save position'));
        final switcher = find.byType(AnimatedSwitcher);
        String current() => reduced
            ? tester
                  .widget<Text>(
                    find.byWidgetPredicate(
                      (widget) => widget is Text && widget.key is ValueKey<int>,
                    ),
                  )
                  .data!
            : (tester.widget<AnimatedSwitcher>(switcher).child! as Text).data!;
        expect(current(), scanTips.first);
        await tester.pump(const Duration(seconds: 8));
        await tester.pump(const Duration(milliseconds: 300));
        expect(current(), scanTips[1]);
        expect(tester.getTopLeft(find.text('Save position')), top);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        // A live iOS binding cannot pump a frame while paused. Wait on the
        // clock instead; the host binding advances its fake timer normally.
        if (Platform.isIOS) {
          await Future<void>.delayed(const Duration(seconds: 9));
        } else {
          await tester.pump(const Duration(seconds: 20));
        }
        expect(current(), scanTips[1]);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(seconds: 8));
        await tester.pump(const Duration(milliseconds: 300));
        expect(current(), scanTips[2]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 20));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('screen reader keeps a stable scan tip', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(accessibleNavigation: true),
          child: Scaffold(body: RotatingScanHint()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 24));
    expect(
      (tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).child!
              as Text)
          .data,
      scanTips.first,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
