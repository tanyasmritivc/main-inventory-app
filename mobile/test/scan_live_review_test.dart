import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/chat/chat_capture_card.dart';
import 'package:mobile/features/chat/extraction_progress_panel.dart';
import 'support/hierarchy_fixture.dart';

Map<String, dynamic> row(
  int id,
  String? name, {
  double? confidence,
  bool review = false,
  bool missing = false,
}) => {
  'index': id,
  'selected': true,
  'item': {
    'name': name,
    'category': 'Tools',
    'quantity': missing ? null : 1,
    if (confidence != null) 'confidence': confidence,
    'scan_evidence': <String, dynamic>{'needs_review': review},
  },
};

void main() {
  test(
    'confidence is descending, unknowns last, ties stable and source untouched',
    () {
      final rows = [
        row(71, 'Unknown item', confidence: .98),
        row(42, 'Lamp', confidence: .8),
        row(9, 'Drill', confidence: .95),
        row(8, 'Tape', confidence: .8),
        row(4, 'Small screw', confidence: .3),
      ];
      final before = jsonEncode(rows);
      expect(scanDisplayRows(rows).map((r) => r['index']), [9, 42, 8, 71, 4]);
      expect(jsonEncode(rows), before);
      expect(identical(scanDisplayRows(rows).first, rows[2]), isTrue);
    },
  );
  test(
    'missing-confidence fallback keeps clean, review, missing, unknown order',
    () {
      final rows = [
        row(10, 'Unknown fastener'),
        row(11, 'Nut', missing: true),
        row(12, 'Drill', review: true),
        row(13, 'Tape'),
        row(14, 'Ruler'),
        row(15, 'Wire', review: true),
      ];
      expect(scanDisplayRows(rows).map((r) => r['index']), [
        13,
        14,
        12,
        15,
        11,
        10,
      ]);
      expect(scanDisplayRows(rows, missing: {13}).map((r) => r['index']), [
        14,
        12,
        15,
        11,
        13,
        10,
      ]);
    },
  );
  test(
    'unscored unknowns keep their original order regardless of missing fields',
    () {
      final rows = [row(1, 'Unknown', missing: true), row(2, 'Item')];
      expect(scanDisplayRows(rows).map((r) => r['index']), [1, 2]);
    },
  );
  test('unknown placeholders and low confidence do not change item names', () {
    for (final name in [
      null,
      '',
      ' ',
      'UNKNOWN',
      'Unknown item',
      'unidentified object',
      'object 2',
      'Item',
    ]) {
      expect(scanUnknown(row(0, name)), isTrue, reason: '$name');
    }
    expect(scanUnknown(row(0, 'Object holder', confidence: .9)), isFalse);
    expect(scanUnknown(row(0, 'Lamp', confidence: .49)), isTrue);
    expect(scanDisplayName(row(0, 'Lamp', confidence: .49)), 'Lamp');
    expect(scanDisplayName(row(0, null)), 'Unknown item');
  });
  test(
    'only valid identity confidence is shown; no invented detection confidence',
    () {
      for (final score in [double.nan, double.infinity, -1.0, 99.0]) {
        expect(scanConfidence(row(0, 'Drill', confidence: score)), isNull);
      }
      final r = row(0, 'Drill', confidence: .7);
      r['item']['scan_evidence']['identity_confidence'] = .91;
      expect(scanConfidence(r), .91);
      r['item'].remove('confidence');
      r['item']['scan_evidence'] = {'detection_confidence': .99};
      expect(scanConfidence(r), isNull);
    },
  );
  test('letterboxed mapping accounts for portrait and landscape margins', () {
    expect(
      containedScanRect(const Size(100, 200), const Size(300, 300)),
      const Rect.fromLTWH(75, 0, 150, 300),
    );
    expect(
      scanBoxRect(
        const Rect.fromLTRB(.1, .2, .5, .6),
        const Size(100, 200),
        const Size(300, 300),
      ),
      const Rect.fromLTRB(90, 60, 150, 180),
    );
    expect(
      containedScanRect(const Size(400, 200), const Size(300, 300)),
      const Rect.fromLTWH(0, 75, 300, 150),
    );
    expect(containedScanRect(Size.zero, const Size(300, 300)), Rect.zero);
  });
  test('details use returned values without rewriting or inventing fields', () {
    final r = row(0, 'Drill');
    r['item'].addAll({
      'brand': 'ACME',
      'model': 'X1',
      'color': 'Blue',
      'material': 'steel',
      'dimensions': '20 × 4 cm',
      'condition': 'used',
      'description': 'Scratched handle',
      'notes': 'Owner note',
    });
    expect(
      scanDetail(r),
      'ACME · X1 · Blue · steel · 20 × 4 cm · used · Scratched handle · Owner note',
    );
    expect(scanDetail(row(1, 'Plain')), '');
  });

  final fixture = HierarchyFixture();
  late ApiClient api;
  late Map<String, dynamic> draft;
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    api = ApiClient.forWorld(fixture.api, 'personal', isCurrent: () => true);
    draft = {
      'id': 'capture',
      'revision': 7,
      'status': 'draft',
      'source_kind': 'photo',
      'inventory_id': 'inventory',
      'space_id': 'space',
      'location': 'Garage',
      'items': [
        row(71, 'Unknown item', confidence: .99),
        row(42, 'Lamp', confidence: .6),
        row(9, 'Drill', confidence: .95),
      ],
    };
    fixture.requests.clear();
    fixture.status = 200;
    fixture.respond = (r) {
      if (r.method == 'PATCH') {
        for (final change in r.data['changes']['items']) {
          final target = (draft['items'] as List).firstWhere(
            (x) => x['index'] == change['index'],
          );
          if (change.containsKey('selected')) {
            target['selected'] = change['selected'];
          }
          for (final key in ['name', 'quantity', 'category']) {
            if (change.containsKey(key)) target['item'][key] = change[key];
          }
        }
      }
      if (r.path.endsWith('/save')) {
        draft = {
          ...draft,
          'status': 'saved',
          'receipt': {
            'saved_count': 3,
            'review_count': 1,
            'failures': [],
            'resource_links': [],
          },
        };
      }
      return {'capture': jsonDecode(jsonEncode(draft))};
    };
  });
  Future<void> mount(
    WidgetTester t, {
    Brightness brightness = Brightness.light,
    double width = 390,
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(width, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: ChatCaptureCard(
            api: api,
            conversationId: 'chat',
            draft: draft,
            embedded: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'sorted checkbox and edit target stable source id; save payload stays unchanged',
    (t) async {
      final originalOrder = jsonEncode(draft['items']);
      await mount(t);
      expect(
        t.getTopLeft(find.text('Drill')).dy,
        lessThan(t.getTopLeft(find.text('Lamp')).dy),
      );
      await t.tap(find.byKey(const ValueKey('scan-row-9')));
      await t.pumpAndSettle();
      expect(fixture.requests, isEmpty);
      expect(jsonEncode(draft['items']), originalOrder);
      await t.tap(find.byKey(const ValueKey('scan-select-9')));
      await t.pumpAndSettle();
      expect(fixture.requests.last.data, {
        'revision': 7,
        'changes': {
          'items': [
            {'index': 9, 'selected': false},
          ],
        },
      });
      await t.tap(find.byKey(const ValueKey('scan-edit-42')));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Lamp exact edit',
      );
      await t.tap(find.text('Update draft'));
      await t.pumpAndSettle();
      expect(fixture.requests.last.data['changes']['items'][0]['index'], 42);
      expect(draft['items'][1]['item']['name'], 'Lamp exact edit');
      expect(draft['items'].map((r) => r['index']).toList(), [71, 42, 9]);
      await t.tap(find.text('Save items'));
      await t.pumpAndSettle();
      expect(fixture.requests.last.data, {
        'revision': 7,
        'allow_duplicates': false,
      });
      expect(fixture.requests.last.path, endsWith('/captures/capture/save'));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('missing quantity after sorting patches the original row id', (
    t,
  ) async {
    draft['summary'] = {
      'unknown_quantity_indices': [9],
    };
    await mount(t);
    await t.tap(find.text('Add quantity'));
    await t.pumpAndSettle();
    expect(find.text('How many Drill?'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextFormField, 'Quantity'), '12');
    await t.tap(find.text('Update quantity'));
    await t.pumpAndSettle();
    expect(fixture.requests.last.data, {
      'revision': 7,
      'changes': {
        'items': [
          {'index': 9, 'quantity': 12},
        ],
      },
    });
    expect(draft['items'].map((r) => r['index']).toList(), [71, 42, 9]);
    expect(draft['items'][2]['item']['quantity'], 12);
  });
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.6]) {
      testWidgets(
        'review fits narrow ${brightness.name} at $scale with 35 items',
        (t) async {
          draft['items'] = [
            for (var i = 0; i < 35; i++)
              row(
                i,
                i == 34 ? 'Unknown item' : 'A detailed item number $i',
                confidence: i == 34 ? .1 : .9,
              ),
          ];
          await mount(t, brightness: brightness, width: 320, scale: scale);
          final scroll = find.byKey(const Key('extraction-preview-scroll'));
          await t.scrollUntilVisible(
            find.text('Not sure about this one'),
            160,
            scrollable: find
                .descendant(of: scroll, matching: find.byType(Scrollable))
                .first,
            maxScrolls: 70,
          );
          expect(find.text('Not sure about this one'), findsOneWidget);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('status uses real counts, retains Steps and reduced motion', (
    t,
  ) async {
    Future<void> show(String text) => t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: ExtractionProgressPanel(message: text)),
        ),
      ),
    );
    await show('Reading your photo...');
    await t.pumpAndSettle();
    expect(
      t
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0,
    );
    await show('Checked 2 of 5 objects...');
    await t.pumpAndSettle();
    expect(
      t
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .6,
    );
    await t.tap(find.text('Steps'));
    await t.pumpAndSettle();
    expect(find.text('Reading your photo...'), findsOneWidget);
    expect(
      find.text('Nothing is saved until you review and approve.'),
      findsOneWidget,
    );
  });
}
