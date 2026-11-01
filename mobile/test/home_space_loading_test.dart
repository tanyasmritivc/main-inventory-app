import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/inventory_cache.dart';
import 'package:mobile/features/home/home_overview.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import 'package:mobile/features/shell/main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _items = [
  for (final category in ['Hardware', 'Tools'])
    InventoryItem(
      itemId: category,
      name: 'Sample $category',
      category: category,
      location: 'Old location',
      spaceId: 'workshop',
      quantity: 1,
      createdAt: DateTime(2026, 10, 5),
    ),
  InventoryItem(
    itemId: 'other',
    name: 'Other Space item',
    category: 'Tools',
    location: 'Workshop',
    spaceId: 'other-space',
    quantity: 1,
    createdAt: DateTime(2026, 10, 5),
  ),
];

SearchItemsResult _result(List<InventoryItem> items) =>
    SearchItemsResult(items: items, parsed: const {});

class _LoadingApi extends ApiClient {
  _LoadingApi({this.shell = false}) : super(baseUrl: 'https://api.test');
  final bool shell;
  Completer<SearchItemsResult> pending = Completer();
  int searches = 0;
  @override
  Future<SearchItemsResult> searchItems({required String query}) {
    searches++;
    // Shell warm-up and Home are ready before lazy Find first mounts.
    if (shell && searches <= 2) return Future.value(_result(_items));
    return pending.future;
  }

  @override
  Future<List<Map<String, dynamic>>> listSpaces() async => [
    {'id': 'workshop', 'name': 'Workshop', 'item_count': 2},
    {'id': 'empty', 'name': 'Empty shelf', 'item_count': 0},
  ];
  @override
  Future<List<dynamic>> getMyShares() async => [];
  @override
  Future<List<dynamic>> getJoinedShares() async => [];
  @override
  Future<ReviewQueueResult> getReviewItems({int limit = 100}) async =>
      const ReviewQueueResult(items: [], pendingCount: 0);
  @override
  Future<List<Map<String, dynamic>>> getActiveCheckouts() async => [];
  @override
  Future<Map<String, dynamic>> getNotifications() async => {'unread_count': 0};
  @override
  Future<Map<String, dynamic>> getMyProfile() async => {};
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
  });
  setUp(() {
    InventoryCache.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.findez.app/push'),
          (_) async => null,
        );
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} cold Home waits for Find inventory', (
      tester,
    ) async {
      final api = _LoadingApi(shell: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(brightness),
          home: MainShell(api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<HomeOverview>(find.byType(HomeOverview)).items,
        _items,
      );
      await tester.scrollUntilVisible(
        find.text('Workshop'),
        150,
        scrollable: find
            .descendant(
              of: find.byType(HomeOverview),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Workshop'));
      await tester.pump();
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(api.searches, greaterThanOrEqualTo(3));
      expect(find.byType(LocationItemsPage), findsNothing);
      api.pending.complete(_result(_items));
      await tester.pumpAndSettle();
      final page = tester.widget<LocationItemsPage>(
        find.byType(LocationItemsPage),
      );
      expect(page.spaceId, 'workshop');
      expect(page.items.map((item) => item.itemId), ['Hardware', 'Tools']);
      expect(find.text('Other Space item'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  Future<Future<void> Function(Map<String, dynamic>)> mount(
    WidgetTester tester,
    _LoadingApi api,
  ) async {
    late Future<void> Function(Map<String, dynamic>) open;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(Brightness.dark),
        home: InventoryPage(
          api: api,
          refreshToken: 0,
          onRegisterOpenAssistDestination: (callback) => open = callback,
        ),
      ),
    );
    await tester.pump();
    return open;
  }

  testWidgets(
    'failed cold read never opens a false empty Space; retry succeeds',
    (tester) async {
      final api = _LoadingApi();
      final open = await mount(tester, api);
      final opening = open({'space_name': 'Workshop', 'space_id': 'workshop'});
      await tester.pump();
      api.pending.completeError(StateError('PRIVATE database failure'));
      await opening;
      await tester.pumpAndSettle();
      expect(find.byType(LocationItemsPage), findsNothing);
      expect(
        find.text('Could not load this Space. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('PRIVATE'), findsNothing);
      api.pending = Completer();
      unawaited(open({'space_name': 'Workshop', 'space_id': 'workshop'}));
      await tester.pump();
      api.pending.complete(_result(_items));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LocationItemsPage>(find.byType(LocationItemsPage))
            .items
            .length,
        2,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'confirmed empty Space opens, repeated taps do not duplicate routes',
    (tester) async {
      final api = _LoadingApi();
      final open = await mount(tester, api);
      unawaited(open({'space_name': 'Empty shelf', 'space_id': 'empty'}));
      unawaited(open({'space_name': 'Empty shelf', 'space_id': 'empty'}));
      await tester.pump();
      expect(api.searches, 1);
      expect(find.byType(LocationItemsPage), findsNothing);
      api.pending.complete(_result([]));
      await tester.pumpAndSettle();
      final page = tester.widget<LocationItemsPage>(
        find.byType(LocationItemsPage),
      );
      expect(page.spaceId, 'empty');
      expect(page.items, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(LocationItemsPage), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'disposed cold destination cannot open after late inventory read',
    (tester) async {
      final api = _LoadingApi();
      final open = await mount(tester, api);
      final opening = open({'space_name': 'Workshop', 'space_id': 'workshop'});
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      api.pending.complete(_result(_items));
      await opening;
      await tester.pumpAndSettle();
      expect(find.byType(LocationItemsPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
