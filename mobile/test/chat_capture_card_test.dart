import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ask_answer.dart';
import 'package:mobile/features/chat/chat_capture_card.dart';
import 'support/hierarchy_fixture.dart';

Future<void> Function(String)? captureAuditCapture;

const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    inv = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    space = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
Map<String, dynamic> draft() => {
  'id': id,
  'version': 1,
  'revision': 1,
  'status': 'draft',
  'items': [
    {
      'index': 0,
      'selected': true,
      'item': {'name': 'Drill', 'category': 'Tools', 'quantity': 1},
    },
    {
      'index': 1,
      'selected': true,
      'item': {
        'name': 'Unknown fastener',
        'category': 'Hardware',
        'quantity': 0,
        'scan_evidence': {'needs_review': true},
      },
    },
  ],
};
void main() {
  final f = HierarchyFixture();
  late Map<String, dynamic> value;
  late ApiClient api;
  setUpAll(f.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    value = draft();
    f.status = 200;
    f.requests.clear();
    api = ApiClient.forWorld(f.api, 'personal', isCurrent: () => true);
    f.respond = (r) {
      if (r.path.endsWith('/spaces')) {
        return {
          'inventories': [
            {
              'inventory_id': inv,
              'name': 'Tools',
              'workspace_name': 'Home',
              'can_edit': true,
              'spaces': [
                {'id': space, 'name': 'Garage'},
              ],
            },
          ],
        };
      }
      if (r.method == 'PATCH') {
        value = jsonDecode(jsonEncode(value));
        final changes = r.data['changes'] as Map;
        if (changes['inventory_id'] != null) {
          value.addAll({
            'inventory_id': inv,
            'space_id': space,
            'location': 'Garage',
            'destination_label': 'Home / Tools',
          });
        }
        for (final item in changes['items'] as List? ?? []) {
          final row = value['items'][item['index']];
          if (item.containsKey('selected')) row['selected'] = item['selected'];
          for (final key in ['quantity', 'name', 'category']) {
            if (item.containsKey(key)) row['item'][key] = item[key];
            if (key == 'quantity' && item.containsKey(key)) {
              (value['summary']?['unknown_quantity_indices'] as List?)?.remove(
                item['index'],
              );
            }
          }
        }
        value['revision']++;
      }
      if (r.path.endsWith('/save')) {
        value = {
          ...value,
          'status': 'saved',
          'receipt': {
            'saved_count': 1,
            'review_count': 1,
            'resource_links': [],
            'failures': [],
          },
        };
      }
      return {'capture': value};
    };
  });
  Future<void> mount(
    WidgetTester t, {
    Brightness brightness = Brightness.light,
    double scale = 1,
    ValueChanged<AskResourceLink>? onOpen,
  }) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: const ValueKey('capture-audit-frame'),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChatCaptureCard(
              api: api,
              conversationId: 'conversation',
              draft: value,
              onChanged: (_) {},
              onOpenResource: onOpen,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'spreadsheet save resumes checkpointed batches without another tap',
    (t) async {
      value = {
        ...draft(),
        'source_kind': 'spreadsheet',
        'inventory_id': inv,
        'space_id': space,
        'location': 'Garage',
      };
      final original = f.respond;
      var saves = 0;
      f.respond = (r) {
        if (!r.path.endsWith('/save')) return original(r);
        saves++;
        value = {
          ...value,
          'status': saves == 3 ? 'saved' : 'saving',
          'processed_count': saves * 200,
          'receipt': {
            'saved_count': saves * 200,
            'review_count': 0,
            'resource_links': [],
            'failures': [],
          },
        };
        return {'capture': value};
      };
      await mount(t);
      await t.tap(find.widgetWithText(FilledButton, 'Save items'));
      await t.pumpAndSettle();
      expect(saves, 3);
      expect(value['status'], 'saved');
      expect(value['receipt']['saved_count'], 600);
    },
  );

  test('invalid capture cannot render editable data', () {
    expect(parseChatCapture(draft()), isNotNull);
    expect(parseChatCapture({...draft(), 'revision': '1'}), isNull);
    expect(
      parseChatCapture({
        ...draft(),
        'items': [
          {'index': 2},
        ],
      }),
      isNull,
    );
  });
  for (final brightness in Brightness.values) {
    testWidgets('explicit capture selection and saving $brightness', (t) async {
      await mount(t, brightness: brightness);
      expect(find.text('Needs Review'), findsOneWidget);
      await captureAuditCapture?.call('draft-${brightness.name}');
      expect(find.byType(ActionChip), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Choose a Space'),
        findsOneWidget,
      );
      await t.tap(find.byType(Checkbox).last);
      await t.pumpAndSettle();
      expect(find.text('1 of 2 selected · Not saved yet'), findsOneWidget);
      expect(f.requests.where((r) => r.path.endsWith('/save')), isEmpty);
      await t.tap(find.widgetWithText(FilledButton, 'Choose a Space'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ListTile, 'Garage'));
      await t.pumpAndSettle();
      expect(find.text('Garage'), findsOneWidget);
      expect(f.requests.where((r) => r.path.endsWith('/save')), isEmpty);
      await t.tap(find.text('Save items'));
      await t.pumpAndSettle();
      expect(find.text('Extraction saved'), findsOneWidget);
      expect(find.text('1 saved · 1 in Review'), findsOneWidget);
      await captureAuditCapture?.call('saved-${brightness.name}');
      expect(f.requests.where((r) => r.path.endsWith('/save')).length, 1);
      expect(t.takeException(), isNull);
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets(
      '1000 saved items stay compact and details are lazy $brightness',
      (t) async {
        value.addAll({
          'status': 'saved',
          'inventory_id': inv,
          'space_id': space,
          'location': 'Garage',
          'items': List.generate(
            1000,
            (i) => {
              'index': i,
              'selected': true,
              'item': {
                'name': 'Part $i',
                'category': 'Hardware',
                'quantity': 1,
              },
            },
          ),
          'receipt': {
            'saved_count': 1000,
            'review_count': 0,
            'failures': [],
            'resource_links': List.generate(
              1000,
              (i) => AskResourceLink(
                kind: 'item',
                id: 'dddddddd-dddd-4ddd-8ddd-${i.toString().padLeft(12, '0')}',
                inventoryId: inv,
                label: 'Part $i',
              ).toJson(),
            ),
          },
        });
        AskResourceLink? opened;
        await mount(t, brightness: brightness, onOpen: (link) => opened = link);
        expect(find.text('1000 saved · 0 in Review'), findsOneWidget);
        expect(find.text('Part 0'), findsNothing);
        expect(find.text('Open Part 0'), findsNothing);
        expect(find.text('Open Part 999'), findsNothing);
        expect(t.getSize(find.byType(ChatCaptureCard)).height, lessThan(300));
        await captureAuditCapture?.call('compact-1000-${brightness.name}');
        await t.tap(find.text('Open Garage'));
        expect(opened?.id, space);
        expect(opened?.kind, 'space');
        await t.tap(find.text('View 1000 extracted items'));
        await t.pumpAndSettle();
        expect(find.text('Extraction details'), findsOneWidget);
        expect(find.text('Part 0'), findsOneWidget);
        expect(find.text('Part 999'), findsNothing);
        expect(find.byType(ListTile).evaluate().length, lessThan(30));
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('large text stays scrollable', (t) async {
    await mount(t, scale: 2);
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Choose a Space'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'unknown quantity is explicit and can be omitted without saving',
    (t) async {
      value['source_kind'] = 'text';
      value['summary'] = {
        'unknown_quantity_indices': [1],
      };
      value['items'][1]['item']['name'] = 'Peas';
      value['items'][1]['item']['quantity'] = 1;
      await mount(t);
      expect(find.textContaining('Quantity needed'), findsOneWidget);
      await captureAuditCapture?.call('unknown-quantity');
      await t.tap(find.widgetWithText(FilledButton, 'Add missing quantity'));
      await t.pumpAndSettle();
      expect(
        t.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
        '',
      );
      await t.tap(find.text('Leave this item out for now'));
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(value['items'][1]['selected'], false);
      expect(
        find.widgetWithText(FilledButton, 'Choose a Space'),
        findsOneWidget,
      );
      expect(f.requests.where((r) => r.path.endsWith('/save')), isEmpty);
    },
  );
  testWidgets('explicitly entering one clears the unknown quantity', (t) async {
    value.addAll({
      'inventory_id': inv,
      'space_id': space,
      'location': 'Pantry',
      'summary': {
        'unknown_quantity_indices': [0],
      },
    });
    await mount(t);
    await t.tap(find.text('Add quantity'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), '1');
    await t.tap(find.text('Update quantity'));
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(value['summary']['unknown_quantity_indices'], isEmpty);
    expect(find.widgetWithText(FilledButton, 'Save items'), findsOneWidget);
    expect(f.requests.where((r) => r.path.endsWith('/save')), isEmpty);
  });
  testWidgets('zero quantity correction retains uncertainty', (t) async {
    await mount(t);
    await t.tap(find.byTooltip('Edit Unknown fastener'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'Quantity'), '0');
    await t.tap(find.text('Update draft'));
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(value['items'][1]['item']['quantity'], 0);
    expect(value['items'][1]['item']['scan_evidence']['needs_review'], true);
    expect(f.requests.where((r) => r.path.endsWith('/save')), isEmpty);
  });
  testWidgets('duplicate save needs a second explicit choice', (t) async {
    value.addAll({
      'inventory_id': inv,
      'space_id': space,
      'location': 'Garage',
      'destination_label': 'Tools',
    });
    final normal = f.respond;
    f.respond = (r) {
      if (r.path.endsWith('/save') && r.data['allow_duplicates'] != true) {
        f.status = 409;
        return {
          'detail': {'code': 'capture_duplicates', 'resource_links': []},
        };
      }
      f.status = 200;
      return normal(r);
    };
    await mount(t);
    await t.tap(find.text('Save items'));
    await t.pumpAndSettle();
    expect(find.text('Possible existing items'), findsOneWidget);
    await t.tap(find.text('Keep draft'));
    await t.pumpAndSettle();
    expect(value['status'], 'draft');
    await t.tap(find.text('Save items'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save separately'));
    await t.pumpAndSettle();
    expect(value['status'], 'saved');
    expect(f.requests.last.data['allow_duplicates'], true);
  });
}
