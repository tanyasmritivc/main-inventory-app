import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/launch_notification_permission.dart';
import 'package:mobile/core/push_notifications.dart';
import 'package:mobile/features/announcements/announcement_controller.dart';
import 'package:mobile/features/announcements/announcement_host.dart';
import 'package:mobile/features/announcements/announcement_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/announcement_fixture.dart';

class _Api extends ApiClient {
  _Api() : super(baseUrl: 'https://api.test');
  String? user;
  int writes = 0;
  int claims = 0;
  @override
  Future<Map<String, dynamic>> collaboration(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async {
    if (path.endsWith('/claim')) {
      claims++;
      return {'campaign': welcomeCampaign, 'access': announcementAccess};
    }
    return {'saved': true};
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
    SharedPreferences.setMockInitialValues({});
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
    'launch never requests consent or registers an anonymous token',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(app());
      await tester.pump();
      expect(find.text('Welcome to FindEZ'), findsOneWidget);
      expect(calls, isEmpty);
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
      expect(calls, isNot(contains('requestPermission')));
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
    expect(calls, isNot(contains('requestPermission')));
    permission.complete(false);
    await tester.pumpAndSettle();
  });

  for (final allowed in [true, false]) {
    iosTestWidgets(
      'welcome waits for completed notification choice: $allowed',
      (tester) async {
        api.user = 'signed-in-account';
        final controller = AnnouncementController(
          api: api,
          accountId: api.user!,
          isCurrent: () => api.user != null,
          platform: 'ios',
        );
        addTearDown(controller.dispose);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [announcementRoutes],
            home: LaunchNotificationPermission(
              api: api,
              child: AnnouncementScope(
                controller: controller,
                child: AnnouncementGate(
                  isSafe: () => true,
                  onCapture: () {},
                  child: const Scaffold(body: Text('Home')),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        expect(
          calls.where((call) => call == 'requestPermission'),
          hasLength(1),
        );
        expect(api.claims, 0);
        expect(find.byType(AnnouncementSheet), findsNothing);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        permission.complete(allowed);
        await tester.pump();
        expect(find.byType(AnnouncementSheet), findsNothing);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnnouncementSheet), findsOneWidget);
        expect(api.claims, 1);
        expect(api.writes, allowed ? 1 : 0);
        await tester.ensureVisible(find.text('Got it'));
        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
        expect(find.byType(AnnouncementSheet), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  iosTestWidgets('allow connects an already signed-in account', (tester) async {
    api.user = 'test-account';
    status = 'authorized';
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
