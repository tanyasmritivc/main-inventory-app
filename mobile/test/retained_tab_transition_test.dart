import 'package:flutter/material.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/skeleton.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/world/retained_tab_transition.dart';

void main() {
  testWidgets('pushed pages stay opaque and use interactive native back', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(
          Brightness.dark,
        ).copyWith(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Center(child: Text('Ready detail'))),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(find.byType(SkeletonPage), findsNothing);
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      find.ancestor(
        of: find.text('Ready detail'),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    expect(tester.getTopLeft(find.byType(Scaffold).last).dx, greaterThan(0));
    await tester.pumpAndSettle();
    expect(find.text('Ready detail'), findsOneWidget);
    // A cancelled edge swipe keeps the detail visible and returns it to rest.
    final gesture = await tester.startGesture(const Offset(1, 200));
    await gesture.moveBy(const Offset(90, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Ready detail'), findsOneWidget);
    await tester.dragFrom(const Offset(1, 200), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Ready detail'), findsNothing);
  });

  testWidgets('tabs switch immediately without opacity and preserve drafts', (
    tester,
  ) async {
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
    update(() => selected = 1);
    await tester.pump();
    expect(find.text('Spaces'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RetainedTabTransition),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    update(() => selected = 2);
    await tester.pump();
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Spaces'), findsNothing);
    update(() => selected = 0);
    await tester.pumpAndSettle();
    expect(find.text('Keep my draft'), findsOneWidget);
    expect(tester.state(find.byType(TextField)), same(original));
    expect(tester.takeException(), isNull);
  });

  testWidgets('only selected tab can receive taps during page settle', (
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
    // The new page is usable on the first transition frame.
    await tester.pump(const Duration(milliseconds: 10));
    await tester.tapAt(tester.getCenter(find.byType(RetainedTabTransition)));
    expect(oldTaps, 0);
    expect(newTaps, 1);
    final oldSemantics = tester
        .widgetList<ExcludeSemantics>(find.byType(ExcludeSemantics))
        .where((w) => w.excluding);
    expect(oldSemantics, isNotEmpty);
    await tester.pumpAndSettle();
  });

  testWidgets('Reduce Motion and rapid selection never schedule a page fade', (
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
