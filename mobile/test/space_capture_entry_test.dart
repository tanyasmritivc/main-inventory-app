import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/inventory_context.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import 'package:mobile/features/inventory/item_editor_sheet.dart';
import 'package:mobile/features/scan/import_sheet_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  const scanner = MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/method',
  );
  const events = MethodChannel('dev.steenbakker.mobile_scanner/scanner/event');
  const orientation = MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/deviceOrientation',
  );
  setUp(() {
    fixture.requests.clear();
    fixture.respond = (_) => <String, dynamic>{};
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(scanner, (call) async {
      if (call.method == 'state') return 1;
      if (call.method == 'start') {
        return {
          'textureId': 1,
          'cameraDirection': 0,
          'numberOfCameras': 1,
          'size': {'width': 390.0, 'height': 844.0},
        };
      }
      return null;
    });
    messenger.setMockMethodCallHandler(events, (_) async => null);
    messenger.setMockMethodCallHandler(orientation, (_) async => null);
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [scanner, events, orientation]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  Future<ApiClient> mount(
    WidgetTester tester, {
    bool readOnly = false,
    bool viewer = false,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient.forInventory(
      fixture.api,
      InventoryContext.fromJson(
        inventory('capture-inventory', role: viewer ? 'viewer' : 'editor'),
        accountId: 'actor-a',
        expectedInventory: 'capture-inventory',
      ),
      isCurrent: () => true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => LocationItemsPage(
              api: api,
              location: 'Garage',
              spaceId: 'garage-space',
              items: const [],
              thresholds: const {},
              allItems: const [],
              readOnly: readOnly,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  Future<void> open(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Add Item'));
    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();
  }

  void expectChoices() {
    for (final label in ['Scan Photo', 'Scan Barcode', 'Import Spreadsheet']) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    expect(find.text('Manual Add'), findsNothing);
    expect(find.byType(ItemEditorSheet), findsNothing);
  }

  testWidgets(
    'empty Space Add Item opens three capture choices without a write',
    (tester) async {
      await mount(tester);
      await open(tester);
      expectChoices();
      expect(fixture.requests.where((r) => r.method != 'GET'), isEmpty);
    },
  );

  testWidgets('plus opens the same capture choices', (tester) async {
    await mount(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expectChoices();
  });

  testWidgets(
    'photo action opens camera/library choice and cancel stays in Space',
    (tester) async {
      await mount(tester);
      await open(tester);
      await tester.tap(find.text('Scan Photo'));
      await tester.pumpAndSettle();
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Library'), findsOneWidget);
      expect(find.byType(ItemEditorSheet), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(LocationItemsPage), findsOneWidget);
      expect(fixture.requests.where((r) => r.method != 'GET'), isEmpty);
    },
  );

  testWidgets('barcode action opens the scanner and Back preserves Space', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    await tester.tap(find.text('Scan Barcode'));
    await tester.pumpAndSettle();
    expect(find.byType(MobileScanner), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LocationItemsPage), findsOneWidget);
    expect(fixture.requests.where((r) => r.method != 'GET'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('spreadsheet action keeps the current inventory and Space', (
    tester,
  ) async {
    final api = await mount(tester);
    await open(tester);
    await tester.tap(find.text('Import Spreadsheet'));
    await tester.pumpAndSettle();
    final page = tester.widget<ImportSheetPage>(find.byType(ImportSheetPage));
    expect(page.api, same(api));
    expect(page.location, 'Garage');
    expect(find.text('Choose file'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LocationItemsPage), findsOneWidget);
    expect(fixture.requests.where((r) => r.method != 'GET'), isEmpty);
  });

  for (final viewer in [false, true]) {
    testWidgets('read-only $viewer does not expose capture entry points', (
      tester,
    ) async {
      await mount(tester, readOnly: !viewer, viewer: viewer);
      expect(find.text('Add Item'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(fixture.requests.where((r) => r.method != 'GET'), isEmpty);
    });
  }

  testWidgets('capture choices remain usable at narrow width and large text', (
    tester,
  ) async {
    await mount(tester, size: const Size(320, 844), textScale: 1.8);
    await open(tester);
    expectChoices();
    expect(tester.takeException(), isNull);
  });
}
