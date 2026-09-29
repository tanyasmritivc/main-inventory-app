import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/inventory/world_views.dart';

InventoryItem _item(int index, {bool photo = false}) => InventoryItem(
  itemId: 'object-$index',
  name: 'Object $index',
  category: 'Test category',
  quantity: index + 1,
  location: 'Test place',
  createdAt: DateTime(2026),
  imageUrl: photo ? 'https://example.invalid/photo-$index.jpg' : null,
);

void main() {
  testWidgets('small object sets use a gallery with API quantities', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: WorldItems(
            items: List.generate(40, (index) => _item(index, photo: true)),
            onOpen: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Object 0'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('photo-less imports use compact rows, not empty gallery tiles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: WorldItems(
            items: [_item(0, photo: true), _item(1)],
            onOpen: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ListView), findsOneWidget);
    expect(
      tester
          .widgetList<WorldRow>(find.byType(WorldRow))
          .map((row) => row.showCrop),
      [true, false],
    );
  });

  testWidgets('large object sets switch to a virtual list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: WorldItems(items: List.generate(1205, _item), onOpen: (_) {}),
        ),
      ),
    );
    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ListView), findsOneWidget);
    expect(
      tester
          .widgetList<WorldRow>(find.byType(WorldRow))
          .every((row) => !row.showCrop),
      isTrue,
    );
    expect(find.text('Object 0'), findsOneWidget);
    expect(find.text('Object 1204'), findsNothing);
  });
}
