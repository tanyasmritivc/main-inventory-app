import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/last_place.dart';

enum WorldStep {
  intro,
  choose,
  organization,
  workspace,
  inventory,
  world,
  auth,
}

class PendingWorld {
  const PendingWorld({
    this.path,
    this.orgName = '',
    this.workspacePurpose = '',
    this.inventoryName = '',
    this.step = WorldStep.intro,
    this.owner,
    this.accepted,
    this.createdIds = const {},
    this.attempts = const {},
  });
  final String? path, owner;
  final String orgName, workspacePurpose, inventoryName;
  final WorldStep step;
  final bool? accepted;
  final Map<String, String> createdIds;
  final Map<String, List<String>> attempts;
  bool get isTeam => path == 'team';
  bool get ready =>
      step == WorldStep.auth &&
      (path == 'personal' || isTeam) &&
      (!isTeam || validName(orgName, 60)) &&
      validName(workspacePurpose, 40) &&
      validName(inventoryName, 40);
  static bool validName(String value, int limit) =>
      value.trim().isNotEmpty &&
      value.trim().length <= limit &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);

  Map<String, dynamic> toJson() => {
    'version': 1,
    'path': path,
    'orgName': orgName,
    'workspacePurpose': workspacePurpose,
    'inventoryName': inventoryName,
    'step': step.name,
    'owner': owner,
    'accepted': accepted,
    'createdIds': createdIds,
    'attempts': attempts,
  };
  factory PendingWorld.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException('Unsupported setup');
    return PendingWorld(
      path: json['path'] as String?,
      orgName: json['orgName'] as String,
      workspacePurpose: json['workspacePurpose'] as String,
      inventoryName: json['inventoryName'] as String,
      step: WorldStep.values.byName(json['step'] as String),
      owner: json['owner'] as String?,
      accepted: json['accepted'] as bool?,
      createdIds: Map<String, String>.from(json['createdIds'] as Map),
      attempts: (json['attempts'] as Map).map(
        (key, value) => MapEntry(key as String, (value as List).cast<String>()),
      ),
    );
  }
  PendingWorld copyWith({
    String? path,
    String? orgName,
    String? workspacePurpose,
    String? inventoryName,
    WorldStep? step,
    String? owner,
    bool? accepted,
    Map<String, String>? createdIds,
    Map<String, List<String>>? attempts,
  }) => PendingWorld(
    path: path ?? this.path,
    orgName: orgName ?? this.orgName,
    workspacePurpose: workspacePurpose ?? this.workspacePurpose,
    inventoryName: inventoryName ?? this.inventoryName,
    step: step ?? this.step,
    owner: owner ?? this.owner,
    accepted: accepted ?? this.accepted,
    createdIds: createdIds ?? this.createdIds,
    attempts: attempts ?? this.attempts,
  );
}

class WorldLanding {
  const WorldLanding(this.workspaceId, this.inventoryId, this.organizationId);
  final String workspaceId, inventoryId;
  final String? organizationId;
  Map<String, dynamic> toJson() => {
    'workspace': workspaceId,
    'inventory': inventoryId,
    'organization': organizationId,
  };
  factory WorldLanding.fromJson(Map<String, dynamic> data) => WorldLanding(
    data['workspace'] as String,
    data['inventory'] as String,
    data['organization'] as String?,
  );
}

/// A draft is claimed once, then all receipts are private to that account.
/// Serialize native writes so a delayed keystroke cannot replace newer progress.
class WorldSetupStore {
  static const draftKey = 'findez.build-world.draft.v1';
  static String accountKey(String id) => 'findez.build-world.account.$id';
  static String landingKey(String id) => 'findez.build-world.landing.$id';
  static Future<void>? _tail;
  static Future<T> _queue<T>(Future<T> Function() action) {
    final previous = _tail ?? Future<void>.value();
    final next = previous.then((_) => action(), onError: (_) => action());
    final pending = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tail = pending;
    return next.whenComplete(() {
      if (identical(_tail, pending)) _tail = null;
    });
  }

  static Future<void> _put(
    SharedPreferences prefs,
    String key,
    Object value,
  ) async {
    if (!await prefs.setString(key, jsonEncode(value))) {
      throw StateError('Setup progress could not be saved');
    }
  }

  static Future<void> _remove(SharedPreferences prefs, String key) async {
    if (prefs.containsKey(key) && !await prefs.remove(key)) {
      throw StateError('Setup progress could not be cleared');
    }
  }

  static PendingWorld? _read(SharedPreferences prefs, String key) {
    final value = prefs.getString(key);
    return value == null
        ? null
        : PendingWorld.fromJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map),
          );
  }

  static Future<PendingWorld?> draft() => _queue(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final result = _read(prefs, draftKey);
    return result?.owner == null ? result : null;
  });
  static Future<void> saveDraft(PendingWorld setup) {
    if (setup.owner != null || setup.createdIds.isNotEmpty) {
      throw StateError('An owned setup cannot become an anonymous draft');
    }
    final value = setup.toJson();
    return _queue(
      () async => _put(await SharedPreferences.getInstance(), draftKey, value),
    );
  }

  static Future<void> skipDraft() => _queue(() async {
    final prefs = await SharedPreferences.getInstance();
    final value = _read(prefs, draftKey);
    if (value?.owner == null) await _remove(prefs, draftKey);
  });
  static Future<PendingWorld?> claim(String userId) => _queue(() async {
    if (userId.isEmpty) throw StateError('Sign in before setting up');
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final owned = _read(prefs, accountKey(userId));
    if (owned != null) {
      if (owned.owner != userId) throw StateError('Setup account changed');
      return owned;
    }
    final value = _read(prefs, draftKey);
    if (value == null ||
        !value.ready ||
        (value.owner != null && value.owner != userId)) {
      return null;
    }
    final claimed = value.copyWith(owner: userId);
    // Bind the original first. A failed copy/removal cannot expose it to account B.
    await _put(prefs, draftKey, claimed.toJson());
    await _put(prefs, accountKey(userId), claimed.toJson());
    await _remove(prefs, draftKey);
    return claimed;
  });
  static Future<void> saveOwned(PendingWorld setup) => _queue(() async {
    if (setup.owner == null || setup.owner!.isEmpty) {
      throw StateError('Setup needs an account');
    }
    await _put(
      await SharedPreferences.getInstance(),
      accountKey(setup.owner!),
      setup.toJson(),
    );
  });
  static Future<void> discard(String userId) => _queue(() async {
    final prefs = await SharedPreferences.getInstance();
    final original = _read(prefs, draftKey);
    if (original?.owner == userId) await _remove(prefs, draftKey);
    await _remove(prefs, accountKey(userId));
  });
  static Future<void> saveLanding(String userId, WorldLanding landing) =>
      _queue(() async {
        await _put(
          await SharedPreferences.getInstance(),
          landingKey(userId),
          landing.toJson(),
        );
      });
  static Future<WorldLanding?> landing(String userId) => _queue(() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(landingKey(userId));
    return raw == null
        ? null
        : WorldLanding.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map),
          );
  });
  static Future<void> clearLanding(String userId, String inventoryId) => _queue(
    () async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(landingKey(userId));
      if (raw != null && (jsonDecode(raw) as Map)['inventory'] == inventoryId) {
        await _remove(prefs, landingKey(userId));
      }
    },
  );
}

abstract class WorldCreationApi {
  String? get accountId;
  Future<List<Map<String, dynamic>>> list(String kind, PendingWorld setup);
  Future<String> create(String kind, PendingWorld setup);
}

class ExistingWorldApi implements WorldCreationApi {
  ExistingWorldApi(this.api);
  final ApiClient api;
  @override
  String? get accountId => api.accountId;
  static List<Map<String, dynamic>> _rows(Object? value) => (value as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
  @override
  Future<List<Map<String, dynamic>>> list(
    String kind,
    PendingWorld setup,
  ) async {
    if (kind == 'organization') {
      return _rows(
        (await api.collaboration('/organizations'))['organizations'],
      );
    }
    if (kind == 'workspace') {
      if (setup.isTeam && setup.createdIds['organization'] != null) {
        return _rows(
          (await api.collaboration(
            '/organizations/${setup.createdIds['organization']}',
          ))['workspaces'],
        );
      }
      final result = _rows(
        (await api.collaboration('/inventory-workspaces'))['workspaces'],
      ).where((row) => row['workspace_id'] != 'personal').toList();
      if (setup.attempts['workspace'] == null) return result;
      // Resolve actual parent IDs before reconciling an uncertain standalone POST.
      final detailed = <Map<String, dynamic>>[];
      for (final row in result) {
        detailed.add(
          Map<String, dynamic>.from(
            (await api.collaboration(
                  '/inventory-workspaces/${row['workspace_id']}/overview',
                ))['workspace']
                as Map,
          ),
        );
      }
      return detailed.where((row) => row['organization_id'] == null).toList();
    }
    final result = <Map<String, dynamic>>[];
    int? offset = 0;
    do {
      final page = await api.collaboration(
        '/inventory-workspaces/${setup.createdIds['workspace']}/inventories',
        query: {'offset': offset},
      );
      result.addAll(_rows(page['inventories']));
      final next = page['next_offset'] as int?;
      if (next != null && next <= offset!) {
        throw const FormatException('Directory changed');
      }
      offset = next;
    } while (offset != null);
    return result;
  }

  @override
  Future<String> create(String kind, PendingWorld setup) async {
    final path = switch (kind) {
      'organization' => '/organizations',
      'workspace' when setup.isTeam =>
        '/organizations/${setup.createdIds['organization']}/workspaces',
      'workspace' => '/teams',
      _ => '/inventory-workspaces/${setup.createdIds['workspace']}/inventories',
    };
    final data = {
      'name': worldName(kind, setup),
      if (kind == 'workspace' && !setup.isTeam) 'program': 'other',
    };
    final response = await api.collaboration(path, method: 'POST', data: data);
    final row = Map<String, dynamic>.from(
      response[kind == 'workspace' && !setup.isTeam ? 'team' : kind] as Map? ??
          {},
    );
    final id =
        row['${kind}_id'] ?? (kind == 'workspace' ? row['team_id'] : null);
    if (id is! String || id.isEmpty) {
      throw const FormatException('Creation could not be confirmed');
    }
    return id;
  }
}

String worldName(String kind, PendingWorld setup) => switch (kind) {
  'organization' => setup.orgName.trim(),
  'workspace' => setup.workspacePurpose.trim(),
  _ => setup.inventoryName.trim(),
};
String worldId(String kind, Map<String, dynamic> row) =>
    (row['${kind}_id'] ?? (kind == 'workspace' ? row['team_id'] : null) ?? '')
        .toString();

class SetupOutcomeUncertain implements Exception {
  const SetupOutcomeUncertain();
}

/// Server creation APIs are reused unchanged. Unknown write outcomes are
/// reconciled from authorized reads, never blindly replayed as another POST.
class WorldProvisioner {
  WorldProvisioner(this.api);
  final WorldCreationApi api;
  static final Map<String, Future<WorldLanding?>> _runs = {};
  Future<WorldLanding?> run(Future<bool?> Function(PendingWorld) choose) {
    final actor = api.accountId;
    if (actor == null || actor.isEmpty) {
      return Future.error(StateError('Sign in first'));
    }
    if (_runs.containsKey(actor)) return _runs[actor]!;
    final future = _run(actor, choose);
    _runs[actor] = future;
    return future.whenComplete(() {
      if (identical(_runs[actor], future)) _runs.remove(actor);
    });
  }

  void _current(String actor) {
    if (api.accountId != actor) throw StateError('Setup account changed');
  }

  Future<WorldLanding?> _run(
    String actor,
    Future<bool?> Function(PendingWorld) choose,
  ) async {
    final claimed = await WorldSetupStore.claim(actor);
    _current(actor);
    if (claimed == null) return WorldSetupStore.landing(actor);
    var setup = claimed;
    if (setup.accepted == false) {
      await WorldSetupStore.discard(actor);
      return null;
    }
    if (!setup.ready) throw StateError('Finish the setup before creating it');
    if (setup.accepted == null) {
      final organizations = await api.list('organization', setup);
      _current(actor);
      final workspaces = await api.list('workspace', setup);
      _current(actor);
      final existing = organizations.isNotEmpty || workspaces.isNotEmpty;
      final accepted = existing ? await choose(setup) : true;
      _current(actor);
      if (accepted == null) {
        throw StateError('Choose whether to add this setup');
      }
      if (!accepted) {
        setup = setup.copyWith(accepted: false);
        await WorldSetupStore.saveOwned(setup);
        await WorldSetupStore.discard(actor);
        return null;
      }
      setup = setup.copyWith(accepted: true);
      await WorldSetupStore.saveOwned(setup);
    }
    for (final kind in [
      if (setup.isTeam) 'organization',
      'workspace',
      'inventory',
    ]) {
      _current(actor);
      if (setup.createdIds[kind] != null) continue;
      final available = await api.list(kind, setup);
      _current(actor);
      final attempted = setup.attempts[kind];
      String id;
      if (attempted != null) {
        final recovered = available
            .where(
              (row) =>
                  worldName(kind, setup) ==
                      (row['name'] as String? ?? '').trim() &&
                  !attempted.contains(worldId(kind, row)) &&
                  (row['owner_user_id'] == actor ||
                      row['created_by_user_id'] == actor),
            )
            .toList();
        if (recovered.length != 1) throw const SetupOutcomeUncertain();
        id = worldId(kind, recovered.single);
        if (id.isEmpty) throw const SetupOutcomeUncertain();
      } else {
        setup = setup.copyWith(
          attempts: {
            ...setup.attempts,
            kind: available.map((row) => worldId(kind, row)).toList(),
          },
        );
        await WorldSetupStore.saveOwned(setup);
        _current(actor);
        try {
          id = await api.create(kind, setup);
        } on DioException catch (error) {
          // These existing routes reject validation/auth/conflicts before a write.
          if ([400, 401, 403, 409, 422].contains(error.response?.statusCode)) {
            setup = setup.copyWith(attempts: {...setup.attempts}..remove(kind));
            await WorldSetupStore.saveOwned(setup);
          }
          rethrow;
        }
      }
      // Retain an acknowledged receipt for A even if signout occurred in flight.
      setup = setup.copyWith(
        createdIds: {...setup.createdIds, kind: id},
        attempts: {...setup.attempts}..remove(kind),
      );
      await WorldSetupStore.saveOwned(setup);
      _current(actor);
    }
    final landing = WorldLanding(
      setup.createdIds['workspace']!,
      setup.createdIds['inventory']!,
      setup.createdIds['organization'],
    );
    await WorldSetupStore.saveLanding(actor, landing);
    _current(actor);
    await LastPlaceStore(actor).save(
      LastPlace.workspace(landing.workspaceId),
      organizationId: landing.organizationId,
      isCurrent: () => api.accountId == actor,
    );
    _current(actor);
    await WorldSetupStore.discard(actor);
    return landing;
  }
}
