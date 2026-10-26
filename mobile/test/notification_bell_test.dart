import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/notifications/notification_bell.dart';

class InboxApi extends ApiClient {
  InboxApi() : super(baseUrl: 'https://api.test');
  String? user = 'account-a';
  bool fail = false;
  Completer<Map<String, dynamic>>? pending;
  @override
  String? get accountId => user;
  @override
  Future<Map<String, dynamic>> getNotifications() async {
    if (pending != null) return pending!.future;
    if (fail) throw StateError('offline');
    return {'unread_count': 3, 'notifications': []};
  }
}

void main() {
  testWidgets('bell is available with unread count and opens the real inbox', (
    tester,
  ) async {
    final api = InboxApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [NotificationBell(api: api)]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notifications, 3 unread'), findsOneWidget);
    await tester.tap(find.byTooltip('Notifications, 3 unread'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('No updates yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('failed counts keep the inbox entry usable', (tester) async {
    final api = InboxApi()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [NotificationBell(api: api)]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notifications'), findsOneWidget);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('late counts from another account cannot populate the badge', (
    tester,
  ) async {
    final api = InboxApi()..pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [NotificationBell(api: api)]),
        ),
      ),
    );
    api.user = 'account-b';
    api.pending!.complete({'unread_count': 9, 'notifications': []});
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notifications, 9 unread'), findsNothing);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
