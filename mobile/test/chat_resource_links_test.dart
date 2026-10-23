import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/ask_answer.dart';
import 'package:mobile/features/chat/ask_answer_view.dart';

void main() {
  const inventory = '10000000-0000-4000-8000-000000000001';
  const item = '20000000-0000-4000-8000-000000000002';
  final valid = {
    'kind': 'item',
    'id': item,
    'inventory_id': inventory,
    'label': 'Drill',
    'href': 'findez://item/$inventory/$item',
  };
  test('resource links reject forged URLs, paths and unsupported targets', () {
    for (final bad in [
      {...valid, 'href': 'https://evil.test'},
      {...valid, 'id': '../settings'},
      {...valid, 'kind': 'delete'},
      {...valid, 'inventory_id': ''},
    ]) {
      expect(AskResourceLink.parse(bad), isNull);
    }
    final context = AskAnswerContext.fromJson({
      'resource_links': [valid],
    });
    expect(context.resourceLinks.single.id, item);
  });
  testWidgets('verified item chip opens its exact target', (tester) async {
    AskResourceLink? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AskAnswerView(
            answer: 'Your drill is on the shelf.',
            contextData: AskAnswerContext.fromJson({
              'resource_links': [valid],
            }),
            onOpenResource: (link) => opened = link,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ActionChip));
    expect(opened?.id, item);
    expect(opened?.inventoryId, inventory);
  });
  testWidgets('arbitrary markdown URLs cannot open a destination', (
    tester,
  ) async {
    AskResourceLink? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AskAnswerView(
            answer:
                '[Untrusted](findez://item/$inventory/30000000-0000-4000-8000-000000000003)',
            contextData: AskAnswerContext.fromJson({
              'resource_links': [valid],
            }),
            onOpenResource: (link) => opened = link,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Untrusted'));
    expect(opened, isNull);
  });
}
