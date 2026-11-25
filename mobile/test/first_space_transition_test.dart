import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/world/first_space.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    for (final reduce in [false, true]) {
      testWidgets('First-space sheet opens cleanly at $size, reduce=$reduce', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        FirstSpaceAction? chosen;
        const composerKey = ValueKey('composer');
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: FirstSpaceAskLanding(
                  height: size.height,
                  composer: const SizedBox(key: composerKey, height: 210),
                  onStart: () async =>
                      chosen = await showFirstSpaceSheet(context),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final composer = tester.getRect(find.byKey(composerKey));
        final centered = (size.height - composer.height) / 2;
        expect(centered - composer.top, inInclusiveRange(25, 36));
        final start = find.text('Start now');
        expect(start.hitTestable(), findsOneWidget);
        await tester.tap(start);
        final header = find.text('Add your first items');
        final tops = <double>[];
        for (final ms in [0, 16, 64, 100]) {
          await tester.pump(Duration(milliseconds: ms));
          final panel = tester.widget<Material>(
            find.ancestor(of: header, matching: find.byType(Material)).first,
          );
          expect(panel.color!.a, 1);
          final filter = find.byType(BackdropFilter);
          expect(tester.getRect(filter), Offset.zero & size);
          expect(
            find.ancestor(of: header, matching: find.byType(FadeTransition)),
            findsNothing,
          );
          expect(find.text('Auto extract').hitTestable(), findsOneWidget);
          tops.add(tester.getTopLeft(header).dy);
        }
        expect(
          tops.first - tops.last,
          reduce ? isZero : inInclusiveRange(1, 30),
        );
        await tester.tap(find.text('Auto extract'));
        await tester.pumpAndSettle();
        expect(chosen, FirstSpaceAction.extract);
        expect(header, findsNothing);
        await tester.tap(start);
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        expect(header, findsNothing);
        expect(chosen, isNull);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
