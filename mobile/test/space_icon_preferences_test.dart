import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/space_icon_preferences.dart';
import 'package:mobile/features/inventory/space_icon_picker.dart';

class _Storage implements SpaceIconStorage {
  final values = <String, String>{};
  final writes = <String>[];
  bool readError = false;
  bool writeError = false;
  bool confirmed = true;
  Completer<String?>? pendingRead;
  Completer<bool>? pendingWrite;

  @override
  Future<String?> read(String key) async {
    if (readError) throw StateError('SECRET read details');
    if (pendingRead != null) return pendingRead!.future;
    return values[key];
  }

  @override
  Future<bool> write(String key, String value) async {
    writes.add(key);
    if (writeError) throw StateError('SECRET write details');
    final success = pendingWrite == null
        ? confirmed
        : await pendingWrite!.future;
    if (success) values[key] = value;
    return success;
  }
}

String _key(
  String actor, {
  String namespace = 'space',
  String id = 'stable-id',
}) =>
    SpaceIconPreferences.keyFor(accountId: actor, namespace: namespace, id: id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  late SpaceIconPreferences preferences;
  String? actor;
  final ids = spaceIconOptions.map((option) => option.id).toSet();
  SpaceIconController controller({
    String namespace = 'space',
    String id = 'stable-id',
  }) => SpaceIconController(
    preferences: preferences,
    accountId: () => actor,
    namespace: namespace,
    id: id,
    validIconIds: ids,
  );

  setUp(() {
    actor = 'account-a';
    storage = _Storage();
    preferences = SpaceIconPreferences(storage: storage);
  });
  tearDown(() => preferences.dispose());

  test(
    'named choices round-trip, reset and survive new controller/rename',
    () async {
      expect(ids.length, spaceIconOptions.length);
      for (final option in spaceIconOptions) {
        final first = controller();
        expect(await first.setIcon(option.id), isTrue);
        expect(storage.values[_key('account-a')], option.id);
        first.dispose();
        // The Space name is intentionally absent from the storage identity.
        final reopened = controller();
        await reopened.load();
        expect(reopened.selectedIconId, option.id);
        expect(await reopened.setIcon(null), isTrue);
        expect(reopened.selectedIconId, isNull);
        reopened.dispose();
      }
      final reset = controller();
      await reset.load();
      expect(reset.selectedIconId, isNull);
      reset.dispose();
    },
  );

  test(
    'device storage is durable and ignores non-string or unknown values',
    () async {
      SharedPreferences.setMockInitialValues({_key('account-a'): 123});
      final device = SpaceIconPreferences();
      final first = SpaceIconController(
        preferences: device,
        accountId: () => actor,
        namespace: 'space',
        id: 'stable-id',
        validIconIds: ids,
      );
      await first.load();
      expect(first.selectedIconId, isNull);
      expect(await first.setIcon('tools'), isTrue);
      first.dispose();
      final second = SpaceIconController(
        preferences: SpaceIconPreferences(),
        accountId: () => actor,
        namespace: 'space',
        id: 'stable-id',
        validIconIds: ids,
      );
      await second.load();
      expect(second.selectedIconId, 'tools');
      second.dispose();
      second.preferences.dispose();
      device.dispose();
      storage.values[_key('account-a')] = 'retired-future-icon';
      final invalid = controller();
      await invalid.load();
      expect(invalid.selectedIconId, isNull);
      expect(await invalid.setIcon('arbitrary-font-code'), isFalse);
      expect(storage.writes, isEmpty);
      invalid.dispose();
    },
  );

  test('accounts, Space IDs and legacy share IDs cannot collide', () async {
    final personal = controller(), joined = controller(namespace: 'share');
    final other = controller(id: 'other-id');
    await personal.setIcon('home');
    await joined.setIcon('people');
    await other.setIcon('books');
    expect(storage.values.length, 3);
    actor = 'account-b';
    await personal.load();
    expect(personal.selectedIconId, isNull);
    await personal.setIcon('gear');
    expect(storage.values[_key('account-a')], 'home');
    expect(storage.values[_key('account-b')], 'gear');
    actor = null;
    await personal.load();
    expect(personal.selectedIconId, isNull);
    expect(await personal.setIcon('star'), isFalse);
    actor = 'account-a';
    await personal.load();
    expect(personal.selectedIconId, 'home');
    expect(_key('a:b', id: 'c'), isNot(_key('a', id: 'b:c')));
    personal.dispose();
    joined.dispose();
    other.dispose();
  });

  test(
    'a failed read cannot overwrite an unread choice; retry restores it',
    () async {
      storage.values[_key('account-a')] = 'tools';
      storage.readError = true;
      final c = controller();
      await c.load();
      expect(c.loaded, isFalse);
      expect(c.error, contains('Could not load'));
      expect(c.error, isNot(contains('SECRET')));
      expect(await c.setIcon(null), isFalse);
      expect(storage.writes, isEmpty);
      storage.readError = false;
      await c.load(force: true);
      expect(c.selectedIconId, 'tools');
      expect(c.error, isNull);
      c.dispose();
    },
  );

  for (final throwing in [false, true]) {
    test(
      'unconfirmed/throwing write $throwing preserves the previous icon',
      () async {
        final c = controller();
        await c.setIcon('home');
        storage.confirmed = false;
        storage.writeError = throwing;
        expect(await c.setIcon('tools'), isFalse);
        expect(c.selectedIconId, 'home');
        expect(c.error, contains('Could not save'));
        expect(c.error, isNot(contains('SECRET')));
        expect(c.saving, isFalse);
        storage.confirmed = true;
        storage.writeError = false;
        expect(await c.setIcon('tools'), isTrue);
        expect(c.error, isNull);
        c.dispose();
      },
    );
  }

  test(
    'duplicate pending saves do not publish early or create a second write',
    () async {
      final c = controller();
      await c.load();
      storage.pendingWrite = Completer<bool>();
      final save = c.setIcon('tools');
      await Future<void>.delayed(Duration.zero);
      expect(c.saving, isTrue);
      expect(c.selectedIconId, isNull);
      expect(await c.setIcon('gear'), isFalse);
      expect(storage.writes.length, 1);
      storage.pendingWrite!.complete(true);
      expect(await save, isTrue);
      expect(c.selectedIconId, 'tools');
      c.dispose();
    },
  );

  test('late reads and writes do not cross an account boundary', () async {
    final c = controller();
    storage.pendingRead = Completer<String?>();
    final pendingRead = c.load();
    actor = 'account-b';
    final originalRead = storage.pendingRead!;
    storage.pendingRead = null;
    await c.load();
    originalRead.complete('home');
    await pendingRead;
    expect(c.selectedIconId, isNull);
    storage.pendingWrite = Completer<bool>();
    final save = c.setIcon('gear');
    await Future<void>.delayed(Duration.zero);
    actor = 'account-a';
    await c.load();
    storage.pendingWrite!.complete(true);
    expect(await save, isFalse);
    expect(storage.writes, [_key('account-b')]);
    expect(storage.values[_key('account-a')], isNull);
    expect(c.selectedIconId, isNull);
    expect(c.saving, isFalse);
    c.dispose();
  });

  test('a save queued behind a read retains the actor that chose it', () async {
    final c = controller();
    storage.pendingRead = Completer<String?>();
    final save = c.setIcon('home');
    actor = 'account-b';
    final oldRead = storage.pendingRead!;
    storage.pendingRead = null;
    await c.load();
    oldRead.complete(null);
    expect(await save, isFalse);
    expect(storage.writes, isEmpty);
    c.dispose();
  });

  test(
    'confirmed changes update another live view of the same Space',
    () async {
      final first = controller(),
          teamView = controller(),
          other = controller(id: 'other');
      await first.load();
      await teamView.load();
      await other.load();
      await first.setIcon('gear');
      await Future<void>.delayed(Duration.zero);
      expect(teamView.selectedIconId, 'gear');
      expect(other.selectedIconId, isNull);
      first.dispose();
      teamView.dispose();
      other.dispose();
    },
  );

  test(
    'disposal rejects late reads, notifications and further saves',
    () async {
      final c = controller();
      storage.pendingRead = Completer<String?>();
      final read = c.load();
      c.dispose();
      storage.pendingRead!.complete('home');
      await read;
      expect(await c.setIcon('home'), isFalse);
      expect(storage.writes, isEmpty);
      final pending = controller();
      storage.pendingRead = null;
      await pending.load();
      storage.pendingWrite = Completer<bool>();
      final save = pending.setIcon('tools');
      await Future<void>.delayed(Duration.zero);
      pending.dispose();
      storage.pendingWrite!.complete(true);
      expect(await save, isFalse);
    },
  );
}
