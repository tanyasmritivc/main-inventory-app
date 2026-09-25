import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/shell/app_destination.dart';
import 'package:mobile/features/shell/main_shell.dart';
import 'package:mobile/features/shell/primary_navigation_bar.dart';

void main() {
  test('primary destinations are unique and Ask is the front door', () {
    expect(AppDestination.values, hasLength(5));
    expect(
      AppDestination.values.map((value) => value.label).toSet(),
      hasLength(5),
    );
    expect(initialAppDestination, AppDestination.ask);
  });

  test('preserved routes remain assigned to a primary destination', () {
    const requiredCapabilities = <String>{
      'Ask and conversation history',
      'Attachments and voice',
      'Photo capture',
      'Barcode and FindEZ QR',
      'Inventory search',
      'Spaces and items',
      'Teams and sharing',
      'Documents',
      'Check-outs',
      'Low stock',
      'Project kits and BOM',
      'Labels and activity',
      'Notifications',
      'Account, support, and legal',
    };

    expect(preservedMobileRoutes.keys, containsAll(requiredCapabilities));
    expect(
      preservedMobileRoutes.values.every(AppDestination.values.contains),
      isTrue,
    );
  });

  testWidgets('primary navigation exposes five accessible destinations', (
    tester,
  ) async {
    AppDestination selected = AppDestination.ask;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: StatefulBuilder(
            builder: (context, setState) => PrimaryNavigationBar(
              selected: selected,
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Primary navigation'), findsOneWidget);
    for (final destination in AppDestination.values) {
      expect(find.text(destination.label), findsOneWidget);
      expect(find.byTooltip(destination.semanticLabel), findsOneWidget);
      await tester.tap(find.text(destination.label));
      await tester.pump();
      expect(selected, destination);
    }
  });

  testWidgets('primary navigation supports large text without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            bottomNavigationBar: PrimaryNavigationBar(
              selected: AppDestination.ask,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('shell starts on Ask and reaches all five destinations', (
    tester,
  ) async {
    final pages = AppDestination.values
        .map((destination) => Center(child: Text('${destination.label} page')))
        .toList();
    await _pumpShell(tester, pages);

    expect(find.text('Ask page'), findsOneWidget);
    for (final destination in AppDestination.values.skip(1)) {
      await tester.tap(find.text(destination.label));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('${destination.label} page'), findsOneWidget);
    }
  });

  testWidgets('destination state survives navigation', (tester) async {
    final pages = <Widget>[
      const _CounterPage(),
      const Center(child: Text('CAPTURE page')),
      const Center(child: Text('FIND page')),
      const Center(child: Text('MEMORY page')),
      const Center(child: Text('PROFILE page')),
    ];
    await _pumpShell(tester, pages);

    await tester.tap(find.text('Increment'));
    await tester.pump();
    expect(find.text('Count 1'), findsOneWidget);

    await tester.tap(find.text('Capture'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Count 1'), findsOneWidget);
  });

  testWidgets('Memory exposes existing supporting tools', (tester) async {
    final pages = AppDestination.values
        .map((destination) => Center(child: Text('${destination.label} page')))
        .toList();
    await _pumpShell(tester, pages);

    await tester.tap(find.text('Memory'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Memory tools'));
    await tester.pumpAndSettle();

    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Check-outs'), findsOneWidget);
    expect(find.text('Low stock'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
  });
}

Future<void> _pumpShell(WidgetTester tester, List<Widget> pages) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: MainShell(
        api: ApiClient(baseUrl: 'https://example.invalid'),
        destinationPagesForTesting: pages,
        enableRuntimeServices: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _CounterPage extends StatefulWidget {
  const _CounterPage();

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Count $count'),
          TextButton(
            onPressed: () => setState(() => count++),
            child: const Text('Increment'),
          ),
        ],
      ),
    );
  }
}
