import 'package:mobile/features/world/world_style.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/low_stock_prefs.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import 'package:mobile/features/inventory/item_detail_drag_sheet.dart';
import 'package:mobile/features/inventory/item_detail_sheet.dart';
import 'package:mobile/features/sharing/shared_inventory_page.dart';

const _data = <String, dynamic>{
  'item_id': 'test-cable',
  'name': 'servo extension cable',
  'category': 'Electronics',
  'quantity': 2,
  'location': 'Parts Room',
  'created_at': '2026-09-29T12:00:00Z',
  'notes': 'Original notes',
  'purchase_source': 'Original store',
};

class _Api extends ApiClient {
  _Api() : super(baseUrl: 'https://api.test');
  Map<String, dynamic> data = Map.from(_data);
  final writes = <UpdateItemRequest>[];
  final photoShares = <String?>[];
  Completer<void>? save;
  Completer<List<ItemPhoto>>? photos;
  List<ItemPhoto> photoList = [];
  Completer<ItemPhotoMutationResult>? deletePhoto;
  List<Map<String, dynamic>> checkouts = [];
  Completer<void>? returning;
  bool failReturn = false;
  bool failSave = false;

  @override
  Future<List<DocumentEntry>> getDocuments({String? itemId}) async => [];
  @override
  Future<List<Map<String, dynamic>>> getItemCheckouts({
    required String itemId,
  }) async => checkouts;
  @override
  Future<void> returnItem({required String checkoutId}) async {
    if (returning != null) await returning!.future;
    if (failReturn) throw StateError('SECRET return exception');
    checkouts = [];
  }

  @override
  Future<List<ItemPhoto>> getItemPhotos({
    required String itemId,
    String? shareId,
  }) async {
    photoShares.add(shareId);
    return photos == null ? photoList : photos!.future;
  }

  @override
  Future<ItemPhotoMutationResult> deleteItemPhoto({
    required String itemId,
    required String photoId,
    String? shareId,
  }) => deletePhoto!.future;

  @override
  Future<List<dynamic>> getShareInventory(String shareId) async => [
    Map<String, dynamic>.from(data),
  ];
  @override
  Future<List<Map<String, dynamic>>> getShareMembers({
    required String shareId,
  }) async => [];
  @override
  Future<InventoryItem> updateItem({required UpdateItemRequest request}) async {
    writes.add(request);
    if (save != null) await save!.future;
    if (failSave) throw StateError('SECRET server exception');
    data.addAll(request.toJson());
    return InventoryItem.fromJson(data);
  }
}

final _visualBoundary = GlobalKey();
Future<void> Function(String, Uint8List)? itemDetailCapture;
final _scroll = find.byKey(const ValueKey('item-detail-scroll'));
final _handle = find.byKey(const ValueKey('item-detail-drag-handle'));
final _notes = find.byKey(const ValueKey('item-detail-notes'));
final _source = find.byKey(const ValueKey('item-detail-purchase-source'));

Future<void> _open(
  WidgetTester tester,
  _Api api, {
  String permission = 'edit',
  String? shareId,
  TextScaler scaler = TextScaler.noScaling,
  double keyboard = 0,
  ValueChanged<int?>? onThresholdChanged,
  Brightness brightness = Brightness.dark,
  bool styled = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _visualBoundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: const bool.fromEnvironment('FINDEZ_VISUAL_QA')
            ? AppTheme.create(brightness).copyWith(
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    textStyle: const TextStyle(fontFamily: 'FindEZ-QA'),
                  ),
                ),
                textTheme: AppTheme.create(
                  brightness,
                ).textTheme.apply(fontFamily: 'FindEZ-QA'),
                primaryTextTheme: AppTheme.create(
                  brightness,
                ).primaryTextTheme.apply(fontFamily: 'FindEZ-QA'),
              )
            : AppTheme.create(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: scaler,
            viewInsets: EdgeInsets.only(bottom: keyboard),
            padding: const EdgeInsets.only(top: 47, bottom: 34),
          ),
          child: styled ? WorldStyle(child: child!) : child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showItemDetailSheet(
                context,
                item: InventoryItem.fromJson(api.data),
                api: api,
                permission: permission,
                shareId: shareId,
                spaceName: 'Parts Room',
                onThresholdChanged: onThresholdChanged,
              ),
              child: const Text('Open info'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open info'));
  if (api.photos == null) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

ScrollController _controller(WidgetTester tester) =>
    tester.widget<SingleChildScrollView>(_scroll).controller!;

Future<void> _pull(WidgetTester tester, {bool fromHandle = true}) async {
  if (fromHandle) {
    _controller(tester).jumpTo(0);
    await tester.pump();
  }
  final point = fromHandle
      ? tester.getCenter(_handle)
      : tester.getTopLeft(_scroll) + const Offset(40, 250);
  await tester.dragFrom(point, const Offset(0, 350));
  await tester.pumpAndSettle();
}

Future<void> _editNotes(WidgetTester tester, String text) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('item-detail-notes-display')),
  );
  await tester.tap(find.byKey(const ValueKey('item-detail-notes-display')));
  await tester.pumpAndSettle();
  await tester.enterText(_notes, text);
  await tester.pump();
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('lower item info uses one field surface ${brightness.name}', (
      tester,
    ) async {
      await _open(tester, _Api(), brightness: brightness, styled: true);
      for (final key in [
        'item-detail-purchase-source',
        'item-detail-threshold',
      ]) {
        final field = tester.widget<TextField>(find.byKey(ValueKey(key)));
        expect(field.decoration!.filled, false);
        expect(field.decoration!.enabledBorder, InputBorder.none);
        expect(field.decoration!.focusedBorder, InputBorder.none);
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('item-detail-purchase-source')),
      );
      await tester.pumpAndSettle();
      if (itemDetailCapture != null) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_visualBoundary),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await itemDetailCapture!(
          'item-details-${brightness.name}',
          data!.buffer.asUint8List(),
        );
        image.dispose();
      }
      _controller(tester).jumpTo(_controller(tester).position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('Close').hitTestable(), findsOneWidget);
      if (itemDetailCapture != null) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_visualBoundary),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await itemDetailCapture!(
          'item-details-bottom-${brightness.name}',
          data!.buffer.asUint8List(),
        );
        image.dispose();
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} Viewer can swipe from crop to original in item info',
      (tester) async {
        final api = _Api()
          ..photoList = const [
            ItemPhoto(
              photoId: 'crop',
              imageUrl: 'https://api.test/crop.jpg',
              isPrimary: true,
            ),
            ItemPhoto(
              photoId: 'original',
              imageUrl: 'https://api.test/original.jpg',
              isPrimary: false,
            ),
          ];
        await _open(tester, api, permission: 'view', brightness: brightness);
        expect(find.text('1 of 2'), findsOneWidget);
        await tester.drag(find.byType(PageView), const Offset(-300, 0));
        await tester.pumpAndSettle();
        expect(find.text('2 of 2'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('view-item-photo-1')));
        await tester.pumpAndSettle();
        expect(find.text('Photo 2 of 2'), findsOneWidget);
        final viewer = tester.widget<InteractiveViewer>(
          find.byKey(const ValueKey('full-item-photo')),
        );
        final image = find.descendant(
          of: find.byKey(const ValueKey('full-item-photo')),
          matching: find.byType(Image),
        );
        expect(tester.widget<Image>(image).fit, BoxFit.contain);
        final center = tester.getCenter(
          find.byKey(const ValueKey('full-item-photo')),
        );
        final left = await tester.startGesture(
          center - const Offset(30, 0),
          pointer: 1,
        );
        final right = await tester.startGesture(
          center + const Offset(30, 0),
          pointer: 2,
        );
        await left.moveTo(center - const Offset(90, 0));
        await right.moveTo(center + const Offset(90, 0));
        await tester.pump();
        await left.up();
        await right.up();
        await tester.pumpAndSettle();
        expect(
          viewer.transformationController!.value.getMaxScaleOnAxis(),
          greaterThan(1),
        );
        await tester.tap(find.text('Reset zoom'));
        await tester.pump();
        expect(viewer.transformationController!.value, Matrix4.identity());
        await tester.tap(find.byTooltip('Previous photo'));
        await tester.pumpAndSettle();
        expect(find.text('Photo 1 of 2'), findsOneWidget);
        await tester.tap(find.byTooltip('Close photo'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('full-item-photo')), findsNothing);
        expect(find.text('2 of 2'), findsOneWidget);
        expect(find.byTooltip('Delete photo'), findsNothing);
        expect(_scroll, findsOneWidget);
        expect(api.writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.6]) {
      testWidgets(
        '${brightness.name} item info supports $scale text and swipe dismissal',
        (tester) async {
          final api = _Api();
          await _open(
            tester,
            api,
            brightness: brightness,
            scaler: TextScaler.linear(scale),
          );
          expect(find.text('servo extension cable'), findsWidgets);
          expect(tester.takeException(), isNull);
          await _pull(tester);
          await tester.pumpAndSettle();
          expect(_scroll, findsNothing);
          expect(api.writes, isEmpty);
        },
      );
    }
  }
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} inline quantity keeps failed draft and saves confirmed value',
      (tester) async {
        final api = _Api();
        await _open(tester, api, brightness: brightness);
        final row = find.byKey(const ValueKey('edit-item-quantity'));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
        final input = find.byKey(const ValueKey('item-field-quantity'));
        await tester.enterText(input, '12');
        api.failSave = true;
        await tester.tap(find.text('Save').last);
        await tester.pumpAndSettle();
        expect(input, findsOneWidget);
        expect(tester.widget<TextField>(input).controller!.text, '12');
        api.failSave = false;
        await tester.tap(find.text('Save').last);
        await tester.pumpAndSettle();
        expect(input, findsNothing);
        expect(api.data['quantity'], 12);
        expect(api.data['name'], _data['name']);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('${brightness.name} Viewer has no inline field controls', (
      tester,
    ) async {
      final api = _Api();
      await _open(tester, api, brightness: brightness, permission: 'view');
      expect(find.byKey(const ValueKey('edit-item-name')), findsNothing);
      expect(find.byKey(const ValueKey('edit-item-quantity')), findsNothing);
      expect(api.writes, isEmpty);
    });
  }
  testWidgets('part-number item edits its description in one inline form', (
    tester,
  ) async {
    final api = _Api();
    api.data['part_number'] = 'PN-F117';
    await _open(tester, api);
    final field = find.byKey(const ValueKey('edit-item-name'));
    await tester.ensureVisible(field);
    expect(field, findsOneWidget);
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, 'servo extension cable'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'servo extension cable'),
      'M10x30 Screw',
    );
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();
    expect(api.writes.single.name, 'M10x30 Screw');
    expect(api.data['part_number'], 'PN-F117');
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline item detail visual acceptance', (tester) async {
    if (!const bool.fromEnvironment('FINDEZ_VISUAL_QA')) return;
    await tester.runAsync(() async {
      final bytes = await File('/System/Library/Fonts/SFNS.ttf').readAsBytes();
      for (final family in [
        'FindEZ-QA',
        'Roboto',
        '.SF UI Text',
        '.SF UI Display',
      ]) {
        await (FontLoader(
          family,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    });
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final mode in Brightness.values) {
      final api = _Api();
      await _open(tester, api, brightness: mode);
      await tester.ensureVisible(
        find.byKey(const ValueKey('edit-item-quantity')),
      );
      await tester.tap(find.byKey(const ValueKey('edit-item-quantity')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_visualBoundary),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/private/tmp/findez-inline-item-${mode.name}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
  });
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, (call) async {
          if (call.method == 'initialize') return true;
          if (call.method == 'requestPermissions') return false;
          throw StateError('Unexpected notification method: ${call.method}');
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, null);
  });

  testWidgets('accepted dismissal never restores sheet height during route exit', (
    tester,
  ) async {
    var dismissals = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItemDetailDragSheet(
            onDismiss: () async {
              dismissals++;
              return true;
            },
            builder: (context, controller) => SingleChildScrollView(
              key: const ValueKey('exit-scroll'),
              controller: controller,
              child: const SizedBox(height: 1500, width: double.infinity),
            ),
          ),
        ),
      ),
    );
    final scroll = find.byKey(const ValueKey('exit-scroll'));
    await tester.dragFrom(
      tester.getTopLeft(scroll) + const Offset(100, 30),
      Offset(0, tester.getSize(scroll).height * 0.35 + 30),
    );
    await tester.pump();
    final sheet = tester
        .widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet))
        .controller!;
    expect(dismissals, 1);
    expect(sheet.size, closeTo(0.7, 0.001));
    final controller = tester.widget<SingleChildScrollView>(scroll).controller!;
    // Layout/scroll notifications can arrive while the modal exit animation is
    // still painting. They must not restart expansion behind the user's finger.
    ScrollEndNotification(
      metrics: controller.position,
      context: tester.element(scroll),
    ).dispatch(tester.element(scroll));
    await tester.pumpAndSettle();
    expect(sheet.size, closeTo(0.7, 0.001));
    expect(dismissals, 1);
  });

  testWidgets(
    'item-info exit moves downward without a height-restoration jump',
    (tester) async {
      await _open(tester, _Api());
      await tester.dragFrom(tester.getCenter(_handle), const Offset(0, 350));
      await tester.pump();
      var previousTop = tester.getTopLeft(_scroll).dy;
      for (
        var frame = 0;
        frame < 20 && _scroll.evaluate().isNotEmpty;
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 16));
        if (_scroll.evaluate().isEmpty) break;
        final nextTop = tester.getTopLeft(_scroll).dy;
        expect(nextTop, greaterThanOrEqualTo(previousTop - 0.5));
        previousTop = nextTop;
      }
      expect(_scroll, findsNothing);
    },
  );

  testWidgets(
    'item info dismisses from handle or top content without any writes',
    (tester) async {
      for (final fromHandle in [true, false]) {
        final api = _Api();
        await _open(tester, api);
        expect(_scroll, findsOneWidget);
        expect(find.text('Edit item'), findsNothing);
        await _pull(tester, fromHandle: fromHandle);
        expect(_scroll, findsNothing);
        expect(api.writes, isEmpty);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'mid-content scrolling and small or horizontal drags do not dismiss',
    (tester) async {
      await _open(tester, _Api());
      final controller = _controller(tester);
      controller.jumpTo(500);
      await tester.pump();
      await tester.dragFrom(
        tester.getTopLeft(_scroll) + const Offset(40, 100),
        const Offset(0, 120),
      );
      await tester.pumpAndSettle();
      expect(_scroll, findsOneWidget);
      expect(controller.offset, lessThan(500));
      expect(controller.offset, greaterThan(0));
      controller.jumpTo(0);
      await tester.pump();
      await tester.timedDragFrom(
        tester.getCenter(_handle),
        const Offset(0, 20),
        const Duration(milliseconds: 900),
      );
      await tester.pumpAndSettle();
      expect(_scroll, findsOneWidget);
      expect(
        tester
            .widget<DraggableScrollableSheet>(
              find.byType(DraggableScrollableSheet),
            )
            .controller!
            .size,
        1,
      );
      await tester.dragFrom(
        tester.getTopLeft(_scroll) + const Offset(40, 80),
        const Offset(180, 0),
      );
      await tester.pumpAndSettle();
      expect(_scroll, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unsaved notes survive swipe cancellation and can save or discard',
    (tester) async {
      final api = _Api();
      await _open(tester, api);
      await _editNotes(tester, 'Updated notes');
      await _pull(tester);
      expect(find.text('Save your notes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(_scroll, findsOneWidget);
      expect(
        tester.widget<TextField>(_notes).controller!.text,
        'Updated notes',
      );
      expect(api.writes, isEmpty);
      await _pull(tester);
      await tester.tap(find.text('Save and close'));
      await tester.pumpAndSettle();
      expect(_scroll, findsNothing);
      expect(api.writes.single.notes, 'Updated notes');
      await _open(tester, api);
      await _editNotes(tester, 'Discarded draft');
      await _pull(tester);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(_scroll, findsNothing);
      expect(api.writes, hasLength(1));
      expect(api.data['notes'], 'Updated notes');
    },
  );

  testWidgets(
    'failed notes save retains draft and pending save cannot be swiped away',
    (tester) async {
      final api = _Api()..failSave = true;
      await _open(tester, api);
      await _editNotes(tester, 'Keep this draft');
      await _pull(tester);
      await tester.tap(find.text('Save and close'));
      await tester.pumpAndSettle();
      expect(_scroll, findsOneWidget);
      expect(
        tester.widget<TextField>(_notes).controller!.text,
        'Keep this draft',
      );
      expect(find.textContaining('SECRET'), findsNothing);
      api.failSave = false;
      api.save = Completer<void>();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pump();
      await _pull(tester);
      expect(_scroll, findsOneWidget);
      expect(api.writes, hasLength(2));
      api.save!.complete();
      await tester.pumpAndSettle();
      await _pull(tester);
      expect(_scroll, findsNothing);
      expect(api.writes, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dismiss flushes debounced purchase source and waits for existing writes',
    (tester) async {
      final api = _Api()..save = Completer<void>();
      await _open(tester, api);
      await tester.ensureVisible(_source);
      await tester.enterText(_source, 'New store');
      // Before the 600ms debounce, dismissal must flush the field itself.
      _controller(tester).jumpTo(0);
      await tester.pump();
      await tester.dragFrom(tester.getCenter(_handle), const Offset(0, 350));
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.writes, hasLength(1));
      expect(_scroll, findsOneWidget);
      api.save!.complete();
      await tester.pumpAndSettle();
      expect(_scroll, findsNothing);
      expect(api.writes.single.purchaseSource, 'New store');
    },
  );

  testWidgets(
    'failed purchase save blocks dismissal and a later retry succeeds',
    (tester) async {
      final api = _Api()..failSave = true;
      await _open(tester, api);
      await tester.ensureVisible(_source);
      await tester.enterText(_source, 'Retry this store');
      await _pull(tester);
      expect(_scroll, findsOneWidget);
      expect(
        tester.widget<TextField>(_source).controller!.text,
        'Retry this store',
      );
      expect(find.textContaining('SECRET'), findsNothing);
      api.failSave = false;
      await _pull(tester);
      expect(_scroll, findsNothing);
      expect(api.data['purchase_source'], 'Retry this store');
    },
  );

  testWidgets(
    'a changed purchase draft and simultaneous dismissal serialize saves',
    (tester) async {
      final api = _Api()..save = Completer<void>();
      await _open(tester, api);
      await tester.ensureVisible(_source);
      await tester.enterText(_source, 'First store');
      await tester.pump(const Duration(milliseconds: 601));
      expect(api.writes, hasLength(1));
      await tester.enterText(_source, 'Latest store');
      _controller(tester).jumpTo(0);
      await tester.pump();
      await tester.dragFrom(tester.getCenter(_handle), const Offset(0, 350));
      await tester.pump(const Duration(milliseconds: 400));
      api.save!.complete();
      await tester.pumpAndSettle();
      expect(_scroll, findsNothing);
      expect(api.writes.map((write) => write.purchaseSource), [
        'First store',
        'Latest store',
      ]);
      expect(api.data['purchase_source'], 'Latest store');
    },
  );

  testWidgets('swipe flushes a pending low-stock threshold before closing', (
    tester,
  ) async {
    int? reported;
    await _open(
      tester,
      _Api(),
      onThresholdChanged: (value) => reported = value,
    );
    final field = find.byKey(const ValueKey('item-detail-threshold'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '5');
    await _pull(tester);
    // Saving also awaits the native notification-permission response (denied
    // above); settling frames alone need not wait for that acknowledgment.
    for (var attempt = 0; attempt < 50 && reported == null; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(_scroll, findsNothing);
    expect(reported, 5);
    expect((await LowStockPrefs.loadAll())['test-cable'], 5);
  });

  testWidgets(
    'Close and system back share save protection and read-only dismissal does not write',
    (tester) async {
      final api = _Api();
      await _open(tester, api);
      await _editNotes(tester, 'Back draft');
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Save your notes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Close'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      await _open(tester, api, permission: 'view', shareId: 'joined-space');
      expect(find.text('Edit'), findsNothing);
      expect(tester.widget<TextField>(_source).readOnly, isTrue);
      await _pull(tester);
      expect(_scroll, findsNothing);
      expect(api.writes, isEmpty);
      expect(api.photoShares.last, 'joined-space');
      expect(await LowStockPrefs.loadAll(), isEmpty);
    },
  );

  testWidgets(
    'photo mutation cannot be dismissed mid-write and horizontal gallery swipes stay inside',
    (tester) async {
      final api = _Api()
        ..photoList = [
          const ItemPhoto(
            photoId: 'one',
            imageUrl: 'https://api.test/one.jpg',
            isPrimary: true,
          ),
          const ItemPhoto(
            photoId: 'two',
            imageUrl: 'https://api.test/two.jpg',
            isPrimary: false,
          ),
        ];
      await _open(tester, api);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
      expect(_scroll, findsOneWidget);
      api.deletePhoto = Completer<ItemPhotoMutationResult>();
      await tester.tap(find.byTooltip('Delete photo').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.dragFrom(tester.getCenter(_handle), const Offset(0, 350));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_scroll, findsOneWidget);
      api.deletePhoto!.complete(
        ItemPhotoMutationResult(
          item: InventoryItem.fromJson(api.data),
          photos: [],
        ),
      );
      await tester.pumpAndSettle();
      await _pull(tester);
      expect(_scroll, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending return keeps info open and a failed return shows a safe error',
    (tester) async {
      final api = _Api()
        ..checkouts = [
          {
            'checkout_id': 'fake-checkout',
            'is_active': true,
            'checked_out_by': 'Test person',
          },
        ];
      await _open(tester, api);
      api.returning = Completer<void>();
      api.failReturn = true;
      await tester.ensureVisible(find.text('Return'));
      await tester.tap(find.text('Return'));
      await tester.pump();
      await _pull(tester);
      expect(_scroll, findsOneWidget);
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .clearSnackBars();
      await tester.pumpAndSettle();
      api.returning!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Could not return the item. Try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('SECRET'), findsNothing);
      await _pull(tester);
      expect(_scroll, findsNothing);
    },
  );

  testWidgets('drag handle has an accessible dismissal action', (tester) async {
    final semantics = tester.ensureSemantics();
    await _open(tester, _Api());
    final handle = find.bySemanticsLabel('Dismiss item details');
    expect(
      tester.getSemantics(handle),
      matchesSemantics(label: 'Dismiss item details', hasDismissAction: true),
    );
    semantics.dispose();
  });

  testWidgets('repeated open and dismissal safely ignores late photo reads', (
    tester,
  ) async {
    final api = _Api()..photos = Completer<List<ItemPhoto>>();
    await _open(tester, api);
    await _pull(tester);
    api.photos!.complete([]);
    await tester.pumpAndSettle();
    api.photos = null;
    await _open(tester, api);
    await _pull(tester);
    expect(_scroll, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large text and keyboard keep item info scrollable and dismissible',
    (tester) async {
      await _open(
        tester,
        _Api(),
        scaler: const TextScaler.linear(2),
        keyboard: 260,
      );
      expect(_scroll, findsOneWidget);
      await _pull(tester);
      expect(_scroll, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'personal and Team-space info buttons open the swipe-dismiss panel, not the editor',
    (tester) async {
      for (final readOnly in [false, true]) {
        final api = _Api();
        final item = InventoryItem.fromJson(api.data);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: LocationItemsPage(
              api: api,
              location: 'Parts Room',
              items: [item],
              thresholds: {},
              allItems: [item],
              spaceId: 'personal-or-team-space',
              readOnly: readOnly,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.info_outline).first);
        await tester.pumpAndSettle();
        expect(_scroll, findsOneWidget);
        expect(find.text('Edit item'), findsNothing);
        await _pull(tester);
        expect(_scroll, findsNothing);
        expect(find.byType(LocationItemsPage), findsOneWidget);
        expect(api.writes, isEmpty);
      }
    },
  );

  testWidgets(
    'joined and shared-space info buttons open the same swipe-dismiss panel',
    (tester) async {
      for (final permission in ['edit', 'view']) {
        final api = _Api();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: SharedInventoryPage(
              api: api,
              shareId: 'shared-space',
              shareName: 'Parts Room',
              permission: permission,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.info_outline).first);
        await tester.pumpAndSettle();
        expect(_scroll, findsOneWidget);
        expect(find.text('Edit item'), findsNothing);
        await _pull(tester);
        expect(_scroll, findsNothing);
        expect(find.byType(SharedInventoryPage), findsOneWidget);
        expect(api.photoShares.single, 'shared-space');
        expect(api.writes, isEmpty);
      }
    },
  );
}
