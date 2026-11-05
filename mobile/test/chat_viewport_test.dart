import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/chat_viewport.dart';
import 'package:mobile/features/chat/auto_extract/extract_widgets.dart';

void main() {
  test(
    'scan phases use count-free server stages without fake timed progress',
    () {
      var phase = ExtractScanPhase.preparing;
      phase = phase.advance('Reading your photo...');
      expect(phase, ExtractScanPhase.scanning);
      phase = phase.advance('Reading details for 8 objects...');
      expect(phase, ExtractScanPhase.analyzing);
      expect(phase.label, 'Analyzing details...');
      expect(phase.advance('Reading details for 27 objects...'), phase);
      expect(phase.advance('Reading your photo...'), phase);
      expect(phase.advance('Still working...'), phase);
      phase = phase.advance('Preparing your review...');
      expect(phase, ExtractScanPhase.review);
      expect(phase.advance('Scanning photo...'), phase);
    },
  );
  testWidgets('sheet chat can reserve header and composer when scrolled', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatViewport(
            keepControlsOutside: true,
            controller: controller,
            header: const SizedBox(
              key: Key('header'),
              height: 60,
              child: Text('Ask'),
            ),
            footer: const SizedBox(
              key: Key('composer'),
              height: 120,
              child: Text('Composer'),
            ),
            messages: List.generate(
              20,
              (i) => SizedBox(height: 80, child: Text('Message $i')),
            ),
          ),
        ),
      ),
    );
    await t.drag(find.byType(ListView), const Offset(0, -600));
    await t.pumpAndSettle();
    final list = t.getRect(find.byType(ListView));
    expect(
      list.top,
      greaterThanOrEqualTo(t.getRect(find.byKey(const Key('header'))).bottom),
    );
    expect(
      list.bottom,
      lessThanOrEqualTo(t.getRect(find.byKey(const Key('composer'))).top),
    );
    controller.jumpTo(controller.position.maxScrollExtent);
    await t.pumpAndSettle();
    expect(find.text('Message 19').hitTestable(), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'messages scroll under glass while last message stays reachable',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatViewport(
              controller: controller,
              header: const SizedBox(
                key: Key('header'),
                height: 60,
                child: Text('Ask'),
              ),
              footer: const SizedBox(
                key: Key('composer'),
                height: 120,
                child: Text('Composer'),
              ),
              messages: List.generate(
                30,
                (i) => SizedBox(height: 80, child: Text('Message $i')),
              ),
            ),
          ),
        ),
      );
      await t.drag(find.byType(ListView), const Offset(0, -600));
      await t.pumpAndSettle();
      final list = t.getRect(find.byType(ListView));
      expect(
        list.top,
        lessThan(t.getRect(find.byKey(const Key('header'))).bottom),
      );
      expect(
        list.bottom,
        greaterThan(t.getRect(find.byKey(const Key('composer'))).top),
      );
      controller.jumpTo(controller.position.maxScrollExtent);
      await t.pumpAndSettle();
      expect(
        t.getRect(find.text('Message 29')).bottom,
        lessThanOrEqualTo(t.getRect(find.byKey(const Key('composer'))).top),
      );
      expect(t.takeException(), isNull);
    },
  );
}
