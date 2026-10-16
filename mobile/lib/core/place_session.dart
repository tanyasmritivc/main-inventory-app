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
      await store.save(current, isCurrent: () => _current(generation));
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

  Future<void> refresh() => select(current);
  String? takeNotice() {
    final value = notice;
    notice = null;
    return value;
  }

  Future<void> signOut() {
    ++_generation;
    data = null;
    return store.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
