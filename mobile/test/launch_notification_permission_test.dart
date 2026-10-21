import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/launch_notification_permission.dart';
import 'package:mobile/core/push_notifications.dart';

class _Api extends ApiClient {
  _Api() : super(baseUrl: 'https://api.test');
  String? user;
  int writes = 0;
  @override
  String? get accountId => user;
  @override
  Future<void> registerPushDevice({
    required String token,
    required String environment,
  }) async {
    writes++;
  }

  @override
  Future<void> unregisterPushDevice(String token) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.findez.app/push');
  late _Api api;
  late List<String> calls;
  late String status;
  late Completer<bool> permission;
  bool failPermission = false;

  void iosTestWidgets(
    String description,
    Future<void> Function(WidgetTester) callback,
  ) {
    testWidgets(description, (tester) async {
      permission = Completer<bool>();
      await callback(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  setUp(() {
    failPermission = false;
    api = _Api();
    calls = [];
    status = 'notDetermined';
    permission = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'authorizationStatus') return status;
          if (call.method == 'requestPermission') {
            if (failPermission) {
              throw PlatformException(code: 'permission_error');
            }
            final allowed = await permission.future;
            status = allowed ? 'authorized' : 'denied';
            return allowed;
          }
          if (call.method == 'register') {
            return {'deviceToken': 'a' * 64, 'environment': 'sandbox'};
          }
          return null;
        });
  });
  tearDown(() async {
    await PushNotifications.stop();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Widget app() => MaterialApp(
    home: LaunchNotificationPermission(
      api: api,
      child: const Scaffold(body: Text('Welcome to FindEZ')),
    ),
  );

  iosTestWidgets(
    'launch asks before sign-in without blocking onboarding or registering a token',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(app());
      await tester.pump();
      expect(find.text('Welcome to FindEZ'), findsOneWidget);
      expect(calls, ['authorizationStatus', 'requestPermission']);
      permission.complete(true);
      await tester.pumpAndSettle();
      expect(api.writes, 0);
      expect(calls, isNot(contains('register')));
    },
  );

  iosTestWidgets(
    'denial keeps onboarding usable and rebuild/resume do not ask again',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(app());
      await tester.pump();
      permission.complete(false);
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Welcome to FindEZ'), findsOneWidget);
      expect(calls.where((value) => value == 'requestPermission').length, 1);
      expect(api.writes, 0);
    },
  );

  iosTestWidgets('background launch waits until the app becomes active', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpWidget(app());
    await tester.pump();
    expect(calls, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(calls, contains('requestPermission'));
    permission.complete(false);
    await tester.pumpAndSettle();
  });

  iosTestWidgets('allow connects an already signed-in account', (tester) async {
    api.user = 'test-account';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(app());
    await tester.pump();
    permission.complete(true);
    await tester.pumpAndSettle();
    expect(api.writes, 1, reason: calls.toString());
    expect(calls.where((value) => value == 'register').length, 1);
  });

  iosTestWidgets('sign-out while the prompt is open prevents registration', (
    tester,
  ) async {
    api.user = 'test-account';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(app());
    await tester.pump();
    api.user = null;
    permission.complete(true);
    await tester.pumpAndSettle();
    expect(api.writes, 0);
    expect(calls, isNot(contains('register')));
  });

  iosTestWidgets(
    'disposing the launch gate prevents a late account registration',
    (tester) async {
      api.user = 'test-account';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(app());
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      permission.complete(true);
      await tester.pumpAndSettle();
      expect(api.writes, 0);
    },
  );

  iosTestWidgets('native failure leaves the app usable', (tester) async {
    failPermission = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.pumpAndSettle();
    expect(find.text('Welcome to FindEZ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
