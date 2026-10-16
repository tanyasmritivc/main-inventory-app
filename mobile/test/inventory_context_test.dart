import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/inventory_cache.dart';
import 'package:mobile/core/inventory_context.dart';
import 'package:mobile/core/inventory_session.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() async {
    await fixture.signIn('actor-a');
    fixture.requests.clear();
    fixture.status = 200;
    (await SharedPreferences.getInstance()).clear();
    InventoryCache.clear();
    fixture.respond = (request) => {
      'inventory': inventory(request.path.split('/').last),
    };
  });
  InventoryContext context(
    String id, {
    String role = 'editor',
    String workspace = 'workspace-a',
  }) => InventoryContext.fromJson(
    inventory(id, role: role, workspace: workspace),
    accountId: 'actor-a',
    expectedInventory: id,
  );

  test(
    'items, capture, documents, Spaces, Review and conversations use one selected inventory',
    () async {
      final api = ApiClient.forInventory(
        fixture.api,
        context('fasteners'),
        isCurrent: () => true,
      );
      fixture.respond = (request) => switch (request.path.split('/').last) {
        'search_items' => {'items': [], 'parsed': {}},
        'spaces' => {'spaces': []},
        'documents' => {'documents': []},
        'conversations' => [],
        'review-items' => {'items': [], 'pending_count': 0},
        _ => {
          'item': {
            'item_id': 'bolt',
            'name': 'Bolt',
            'category': 'Parts',
            'quantity': 2,
            'location': 'Bin 4',
          },
        },
      };
      await api.searchItems(query: 'bolt');
      await api.listSpaces();
      await api.getDocuments();
      await api.listConversations();
      await api.getReviewItems();
      await api.addItem(
        item: AddItemRequest(
          name: 'Bolt',
          category: 'Parts',
          quantity: 2,
          location: 'Bin 4',
        ),
      );
      await api.updateItem(
        request: UpdateItemRequest(itemId: 'bolt', quantity: 3),
      );
      expect(
        fixture.requests.map((r) => r.path),
        everyElement(startsWith('/inventories/fasteners/')),
      );
      expect(
        fixture.requests,
        everyElement(
          predicate<dio.RequestOptions>(
            (r) => r.headers['Authorization'].toString().startsWith('Bearer '),
          ),
        ),
      );
      expect(fixture.requests.last.data['item_id'], 'bolt');
      expect(fixture.requests.last.data['quantity'], 3);
      expect(
        api.inventoryPath('/ai_command?stream=true'),
        '/inventories/fasteners/ai_command?stream=true',
      );
      expect(
        api.inventoryPath('/ai_photo_question'),
        '/inventories/fasteners/ai_photo_question',
      );
      expect(api.inventoryPath('/me/profile'), '/me/profile');
    },
  );

  test(
    'viewer can search and chat but cannot create, scan, edit or delete',
    () async {
      final api = ApiClient.forInventory(
        fixture.api,
        context('tools', role: 'viewer'),
        isCurrent: () => true,
      );
      fixture.respond = (_) => {'items': [], 'parsed': {}};
      await api.searchItems(query: 'drill');
      for (final operation in [
        () => api.addItem(
          item: AddItemRequest(
            name: 'Drill',
            category: 'Tools',
            quantity: 1,
            location: 'Bench',
          ),
        ),
        () => api.updateItem(
          request: UpdateItemRequest(itemId: 'drill', quantity: 4),
        ),
        () => api.deleteItem(itemId: 'drill'),
        () => api.extractInventoryFromImage(
          bytes: [1, 2, 3],
          filename: 'photo.jpg',
        ),
        () => api.createSpace(name: 'Cabinet'),
      ]) {
        await expectLater(operation(), throwsA(isA<dio.DioException>()));
      }
      expect(fixture.requests, hasLength(1));
    },
  );

  test(
    'late inventory response is rejected and old client never writes into new context',
    () async {
      var current = true;
      final old = ApiClient.forInventory(
        fixture.api,
        context('old'),
        isCurrent: () => current,
      );
      final started = Completer<void>(), release = Completer<void>();
      fixture.respond = (_) async {
        started.complete();
        await release.future;
        return {'items': []};
      };
      final pending = old.searchItems(query: '');
      final assertion = expectLater(pending, throwsA(isA<dio.DioException>()));
      await started.future;
      current = false;
      release.complete();
      await assertion;
      await expectLater(
        old.addItem(
          item: AddItemRequest(
            name: 'Bolt',
            category: 'Parts',
            quantity: 1,
            location: 'Bin',
          ),
        ),
        throwsA(isA<AskRequestException>()),
      );
      expect(fixture.requests.single.path, '/inventories/old/search_items');
    },
  );

  test(
    'account change rejects old clients and personal context stays scoped',
    () async {
      final api = ApiClient.forInventory(
        fixture.api,
        context('personal-a', workspace: 'personal'),
        isCurrent: () => true,
      );
      expect(api.inventoryPath('/spaces'), '/inventories/personal-a/spaces');
      await fixture.signIn('actor-b');
      await expectLater(api.listSpaces(), throwsA(isA<AskRequestException>()));
      expect(fixture.requests, isEmpty);
    },
  );

  test('Ask streams use inventory route and reject late events', () async {
    var current = true;
    final api = ApiClient.forInventory(
      fixture.api,
      context('fasteners'),
      isCurrent: () => current,
    );
    await http.runWithClient(
      () async {
        final events = await api.aiCommandStream(message: 'Where?').toList();
        expect(events.single.delta, 'Bin 4');
        current = false;
        await expectLater(
          api.aiCommandStream(message: 'Again').toList(),
          throwsA(isA<AskRequestException>()),
        );
      },
      () => MockClient((request) async {
        expect(request.url.path, '/inventories/fasteners/ai_command');
        expect(request.url.queryParameters['stream'], 'true');
        return http.Response(
          'data: ${jsonEncode({'type': 'delta', 'delta': 'Bin 4'})}\n\n',
          200,
        );
      }),
    );
  });

  test(
    'switching rejects stale selections and clears cached records',
    () async {
      final session = InventorySession(fixture.api, 'actor-a');
      addTearDown(session.dispose);
      final started = Completer<void>(), release = Completer<void>();
      fixture.respond = (request) async {
        final id = request.path.split('/').last;
        if (id == 'a') {
          started.complete();
          await release.future;
        }
        return {'inventory': inventory(id)};
      };
      final old = session.open('a');
      await started.future;
      await session.open(
        'b',
        workspaceId: 'workspace-a',
        organizationId: 'org-a',
      );
      release.complete();
      await old;
      expect(session.selection?.inventoryId, 'b');
      expect(
        (await SharedPreferences.getInstance()).getString(
          'findez.active-inventory:actor-a',
        ),
        'b',
      );
      final oldClient = session.inventoryApi!;
      await session.chooseAnother();
      await expectLater(
        oldClient.listSpaces(),
        throwsA(isA<AskRequestException>()),
      );
    },
  );

  test(
    'invalid inventory workspace or organization is never activated',
    () async {
      final session = InventorySession(fixture.api, 'actor-a');
      addTearDown(session.dispose);
      await session.open('a', workspaceId: 'workspace-b');
      expect(session.error, isA<FormatException>());
      expect(session.inventoryApi, isNull);
      await session.open('a', organizationId: 'org-b');
      expect(session.error, isA<FormatException>());
      expect(session.selection, isNull);
      expect(
        () => InventoryContext.fromJson(
          {...inventory('a'), 'team_id': 'other'},
          accountId: 'actor-a',
          expectedInventory: 'a',
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'refresh reflects web changes, rechecks roles, denial retires context',
    () async {
      final session = InventorySession(fixture.api, 'actor-a');
      addTearDown(session.dispose);
      await session.open('a');
      final previous = session.inventoryApi!;
      fixture.respond = (_) => {
        'inventory': inventory('a', role: 'viewer', name: 'Renamed on web'),
      };
      await session.revalidate();
      expect(session.selection?.name, 'Renamed on web');
      expect(session.inventoryApi?.canEdit, false);
      expect(
        () => previous.assertCurrentContext(),
        throwsA(isA<AskRequestException>()),
      );
      fixture.status = 403;
      fixture.respond = (_) => {
        'detail': 'You do not have access to this inventory.',
      };
      await session.revalidate();
      expect(session.selection, isNull);
      expect(session.error, isA<dio.DioException>());
    },
  );

  test(
    'offline restoration offers retry and never falls back to arbitrary inventory',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('findez.active-inventory:actor-a', 'a');
      final session = InventorySession(fixture.api, 'actor-a');
      addTearDown(session.dispose);
      fixture.respond = (r) => throw dio.DioException(
        requestOptions: r,
        type: dio.DioExceptionType.connectionError,
      );
      await session.restore();
      expect(session.selection, isNull);
      expect(session.loading, false);
      expect(session.error, isNotNull);
      fixture.respond = (_) => {
        'inventory': inventory('a', workspace: 'personal', role: 'owner'),
      };
      await session.restore();
      expect(session.selection?.isPersonal, true);
      expect(session.error, isNull);
    },
  );

  test('cache keys isolate duplicate matching and Home across inventories', () {
    final a = ApiClient.forInventory(
      fixture.api,
      context('a'),
      isCurrent: () => true,
    );
    final b = ApiClient.forInventory(
      fixture.api,
      context('b'),
      isCurrent: () => true,
    );
    final item = InventoryItem.fromJson({'item_id': 'a-item', 'name': 'Bolt'});
    InventoryCache.setItems([item], contextKey: a.cacheKey);
    expect(InventoryCache.forContext(b.cacheKey), isEmpty);
    expect(InventoryCache.forContext(a.cacheKey).single.itemId, 'a-item');
    expect(InventoryCache.items, isEmpty);
  });
}
