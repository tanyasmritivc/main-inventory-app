import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SpaceIconStorage {
  Future<String?> read(String key);
  Future<bool> write(String key, String value);
}

class DeviceSpaceIconStorage implements SpaceIconStorage {
  @override
  Future<String?> read(String key) async {
    final value = (await SharedPreferences.getInstance()).get(key);
    return value is String ? value : null;
  }

  @override
  Future<bool> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}

/// Personal device preferences, not a change to a shared Space's data.
class SpaceIconPreferences extends ChangeNotifier {
  SpaceIconPreferences({SpaceIconStorage? storage})
    : _storage = storage ?? DeviceSpaceIconStorage();

  static final instance = SpaceIconPreferences();
  final SpaceIconStorage _storage;
  String? lastChangedKey;

  static String keyFor({
    required String accountId,
    required String namespace,
    required String id,
  }) =>
      'findez.space-icon.v1:${Uri.encodeComponent(accountId)}:'
      '${Uri.encodeComponent(namespace)}:${Uri.encodeComponent(id)}';

  Future<String?> read(String key) => _storage.read(key);

  Future<void> save(String key, String? iconId) async {
    if (!await _storage.write(key, iconId ?? 'automatic')) {
      throw StateError('Space icon save was not confirmed');
    }
    lastChangedKey = key;
    notifyListeners();
  }
}

/// A stable, account-bound preference for one Space or legacy shared Space.
class SpaceIconController extends ChangeNotifier {
  SpaceIconController({
    required this.preferences,
    required this.accountId,
    required this.namespace,
    required this.id,
    required this.validIconIds,
  }) {
    preferences.addListener(_preferenceChanged);
  }

  final SpaceIconPreferences preferences;
  final String? Function() accountId;
  final String namespace;
  final String id;
  final Set<String> validIconIds;
  String? _actor;
  String? _selectedIconId;
  String? _error;
  bool _loaded = false;
  bool _saving = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _loadFuture;

  String? get actor => _actor;
  String? get selectedIconId => _selectedIconId;
  String? get error => _error;
  bool get loaded => _loaded;
  bool get saving => _saving;
  bool get accountIsCurrent => _actor != null && _actor == accountId();
  bool get canSave => !_disposed && _loaded && !_saving && accountIsCurrent;

  String? get _key => _actor == null
      ? null
      : SpaceIconPreferences.keyFor(
          accountId: _actor!,
          namespace: namespace,
          id: id,
        );

  void _preferenceChanged() {
    if (!_disposed && !_saving && preferences.lastChangedKey == _key) {
      load(force: true);
    }
  }

  Future<void> load({bool force = false}) {
    if (_disposed) return Future.value();
    final actor = accountId();
    if (_actor != actor) {
      _generation++;
      _actor = actor;
      _selectedIconId = null;
      _error = null;
      _loaded = false;
      _saving = false;
      _loadFuture = null;
      force = true;
      notifyListeners();
    }
    if (!force && _loaded) return Future.value();
    if (!force && _loadFuture != null) return _loadFuture!;
    final generation = ++_generation;
    final key = _key;
    _loaded = false;
    _error = null;
    _loadFuture = _read(key, actor, generation);
    return _loadFuture!;
  }

  Future<void> _read(String? key, String? actor, int generation) async {
    try {
      final value = key == null ? null : await preferences.read(key);
      if (!_current(actor, generation)) return;
      _selectedIconId = validIconIds.contains(value) ? value : null;
      _loaded = true;
    } catch (_) {
      if (!_current(actor, generation)) return;
      _error = 'Could not load this Space icon. Please try again.';
    } finally {
      if (_current(actor, generation)) {
        _loadFuture = null;
        notifyListeners();
      }
    }
  }

  bool _current(String? actor, int generation) =>
      !_disposed &&
      _actor == actor &&
      accountId() == actor &&
      _generation == generation;

  Future<bool> setIcon(String? iconId) async {
    if (iconId != null && !validIconIds.contains(iconId)) return false;
    final intendedActor = accountId();
    await load();
    if (!canSave || _actor != intendedActor || id.trim().isEmpty) return false;
    final actor = _actor;
    final key = _key!;
    final generation = _generation;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await preferences.save(key, iconId);
      if (!_current(actor, generation)) return false;
      _selectedIconId = iconId;
      return true;
    } catch (_) {
      if (_current(actor, generation)) {
        _error = 'Could not save this Space icon. Please try again.';
      }
      return false;
    } finally {
      if (_current(actor, generation)) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    preferences.removeListener(_preferenceChanged);
    super.dispose();
  }
}
