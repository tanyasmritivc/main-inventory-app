import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/last_place.dart';
import 'package:mobile/core/place_session.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  test(
    'workspace links accept only registered FindEZ origins and notifications bind recipient',
    () {
      expect(
        placeFromLink(Uri.parse('https://www.findez.ai/workspaces/a')),
        const LastPlace.workspace('a'),
      );
      expect(
        placeFromLink(Uri.parse('https://findez.ai.evil.test/workspaces/a')),
        null,
      );
      expect(placeFromLink(Uri.parse('http://findez.ai/workspaces/a')), null);
      expect(
        placeFromNotification({
          'workspace_id': 'a',
          'recipient_user_id': 'other',
        }, 'actor-a'),
        null,
      );
      expect(
        placeFromNotification({
          'metadata': {'team_id': 'a'},
        }, 'actor-a'),
        const LastPlace.workspace('a'),
      );
    },
  );
  tearDownAll(() => Supabase.instance.dispose());
  final sessions = <PlaceSession>[];
  PlaceSession session() {
    final s = PlaceSession(fixture.api, fixture.api.accountId!);
    sessions.add(s);
    return s;
  }

  Object response(RequestOptions r) {
    final id = r.path.split('/').length > 2 ? r.path.split('/')[2] : '';
    if (r.path.endsWith('/overview')) {
      return {
        'workspace': {
          'workspace_id': id,
          'name': id,
          'organization_id': id == 'a' ? 'org' : null,
          'role': 'member',
        },
        'members': [],
      };
    }
    if (r.path.endsWith('/directory')) {
      return {'inventories': [], 'next_offset': null};
    }
    if (r.path == '/organizations') {
      return {
        'organizations': [
          {'organization_id': 'org', 'name': 'Organization', 'role': 'member'},
        ],
      };
    }
    if (r.path == '/inventory-workspaces') {
      return {
        'workspaces': [
          {'workspace_id': 'a'},
          {'workspace_id': 'a'},
          {'workspace_id': 'b'},
        ],
      };
    }
    throw StateError(r.path);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fixture.status = 200;
    fixture.requests.clear();
    fixture.respond = response;
  });
  tearDown(() {
    for (final s in sessions) {
      s.dispose();
    }
    sessions.clear();
  });
  test(
    'first launch is Personal; a switch saves its account-bound place',
    () async {
      final s = session();
      await s.restore();
      expect(s.current.isPersonal, true);
      await s.select(const LastPlace.workspace('a'));
      expect(await s.store.read(), const LastPlace.workspace('a'));
      expect(
        (await SharedPreferences.getInstance()).getString('last_place_actor-a'),
        contains('"userId":"actor-a"'),
      );
    },
  );
  test(
    'cold restore validates saved workspace before exposing a home',
    () async {
      await LastPlaceStore(
        'actor-a',
      ).save(const LastPlace.workspace('a'), isCurrent: () => true);
      final waiting = Completer<Object>();
      fixture.respond = (r) =>
          r.path.endsWith('/overview') ? waiting.future : response(r);
      final s = session();
      final restoring = s.restore();
      await Future<void>.delayed(Duration.zero);
      expect(s.loading, true);
      expect(s.data, null);
      waiting.complete({
        'workspace': {'workspace_id': 'a', 'name': 'A', 'role': 'member'},
      });
      await restoring;
      expect(s.data?.name, 'A');
      expect(s.current, const LastPlace.workspace('a'));
    },
  );
  test(
    'revoked access falls back to Personal, persists it and explains why',
    () async {
      await LastPlaceStore(
        'actor-a',
      ).save(const LastPlace.workspace('a'), isCurrent: () => true);
      fixture.respond = (r) {
        if (r.path.endsWith('/overview')) {
          throw DioException(
            requestOptions: r,
            response: Response(requestOptions: r, statusCode: 403),
          );
        }
        return response(r);
      };
      final s = session();
      await s.restore();
      expect(s.current.isPersonal, true);
      expect(await s.store.read(), const LastPlace.personal());
      expect(s.takeNotice(), 'That workspace is no longer available');
      expect(s.error, null);
    },
  );
  test(
    'offline restore retains intended place and Retry, never falls back',
    () async {
      await LastPlaceStore(
        'actor-a',
      ).save(const LastPlace.workspace('a'), isCurrent: () => true);
      fixture.respond = (r) => throw DioException(
        requestOptions: r,
        type: DioExceptionType.connectionError,
      );
      final s = session();
      await s.restore();
      expect(s.error, isNotNull);
      expect(s.data, null);
      expect(s.current, const LastPlace.workspace('a'));
      expect(await s.store.read(), const LastPlace.workspace('a'));
      fixture.respond = response;
      await s.refresh();
      expect(s.data, isNotNull);
      expect(s.error, null);
    },
  );
  test(
    'explicit deep-link target overrides the stored place and becomes saved',
    () async {
      await LastPlaceStore(
        'actor-a',
      ).save(const LastPlace.workspace('a'), isCurrent: () => true);
      final s = session();
      await s.restore(override: const LastPlace.workspace('b'));
      expect(s.current, const LastPlace.workspace('b'));
      expect(await s.store.read(), s.current);
    },
  );
  test(
    'sign out clears only this user and a second user has separate storage',
    () async {
      final s = session();
      await s.select(const LastPlace.workspace('a'));
      await LastPlaceStore(
        'actor-b',
      ).save(const LastPlace.workspace('b'), isCurrent: () => true);
      await s.signOut();
      expect(await s.store.read(), const LastPlace.personal());
      expect(
        await LastPlaceStore('actor-b').read(),
        const LastPlace.workspace('b'),
      );
    },
  );
  test(
    'slow old workspace cannot replace a newer selection or its preference',
    () async {
      final waiting = Completer<Object>();
      fixture.respond = (r) => r.path == '/inventory-workspaces/a/overview'
          ? waiting.future
          : response(r);
      final s = session();
      final pending = s.select(const LastPlace.workspace('a'));
      await s.select(const LastPlace.workspace('b'));
      waiting.complete({
        'workspace': {'workspace_id': 'a', 'name': 'A', 'role': 'member'},
      });
      await pending;
      expect(s.current, const LastPlace.workspace('b'));
      expect(await s.store.read(), s.current);
    },
  );
  test('sign out wins over a pending response and late device save', () async {
    final waiting = Completer<Object>();
    fixture.respond = (r) =>
        r.path.endsWith('/overview') ? waiting.future : response(r);
    final s = session();
    final pending = s.select(const LastPlace.workspace('a'));
    await s.signOut();
    waiting.complete({
      'workspace': {'workspace_id': 'a', 'name': 'A', 'role': 'member'},
    });
    await pending;
    expect(
      (await SharedPreferences.getInstance()).containsKey(s.store.key),
      false,
    );
  });
  test('a directory row from a different parent is rejected', () async {
    fixture.respond = (r) => r.path.endsWith('/directory')
        ? {
            'inventories': [
              {'inventory_id': 'i', 'workspace_id': 'other'},
            ],
          }
        : response(r);
    final s = session();
    await s.select(const LastPlace.workspace('a'));
    expect(s.error, isA<FormatException>());
    expect(s.data, null);
  });
  test(
    'directory resolves missing parent IDs and lists each workspace once',
    () async {
      final directory = await session().repository.directory();
      expect(directory.workspaces.map((w) => w.place.id), ['a', 'b']);
      expect(directory.workspaces.first.organizationId, 'org');
      expect(directory.workspaces.last.organizationId, null);
    },
  );
}
