import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/push_notifications.dart';

class _PushApi extends ApiClient {
  _PushApi() : super(baseUrl: 'https://api.test');
  String? user = 'account-a';
  int writes = 0;
  int removals = 0;
  @override
  Future<void> unregisterPushDevice(String token) async {
    removals++;
  }

  @override
  String? get accountId => user;
  @override
  Future<void> registerPushDevice({
    required String token,
    required String environment,
  }) async {
    writes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.findez.app/push');
  late List<String> calls;
  late String status;
  Completer<Map<String, dynamic>>? registration;
  Completer<bool>? permission;
  bool granted = true;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls = [];
    status = 'notDetermined';
    registration = null;
    permission = null;
    granted = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'authorizationStatus') return status;
          if (call.method == 'requestPermission') {
            final result = await (permission?.future ?? Future.value(granted));
            status = result ? 'authorized' : 'denied';
            return result;
          }
          if (call.method == 'register') {
            return registration?.future ??
                {'deviceToken': 'a' * 64, 'environment': 'sandbox'};
          }
          return null;
        });
  });
  tearDown(() async {
    await PushNotifications.stop();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'undetermined permission asks iOS without registering an account',
    () async {
      expect(await PushNotifications.requestPermissionIfNeeded(), isTrue);
      expect(calls, ['authorizationStatus', 'requestPermission']);
      expect(await PushNotifications.requestPermissionIfNeeded(), isTrue);
      expect(calls.where((value) => value == 'requestPermission').length, 1);
    },
  );
  test('denial is retained and never prompts again', () async {
    granted = false;
    expect(await PushNotifications.requestPermissionIfNeeded(), isFalse);
    expect(await PushNotifications.requestPermissionIfNeeded(), isFalse);
    expect(calls.where((value) => value == 'requestPermission').length, 1);
  });
  test('existing OS decisions are respected', () async {
    for (final value in ['denied', 'authorized', 'provisional', 'ephemeral']) {
      status = value;
      expect(
        await PushNotifications.requestPermissionIfNeeded(),
        value != 'denied',
      );
    }
    expect(calls.where((value) => value != 'authorizationStatus'), isEmpty);
  });
  test(
    'concurrent launch requests share one native permission result',
    () async {
      permission = Completer<bool>();
      final first = PushNotifications.requestPermissionIfNeeded();
      final second = PushNotifications.requestPermissionIfNeeded();
      await Future<void>.delayed(Duration.zero);
      expect(calls.where((value) => value == 'requestPermission').length, 1);
      permission!.complete(true);
      expect(await first, isTrue);
      expect(await second, isTrue);
    },
  );
  test('native permission failure does not prevent a later retry', () async {
    permission = Completer<bool>();
    final failed = PushNotifications.requestPermissionIfNeeded();
    final expectation = expectLater(failed, throwsA(isA<PlatformException>()));
    await Future<void>.delayed(Duration.zero);
    permission!.completeError(PlatformException(code: 'permission_error'));
    await expectation;
    permission = null;
    expect(await PushNotifications.requestPermissionIfNeeded(), isTrue);
  });
  test('other platforms do not invoke iOS permission methods', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await PushNotifications.requestPermissionIfNeeded(), isFalse);
    expect(calls, isEmpty);
  });
  test('shell reconnects only existing notification permission', () async {
    final api = _PushApi();
    for (final value in ['notDetermined', 'denied']) {
      status = value;
      expect(await PushNotifications.registerIfAuthorized(api), isFalse);
    }
    expect(calls.where((call) => call == 'register'), isEmpty);
    status = 'authorized';
    expect(await PushNotifications.registerIfAuthorized(api), isTrue);
    expect(api.writes, 1);
  });
  test('concurrent registration cannot overwrite a native result', () async {
    final api = _PushApi();
    registration = Completer<Map<String, dynamic>>();
    final first = PushNotifications.register(api);
    final second = PushNotifications.register(api);
    await Future<void>.delayed(Duration.zero);
    registration!.complete({'deviceToken': 'a' * 64});
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(calls.where((call) => call == 'register').length, 1);
    expect(api.writes, 1);
  });
  test('sign out deactivates the currently registered server token', () async {
    final api = _PushApi();
    expect(await PushNotifications.register(api), isTrue);
    await PushNotifications.stop();
    expect(api.removals, 1);
  });
  test(
    'an account change while awaiting a device token prevents its write',
    () async {
      final api = _PushApi();
      registration = Completer<Map<String, dynamic>>();
      final result = PushNotifications.register(api);
      api.user = 'account-b';
      registration!.complete({'deviceToken': 'a' * 64});
      expect(await result, isFalse);
      expect(api.writes, 0);
    },
  );
  test(
    'sign out stops OS delivery and invalidates pending registration',
    () async {
      final api = _PushApi();
      registration = Completer<Map<String, dynamic>>();
      final result = PushNotifications.register(api);
      await PushNotifications.stop();
      registration!.complete({'deviceToken': 'a' * 64});
      expect(await result, isFalse);
      expect(api.writes, 0);
      expect(calls, contains('unregister'));
    },
  );
}
