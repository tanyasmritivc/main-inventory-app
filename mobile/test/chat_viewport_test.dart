import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/chat_viewport.dart';

void main() {
  testWidgets('scrolling messages remain between header and composer', (
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
      greaterThanOrEqualTo(t.getRect(find.byKey(const Key('header'))).bottom),
    );
    expect(
      list.bottom,
      lessThanOrEqualTo(t.getRect(find.byKey(const Key('composer'))).top),
    );
    expect(
      find.ancestor(of: find.byType(ListView), matching: find.byType(ClipRect)),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });
}
