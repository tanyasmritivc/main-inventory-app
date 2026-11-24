import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:findez_dashboard/dashboard_api.dart';
import 'package:findez_dashboard/notification_analytics.dart';

class AnalyticsApi extends DashboardApi {
  bool unavailable = true;
  @override
  Future<Json> notificationAnalytics() async {
    if (unavailable) throw DashboardError('Unavailable');
    return {
      'experiment_enabled': false,
      'disablements': {},
      'account_frequency': [],
      'groups': [
        {'category': 'All categories', 'selected': 7, 'tap_rate': null},
      ],
    };
  }
}

void main() {
  testWidgets('founder retries a missing report and sees the actual count', (
    tester,
  ) async {
    final api = AnalyticsApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NotificationAnalytics(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Selected'), findsNothing);
    api.unavailable = false;
    await tester.tap(find.text('Notification analytics unavailable. Retry'));
    await tester.pumpAndSettle();
    expect(find.text('All categories'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });
}
