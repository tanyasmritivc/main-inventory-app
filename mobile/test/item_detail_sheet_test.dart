import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/low_stock_prefs.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
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
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: scaler,
          viewInsets: EdgeInsets.only(bottom: keyboard),
          padding: const EdgeInsets.only(top: 47, bottom: 34),
        ),
        child: child!,
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
  await tester.ensureVisible(find.text('Edit'));
  await tester.tap(find.text('Edit'));
  await tester.pumpAndSettle();
  await tester.enterText(_notes, text);
  await tester.pump();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
