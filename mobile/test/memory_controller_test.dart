import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/memory_controller.dart';

class MemoryApi extends ApiClient {
  MemoryApi() : super(baseUrl: 'https://api.test');
  String? actor = 'a';
  bool fail = false, missing = false;
  Completer<void>? pendingRead;
  Map<String, dynamic> record = {
    'enabled': false,
    'revision': 0,
    'entries': [],
    'legacy': [],
  };
  final writes = <Map<String, dynamic>>[];
  @override
  String? get accountId => actor;
  @override
  Future<Map<String, dynamic>> collaboration(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async {
    if (method == 'POST') {
      writes.add(Map.from(data!));
      if (fail) throw const AskRequestException('Offline');
      if (missing) return {};
      record = {
        ...record,
        'revision': (record['revision'] as int) + 1,
        if (data['action'] == 'settings') 'enabled': data['enabled'],
      };
      return {'saved': true};
    }
    if (pendingRead != null) await pendingRead!.future;
    if (fail) throw const AskRequestException('Offline');
    return path == '/memory/export'
        ? {'partial': false, 'memory': record}
        : Map.from(record);
  }
}

void main() {
  test('loads, saves and refetches without caching another session', () async {
    final api = MemoryApi(), store = MemoryController(MemoryApi());
    store.dispose();
    final first = MemoryController(api);
    await first.load();
    await first.change({'action': 'settings', 'enabled': true});
    expect(first.enabled, isTrue);
    expect(first.snapshot!['revision'], 1);
    final next = MemoryController(api);
    await next.load();
    expect(next.enabled, isTrue);
    expect(api.writes.single.containsKey('user_id'), isFalse);
    first.dispose();
    next.dispose();
  });
  test(
    'unknown outcome retains one operation for retry and blocks another change',
    () async {
      final api = MemoryApi();
      final store = MemoryController(api);
      await store.load();
      api.fail = true;
      await store.change({'action': 'settings', 'enabled': true});
      final pending = Map<String, dynamic>.from(store.pending!);
      expect(store.error, isNotNull);
      await store.change({'action': 'clear'});
      expect(api.writes.length, 1);
      api.fail = false;
      await store.change(null);
      expect(api.writes[1], pending);
      expect(store.pending, isNull);
      expect(store.enabled, isTrue);
      expect(
        pending['operation_id'],
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      store.dispose();
    },
  );
  test('offline initial load retries and does not invent records', () async {
    final api = MemoryApi()..fail = true;
    final store = MemoryController(api);
    await store.load();
    expect(store.snapshot, isNull);
    expect(store.error, isNotNull);
    api.fail = false;
    await store.load();
    expect(store.snapshot, isNotNull);
    expect(store.error, isNull);
    store.dispose();
  });
  test(
    'account change while request is pending clears private response',
    () async {
      final api = MemoryApi()..pendingRead = Completer<void>();
      final store = MemoryController(api);
      final work = store.load();
      api.actor = 'b';
      api.pendingRead!.complete();
      await work;
      expect(store.snapshot, isNull);
      expect(store.pending, isNull);
      expect(store.error, contains('account changed'));
      store.dispose();
    },
  );
  test('unconfirmed mutation never reports success', () async {
    final api = MemoryApi();
    final store = MemoryController(api);
    await store.load();
    api.missing = true;
    await store.change({'action': 'settings', 'enabled': true});
    expect(store.notice, isNull);
    expect(store.pending, isNotNull);
    expect(store.enabled, isFalse);
    store.dispose();
  });
  test(
    'export is account checked and unknown response is not copied after switch',
    () async {
      final api = MemoryApi();
      final store = MemoryController(api);
      await store.load();
      expect(await store.export(), contains('"memory"'));
      api.actor = 'b';
      expect(await store.export(), isNull);
      expect(store.snapshot, isNull);
      store.dispose();
    },
  );
  test('disposed controller does not publish late network results', () async {
    final api = MemoryApi()..pendingRead = Completer<void>();
    final store = MemoryController(api);
    final work = store.load();
    store.dispose();
    api.pendingRead!.complete();
    await work;
    expect(store.snapshot, isNull);
  });
}
