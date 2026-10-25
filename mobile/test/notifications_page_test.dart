import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/notification_snapshot.dart';
import 'package:mobile/core/push_notifications.dart';
import 'package:mobile/features/notifications/notifications_page.dart';

class _InboxApi extends ApiClient {
  _InboxApi() : super(baseUrl: 'https://api.test');
  String user = 'account-a';
  bool failRead = false;
  bool failFetch = false;
  bool failTest = false;
  int tests = 0;
  @override
  Future<void> registerPushDevice({
    required String token,
    required String environment,
  }) async {}
  @override
  Future<void> unregisterPushDevice(String token) async {}
  @override
  Future<void> sendTestPush() async {
    tests++;
    if (failTest) throw StateError('synthetic delivery failure');
  }

  int writes = 0;
  int reads = 0;
  Completer<Map<String, dynamic>>? pending;
  @override
  String? get accountId => user;
  @override
  Future<Map<String, dynamic>> getNotifications() async {
    reads++;
    if (pending != null) return pending!.future;
    if (failFetch) throw StateError('SECRET server details');
    return {
      'unread_count': 1,
      'notifications': [
        {
          'id': 'first',
          'display_text': 'A teammate joined.',
          'is_read': writes > 0,
        },
        if (writes > 0)
          {
            'id': 'new',
            'display_text': 'A new task arrived.',
            'is_read': false,
          },
      ],
    };
  }

  @override
  Future<void> markNotificationsRead() async {
    if (failRead) throw StateError('SECRET write failure');
    writes++;
  }
}

void main() {
  const channel = MethodChannel('com.findez.app/push');
  late List<String> methods;
  setUp(() {
    methods = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          return call.method == 'authorizationStatus' ? 'notDetermined' : null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  testWidgets(
    'authorized phone alerts expose a test with honest acceptance feedback',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'authorizationStatus') return 'authorized';
            if (call.method == 'register') {
              return {'deviceToken': 'a' * 64, 'environment': 'sandbox'};
            }
            return null;
          });
      final api = _InboxApi();
      await tester.pumpWidget(MaterialApp(home: NotificationsPage(api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Notification options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send test notification'));
      await tester.pumpAndSettle();
      expect(api.tests, 1);
      expect(find.textContaining('Apple accepted'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await PushNotifications.stop();
      debugDefaultTargetPlatformOverride = null;
    },
  );
  test('malformed inbox counts and rows never become a false empty feed', () {
    for (final result in [
      {'unread_count': -1, 'notifications': []},
      {'unread_count': 0.5, 'notifications': []},
      {'unread_count': 0, 'notifications': 'bad'},
    ]) {
      expect(() => NotificationSnapshot.parse(result), throwsFormatException);
    }
  });
  testWidgets(
    'opening the inbox neither requests phone permission nor marks it read',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final api = _InboxApi();
      await tester.pumpWidget(MaterialApp(home: NotificationsPage(api: api)));
      await tester.pumpAndSettle();
      expect(api.writes, 0);
      expect(methods, isNot(contains('register')));
      expect(find.text('Enable phone alerts'), findsOneWidget);
      expect(find.text('A teammate joined.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets('a read write re-fetches and preserves a new unread event', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final api = _InboxApi();
    final counts = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsPage(api: api, onUnreadChanged: counts.add),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mark all as read'));
    await tester.pumpAndSettle();
    expect(api.writes, 1);
    expect(api.reads, 2);
    expect(counts, [1, 1]);
    expect(find.text('A new task arrived.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.semanticLabel == 'Unread',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('failed background reads retain rows and show a safe error', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final api = _InboxApi();
    await tester.pumpWidget(MaterialApp(home: NotificationsPage(api: api)));
    await tester.pumpAndSettle();
    api.failFetch = true;
    await tester.tap(find.byTooltip('Notification options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('A teammate joined.'), findsOneWidget);
    expect(find.textContaining('SECRET'), findsNothing);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('failed writes preserve the unread count and permit retry', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final api = _InboxApi()..failRead = true;
    final counts = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsPage(api: api, onUnreadChanged: counts.add),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mark all as read'));
    await tester.pumpAndSettle();
    expect(counts, [1]);
    expect(find.text('A teammate joined.'), findsOneWidget);
    api.failRead = false;
    await tester.tap(find.byTooltip('Mark all as read'));
    await tester.pumpAndSettle();
    expect(api.writes, 1);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets(
    'late responses from a previous account do not render or publish badges',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final api = _InboxApi()..pending = Completer<Map<String, dynamic>>();
      final counts = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsPage(api: api, onUnreadChanged: counts.add),
        ),
      );
      await tester.pump();
      api.user = 'account-b';
      api.pending!.complete({
        'unread_count': 1,
        'notifications': [
          {'display_text': 'Private old event'},
        ],
      });
      await tester.pumpAndSettle();
      expect(counts, isEmpty);
      expect(find.text('Private old event'), findsNothing);
      expect(find.text('Sign in again to view notifications.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
