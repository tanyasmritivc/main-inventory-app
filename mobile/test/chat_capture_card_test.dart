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
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

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
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save items'),
            )
            .onPressed,
        isNull,
      );
      await t.tap(find.byType(Checkbox).last);
      await t.pumpAndSettle();
      expect(find.text('1 of 2 selected · Not saved yet'), findsOneWidget);
      expect(f.requests.where((r) => r.path.endsWith('/save')), isEmpty);
      await t.tap(find.text('Choose inventory and Space'));
      await t.pumpAndSettle();
      await t.tap(find.text('Garage'));
      await t.pumpAndSettle();
      expect(find.text('Home / Tools / Garage'), findsOneWidget);
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
  testWidgets('large text stays scrollable', (t) async {
    await mount(t, scale: 2);
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.text('Save items'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
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
