import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'last_place.dart';

List<Map<String, dynamic>> placeRows(Object? value) => (value as List? ?? [])
    .map((r) => Map<String, dynamic>.from(r as Map))
    .toList();

class PlaceData {
  const PlaceData(this.place, this.resource, this.inventories, this.members);
  final LastPlace place;
  final Map<String, dynamic> resource;
  final List<Map<String, dynamic>> inventories;
  final List<Map<String, dynamic>>? members;
  String get name => resource['name'].toString();
  String? get organizationId => resource['organization_id'] as String?;
  String? get organizationName => resource['organization_name'] as String?;
  bool get canCreate =>
      place.isPersonal || ['owner', 'mentor'].contains(resource['role']);
}

class PlaceDirectory {
  const PlaceDirectory(this.organizations, this.workspaces);
  final List<Map<String, dynamic>> organizations;
  final List<PlaceData> workspaces;
}

class PlaceRepository {
  PlaceRepository(this.api);
  final ApiClient api;
  Future<PlaceData> load(LastPlace place) async {
    final base = '/inventory-workspaces/${Uri.encodeComponent(place.id)}';
    final Map<String, dynamic> overview = place.isPersonal
        ? {
            'workspace': {
              'workspace_id': 'personal',
              'name': 'Personal',
              'role': 'owner',
            },
          }
        : await api.collaboration('$base/overview');
    final resource = Map<String, dynamic>.from(overview['workspace'] as Map);
    if (resource['workspace_id'] != place.id) {
      throw const FormatException(
        'This workspace changed. Refresh and choose again.',
      );
    }
    final inventories = <Map<String, dynamic>>[];
    int? offset = 0;
    final seen = <String>{};
    do {
      final data = await api.collaboration(
        '$base/directory',
        query: {'offset': offset},
      );
      for (final row in placeRows(data['inventories'])) {
        if (row['workspace_id'] != place.id ||
            !seen.add(row['inventory_id'].toString())) {
          throw const FormatException(
            'This inventory directory changed. Refresh and choose again.',
          );
        }
        inventories.add(row);
      }
      final next = data['next_offset'] as int?;
      if (next != null && next <= offset!) {
        throw const FormatException('The directory could not be loaded.');
      }
      offset = next;
    } while (offset != null);
    return PlaceData(
      place,
      resource,
      inventories,
      overview['members'] == null
          ? null
          : placeRows(
              overview['members'],
            ).where((m) => m['role'] != 'none').toList(),
    );
  }

  Future<PlaceDirectory> directory() async {
    final lists = await Future.wait([
      api.collaboration('/organizations'),
      api.collaboration('/inventory-workspaces'),
    ]);
    final ids = placeRows(lists[1]['workspaces'])
        .where((w) => w['workspace_id'] != 'personal')
        .map((w) => w['workspace_id'].toString())
        .toSet()
        .toList();
    final workspaces = <PlaceData>[];
    // The list API omits parent IDs. Authorized overviews supply actual parents.
    for (var i = 0; i < ids.length; i += 4) {
      final batch = ids.skip(i).take(4).map((id) async {
        try {
          return await load(LastPlace.workspace(id));
        } on DioException catch (e) {
          if ([403, 404].contains(e.response?.statusCode)) return null;
          rethrow;
        }
      });
      workspaces.addAll((await Future.wait(batch)).whereType<PlaceData>());
    }
    return PlaceDirectory(placeRows(lists[0]['organizations']), workspaces);
  }

  Future<List<Map<String, dynamic>>> independentWorkspaces() async {
    final result = await api.collaboration('/inventory-workspaces');
    final ids = placeRows(result['workspaces'])
        .map((row) => row['workspace_id'].toString())
        .where((id) => id != 'personal')
        .toSet()
        .toList();
    final choices = <Map<String, dynamic>>[];
    for (var i = 0; i < ids.length; i += 4) {
      final batch = await Future.wait(
        ids.skip(i).take(4).map((id) async {
          try {
            final result = await api.collaboration(
              '/inventory-workspaces/${Uri.encodeComponent(id)}/overview',
            );
            final workspace = Map<String, dynamic>.from(
              result['workspace'] as Map,
            );
            if (workspace['workspace_id'] != id) {
              throw const FormatException(
                'Workspace changed. Refresh and choose again.',
              );
            }
            return workspace['organization_id'] == null ? workspace : null;
          } on DioException catch (e) {
            if ([403, 404, 410].contains(e.response?.statusCode)) return null;
            rethrow;
          }
        }),
      );
      choices.addAll(batch.whereType<Map<String, dynamic>>());
    }
    return choices;
  }
}

/// The working place is independent of a temporarily opened inventory.
class PlaceSession extends ChangeNotifier {
  PlaceSession(ApiClient source, this.accountId)
    : api = ApiClient.forAccount(source, accountId),
      _source = source,
      store = LastPlaceStore(accountId) {
    repository = PlaceRepository(api);
  }
  final ApiClient _source, api;
  final String accountId;
  final LastPlaceStore store;
  late final PlaceRepository repository;
  LastPlace current = const LastPlace.personal();
  PlaceData? data;
  Object? error;
  String? notice;
  bool loading = true, _disposed = false;
  // Navigation scope is independent of a child workspace, including empty orgs.
  String? organizationId;
  Map<String, dynamic>? organization;
  List<Map<String, dynamic>> workspaces = [];
  bool navigationReady = false;
  String get organizationName =>
      organization?['name']?.toString() ??
      data?.organizationName ??
      (organizationId == null ? 'Personal' : 'Organization');
  bool get canCreateWorkspace =>
      organizationId == null ||
      ['owner', 'admin'].contains(organization?['role']);
  int _generation = 0;
  bool _current(int generation) =>
      !_disposed && generation == _generation && _source.accountId == accountId;

  Future<void> restore({LastPlace? override}) async {
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final place = override ?? await store.read();
      if (_current(generation)) await select(place);
    } catch (e) {
      if (_current(generation)) {
        error = e;
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> select(LastPlace place) async {
    final generation = ++_generation;
    current = place;
    navigationReady = false;
    data = null;
    loading = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      PlaceData next;
      try {
        next = await repository.load(place);
      } on DioException catch (e) {
        if (place.isPersonal ||
            ![403, 404, 410].contains(e.response?.statusCode)) {
          rethrow;
        }
        next = await repository.load(const LastPlace.personal());
        if (!_current(generation)) return;
        notice = 'That workspace is no longer available';
      }
      if (!_current(generation)) return;
      current = next.place;
      data = next;
      organizationId = next.organizationId;
      organization = next.organizationId == null
          ? null
          : {
              'organization_id': next.organizationId,
              'name': next.organizationName,
            };
      await store.save(
        current,
        organizationId: organizationId,
        isCurrent: () => _current(generation),
      );
      if (!_current(generation)) return;
      loading = false;
      notifyListeners();
    } catch (e) {
      if (_current(generation)) {
        error = e;
        loading = false;
        notifyListeners();
      }
    }
  }

  /// Explicit links/onboarding may establish a new scope; workspace controls may not.
  Future<void> restoreNavigation({LastPlace? override}) async {
    if (override != null) {
      await select(override);
      if (error == null && !_disposed) await initializeNavigation();
      return;
    }
    final generation = ++_generation;
    try {
      final hasSavedPlace = await store.hasSavedPlace();
      final savedOrganization = await store.readOrganization();
      final place = await store.read();
      if (!_current(generation)) return;
      if (savedOrganization != null) {
        await selectOrganization(savedOrganization, preferred: place);
      } else if (!hasSavedPlace) {
        // A fresh sign-in has no local destination. Prefer an organization the
        // account owns; selectOrganization rechecks current server access.
        final result = await api.collaboration('/organizations');
        if (!_current(generation)) return;
        final owned = placeRows(result['organizations'])
            .where(
              (row) =>
                  row['owner_user_id'] == accountId || row['role'] == 'owner',
            )
            .toList();
        owned.sort(
          (a, b) => (b['created_at']?.toString() ?? '').compareTo(
            a['created_at']?.toString() ?? '',
          ),
        );
        if (owned.isNotEmpty) {
          await selectOrganization(owned.first['organization_id'] as String);
        } else {
          await select(place);
          if (error == null && !_disposed) await initializeNavigation();
        }
      } else {
        await select(place);
        if (error == null && !_disposed) await initializeNavigation();
      }
    } catch (reason) {
      if (_current(generation)) {
        data = null;
        error = reason;
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> initializeNavigation() async {
    if (navigationReady || loading || error != null) return;
    await selectOrganization(data?.organizationId, preferred: current);
  }

  Future<void> selectOrganization(
    String? id, {
    LastPlace? preferred,
    bool quiet = false,
  }) async {
    final generation = ++_generation;
    final oldOrganization = organizationId;
    final candidate = preferred ?? (oldOrganization == id ? current : null);
    organizationId = id;
    if (oldOrganization != id) organization = null;
    navigationReady = true;
    if (!quiet) {
      workspaces = [];
      data = null;
      error = null;
      loading = true;
      notifyListeners();
    }
    try {
      Map<String, dynamic>? nextOrganization;
      List<Map<String, dynamic>> choices;
      if (id != null) {
        final result = await api.collaboration(
          '/organizations/${Uri.encodeComponent(id)}',
        );
        nextOrganization = Map<String, dynamic>.from(
          result['organization'] as Map,
        );
        if (nextOrganization['organization_id'] != id) {
          throw const FormatException('Organization changed. Choose again.');
        }
        choices = placeRows(result['workspaces'])
            .map(
              (row) => {
                ...row,
                'workspace_id': row['team_id'] ?? row['workspace_id'],
              },
            )
            .where((row) => row['can_open'] != false)
            .toList();
      } else {
        // Existing independent workspaces stay in the private Personal scope.
        choices = [
          {'workspace_id': 'personal', 'name': 'Personal'},
          ...await repository.independentWorkspaces(),
        ];
      }
      final seen = <String>{};
      for (final row in choices) {
        final childId = row['workspace_id'];
        if (childId is! String ||
            childId.isEmpty ||
            !seen.add(childId) ||
            (id != null && childId == 'personal') ||
            (row['organization_id'] != null && row['organization_id'] != id)) {
          throw const FormatException(
            'This organization directory changed. Refresh and choose again.',
          );
        }
      }
      choices.sort(
        (a, b) => a['name'].toString().toLowerCase().compareTo(
          b['name'].toString().toLowerCase(),
        ),
      );
      final chosen =
          choices
              .where((row) => row['workspace_id'] == candidate?.id)
              .firstOrNull ??
          choices.firstOrNull;
      PlaceData? next;
      if (chosen != null) {
        final childId = chosen['workspace_id'] as String;
        next = await repository.load(
          childId == 'personal'
              ? const LastPlace.personal()
              : LastPlace.workspace(childId),
        );
        if (next.organizationId != id) {
          throw const FormatException(
            'This workspace belongs to another organization. Refresh and choose again.',
          );
        }
      }
      if (!_current(generation)) return;
      error = null;
      organization = nextOrganization;
      workspaces = choices;
      data = next;
      current = next?.place ?? const LastPlace.personal();
      await store.save(
        current,
        organizationId: id,
        isCurrent: () => _current(generation),
      );
      if (!_current(generation)) return;
      loading = false;
      notifyListeners();
    } catch (reason) {
      if (!_current(generation)) return;
      if (reason is DioException &&
          [401, 403, 404, 410].contains(reason.response?.statusCode)) {
        data = null;
        workspaces = [];
        organization = null;
      }
      error = reason;
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectWorkspace(String id) async {
    if (!navigationReady || !workspaces.any((w) => w['workspace_id'] == id)) {
      throw const FormatException('Choose a workspace in this organization.');
    }
    await selectOrganization(
      organizationId,
      preferred: id == 'personal'
          ? const LastPlace.personal()
          : LastPlace.workspace(id),
    );
  }

  Future<void> refresh({bool quiet = false}) => navigationReady
      ? selectOrganization(organizationId, preferred: current, quiet: quiet)
      : select(current);
  String? takeNotice() {
    final value = notice;
    notice = null;
    return value;
  }

  Future<void> signOut() {
    ++_generation;
    data = null;
    organization = null;
    organizationId = null;
    workspaces = [];
    return store.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
