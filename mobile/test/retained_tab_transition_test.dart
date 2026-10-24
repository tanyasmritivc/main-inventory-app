import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/world/retained_tab_transition.dart';

void main() {
  testWidgets(
    'crossfade preserves draft and retargets without an opacity jump',
    (tester) async {
      var selected = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return RetainedTabTransition(
                index: selected,
                children: const [
                  Material(child: TextField()),
                  Center(child: Text('Spaces')),
                  Center(child: Text('More')),
                ],
              );
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Keep my draft');
      final original = tester.state(find.byType(TextField));
      List<double> opacity() => tester
          .widgetList<Opacity>(
            find.descendant(
              of: find.byType(RetainedTabTransition),
              matching: find.byType(Opacity, skipOffstage: false),
              skipOffstage: false,
            ),
          )
          .map((o) => o.opacity)
          .toList();
      update(() => selected = 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // No delayed ease-in: the destination is visibly appearing at 50ms.
      expect(opacity()[0], inExclusiveRange(.65, .8));
      expect(opacity()[1], inExclusiveRange(.2, .35));
      final before = opacity();
      update(() => selected = 2);
      await tester.pump();
      expect(opacity(), before);
      await tester.pumpAndSettle();
      expect(opacity(), [0, 0, 1]);
      update(() => selected = 0);
      await tester.pumpAndSettle();
      expect(find.text('Keep my draft'), findsOneWidget);
      expect(tester.state(find.byType(TextField)), same(original));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('only selected tab can receive taps during dissolve', (
    tester,
  ) async {
    var selected = 0;
    var oldTaps = 0;
    var newTaps = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return RetainedTabTransition(
              index: selected,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => oldTaps++,
                  child: const Center(child: Text('Old')),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => newTaps++,
                  child: const Center(child: Text('New')),
                ),
              ],
            );
          },
        ),
      ),
    );
    update(() => selected = 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(tester.getCenter(find.byType(RetainedTabTransition)));
    expect(oldTaps, 0);
    expect(newTaps, 1);
    final oldSemantics = tester
        .widgetList<ExcludeSemantics>(find.byType(ExcludeSemantics))
        .where((w) => w.excluding);
    expect(oldSemantics, isNotEmpty);
    await tester.pumpAndSettle();
  });

  testWidgets('Reduce Motion changes immediately and stops an in-flight fade', (
    tester,
  ) async {
    var selected = 0;
    var reduced = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: RetainedTabTransition(
                index: selected,
                children: const [Text('Ask'), Text('Spaces')],
              ),
            );
          },
        ),
      ),
    );
    update(() => selected = 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    update(() => reduced = true);
    await tester.pump();
    expect(find.text('Ask'), findsNothing);
    expect(find.text('Spaces'), findsOneWidget);
    update(() => selected = 0);
    await tester.pump();
    expect(find.text('Ask'), findsOneWidget);
    expect(find.text('Spaces'), findsNothing);
    expect(tester.binding.hasScheduledFrame, false);
  });
}
