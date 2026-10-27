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
  tearDownAll(() => Supabase.instance.dispose());
  final sessions = <PlaceSession>[];
  PlaceSession session() {
    final result = PlaceSession(fixture.api, 'actor-a');
    sessions.add(result);
    return result;
  }

  Object response(RequestOptions r) {
    final id = r.path.split('/').last;
    if (r.path.startsWith('/organizations/')) {
      return {
        'organization': {
          'organization_id': id,
          'name': 'Organization $id',
          'role': 'owner',
        },
        'workspaces': [
          if (id != 'empty')
            {'team_id': '$id-work', 'name': 'Workshop', 'organization_id': id},
        ],
      };
    }
    if (r.path.endsWith('/overview')) {
      final workspace = r.path.split('/')[2];
      final org = workspace == 'independent'
          ? null
          : workspace.split('-').first;
      return {
        'workspace': {
          'workspace_id': workspace,
          'name': 'Workshop',
          'organization_id': org,
          'organization_name': org,
          'role': 'owner',
        },
      };
    }
    if (r.path.endsWith('/directory')) {
      final workspace = r.path.split('/')[2];
      return {
        'inventories': [
          {
            'workspace_id': workspace,
            'inventory_id': '$workspace-inv',
            'name': 'Hardware',
            'can_open': true,
          },
        ],
        'next_offset': null,
      };
    }
    if (r.path == '/organizations') return {'organizations': []};
    if (r.path == '/inventory-workspaces') {
      return {
        'workspaces': [
          {'workspace_id': 'a-work'},
          {'workspace_id': 'b-work'},
          {'workspace_id': 'independent'},
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
    'same names cannot mix organization IDs or fetch another organization inventory',
    () async {
      final s = session();
      await s.selectOrganization('a');
      expect(s.organizationId, 'a');
      expect(s.workspaces.single['workspace_id'], 'a-work');
      expect(s.data!.inventories.single['inventory_id'], 'a-work-inv');
      expect(fixture.requests.any((r) => r.path.contains('b-work')), false);
      await expectLater(s.selectWorkspace('b-work'), throwsFormatException);
      expect(s.current.id, 'a-work');
      await s.selectOrganization('b');
      expect(s.data!.inventories.single['inventory_id'], 'b-work-inv');
      expect(s.workspaces.single['workspace_id'], 'b-work');
    },
  );
  test(
    'cold launch restores the selected organization and workspace',
    () async {
      await session().selectOrganization('b');
      final restored = session();
      await restored.restoreNavigation();
      expect(restored.organizationId, 'b');
      expect(restored.current.id, 'b-work');
    },
  );
  test(
    'empty organization remains selected across refresh and cold launch',
    () async {
      final s = session();
      await s.selectOrganization('empty');
      expect(s.data, null);
      expect(s.error, null);
      await s.refresh();
      final restored = session();
      await restored.restoreNavigation();
      expect(restored.organizationId, 'empty');
      expect(restored.workspaces, isEmpty);
      expect(restored.data, null);
      expect(restored.error, null);
    },
  );
  test(
    'slow old organization cannot replace a newer scope or preference',
    () async {
      final waiting = Completer<Object>();
      fixture.respond = (r) =>
          r.path == '/organizations/a' ? waiting.future : response(r);
      final s = session();
      final old = s.selectOrganization('a');
      await s.selectOrganization('b');
      waiting.complete(response(RequestOptions(path: '/organizations/a')));
      await old;
      expect(s.organizationId, 'b');
      expect(s.data!.place.id, 'b-work');
      expect(await s.store.readOrganization(), 'b');
    },
  );
  test(
    'switch clears the previous directory while loading and failures never show it',
    () async {
      final s = session();
      await s.selectOrganization('a');
      final waiting = Completer<Object>();
      fixture.respond = (r) => waiting.future;
      final next = s.selectOrganization('b');
      expect(s.data, null);
      expect(s.workspaces, isEmpty);
      expect(s.loading, true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      waiting.completeError(
        DioException(
          requestOptions: RequestOptions(path: '/organizations/b'),
          type: DioExceptionType.connectionError,
        ),
      );
      await next;
      expect(s.error, isNotNull);
      expect(s.organizationId, 'b');
      expect(s.data, null);
      fixture.respond = response;
      await s.refresh();
      expect(s.data!.place.id, 'b-work');
    },
  );
  test(
    'authoritative workspace parent mismatch rejects the entire directory',
    () async {
      fixture.respond = (r) => r.path.endsWith('/overview')
          ? {
              'workspace': {
                'workspace_id': 'a-work',
                'name': 'Workshop',
                'organization_id': 'b',
              },
            }
          : response(r);
      final s = session();
      await s.selectOrganization('a');
      expect(s.error, isA<FormatException>());
      expect(s.data, null);
      expect(s.workspaces, isEmpty);
    },
  );
  test(
    'revoked organization does not silently enter another organization or Personal',
    () async {
      final s = session();
      await s.selectOrganization('a');
      fixture.respond = (r) => throw DioException(
        requestOptions: r,
        response: Response(requestOptions: r, statusCode: 403),
      );
      await s.refresh();
      expect(s.organizationId, 'a');
      expect(s.error, isNotNull);
      expect(s.data, null);
    },
  );
  test('Personal shows only private and independent workspaces', () async {
    final s = session();
    await s.selectOrganization(null);
    expect(s.workspaces.map((w) => w['workspace_id']).toSet(), {
      'personal',
      'independent',
    });
    expect(s.data!.organizationId, null);
    expect(
      fixture.requests.any(
        (r) =>
            r.path.contains('a-work/directory') ||
            r.path.contains('b-work/directory'),
      ),
      false,
    );
    await expectLater(s.selectWorkspace('a-work'), throwsFormatException);
  });
  test(
    'explicit onboarding or link establishes scope from the validated parent',
    () async {
      final s = session();
      await s.selectOrganization('b');
      await s.restoreNavigation(override: const LastPlace.workspace('a-work'));
      expect(s.organizationId, 'a');
      expect(s.current.id, 'a-work');
      expect(s.navigationReady, true);
    },
  );
  test(
    'sign-out retires pending scope and clears its account-bound selection',
    () async {
      final s = session();
      await s.selectOrganization('a');
      final waiting = Completer<Object>();
      fixture.respond = (r) =>
          r.path == '/organizations/b' ? waiting.future : response(r);
      final next = s.selectOrganization('b');
      await s.signOut();
      waiting.complete(response(RequestOptions(path: '/organizations/b')));
      await next;
      expect(s.data, null);
      expect(s.organizationId, null);
      expect(await s.store.readOrganization(), null);
      expect(await LastPlaceStore('actor-b').readOrganization(), null);
    },
  );
}
