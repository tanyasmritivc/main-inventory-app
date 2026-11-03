import 'support/extract_photo_fixture.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
bool captureAuditUseNativeViewport = false;

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
    SharedPreferences.setMockInitialValues({});
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
    // Native keyboard insets use device pixels. A fake 390px view with DPR 1
    // makes the real iOS keyboard taller than this test's entire screen.
    if (!captureAuditUseNativeViewport) {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
    }
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
            padding: const EdgeInsets.fromLTRB(16, 54, 16, 24),
            child: ChatCaptureCard(
              api: api,
              conversationId: 'conversation',
              draft: value,
              photoBytes:
                  value['source_kind'] == 'photo' && value['status'] == 'draft'
                  ? extractPhotoFixture
                  : null,
              onChanged: (_) {},
              onOpenResource: onOpen,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  for (final count in [1, 4, 12]) {
    testWidgets(
      'photo prototype renders $count items and excludes low confidence',
      (t) async {
        value['source_kind'] = 'photo';
        value['items'] = [
          for (var i = 0; i < count; i++)
            {
              'index': i,
              'selected': true,
              'item': {
                'name': 'Socket screws $i',
                'category': 'Hardware',
                'quantity': 24,
                if (i == count - 1 && count > 1) 'confidence': .2,
              },
            },
        ];
        await mount(t, brightness: Brightness.dark);
        await t.pump(const Duration(seconds: 2));
        await t.pumpAndSettle();
        expect(find.textContaining('I found $count'), findsOneWidget);
        expect(
          find.text(
            'Save ${count > 1 ? count - 1 : 1} ${count > 2 ? 'items' : 'item'}',
          ),
          findsOneWidget,
        );
        expect(f.requests.where((r) => r.method == 'POST'), isEmpty);
        if (captureAuditCapture != null) {
          await captureAuditCapture!('photo-review-$count');
        }
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('photo typed edit is durable and ambiguous edits fall through', (
    t,
  ) async {
    value['source_kind'] = 'photo';
    await mount(t);
    final card = t.state<ChatCaptureCardState>(find.byType(ChatCaptureCard));
    final update = card.correctFromChat('There are 12 drills');
    await t.pumpAndSettle();
    expect(await update, 'Updated: Drill ×12.');
    expect(value['items'][0]['item']['quantity'], 12);
    expect(await card.correctFromChat('What is in my garage?'), isNull);
    final remove = card.correctFromChat('skip the fastener');
    await t.pumpAndSettle();
    expect(await remove, 'Left out Unknown fastener.');
    expect(value['items'][1]['selected'], false);
    expect(f.requests.where((r) => r.path.endsWith('/save')), isEmpty);
  });
  testWidgets(
    'photo edit sheet keeps edits through failed save and explicit retry',
    (t) async {
      value.addAll({
        'source_kind': 'photo',
        'inventory_id': inv,
        'space_id': space,
        'location': 'Garage',
      });
      await mount(t);
      await t.tap(find.byTooltip('Edit Drill'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'Cordless drill');
      await t.ensureVisible(find.text('Done'));
      if (captureAuditCapture != null) await captureAuditCapture!('photo-edit');
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      expect(value['items'][0]['item']['name'], 'Cordless drill');
      final successful = f.respond;
      f.respond = (_) => {'detail': 'Temporarily unavailable'};
      f.status = 503;
      await t.ensureVisible(find.text('Save 2 items'));
      await t.tap(find.text('Save 2 items'));
      await t.pumpAndSettle();
      expect(value['status'], 'draft');
      expect(find.text('Cordless drill'), findsOneWidget);
      f.status = 200;
      f.respond = successful;
      await t.tap(find.text('Save 2 items'));
      await t.pumpAndSettle();
      expect(value['status'], 'saved');
      expect(f.requests.where((r) => r.path.endsWith('/save')).length, 2);
      if (captureAuditCapture != null) {
        await captureAuditCapture!('photo-saved');
      }
    },
  );
  testWidgets('photo Space search chooses a destination without saving', (
    t,
  ) async {
    value['source_kind'] = 'photo';
    await mount(t);
    await t.ensureVisible(find.text('Choose a Space'));
    await t.tap(find.text('Choose a Space'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'gar');
    await t.pumpAndSettle();
    expect(find.text('Garage'), findsOneWidget);
    if (captureAuditCapture != null) await captureAuditCapture!('photo-space');
    await t.tap(find.text('Garage'));
    await t.pumpAndSettle();
    expect(value['space_id'], space);
    expect(value['status'], 'draft');
    expect(f.requests.where((r) => r.path.endsWith('/save')), isEmpty);
    expect(find.text('Search Spaces'), findsNothing);
  });

  testWidgets(
    'photo creates a Space through the authorized inventory and does not save items',
    (t) async {
      value['source_kind'] = 'photo';
      final original = f.respond;
      f.respond = (r) {
        if (r.path == '/inventories/$inv') {
          return {
            'inventory': inventory(
              inv,
              workspace: 'personal',
              organization: 'personal',
            ),
          };
        }
        if (r.method == 'POST' && r.path == '/inventories/$inv/spaces') {
          return {
            'space': {'id': space, 'name': 'Workbench'},
          };
        }
        return original(r);
      };
      await mount(t);
      await t.ensureVisible(find.text('Choose a Space'));
      await t.tap(find.text('Choose a Space'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Workbench');
      await t.pumpAndSettle();
      await t.tap(find.text('New Space “Workbench”'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Create Space'));
      await t.tap(find.text('Create Space'));
      await t.pumpAndSettle();
      expect(
        f.requests.where(
          (r) => r.method == 'POST' && r.path == '/inventories/$inv/spaces',
        ),
        hasLength(1),
      );
      expect(value['space_id'], space);
      expect(value['status'], 'draft');
      expect(f.requests.where((r) => r.path.endsWith('/save')), isEmpty);
    },
  );
  testWidgets(
    'photo Undo deletes only receipt items and preserves partial retry',
    (t) async {
      const first = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
          second = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
      value.addAll({
        'source_kind': 'photo',
        'status': 'saved',
        'inventory_id': inv,
        'space_id': space,
        'location': 'Garage',
        'receipt': {
          'saved_count': 2,
          'review_count': 0,
          'resource_links': [
            for (final id in [first, second])
              {
                'kind': 'item',
                'id': id,
                'inventory_id': inv,
                'label': 'Saved item',
                'href': 'findez://item/$inv/$id',
              },
          ],
        },
      });
      var fail = true;
      f.respond = (r) {
        if (r.path == '/inventories/$inv') {
          return {
            'inventory': inventory(
              inv,
              workspace: 'personal',
              organization: 'personal',
            ),
          };
        }
        if (r.method == 'DELETE') {
          if (r.queryParameters['item_id'] == second && fail) {
            f.status = 503;
            return {'detail': 'Unavailable'};
          }
          return {'deleted': true};
        }
        return {'capture': value};
      };
      await mount(t);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(
        find.text('Undone. Nothing from that photo was saved.'),
        findsNothing,
      );
      fail = false;
      f.status = 200;
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 3));
      expect(
        find.text('Undone. Nothing from that photo was saved.'),
        findsOneWidget,
      );
      final deletes = f.requests.where((r) => r.method == 'DELETE').toList();
      expect(deletes.map((r) => r.queryParameters['item_id']).toList(), [
        first,
        second,
        second,
      ]);
      expect(
        deletes.every((r) => r.path == '/inventories/$inv/delete_item'),
        isTrue,
      );
    },
  );
  testWidgets(
    'chat save confirms once and a failed save is not retried silently',
    (t) async {
      value.addAll({
        'inventory_id': inv,
        'space_id': space,
        'location': 'Garage',
      });
      await mount(t);
      final saving = t
          .state<ChatCaptureCardState>(find.byType(ChatCaptureCard))
          .saveFromChat();
      await t.pumpAndSettle();
      await saving;
      expect(value['status'], 'saved');
      expect(find.text('Extraction saved'), findsOneWidget);
      expect(f.requests.where((r) => r.path.endsWith('/save')).length, 1);
      await t
          .state<ChatCaptureCardState>(find.byType(ChatCaptureCard))
          .saveFromChat();
      expect(f.requests.where((r) => r.path.endsWith('/save')).length, 1);
    },
  );

  testWidgets(
    'chat save failure keeps draft editable without claiming success',
    (t) async {
      value.addAll({
        'inventory_id': inv,
        'space_id': space,
        'location': 'Garage',
      });
      f.status = 503;
      f.respond = (_) => {'detail': 'Temporarily unavailable'};
      await mount(t);
      final saving = t
          .state<ChatCaptureCardState>(find.byType(ChatCaptureCard))
          .saveFromChat();
      await t.pumpAndSettle();
      await saving;
      expect(value['status'], 'draft');
      expect(find.text('Extraction saved'), findsNothing);
      expect(f.requests.where((r) => r.path.endsWith('/save')).length, 1);
    },
  );

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
      await t.tap(find.widgetWithText(FilledButton, 'Add to Space'));
      await t.pumpAndSettle();
      expect(saves, 3);
      expect(value['status'], 'saved');
      expect(value['receipt']['saved_count'], 600);
    },
  );

  for (final confirm in [true, false]) {
    testWidgets('explicit save choice confirm=$confirm', (t) async {
      value.addAll({
        'inventory_id': inv,
        'space_id': space,
        'location': 'Garage',
      });
      await mount(t);
      await t.tap(
        find.text(confirm ? 'Add to Space' : 'Keep uncertain items in Review'),
      );
      await t.pumpAndSettle();
      final saves = f.requests.where((r) => r.path.endsWith('/save')).toList();
      expect(saves, hasLength(1));
      expect(saves.single.data['confirm_items'], confirm);
      expect(saves.single.data['revision'], 1);
    });
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
      expect(find.text('Check extracted details'), findsOneWidget);
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
      await t.tap(find.text('Add to Space'));
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
      await t.pump(const Duration(milliseconds: 700));
      await t.ensureVisible(find.text('Leave this item out for now'));
      await t.pumpAndSettle();
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
    await t.pump(const Duration(milliseconds: 700));
    await t.ensureVisible(find.text('Update quantity'));
    await t.pumpAndSettle();
    await t.tap(find.text('Update quantity'));
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(value['summary']['unknown_quantity_indices'], isEmpty);
    expect(find.widgetWithText(FilledButton, 'Add to Space'), findsOneWidget);
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
    await t.tap(find.text('Add to Space'));
    await t.pumpAndSettle();
    expect(find.text('Possible existing items'), findsOneWidget);
    await t.tap(find.text('Keep draft'));
    await t.pumpAndSettle();
    expect(value['status'], 'draft');
    await t.tap(find.text('Add to Space'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save separately'));
    await t.pumpAndSettle();
    expect(value['status'], 'saved');
    expect(f.requests.last.data['allow_duplicates'], true);
    expect(f.requests.last.data['confirm_items'], true);
  });
}
