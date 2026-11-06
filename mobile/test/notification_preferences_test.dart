import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/push_notifications.dart';
import 'package:mobile/core/ui/native_presentation.dart';
import 'package:mobile/features/notifications/notification_preferences.dart';
import 'package:mobile/features/notifications/notifications_page.dart';

class PreferenceApi extends ApiClient {
  PreferenceApi() : super(baseUrl: 'https://api.test');
  String? user = 'account-a';
  @override
  String? get accountId => user;
  int registrations = 0;
  bool fail = false;
  Completer<Map<String, dynamic>>? pending;
  Map<String, dynamic> saved = {
    'revision': 0,
    'push_enabled': false,
    'in_app_enabled': true,
    'quiet_enabled': true,
    'quiet_start': 1260,
    'quiet_end': 480,
    'timezone': 'America/Los_Angeles',
    'inventory_alerts': true,
    'capture_reminders': true,
    'show_details': false,
    'paused_until': null,
  };
  List<Map<String, dynamic>> changes = [];
  List<Map<String, dynamic>> rows = [
    {
      'id': '10000000-0000-0000-0000-000000000001',
      'action': 'personalization',
      'is_read': false,
      'display_text': 'An inventory item needs your attention.',
      'created_at': '2026-11-06T09:00:00Z',
    },
  ];
  @override
  Future<Map<String, dynamic>> getNotificationPreferences() async =>
      pending == null
      ? {
          'preferences': Map<String, dynamic>.from(saved),
          'timezones': ['America/Los_Angeles', 'America/New_York', 'UTC'],
        }
      : await pending!.future;
  @override
  Future<Map<String, dynamic>> updateNotificationPreferences(
    int revision,
    Map<String, dynamic> values,
  ) async {
    if (fail) throw const FormatException('Could not save preferences');
    expect(revision, saved['revision']);
    changes.add(values);
    saved = {...saved, ...values, 'revision': revision + 1};
    return {'preferences': Map<String, dynamic>.from(saved)};
  }

  @override
  Future<void> registerPushDevice({
    required String token,
    required String environment,
  }) async {
    registrations++;
  }

  @override
  Future<void> unregisterPushDevice(String token) async {}
  @override
  Future<Map<String, dynamic>> getNotifications() async => {
    'notifications': rows,
    'unread_count': rows.length,
    'policy_version': 1,
  };
  @override
  Future<void> dismissNotification(String id) async {
    rows = rows.where((r) => r['id'] != id).toList();
  }

  @override
  Future<void> clearNotifications() async {
    rows = [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.findez.app/push');
  late List<String> calls;
  late String permission;
  setUp(() {
    debugNativePresentationOverride = false;
    calls = [];
    permission = 'notDetermined';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'authorizationStatus') return permission;
          if (call.method == 'requestPermission') {
            permission = 'authorized';
            return true;
          }
          if (call.method == 'register') {
            return {'deviceToken': 'a' * 64, 'environment': 'sandbox'};
          }
          return null;
        });
  });
  tearDown(() async {
    await PushNotifications.stop();
    debugNativePresentationOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'reading preferences is passive; explicit phone toggle requests consent',
    (tester) async {
      final api = PreferenceApi();
      final c = NotificationPreferencesController(api);
      expect(c.model()['load'], isTrue);
      await c.perform('load', null);
      expect(c.model()['load'], isFalse);
      expect(calls, isNot(contains('requestPermission')));
      await c.perform('toggle:push_enabled', true);
      expect(api.saved['push_enabled'], isTrue);
      expect(calls.where((s) => s == 'requestPermission'), hasLength(1));
      expect(api.registrations, 1);
      expect(c.permission, 'authorized');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'denied permission stays separate from app opt-in and never reprompts',
    (tester) async {
      permission = 'denied';
      final api = PreferenceApi();
      final c = NotificationPreferencesController(api);
      await c.perform('load', null);
      await c.perform('toggle:push_enabled', true);
      expect(api.saved['push_enabled'], isTrue);
      expect(c.permission, 'denied');
      expect(calls, isNot(contains('requestPermission')));
      expect(api.registrations, 0);
      expect(c.model().toString(), contains('Off in iPhone Settings'));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  test('failed save keeps confirmed state and reports error', () async {
    final api = PreferenceApi();
    final c = NotificationPreferencesController(api);
    await c.perform('load', null);
    api.fail = true;
    await c.perform('toggle:in_app_enabled', false);
    expect(c.preferences!['in_app_enabled'], isTrue);
    expect(c.error, isNotNull);
  });

  test('account switch ignores late load and prevents writes', () async {
    final api = PreferenceApi()..pending = Completer();
    final c = NotificationPreferencesController(api);
    final future = c.perform('load', null);
    api.user = 'account-b';
    api.pending!.complete({'preferences': api.saved});
    await future;
    expect(c.preferences, isNull);
    await c.perform('toggle:show_details', true);
    expect(api.changes, isEmpty);
  });

  test(
    'timezones quiet hours and pause are bounded explicit actions',
    () async {
      final api = PreferenceApi();
      final c = NotificationPreferencesController(api);
      await c.perform('load', null);
      await c.perform('timezone:America/New_York', null);
      await c.perform('quiet_end:600', null);
      await c.perform('pause:7', null);
      expect(api.saved['timezone'], 'America/New_York');
      expect(api.saved['quiet_end'], 600);
      expect(api.saved['paused_until'], isNotNull);
      await c.perform('pause:0', null);
      expect(api.saved['paused_until'], isNull);
      final count = api.changes.length;
      await c.perform('toggle:weekly_recap', true);
      await c.perform('quiet_start:1440', null);
      await c.perform('timezone:Mars/Unknown', null);
      await c.perform('pause:8', null);
      expect(api.changes, hasLength(count));
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'preferences fit ${brightness.name} large text without changing Settings',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showNotificationPreferences(context, PreferenceApi()),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Notification preferences'), findsOneWidget);
        expect(find.text('Phone alerts'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'policy inbox dismisses alert and exposes preferences without legacy test button',
    (tester) async {
      final api = PreferenceApi();
      await tester.pumpWidget(MaterialApp(home: NotificationsPage(api: api)));
      await tester.pumpAndSettle();
      expect(
        find.text('An inventory item needs your attention.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Dismiss notification'));
      await tester.pumpAndSettle();
      expect(find.text('All caught up'), findsOneWidget);
      expect(api.rows, isEmpty);
      await tester.tap(find.byTooltip('Notification options'));
      await tester.pumpAndSettle();
      expect(find.text('Notification preferences'), findsOneWidget);
      expect(find.text('Send test notification'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
