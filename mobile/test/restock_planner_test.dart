import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/inventory_cache.dart';
import 'package:mobile/core/restock_plan.dart';
import 'package:mobile/core/ui/app_typography.dart';
import 'package:mobile/core/ui/restock_status.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import 'package:mobile/features/shopping/shopping_list_page.dart';

InventoryItem _item(String id, int quantity) => InventoryItem(
  itemId: id,
  name: id == 'cable'
      ? 'Cable'
      : id == 'bolts'
      ? 'M4 bolts'
      : 'Personal handbag',
  category: 'Supplies',
  location: 'Workshop',
  spaceId: 'space',
  quantity: quantity,
  notes: 'Keep this note',
  createdAt: DateTime(2026, 10, 5),
);

class _Api extends ApiClient {
  _Api() : super(baseUrl: 'https://api.test');
  List<InventoryItem> items = [_item('cable', 1), _item('handbag', 1)];
  bool failRead = false, loseResponse = false;
  Completer<void>? pending;
  List<UpdateItemRequest> writes = [];
  int sharedWrites = 0;
  @override
  Future<SearchItemsResult> searchItems({required String query}) async {
    if (failRead) throw StateError('SECRET network stack');
    return SearchItemsResult(items: items, parsed: const {});
  }

  @override
  Future<InventoryItem> updateItem({required UpdateItemRequest request}) async {
    writes.add(request);
    if (pending != null) await pending!.future;
    final updated = _item(request.itemId, request.quantity!);
    items = items.map((i) => i.itemId == updated.itemId ? updated : i).toList();
    if (loseResponse) throw StateError('SECRET lost response');
    return updated;
  }

  @override
  Future<InventoryItem> updateSharedItem({
    required String shareId,
    required UpdateItemRequest request,
  }) async {
    expect(shareId, 'share');
    sharedWrites++;
    return updateItem(request: request);
  }

  @override
  Future<List<dynamic>> getShareInventory(String shareId) async => [
    for (final i in items)
      {
        'item_id': i.itemId,
        'name': i.name,
        'quantity': i.quantity,
        'category': i.category,
        'location': i.location,
        'space_id': i.spaceId,
        'created_at': i.createdAt.toIso8601String(),
      },
  ];
  @override
  Future<List<Map<String, dynamic>>> listSpaces() async => [
    {'id': 'space', 'name': 'Workshop'},
  ];
  @override
  Future<List<dynamic>> getMyShares() async => [];
  @override
  Future<List<dynamic>> getJoinedShares() async => [];
}

class _RejectWrites extends InMemorySharedPreferencesStore {
  _RejectWrites() : super.empty();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

Future<void> _seed({bool ordered = false}) async {
  SharedPreferences.setMockInitialValues({
    RestockPrefs.accountKey: jsonEncode({
      'cable': {
        'minimum': 1,
        if (ordered) 'ordered': true,
        if (ordered) 'order_quantity': 4,
      },
    }),
  });
}

ThemeData _theme(Brightness brightness) {
  final theme = AppTheme.create(brightness);
  if (!const bool.fromEnvironment('FINDEZ_VISUAL_QA')) return theme;
  TextStyle font(TextStyle? style) =>
      (style ?? const TextStyle()).copyWith(fontFamily: 'FindEZQA');
  ButtonStyle? button(ButtonStyle? style) => style?.copyWith(
    textStyle: WidgetStateProperty.resolveWith(
      (states) => font(style.textStyle?.resolve(states)),
    ),
  );
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'FindEZQA'),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'FindEZQA'),
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: font(theme.appBarTheme.titleTextStyle),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: button(theme.filledButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: button(theme.textButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: button(theme.outlinedButtonTheme.style),
    ),
  );
}

Widget _page(
  _Api api, {
  Brightness brightness = Brightness.dark,
  double scale = 1,
  bool shared = false,
  bool viewOnly = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: _theme(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(boldText: true, textScaler: TextScaler.linear(scale)),
    child: AppTypography(child: child!),
  ),
  home: ShoppingListPage(
    api: api,
    shareId: shared ? 'share' : null,
    canEditStock: !viewOnly,
  ),
);
Future<void> _count(WidgetTester tester, String button, int count) async {
  final action = find.widgetWithText(FilledButton, button);
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('restock-count')),
    count.toString(),
  );
}

Future<void> _login(String id) => Supabase.instance.client.auth
    .signInWithPassword(email: '$id@example.test', password: 'test-password')
    .then((_) {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
      final fontBytes = File(
        '/System/Library/Fonts/SFNS.ttf',
      ).readAsBytes().then(ByteData.sublistView);
      for (final family in ['FindEZQA', 'Ahem', 'Roboto']) {
        await (FontLoader(family)..addFont(fontBytes)).load();
      }
      await (FontLoader('MaterialIcons')..addFont(
            File(
              '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://auth.test',
      anonKey: 'test',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((request) async {
        final body = request.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(request.body) as Map<String, dynamic>;
        final id = (body['email'] as String? ?? 'a@example.test')
            .split('@')
            .first;
        final user = {
          'id': id,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': '$id@example.test',
          'created_at': '2026-01-01T00:00:00Z',
          'app_metadata': {},
          'user_metadata': {},
        };
        final jwt =
            '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': id, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.signature';
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/token')
                ? {
                    'access_token': jwt,
                    'refresh_token': 'refresh-test',
                    'expires_in': 3600,
                    'token_type': 'bearer',
                    'user': user,
                  }
                : user,
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  setUp(() async {
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    SharedPreferences.setMockInitialValues({});
    InventoryCache.clear();
  });

  test(
    'migration retains thresholds and ordered selections without inventing quantities',
    () async {
      SharedPreferences.setMockInitialValues({
        'low_stock_thresholds:signed-out': '{"cable":1}',
        'shopping_list_checked:signed-out': ['cable'],
      });
      final plan = await RestockPrefs.load();
      expect(plan.entry('cable').minimum, 1);
      expect(plan.onOrder('cable'), isTrue);
      expect(plan.needsBuying('cable', 1), isFalse);
      expect(plan.entry('cable').orderQuantity, isNull);
      expect(plan.needsBuying('handbag', 1), isFalse);
      expect(plan.needsBuying('handbag', 0), isFalse);
      expect((await RestockPrefs.load()).onOrder('cable'), isTrue);
    },
  );
  test(
    'concurrent planning edits persist, zero triggers are explicit and purchases reopen after stock falls',
    () async {
      final account = RestockPrefs.accountKey;
      await Future.wait([
        RestockPrefs.setThreshold('cable', 0),
        RestockPrefs.planPurchase('handbag', 3, account: account),
      ]);
      var plan = await RestockPrefs.load();
      expect(plan.needsBuying('cable', 1), isFalse);
      expect(plan.needsBuying('cable', 0), isTrue);
      expect(plan.entry('handbag').quantityToBuy(1), 3);
      await RestockPrefs.order('cable', 2, account: account);
      await RestockPrefs.prepareReceipt('cable', 2, account: account);
      await RestockPrefs.finishReceipt('cable', account: account);
      plan = await RestockPrefs.load();
      expect(plan.onOrder('cable'), isFalse);
      expect(plan.needsBuying('cable', 2), isFalse);
      expect(plan.needsBuying('cable', 0), isTrue);
    },
  );
  test(
    'a failed disk write restores cached state and does not publish success',
    () async {
      await _seed();
      await RestockPrefs.load();
      final before = RestockPrefs.changes.value;
      SharedPreferencesStorePlatform.instance = _RejectWrites();
      await expectLater(
        RestockPrefs.order('cable', 8, account: RestockPrefs.accountKey),
        throwsStateError,
      );
      expect((await RestockPrefs.load()).onOrder('cable'), isFalse);
      expect(RestockPrefs.changes.value, before);
    },
  );
  test(
    'damaged saved planning is reported rather than silently erased',
    () async {
      SharedPreferences.setMockInitialValues({
        RestockPrefs.accountKey: 'broken-json',
      });
      await expectLater(RestockPrefs.load(), throwsFormatException);
      expect(
        (await SharedPreferences.getInstance()).getString(
          RestockPrefs.accountKey,
        ),
        'broken-json',
      );
      for (final damaged in [
        '{"cable":null}',
        '{"cable":{"ordered":"yes"}}',
        '{"cable":{"receipt_total":-2}}',
      ]) {
        SharedPreferences.setMockInitialValues({
          RestockPrefs.accountKey: damaged,
        });
        await expectLater(RestockPrefs.load(), throwsFormatException);
        expect(
          (await SharedPreferences.getInstance()).getString(
            RestockPrefs.accountKey,
          ),
          damaged,
        );
      }
    },
  );
  test(
    'account changes reject stale writes and keep each account purchase private',
    () async {
      await _login('a');
      final a = RestockPrefs.accountKey;
      await RestockPrefs.order('cable', 4, account: a);
      await _login('b');
      final b = RestockPrefs.accountKey;
      expect(b, isNot(a));
      expect((await RestockPrefs.load()).entries, isEmpty);
      await expectLater(
        RestockPrefs.remove('cable', account: a),
        throwsStateError,
      );
      await RestockPrefs.planPurchase('handbag', 2, account: b);
      await _login('a');
      final restored = await RestockPrefs.load();
      expect(restored.onOrder('cable'), isTrue);
      expect(restored.entry('handbag').buyQuantity, isNull);
    },
  );
  testWidgets(
    'ordering moves a purchase immediately and persists across reopening without changing inventory',
    (tester) async {
      await _seed();
      final api = _Api();
      await tester.pumpWidget(_page(api));
      await tester.pumpAndSettle();
      expect(find.text('1 to buy | 0 on order'), findsOneWidget);
      expect(find.text('Personal handbag'), findsNothing);
      await _count(tester, 'Mark ordered', 4);
      await tester.tap(find.widgetWithText(FilledButton, 'Save order'));
      await tester.pumpAndSettle();
      expect(find.text('0 to buy | 1 on order'), findsOneWidget);
      expect(find.text('4 ordered'), findsOneWidget);
      expect(api.writes, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_page(api));
      await tester.pumpAndSettle();
      expect(find.text('0 to buy | 1 on order'), findsOneWidget);
    },
  );
  testWidgets('failed order save retains the quantity draft for retry', (
    tester,
  ) async {
    await _seed();
    final api = _Api();
    await tester.pumpWidget(_page(api));
    await tester.pumpAndSettle();
    SharedPreferencesStorePlatform.instance = _RejectWrites();
    await _count(tester, 'Mark ordered', 8);
    await tester.tap(find.widgetWithText(FilledButton, 'Save order'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save this change. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('1 to buy | 0 on order'), findsOneWidget);
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.empty();
    await tester.tap(find.widgetWithText(FilledButton, 'Mark ordered'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('restock-count')))
          .controller!
          .text,
      '8',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save order'));
    await tester.pumpAndSettle();
    expect(find.text('0 to buy | 1 on order'), findsOneWidget);
    expect(api.writes, isEmpty);
  });
  testWidgets(
    'a specific personal belonging can be added without tracking its category',
    (tester) async {
      SharedPreferences.setMockInitialValues({RestockPrefs.accountKey: '{}'});
      final api = _Api();
      await tester.pumpWidget(_page(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add item to buy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personal handbag'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('restock-count')), '3');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('1 to buy | 0 on order'), findsOneWidget);
      final plan = await RestockPrefs.load();
      expect(plan.entry('handbag').buyQuantity, 3);
      expect(plan.entry('handbag').minimum, isNull);
      expect(plan.needsBuying('cable', 1), isFalse);
      expect(api.writes, isEmpty);
    },
  );
  testWidgets(
    'arrival saves exactly the counted total once and clears the purchase after confirmation',
    (tester) async {
      await _seed(ordered: true);
      final api = _Api()..pending = Completer<void>();
      await tester.pumpWidget(_page(api));
      await tester.pumpAndSettle();
      await _count(tester, 'Record arrival', 100001);
      await tester.tap(find.widgetWithText(FilledButton, 'Save stock count'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a whole number from 0 to 100000.'),
        findsOneWidget,
      );
      expect(api.writes, isEmpty);
      await tester.enterText(find.byKey(const ValueKey('restock-count')), '6');
      await tester.tap(find.widgetWithText(FilledButton, 'Save stock count'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.writes.length, 1);
      expect(api.writes.single.toJson(), {'item_id': 'cable', 'quantity': 6});
      final receive = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Record arrival'),
      );
      expect(receive.onPressed, isNull);
      expect((await RestockPrefs.load()).onOrder('cable'), isTrue);
      api.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('0 to buy | 0 on order'), findsOneWidget);
      expect(api.items.first.quantity, 6);
      expect(api.items.first.notes, 'Keep this note');
      expect((await RestockPrefs.load()).entry('cable').minimum, 1);
    },
  );
  testWidgets(
    'lost stock response retains confirmation and an explicit retry never doubles receipt',
    (tester) async {
      await _seed(ordered: true);
      final api = _Api()..loseResponse = true;
      await tester.pumpWidget(_page(api));
      await tester.pumpAndSettle();
      await _count(tester, 'Record arrival', 6);
      await tester.tap(find.widgetWithText(FilledButton, 'Save stock count'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm stock: 6'), findsOneWidget);
      expect(
        find.textContaining('Stock could not be confirmed'),
        findsOneWidget,
      );
      api.loseResponse = false;
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Record arrival'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Record arrival'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('restock-count')))
            .controller!
            .text,
        '6',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save stock count'));
      await tester.pumpAndSettle();
      expect(api.writes.map((r) => r.quantity), [6, 6]);
      expect(api.items.first.quantity, 6);
      expect((await RestockPrefs.load()).onOrder('cable'), isFalse);
    },
  );
  testWidgets(
    'remove disables irrelevant tracking without deleting inventory',
    (tester) async {
      await _seed();
      final api = _Api();
      await tester.pumpWidget(_page(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Options for Cable'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from planner'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(find.text('0 to buy | 0 on order'), findsOneWidget);
      expect((await RestockPrefs.load()).entries, isEmpty);
      expect(api.items.length, 2);
      expect(api.writes, isEmpty);
    },
  );
  testWidgets('failed load shows retry rather than a false stocked-up state', (
    tester,
  ) async {
    await _seed();
    final api = _Api()..failRead = true;
    await tester.pumpWidget(_page(api));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Nothing to buy.'), findsNothing);
    expect(find.textContaining('SECRET'), findsNothing);
    api.failRead = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('1 to buy | 0 on order'), findsOneWidget);
  });
  testWidgets(
    'shared arrival uses the membership-authorized route and viewers cannot update stock',
    (tester) async {
      await _seed(ordered: true);
      final api = _Api();
      await tester.pumpWidget(_page(api, shared: true, viewOnly: true));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Record arrival'),
            )
            .onPressed,
        isNull,
      );
      expect(api.writes, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_page(api, shared: true));
      await tester.pumpAndSettle();
      await _count(tester, 'Record arrival', 5);
      await tester.tap(find.widgetWithText(FilledButton, 'Save stock count'));
      await tester.pumpAndSettle();
      expect(api.sharedWrites, 1);
    },
  );
  testWidgets(
    'Find banner and Space summary react to ordering rather than still requesting restock',
    (tester) async {
      await _seed();
      final api = _Api();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(Brightness.dark),
          home: InventoryPage(api: api, refreshToken: 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 to buy | 0 on order'), findsOneWidget);
      await RestockPrefs.order('cable', 4, account: RestockPrefs.accountKey);
      await tester.pumpAndSettle();
      expect(find.text('0 to buy | 1 on order'), findsOneWidget);
      expect(find.textContaining('need restocking'), findsNothing);
      expect(find.text('1 to buy'), findsNothing);
    },
  );
  testWidgets('legacy orders stay compact with extra guidance only in Info', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'low_stock_thresholds:signed-out': '{"cable":1,"handbag":1}',
      'shopping_list_checked:signed-out': ['cable', 'handbag'],
    });
    final api = _Api();
    await tester.pumpWidget(
      RepaintBoundary(key: const ValueKey('compact-qa'), child: _page(api)),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 to buy | 2 on order'), findsOneWidget);
    expect(find.text('Nothing to buy.'), findsNothing);
    expect(find.textContaining('Ordered previously'), findsNothing);
    expect(find.textContaining('Low-stock alert'), findsNothing);
    expect(find.textContaining('Purchase plans stay'), findsNothing);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('compact-qa')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/private/tmp/findez-restock-compact-orders.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.byTooltip('About restock planner'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Purchase plans stay on this device for your account. Stock counts sync.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    await tester.pumpAndSettle();
    expect(find.text('About restocking'), findsNothing);
    expect(api.writes, isEmpty);
  });
  testWidgets('compact order menu retains editing and move-to-buy actions', (
    tester,
  ) async {
    await _seed(ordered: true);
    final api = _Api();
    await tester.pumpWidget(_page(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Options for Cable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit order'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('restock-count')), '7');
    await tester.tap(find.widgetWithText(FilledButton, 'Save order'));
    await tester.pumpAndSettle();
    expect(find.text('7 ordered'), findsOneWidget);
    await tester.tap(find.byTooltip('Options for Cable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to To buy'));
    await tester.pumpAndSettle();
    expect(find.text('1 to buy | 0 on order'), findsOneWidget);
    expect(find.text('7 to buy'), findsOneWidget);
    expect(api.writes, isEmpty);
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} purchase colors retain labels, contrast and shared typography',
      (tester) async {
        final theme = _theme(brightness);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: const MediaQueryData(boldText: true),
              child: const AppTypography(
                child: Scaffold(
                  body: RestockSummary(
                    toBuy: 3,
                    onOrder: 8,
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('3 to buy | 8 on order'), findsOneWidget);
        final text = tester.widget<RichText>(find.byType(RichText));
        final colors = <String, Color>{};
        text.text.visitChildren((span) {
          if (span is TextSpan &&
              span.text != null &&
              span.style?.color != null) {
            colors[span.text!] = span.style!.color!;
          }
          return true;
        });
        expect(colors['3 to buy'], isNot(colors['8 on order']));
        for (final color in [colors['3 to buy']!, colors['8 on order']!]) {
          final background = Color.alphaBlend(
            color.withValues(alpha: .08),
            theme.scaffoldBackgroundColor,
          );
          final a = color.computeLuminance(), b = background.computeLuminance();
          expect(
            ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05),
            greaterThanOrEqualTo(4.5),
          );
        }
        expect(text.text.style!.fontWeight, FontWeight.w500);
      },
    );
    testWidgets(
      '${brightness.name} planner distinguishes purchases and orders at phone size',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          RestockPrefs.accountKey:
              '{"cable":{"minimum":2},"bolts":{"ordered":true,"order_quantity":20}}',
        });
        final api = _Api()..items = [_item('cable', 1), _item('bolts', 0)];
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('restock-qa'),
            child: _page(api, brightness: brightness),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('1 to buy | 1 on order'), findsOneWidget);
        expect(find.text('2 to buy'), findsOneWidget);
        expect(find.text('20 ordered'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('restock-qa')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/private/tmp/findez-restock-${brightness.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
    testWidgets(
      '${brightness.name} planner has reachable actions at 320pt and 2.6x Bold Text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _seed(ordered: true);
        await tester.pumpWidget(
          _page(_Api(), brightness: brightness, scale: 2.6),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.widgetWithText(FilledButton, 'Record arrival'),
          120,
        );
        expect(tester.takeException(), isNull);
        await _count(tester, 'Record arrival', 5);
        expect(tester.takeException(), isNull);
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byTooltip('About restock planner'),
          -160,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('About restock planner'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.widgetWithText(TextButton, 'Done'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Done'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
