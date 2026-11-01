import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:mobile/core/last_place.dart';
import 'package:mobile/features/onboarding/pending_world.dart';

const teamSetup = PendingWorld(
  path: 'team',
  orgName: 'Kestrel Labs',
  workspacePurpose: 'R&D',
  inventoryName: 'Hardware',
  step: WorldStep.auth,
);
const personalSetup = PendingWorld(
  path: 'personal',
  workspacePurpose: 'Workshop',
  inventoryName: 'Tools',
  step: WorldStep.auth,
);

class CreationApi implements WorldCreationApi {
  String? actor = 'account-a';
  String? reject, loseReceipt, loseBeforeWrite;
  Completer<void>? paused;
  final requests = <String>[];
  final records = <String, List<Map<String, dynamic>>>{
    'organization': [],
    'workspace': [],
    'inventory': [],
  };
  @override
  String? get accountId => actor;
  @override
  Future<List<Map<String, dynamic>>> list(
    String kind,
    PendingWorld setup,
  ) async => records[kind]!
      .where(
        (row) =>
            kind != 'workspace' ||
            !setup.isTeam ||
            setup.createdIds['organization'] == null ||
            row['organization_id'] == setup.createdIds['organization'],
      )
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
  @override
  Future<String> create(String kind, PendingWorld setup) async {
    requests.add(kind);
    final owner = actor;
    if (paused != null) await paused!.future;
    if (reject == kind) {
      reject = null;
      final options = RequestOptions(path: '/synthetic');
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 422),
        type: DioExceptionType.badResponse,
      );
    }
    if (loseBeforeWrite == kind) {
      loseBeforeWrite = null;
      throw DioException(
        requestOptions: RequestOptions(path: '/synthetic'),
        type: DioExceptionType.receiveTimeout,
      );
    }
    final id = '$kind-${records[kind]!.length + 1}';
    records[kind]!.add({
      '${kind}_id': id,
      'name': worldName(kind, setup),
      'owner_user_id': owner,
      'created_by_user_id': owner,
      if (kind == 'workspace') 'organization_id': setup.createdIds['organization'],
    });
    if (loseReceipt == kind) {
      loseReceipt = null;
      throw DioException(
        requestOptions: RequestOptions(path: '/synthetic'),
        type: DioExceptionType.receiveTimeout,
      );
    }
    return id;
  }
}

class RejectAttemptWrites extends InMemorySharedPreferencesStore {
  RejectAttemptWrites() : super.empty();
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.contains('build-world.account.') &&
        value is String &&
        (jsonDecode(value) as Map)['attempts'].isNotEmpty) {
      return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'draft persists and resumes the exact user step and custom answers',
    () async {
      final value = teamSetup.copyWith(
        step: WorldStep.inventory,
        workspacePurpose: 'Field service',
      );
      await WorldSetupStore.saveDraft(value);
      final restored = await WorldSetupStore.draft();
      expect(restored!.toJson(), value.toJson());
      expect(restored.ready, isFalse);
      final api = CreationApi();
      expect(await WorldProvisioner(api).run((_) async => true), isNull);
      expect(api.requests, isEmpty);
    },
  );
  test(
    'team creates organization then workspace then inventory, once, and saves the landing',
    () async {
      final api = CreationApi();
      await WorldSetupStore.saveDraft(teamSetup);
      final result = await WorldProvisioner(
        api,
      ).run((_) async => throw StateError('New account needs no sheet'));
      expect(api.requests, ['organization', 'workspace', 'inventory']);
      expect(result!.organizationId, 'organization-1');
      expect(result.workspaceId, 'workspace-1');
      expect(result.inventoryId, 'inventory-1');
      expect(await WorldSetupStore.draft(), isNull);
      expect(
        (await SharedPreferences.getInstance()).getString(
          WorldSetupStore.accountKey('account-a'),
        ),
        isNull,
      );
      expect(
        await LastPlaceStore('account-a').read(),
        const LastPlace.workspace('workspace-1'),
      );
      expect(
        (await WorldSetupStore.landing('account-a'))!.inventoryId,
        'inventory-1',
      );
      expect(
        (await WorldProvisioner(api).run((_) async => true))!.inventoryId,
        'inventory-1',
      );
      expect(api.requests.length, 3);
      await WorldSetupStore.clearLanding('account-a', 'different');
      expect(await WorldSetupStore.landing('account-a'), isNotNull);
      await WorldSetupStore.clearLanding('account-a', 'inventory-1');
      expect(await WorldSetupStore.landing('account-a'), isNull);
    },
  );
  test(
    'personal creates a standalone workspace and inventory without touching built-in Personal',
    () async {
      final api = CreationApi();
      await WorldSetupStore.saveDraft(personalSetup);
      final result = await WorldProvisioner(api).run((_) async => true);
      expect(api.requests, ['workspace', 'inventory']);
      expect(result!.organizationId, isNull);
      expect(result.workspaceId, isNot('personal'));
      expect(api.records['workspace']!.single['organization_id'], isNull);
    },
  );
  test(
    'failed workspace retries from the saved organization receipt',
    () async {
      final api = CreationApi()..reject = 'workspace';
      await WorldSetupStore.saveDraft(teamSetup);
      await expectLater(
        WorldProvisioner(api).run((_) async => true),
        throwsA(isA<DioException>()),
      );
      final restored = await WorldSetupStore.claim('account-a');
      expect(restored!.createdIds, {'organization': 'organization-1'});
      final result = await WorldProvisioner(
        api,
      ).run((_) async => throw StateError('Consent was already saved'));
      expect(result!.inventoryId, 'inventory-1');
      expect(api.requests, [
        'organization',
        'workspace',
        'workspace',
        'inventory',
      ]);
      expect(api.records.values.map((rows) => rows.length), [1, 1, 1]);
    },
  );
  for (final kind in ['organization', 'workspace', 'inventory']) {
    test(
      'lost $kind response is recovered from authorized records without a duplicate POST',
      () async {
        final api = CreationApi()..loseReceipt = kind;
        await WorldSetupStore.saveDraft(teamSetup);
        await expectLater(
          WorldProvisioner(api).run((_) async => true),
          throwsA(isA<DioException>()),
        );
        final result = await WorldProvisioner(api).run((_) async => true);
        expect(result!.inventoryId, 'inventory-1');
        expect(api.requests, ['organization', 'workspace', 'inventory']);
        expect(api.records.values.map((rows) => rows.length), [1, 1, 1]);
      },
    );
  }
  test(
    'unknown uncommitted outcome stays retryable but never blindly duplicates a POST',
    () async {
      final api = CreationApi()..loseBeforeWrite = 'organization';
      await WorldSetupStore.saveDraft(teamSetup);
      await expectLater(
        WorldProvisioner(api).run((_) async => true),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        WorldProvisioner(api).run((_) async => true),
        throwsA(isA<SetupOutcomeUncertain>()),
      );
      expect(api.requests, ['organization']);
      expect(
        (await WorldSetupStore.claim(
          'account-a',
        ))!.attempts.containsKey('organization'),
        isTrue,
      );
    },
  );
  for (final decision in [true, false]) {
    test(
      'existing account ${decision ? 'Add' : 'Skip'} is explicit and stored',
      () async {
        final api = CreationApi();
        api.records['organization']!.add({
          'organization_id': 'old-org',
          'name': 'Existing',
          'owner_user_id': 'account-a',
        });
        await WorldSetupStore.saveDraft(teamSetup);
        var asked = 0;
        final result = await WorldProvisioner(api).run((setup) async {
          asked++;
          expect(api.requests, isEmpty);
          return decision;
        });
        expect(asked, 1);
        expect(api.requests.length, decision ? 3 : 0);
        expect(result == null, !decision);
        expect(await WorldSetupStore.claim('account-a'), isNull);
        expect(
          api.records['organization']!.first['organization_id'],
          'old-org',
        );
      },
    );
  }
  test('returning-user skip discards the draft and creates nothing', () async {
    final api = CreationApi();
    await WorldSetupStore.saveDraft(teamSetup);
    await WorldSetupStore.skipDraft();
    expect(await WorldProvisioner(api).run((_) async => true), isNull);
    expect(api.requests, isEmpty);
  });
  test('signed-out provisioning is rejected before any API call', () async {
    final api = CreationApi()..actor = null;
    await WorldSetupStore.saveDraft(teamSetup);
    await expectLater(
      WorldProvisioner(api).run((_) async => true),
      throwsStateError,
    );
    expect(api.requests, isEmpty);
    expect(await WorldSetupStore.draft(), isNotNull);
  });
  test('two simultaneous entry rebuilds share a single sequence', () async {
    final api = CreationApi();
    await WorldSetupStore.saveDraft(teamSetup);
    final results = await Future.wait([
      WorldProvisioner(api).run((_) async => true),
      WorldProvisioner(api).run((_) async => true),
    ]);
    expect(results.map((result) => result!.inventoryId), [
      'inventory-1',
      'inventory-1',
    ]);
    expect(api.requests, ['organization', 'workspace', 'inventory']);
  });
  test(
    'account switch in flight retains A receipt without creating under B',
    () async {
      final api = CreationApi()..paused = Completer<void>();
      await WorldSetupStore.saveDraft(teamSetup);
      final run = WorldProvisioner(api).run((_) async => true);
      while (api.requests.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      api.actor = 'account-b';
      final expected = expectLater(run, throwsStateError);
      api.paused!.complete();
      await expected;
      expect((await WorldSetupStore.claim('account-a'))!.createdIds, {
        'organization': 'organization-1',
      });
      expect(await WorldSetupStore.claim('account-b'), isNull);
      expect(await WorldSetupStore.landing('account-b'), isNull);
      expect(api.requests, ['organization']);
    },
  );
  test('failed native intent write stops before server creation', () async {
    SharedPreferencesStorePlatform.instance = RejectAttemptWrites();
    await WorldSetupStore.saveDraft(teamSetup);
    final api = CreationApi();
    await expectLater(
      WorldProvisioner(api).run((_) async => true),
      throwsStateError,
    );
    expect(api.requests, isEmpty);
  });
}
