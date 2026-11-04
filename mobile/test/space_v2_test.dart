import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:mobile/features/founding_access/riso_art.dart';
import 'package:mobile/core/private_image.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/ask_answer.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/chat_source.dart';
import 'package:mobile/core/inventory_context.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import 'package:mobile/features/inventory/space_v2/space_widgets.dart';
import 'package:mobile/features/inventory/space_v2/space_style.dart';
import 'package:mobile/features/chat/chat_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/hierarchy_fixture.dart';

Future<void> Function(String)? spaceV2Capture;
Future<void> Function(Future<void> Function())? spacePolishProfile;

class _Api extends ApiClient {
  _Api(this.fixture, {bool viewer = false, String? spaceId, _Api? source})
    : stream = source?.stream ?? StreamController<AiStreamEvent>.broadcast(),
      messages = source?.messages ?? <String>[],
      super(
        baseUrl: 'https://api.test',
        chatSpaceId: spaceId,
        httpClient: dio.Dio(dio.BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = fixture,
        inventoryContext: InventoryContext.fromJson(
          inventory(
            'inventory-a',
            name: 'Parts Inventory',
            role: viewer ? 'viewer' : 'editor',
          ),
          accountId: 'actor-a',
          expectedInventory: 'inventory-a',
        ),
      );
  final HierarchyFixture fixture;
  final StreamController<AiStreamEvent> stream;
  final List<String> messages;
  @override
  ApiClient bindSpaceChat(String spaceId) =>
      _Api(fixture, viewer: !canEdit, spaceId: spaceId, source: this);
  @override
  void assertCurrentContext() {}
  @override
  Stream<AiStreamEvent> aiCommandStream({
    required String message,
    String? conversationId,
    String? requestId,
    List<ChatSource> sources = const [],
  }) {
    messages.add(message);
    return stream.stream;
  }
}

Map<String, dynamic> row(int i, {String kind = 'manual'}) => {
  'item_id': 'item-$i',
  'name': i == 0
      ? '5mm Timing Belts - Tooth Count 120.0'
      : 'PN-F${i.toString().padLeft(3, '0')}',
  'quantity': i == 0 ? 2 : i + 1,
  'category': i.isEven ? 'Supplies' : 'Hardware',
  'location': 'Fastener DB',
  'space_id': 'space-a',
  'created_at': '2026-04-01T10:30:00Z',
  'brand': 'Original Brand',
  'part_number': i == 0 ? 'PN-F105' : null,
  'notes': 'Keep casing: M5 / 0.50',
  'purchase_source': 'Original supplier',
  'tags': ['M5', 'spare'],
  if (kind == 'auto') 'confidence': .93,
  if (kind == 'import')
    'import_data': {
      'filename': 'Parts.xlsx',
      'sheet': 'Original sheet',
      'row_index': 2,
      'fields': [
        {'name': 'Part Number', 'value': 'PN-F105'},
        {'name': 'Tooth Count', 'value': 120.0},
        {'name': 'Finish / Custom', 'value': 'Blue - keep CASE'},
        {'name': 'Part Number', 'value': 'Original duplicate'},
      ],
    },
};

void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  late List<Map<String, dynamic>> data;
  bool failWrite = false;
  Completer<void>? pending;
  setUp(() {
    data = [];
    fixture.requests.clear();
    fixture.status = 200;
    failWrite = false;
    pending = null;
    fixture.respond = (request) async {
      if (request.path.endsWith('/update_item')) {
        await pending?.future;
        if (failWrite) {
          fixture.status = 500;
          return {'detail': 'Could not save this item.'};
        }
        final body = Map<String, dynamic>.from(request.data as Map);
        final item = data.firstWhere(
          (item) => item['item_id'] == body['item_id'],
        );
        item.addAll(body);
        if (body['location'] == 'Shelf B') item['space_id'] = 'space-b';
        return {'item': item};
      }
      if (request.path.endsWith('/spaces')) {
        return {
          'spaces': [
            {'id': 'space-a', 'name': 'Fastener DB'},
            {'id': 'space-b', 'name': 'Shelf B'},
          ],
        };
      }
      if (request.path.endsWith('/conversations')) {
        return [
          {
            'id': 'history-a',
            'title': 'Saved conversation',
            'created_at': '2026-04-01T10:30:00Z',
            'updated_at': '2026-04-01T10:30:00Z',
          },
        ];
      }
      if (request.path.endsWith('/conversations/history-a')) {
        return {
          'conversation': {'id': 'history-a', 'title': 'Saved conversation'},
          'messages': [
            {
              'id': 'message-a',
              'role': 'assistant',
              'content': 'Saved inventory answer.',
              'created_at': '2026-04-01T10:30:00Z',
            },
          ],
        };
      }
      if (request.path.endsWith('/search_items')) {
        return {'items': data, 'parsed': {}};
      }
      return {
        'photos': [],
        'documents': [],
        'active': [],
        'returned': [],
        'notifications': [],
        'unread_count': 0,
        'conversations': [],
      };
    };
  });

  Future<_Api> mount(
    WidgetTester tester,
    int count, {
    String kind = 'manual',
    bool photos = false,
    bool low = true,
    bool viewer = false,
    ThemeMode mode = ThemeMode.dark,
    double scale = 1,
    double keyboard = 0,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    data = List.generate(
      count,
      (i) => {
        ...row(i, kind: kind),
        if (photos) 'image_url': 'https://images.test/item-$i.jpg',
      },
    );
    await tester.runAsync(() async {
      await Future.wait(RisoPalette.values.map(RisoTile.image));
      if (photos) {
        final bytes = await rootBundle.load(
          'assets/onboarding/sample_workbench.jpg',
        );
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        for (var i = 0; i < count; i++) {
          PaintingBinding.instance.imageCache.putIfAbsent(
            NetworkImage('https://images.test/item-$i.jpg'),
            () => OneFrameImageStreamCompleter(
              Future.value(ImageInfo(image: frame.image.clone())),
            ),
          );
        }
        frame.image.dispose();
      }
    });
    final api = _Api(fixture, viewer: viewer);
    final items = data.map(InventoryItem.fromJson).toList();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('space-v2-frame'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.create(Brightness.light),
          darkTheme: AppTheme.create(Brightness.dark),
          themeMode: mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 44, bottom: 24),
              viewPadding: const EdgeInsets.only(top: 44, bottom: 24),
              textScaler: TextScaler.linear(scale),
              viewInsets: keyboard > 0
                  ? EdgeInsets.only(bottom: keyboard)
                  : MediaQuery.viewInsetsOf(context),
            ),
            child: child!,
          ),
          home: LocationItemsPage(
            api: api,
            location: 'Fastener DB',
            spaceId: 'space-a',
            items: items,
            allItems: items,
            thresholds: low ? const {'item-0': 3} : const {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(api.stream.close);
    return api;
  }

  for (final mode in ThemeMode.values) {
    testWidgets('compact Space header and solid actions ${mode.name}', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await mount(tester, 30, mode: mode);
      final title = find.text('Fastener DB');
      expect(title, findsOneWidget);
      expect(
        tester.widget<Text>(title).style!.fontFamily,
        'CupertinoSystemText',
      );
      expect(tester.widget<Text>(title).style!.fontWeight, FontWeight.w400);
      final count = find.byKey(const ValueKey('space-unit-count'));
      expect(tester.getCenter(count).dx, closeTo(195, 1));
      expect(tester.getCenter(title).dx, closeTo(195, 1));
      final page = find.byType(LocationItemsPage);
      Color background() => tester
          .widget<Scaffold>(
            find.descendant(of: page, matching: find.byType(Scaffold)).first,
          )
          .backgroundColor!;
      expect(background().computeLuminance() > .5, mode != ThemeMode.dark);
      await spaceV2Capture?.call('compact-${mode.name}');
      if (mode == ThemeMode.system) {
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        await tester.pumpAndSettle();
        expect(background().computeLuminance(), lessThan(.1));
        await spaceV2Capture?.call('system-dark');
      }
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('space-title-fade')))
            .opacity,
        0,
      );
      expect(find.byTooltip('Sort').hitTestable(), findsOneWidget);
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      final pinnedY = tester.getTopLeft(find.byType(TextField).first).dy;
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(TextField).first).dy,
        closeTo(pinnedY, .1),
      );
      for (final glass in find.byType(SpaceHeaderGlass).evaluate()) {
        expect(glass.size!.width, 390);
      }
      await spaceV2Capture?.call('scrolled-${mode.name}');
      await tester.tap(find.byType(SpaceItemRow).hitTestable().first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Move'));
      await tester.pumpAndSettle();
      for (final label in ['Move', 'Ask']) {
        final buttonFinder = find.ancestor(
          of: find.text(label),
          matching: find.byType(FilledButton),
        );
        final button = tester.widget<FilledButton>(buttonFinder);
        final style = button.style!;
        final color = style.backgroundColor!.resolve({})!;
        expect(color.a, 1);
        final marker = Container();
        expect(
          style.backgroundBuilder!(tester.element(buttonFinder), {}, marker),
          same(marker),
        );
        expect(style.shape!.resolve({}), isA<StadiumBorder>());
        final foreground = style.foregroundColor!.resolve({})!;
        final a = color.computeLuminance(), b = foreground.computeLuminance();
        expect(
          ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05),
          greaterThan(4.5),
        );
      }
      if (mode == ThemeMode.system) {
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        await tester.pumpAndSettle();
        final move = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Move'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(
          move.style!.backgroundColor!.resolve({})!.computeLuminance(),
          greaterThan(.5),
        );
      }
      await spaceV2Capture?.call('actions-${mode.name}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'Space polish preserves photos and hides zero low card without new requests',
    (tester) async {
      await mount(tester, 3, photos: true, low: false);
      expect(find.text('Low quantity'), findsNothing);
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Items to finish'), findsNothing);
      expect(find.byType(PrivateImage), findsNWidgets(3));
      expect(fixture.requests.where((r) => r.path.contains('review')), isEmpty);
      final sort = tester.getRect(find.text('Part # / Item A → Z'));
      final quantity = tester.getRect(find.text('2').first);
      expect(sort.right, closeTo(quantity.right, .1));
      await spaceV2Capture?.call('photos-no-low');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Space 300 cached tiles scroll profile', (tester) async {
    await mount(tester, 300);
    expect(
      identical(
        RisoTile.image(RisoPalette.plumRust),
        RisoTile.image(RisoPalette.plumRust),
      ),
      isTrue,
    );
    Future<void> scroll() async {
      for (var i = 0; i < 12; i++) {
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, -650),
          1800,
        );
        await tester.pumpAndSettle();
      }
    }

    if (spacePolishProfile != null) {
      await spacePolishProfile!(scroll);
    } else {
      await scroll();
    }
    expect(find.byType(SpaceItemRow).evaluate().length, lessThan(20));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final count in [0, 3, 40, 298]) {
    testWidgets(
      'Space $count items has stable layout, search, low filter and lazy rows',
      (tester) async {
        await mount(tester, count);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(SpaceItemRow).evaluate().length, lessThan(20));
        await spaceV2Capture?.call('space-$count');
        if (count > 0) {
          await tester.tap(find.text('Low quantity'));
          await tester.pumpAndSettle();
          expect(find.text('PN-F105'), findsOneWidget);
          expect(find.text('PN-F001'), findsNothing);
          await spaceV2Capture?.call('low-$count');
          await tester.tap(find.text('Low quantity').first);
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'no such part');
          await tester.pumpAndSettle();
          expect(find.textContaining('No “no such part”'), findsOneWidget);
          await tester.tap(find.byTooltip('Clear search'));
          await tester.pumpAndSettle();
        }
        if (count == 298) {
          await tester.scrollUntilVisible(
            find.text('PN-F090'),
            500,
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(find.text('PN-F090').hitTestable(), findsOneWidget);
          expect(find.byType(TextField).hitTestable(), findsOneWidget);
          await spaceV2Capture?.call('scrolled-298');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final kind in ['manual', 'auto', 'import']) {
    testWidgets(
      '$kind quick view preserves field labels, values, order and edit destination',
      (tester) async {
        await mount(tester, 3, kind: kind);
        final before = data.first.toString();
        await tester.tap(find.text('PN-F105'));
        await tester.pumpAndSettle();
        final quick = find.byKey(const ValueKey('space-quick-view'));
        final scrollable = find.descendant(
          of: quick,
          matching: find.byType(Scrollable),
        );
        expect(quick, findsOneWidget);
        await spaceV2Capture?.call('quick-$kind');
        await tester.scrollUntilVisible(
          find.text('Part number'),
          300,
          scrollable: scrollable,
        );
        final labels = find
            .descendant(of: quick, matching: find.byType(Text))
            .evaluate()
            .map((element) => (element.widget as Text).data)
            .whereType<String>()
            .toList();
        for (final label in [
          'Description',
          'Part number',
          'Category',
          'Location',
          'Quantity',
          'Brand',
          'Barcode',
          'Subcategory',
          'Date added',
          'Tags',
        ]) {
          expect(labels, contains(label));
        }
        expect(
          labels.indexOf('Part number'),
          lessThan(labels.indexOf('Category')),
        );
        if (kind == 'import') {
          await tester.scrollUntilVisible(
            find.text('Finish / Custom'),
            300,
            scrollable: scrollable,
          );
          expect(find.text('Part Number'), findsNWidgets(2));
          expect(find.text('Blue - keep CASE'), findsOneWidget);
          expect(find.text('120.0'), findsOneWidget);
          await spaceV2Capture?.call('import-fields');
        }
        final editPart = find.byKey(const ValueKey('space-edit-part_number'));
        await tester.scrollUntilVisible(editPart, -300, scrollable: scrollable);
        await tester.tap(editPart);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('space-item-field-part_number')),
          findsOneWidget,
        );
        expect(find.text('Edit'), findsNothing);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(data.first.toString(), before);
        expect(fixture.requests.where((r) => r.method != 'GET'), isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'inline part editing preserves failed draft and sends one confirmed update',
    (tester) async {
      await mount(tester, 3);
      await tester.tap(find.text('PN-F105'));
      await tester.pumpAndSettle();
      final scroll = find.descendant(
        of: find.byKey(const ValueKey('space-quick-view')),
        matching: find.byType(Scrollable),
      );
      final edit = find.byKey(const ValueKey('space-edit-part_number'));
      await tester.scrollUntilVisible(edit, 300, scrollable: scroll);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('space-item-field-part_number'));
      await tester.enterText(input, 'NEW-123');
      await spaceV2Capture?.call('inline-edit');
      failWrite = true;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).decoration!.errorText, isNotEmpty);
      expect(tester.widget<TextField>(input).controller!.text, 'NEW-123');
      expect(data.first['part_number'], 'PN-F105');
      failWrite = false;
      fixture.status = 200;
      pending = Completer<void>();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.tap(find.text('Saving...'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(
        fixture.requests.where((r) => r.path.endsWith('/update_item')).length,
        2,
      );
      pending!.complete();
      await tester.pumpAndSettle();
      expect(data.first['part_number'], 'NEW-123');
      expect(input, findsNothing);
      expect(find.text('Edit'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'photo section opens the full image and empty section offers camera or library',
    (tester) async {
      await mount(tester, 3, photos: true);
      await tester.tap(find.text('PN-F105'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('space-item-photo')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('full-item-photo')), findsOneWidget);
      final photo = tester.widget<PrivateImage>(
        find.descendant(
          of: find.byKey(const ValueKey('full-item-photo')),
          matching: find.byType(PrivateImage),
        ),
      );
      expect(photo.fit, BoxFit.contain);
      await spaceV2Capture?.call('full-photo');
      await tester.tap(find.byTooltip('Close photo'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await mount(tester, 3);
      await tester.tap(find.text('PN-F105'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('space-item-photo')));
      await tester.pumpAndSettle();
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose photo'), findsOneWidget);
      await spaceV2Capture?.call('add-photo');
      expect(find.text('Cancel'), findsNothing);
      await tester.tapAt(const Offset(4, 40));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('space-quick-view')), findsOneWidget);
      expect(fixture.requests.where((r) => r.method != 'GET'), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'alert threshold is editable in place without an inventory write',
    (tester) async {
      await mount(tester, 3);
      await tester.tap(find.text('PN-F105'));
      await tester.pumpAndSettle();
      final scroll = find.descendant(
        of: find.byKey(const ValueKey('space-quick-view')),
        matching: find.byType(Scrollable),
      );
      final field = find.byKey(const ValueKey('space-edit-threshold'));
      await tester.scrollUntilVisible(field, 300, scrollable: scroll);
      await tester.tap(field);
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('space-item-field-threshold'));
      await tester.enterText(input, '-2');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).decoration!.errorText, isNotEmpty);
      await tester.enterText(input, '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(input, findsNothing);
      expect(
        fixture.requests.where((r) => r.path.endsWith('/update_item')),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('swipe dismissal protects an unsaved inline edit', (
    tester,
  ) async {
    await mount(tester, 3);
    await tester.tap(find.text('PN-F105'));
    await tester.pumpAndSettle();
    final scroll = find.descendant(
      of: find.byKey(const ValueKey('space-quick-view')),
      matching: find.byType(Scrollable),
    );
    final edit = find.byKey(const ValueKey('space-edit-name'));
    await tester.scrollUntilVisible(edit, 250, scrollable: scroll);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('space-item-field-name')),
      'Changed draft',
    );
    tester.state<ScrollableState>(scroll.first).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SpaceHandle).last, const Offset(0, 180));
    await tester.pumpAndSettle();
    expect(find.text('Save your changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Changed draft'), findsOneWidget);
    expect(data.first['name'], '5mm Timing Belts - Tooth Count 120.0');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('space-quick-view')), findsNothing);
    expect(data.first['name'], '5mm Timing Belts - Tooth Count 120.0');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'quantity is confirmed, duplicate taps blocked, failure visible, move removes row',
    (tester) async {
      await mount(tester, 3, kind: 'import');
      final originalImport = data.first['import_data'].toString();
      await tester.tap(find.text('PN-F105'));
      await tester.pumpAndSettle();
      pending = Completer<void>();
      await tester.tap(find.byTooltip('Add one'));
      await tester.pump();
      await tester.tap(find.byTooltip('Add one'));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(fixture.requests.where((r) => r.method == 'PATCH').length, 1);
      pending!.complete();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Saved · 3 left'), findsOneWidget);
      pending = null;
      failWrite = true;
      await tester.tap(find.byTooltip('Use one'));
      await tester.pumpAndSettle();
      expect(data.first['quantity'], 3);
      expect(find.text('Saved · 2 left'), findsNothing);
      failWrite = false;
      fixture.status = 200;
      await tester.tap(find.byTooltip('Use one'));
      await tester.pumpAndSettle();
      expect(data.first['quantity'], 2);
      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('space-quick-view')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Move'),
        300,
        scrollable: scrollable,
      );
      await tester.tap(find.text('Move'));
      await tester.pumpAndSettle();
      await spaceV2Capture?.call('move');
      await tester.tap(find.text('Shelf B'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      expect(data.first['location'], 'Shelf B');
      expect(data.first['import_data'].toString(), originalImport);
      await tester.tapAt(const Offset(4, 80));
      await tester.pumpAndSettle();
      expect(find.text('PN-F105'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'all sort choices remain usable, menu and add sheet dismiss cleanly',
    (tester) async {
      await mount(tester, 40);
      for (final label in [
        'Quantity: Low → High',
        'Quantity: High → Low',
        'Category A → Z',
        'Newest first',
        'Oldest first',
        'Part # / Item Z → A',
        'Part # / Item A → Z',
      ]) {
        await tester.tap(find.byTooltip('Sort'));
        await tester.pumpAndSettle();
        if (label == 'Quantity: Low → High') await spaceV2Capture?.call('sort');
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Sort').hitTestable(), findsOneWidget);
      }
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await spaceV2Capture?.call('menu');
      await tester.tapAt(const Offset(10, 160));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add items'));
      await tester.pumpAndSettle();
      await spaceV2Capture?.call('add');
      await tester.tap(find.text('Type it in'));
      await tester.pumpAndSettle();
      final composer = find.descendant(
        of: find.byType(ChatPage),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(composer).controller!.text, 'Add ');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final resultCount in [0, 1, 6]) {
    testWidgets(
      'Ask $resultCount results uses Space scope and server references',
      (tester) async {
        final api = await mount(tester, 40);
        await tester.tap(find.text('Ask about Fastener DB'));
        await tester.pumpAndSettle();
        expect(find.text('Only in Fastener DB'), findsOneWidget);
        expect(
          tester.widget<ChatPage>(find.byType(ChatPage)).api.chatSpaceId,
          'space-a',
        );
        await spaceV2Capture?.call('ask-empty');
        await tester.enterText(
          find.descendant(
            of: find.byType(ChatPage),
            matching: find.byType(TextField),
          ),
          'Find supplies',
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Send message'));
        await tester.pump();
        expect(api.messages, ['Find supplies']);
        api.stream.add(
          AiStreamEvent(
            type: 'delta',
            delta: resultCount == 0
                ? 'No matching items found.'
                : 'Here are the matching items.',
          ),
        );
        api.stream.add(
          AiStreamEvent(
            type: 'done',
            conversationId: 'conversation-a',
            answerContext: AskAnswerContext(
              rows: [
                for (var i = 0; i < resultCount; i++)
                  AskResultRow(
                    id: 'item-$i',
                    name: data[i]['name'] as String,
                    availableQuantity: data[i]['quantity'] as int,
                    location: 'Fastener DB',
                  ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await spaceV2Capture?.call('ask-$resultCount');
        if (resultCount == 1) {
          final card = find.descendant(
            of: find.byType(ChatPage),
            matching: find.byType(SpaceItemRow),
          );
          await tester.ensureVisible(card);
          await tester.tap(card);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('space-quick-view')),
            findsOneWidget,
          );
          await spaceV2Capture?.call('quick-from-ask');
          await tester.drag(
            find.byType(SpaceHandle).last,
            const Offset(0, 180),
          );
          await tester.pumpAndSettle();
          expect(find.byType(ChatPage), findsOneWidget);
          await tester.ensureVisible(find.text('− I used one'));
          await tester.tap(find.text('− I used one'));
          await tester.pumpAndSettle();
          expect(data.first['quantity'], 1);
          expect(find.text('Saved · 1 left'), findsOneWidget);
          await tester.ensureVisible(find.text('Move'));
          await tester.tap(find.text('Move'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Shelf B'));
          await tester.pumpAndSettle();
          expect(data.first['location'], 'Shelf B');
          expect(find.text('Show low quantity in list'), findsNothing);
        }
        if (resultCount == 0) {
          await tester.tap(find.byTooltip('New chat'));
          await tester.pumpAndSettle();
          expect(find.text('Ask about Fastener DB.'), findsOneWidget);
          await tester.tap(find.byTooltip('Chat history'));
          await tester.pumpAndSettle();
          expect(find.byTooltip('Close history'), findsNothing);
          expect(find.text('Saved conversation'), findsOneWidget);
          expect(find.text("Couldn't load history."), findsNothing);
          await spaceV2Capture?.call('ask-history');
          await tester.tap(find.text('Saved conversation'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Saved inventory answer.'),
            findsOneWidget,
          );
          await spaceV2Capture?.call('ask-history-loaded');
        }
        if (resultCount == 6) {
          await tester.ensureVisible(find.text('See all 6 in the list'));
          await tester.tap(find.text('See all 6 in the list'));
          await tester.pumpAndSettle();
          expect(find.byType(ChatPage), findsNothing);
          expect(find.text('Ask results'), findsOneWidget);
        } else {
          await tester.drag(
            find.byType(SpaceHandle).last,
            const Offset(0, 180),
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('keyboard keeps Ask header and composer outside messages', (
    tester,
  ) async {
    await mount(tester, 3);
    await tester.tap(find.text('Ask about Fastener DB'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(ChatPage),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'Where are the belts?');
    await tester.pump();
    expect(find.byType(SpaceHandle).hitTestable(), findsOneWidget);
    expect(find.byTooltip('Send message').hitTestable(), findsOneWidget);
    expect(tester.getBottomLeft(field).dy, lessThan(544));
    await spaceV2Capture?.call('ask-keyboard');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('viewer quick view has no quantity or move writes', (
    tester,
  ) async {
    await mount(tester, 3, viewer: true);
    await tester.tap(find.text('PN-F105'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Use one'), findsNothing);
    expect(find.byTooltip('Add one'), findsNothing);
    expect(find.text('Move'), findsNothing);
    expect(fixture.requests.where((r) => r.method != 'GET'), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'narrow large-text keyboard Ask is bounded and read-only hides writes',
    (tester) async {
      await mount(
        tester,
        3,
        viewer: true,
        scale: 1.8,
        size: const Size(320, 844),
      );
      expect(find.byTooltip('Add items'), findsNothing);
      await tester.tap(find.text('Ask about Fastener DB'));
      await tester.pumpAndSettle();
      await spaceV2Capture?.call('ask-large-text');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.byType(SpaceHandle).hitTestable(), findsOneWidget);
      expect(find.byTooltip('Send message').hitTestable(), findsOneWidget);
      await spaceV2Capture?.call('ask-large-text-keyboard');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
