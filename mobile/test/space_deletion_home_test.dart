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
import 'package:mobile/features/shell/main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _items = [
  InventoryItem(
    itemId: 'robot-part',
    name: 'Sample sensor',
    category: 'Tools',
    spaceId: 'robot-room',
    location: 'Robot Room',
    quantity: 0,
    createdAt: DateTime(2026, 10, 12),
  ),
  InventoryItem(
    itemId: 'other-part',
    name: 'Lab instrument',
    category: 'Tools',
    spaceId: 'lab',
    location: 'Lab',
    quantity: 2,
    createdAt: DateTime(2026, 10, 12),
  ),
];

class _SpaceApi extends ApiClient {
  _SpaceApi({
    this.rejectDelete = false,
    this.offlineAfterDelete = false,
    this.delayedWarmup,
  }) : super(baseUrl: 'https://api.test');
  final bool rejectDelete, offlineAfterDelete;
  final Completer<SearchItemsResult>? delayedWarmup;
  bool deleted = false;
  int searches = 0, deletions = 0;
  @override
  Future<SearchItemsResult> searchItems({required String query}) async {
    searches++;
    if (searches == 1 && delayedWarmup != null) return delayedWarmup!.future;
    if (deleted && offlineAfterDelete) throw StateError('offline');
    return SearchItemsResult(
      items: deleted ? [_items.last] : _items,
      parsed: const {},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> listSpaces() async {
    if (deleted && offlineAfterDelete) throw StateError('offline');
    return [
      if (!deleted) {'id': 'robot-room', 'name': 'Robot Room', 'item_count': 1},
      {'id': 'lab', 'name': 'Lab', 'item_count': 1},
    ];
  }

  @override
  Future<Map<String, dynamic>> collaboration(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async {
    expect(path, '/resource-removal/space/robot-room');
    if (method == 'GET') {
      return {
        'kind': 'space',
        'id': 'robot-room',
        'name': 'Robot Room',
        'items': 1,
        'spaces': 0,
        'inventories': 0,
        'workspaces': 0,
        'can_move': false,
        'destinations': [],
      };
    }
    deletions++;
    if (rejectDelete) return {'deleted': false};
    deleted = true;
    return {
      'kind': 'space',
      'id': 'robot-room',
      'action': 'delete',
      'deleted': true,
      'moved': false,
    };
  }

  @override
  Future<ReviewQueueResult> getReviewItems({int limit = 100}) async {
    if (deleted && offlineAfterDelete) throw StateError('offline');
    return ReviewQueueResult(items: const [], pendingCount: deleted ? 1 : 12);
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveCheckouts() async => [];
  @override
  Future<List<dynamic>> getMyShares() async => [];
  @override
  Future<List<dynamic>> getJoinedShares() async => [];
  @override
  Future<List<Map<String, dynamic>>> listTeams() async => [];
  @override
  Future<Map<String, dynamic>> getMyProfile() async => {};
  @override
  Future<Map<String, dynamic>> getNotifications() async => {'unread_count': 0};
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
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
  Future<void> mount(
    WidgetTester tester,
    _SpaceApi api,
    Brightness theme,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(theme),
        home: MainShell(api: api),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> deleteSpace(WidgetTester tester) async {
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    final cardRow = find
        .ancestor(
          of: find.text('Robot Room').hitTestable(),
          matching: find.byType(Row),
        )
        .first;
    final options = find.descendant(
      of: cardRow,
      matching: find.byTooltip('Space options'),
    );
    await tester.ensureVisible(options);
    await tester.tap(options);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Space'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.enterText(find.byType(TextFormField), 'Robot Room');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Delete space'));
    await tester.pumpAndSettle();
    if (find.byType(AlertDialog).evaluate().isNotEmpty) {
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byType(NavigationDestination).at(0));
    await tester.pumpAndSettle();
  }

  for (final theme in Brightness.values) {
    testWidgets('${theme.name} deleting a Space refreshes Home decisions', (
      tester,
    ) async {
      final api = _SpaceApi();
      await mount(tester, api, theme);
      expect(
        tester.widget<HomeOverview>(find.byType(HomeOverview)).pendingReviews,
        12,
      );
      await deleteSpace(tester);
      final home = tester.widget<HomeOverview>(find.byType(HomeOverview));
      expect(api.deletions, 1);
      expect(home.spaces.map((s) => s['id']), ['lab']);
      expect(home.items.map((i) => i.itemId), ['other-part']);
      expect(home.pendingReviews, 1);
      expect(home.outOfStock, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('failed deletion preserves Home items and decisions', (
    tester,
  ) async {
    final api = _SpaceApi(rejectDelete: true);
    await mount(tester, api, Brightness.light);
    await deleteSpace(tester);
    final home = tester.widget<HomeOverview>(find.byType(HomeOverview));
    expect(home.items, _items);
    expect(home.pendingReviews, 12);
    expect(home.outOfStock, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'late warmup cannot restore a deleted Space in cached inventory',
    (tester) async {
      final warmup = Completer<SearchItemsResult>();
      final api = _SpaceApi(delayedWarmup: warmup);
      await mount(tester, api, Brightness.dark);
      await deleteSpace(tester);
      warmup.complete(SearchItemsResult(items: _items, parsed: const {}));
      await tester.pumpAndSettle();
      expect(InventoryCache.items.map((i) => i.itemId), ['other-part']);
      expect(
        tester.widget<HomeOverview>(find.byType(HomeOverview)).outOfStock,
        0,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'failed refresh after deletion never displays the obsolete review count',
    (tester) async {
      final api = _SpaceApi(offlineAfterDelete: true);
      await mount(tester, api, Brightness.dark);
      await deleteSpace(tester);
      final home = tester.widget<HomeOverview>(find.byType(HomeOverview));
      expect(home.pendingReviews, isNull);
      expect(home.items.any((i) => i.spaceId == 'robot-room'), isFalse);
      expect(home.spaces.any((s) => s['id'] == 'robot-room'), isFalse);
      expect(find.textContaining('could not refresh'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
