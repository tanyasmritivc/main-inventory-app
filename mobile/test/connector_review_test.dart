import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/scan/connector_review_page.dart';
import 'package:mobile/features/chat/assistant_connections_page.dart';
import 'support/hierarchy_fixture.dart';

Map<String, dynamic> source() => {
  'id': 'source',
  'filename': 'stock.csv',
  'kind': 'inventory',
  'location': 'Storage',
  'revision': 1,
  'status': 'review',
  'decisions': null,
  'receipts': <String, dynamic>{},
  'counts': {
    'imported': 0,
    'skipped': 0,
    'failed': 0,
    'pending': 2,
    'total': 2,
  },
  'fields': ['name', 'quantity'],
  'sheets': [
    {
      'name': 'Sheet1',
      'row_count': 2,
      'headers': ['Name', 'Qty'],
      'warnings': [],
      'sample': [
        ['Battery', '10'],
      ],
      'suggested_mapping': {'name': 0, 'quantity': 1},
    },
  ],
  'rows': [
    {
      'index': 0,
      'source_row': 2,
      'item': {'name': 'Battery', 'quantity': 10, 'location': 'Storage'},
      'errors': [],
      'duplicates': [],
      'duplicate_rows': [],
      'excluded': false,
    },
    {
      'index': 1,
      'source_row': 3,
      'item': {'name': 'Cable', 'quantity': 4, 'location': 'Storage'},
      'errors': [],
      'duplicates': [
        {'item_id': 'existing', 'name': 'Cable', 'location': 'Storage'},
      ],
      'duplicate_rows': [],
      'excluded': false,
    },
  ],
};
void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    fixture.requests.clear();
    fixture.status = 200;
  });
  Widget frame(
    Widget child, {
    Brightness brightness = Brightness.dark,
    double scale = 1,
  }) => MaterialApp(
    theme: AppTheme.create(brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child,
  );
  testWidgets(
    'review does not write; confirmation skips duplicates and navigates after receipts',
    (tester) async {
      fixture.respond = (request) => {
        ...source(),
        'status': 'complete',
        'decisions': {'0': 'create', '1': 'skip'},
        'receipts': {
          '0': {'status': 'imported', 'item_id': 'saved'},
          '1': {'status': 'skipped'},
        },
        'counts': {
          'imported': 1,
          'skipped': 1,
          'failed': 0,
          'pending': 0,
          'total': 2,
        },
      };
      await tester.pumpWidget(
        frame(ConnectorReviewPage(api: fixture.api, source: source())),
      );
      await tester.pumpAndSettle();
      expect(fixture.requests, isEmpty);
      await tester.scrollUntilVisible(find.text('Confirm import'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm import'));
      await tester.pumpAndSettle();
      expect(fixture.requests.single.data['decisions'], {
        '0': 'create',
        '1': 'skip',
      });
      expect(find.text('Import results'), findsOneWidget);
      expect(find.text('Confirm import'), findsNothing);
      expect(find.text('View inventory'), findsOneWidget);
    },
  );
  testWidgets(
    'unknown result freezes choices and retry uses same session and revision',
    (tester) async {
      fixture.status = 503;
      fixture.respond = (_) => {'detail': 'Retry safely'};
      await tester.pumpWidget(
        frame(ConnectorReviewPage(api: fixture.api, source: source())),
      );
      await tester.scrollUntilVisible(find.text('Confirm import'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm import'));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButton<String>), findsNothing);
      final first = fixture.requests.single.data;
      fixture.status = 200;
      fixture.respond = (_) => {
        ...source(),
        'decisions': first['decisions'],
        'status': 'complete',
        'counts': {
          'imported': 1,
          'skipped': 1,
          'failed': 0,
          'pending': 0,
          'total': 2,
        },
      };
      await tester.scrollUntilVisible(find.text('Resume import'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume import'));
      await tester.pumpAndSettle();
      expect(fixture.requests.length, 2);
      expect(fixture.requests.last.data, first);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'compact connections and import cards wrap at large text $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          frame(
            AssistantConnectionsPage(api: fixture.api),
            brightness: brightness,
            scale: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Google Drive'), findsNothing);
        expect(find.text('Google Sheets'), findsNothing);
        await tester.pumpWidget(
          frame(
            ConnectorReviewPage(api: fixture.api, source: source()),
            brightness: brightness,
            scale: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Confirm import'), 300);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
