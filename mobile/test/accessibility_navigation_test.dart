import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/inventory/world_views.dart';

void main() {
  testWidgets('a place row is actionable with large text and Bold Text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2), boldText: true),
          child: child!,
        ),
        home: Scaffold(
          body: WorldRow(
            title: 'Workshop storage',
            subtitle: 'Shared by you',
            count: '12',
            countSemantics: '12 objects',
            onTap: () => opened = true,
          ),
        ),
      ),
    );

    final row = find.bySemanticsLabel(
      'Workshop storage, Shared by you, 12 objects',
    );
    expect(row, findsOneWidget);
    await tester.tap(row);
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('large text uses a flexible object list instead of fixed tiles', (
    tester,
  ) async {
    final item = InventoryItem.fromJson({
      'item_id': 'one',
      'name': 'A long object name that needs room to remain readable',
      'category': 'Tools',
      'quantity': 2,
      'location': 'Workshop',
    });
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: WorldItems(items: [item], onOpen: (_) {}),
        ),
      ),
    );

    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
