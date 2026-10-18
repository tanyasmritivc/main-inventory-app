import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:findez_dashboard/dashboard_api.dart';
import 'package:findez_dashboard/main.dart';

class FakeApi extends DashboardApi {
  @override
  Future<void> restore() async {
    restoring = false;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {}
}

Json fixture() => {
  'analytics': {
    'metrics': [
      {
        'id': 'users',
        'label': 'Registered users',
        'value': 12,
        'unit': 'count',
        'source': 'Test fixture',
        'period': 'Current',
      },
    ],
  },
  'ai': {'metrics': []},
  'revenue': {'metrics': []},
  'infrastructure': {
    'checks': [
      {'id': 'api', 'label': 'Backend API', 'healthy': true, 'latency_ms': 15},
    ],
    'metrics': [],
  },
  'issues': [],
  'customers': [],
  'audit': [],
  'activity': [],
  'source_status': [],
};

class RefreshApi extends FakeApi {
  int refreshes = 0;
  @override
  Future<void> refresh() async {
    refreshes++;
    data = fixture();
    data!['analytics']['metrics'][0]['value'] = 12 + refreshes;
    lastSuccess = DateTime(2026, 10, 18, 3, refreshes);
    notifyListeners();
  }
}

void main() {
  test('unavailable and a measured zero have different presentations', () {
    expect(displayValue({'value': null}), 'Unavailable');
    expect(displayValue({'value': 0, 'unit': 'count'}), '0');
    expect(displayValue({'value': 0, 'unit': 'usd'}), '\$0.00');
  });

  testWidgets('private sign in has no customer navigation', (tester) async {
    await tester.pumpWidget(FounderApp(api: FakeApi()));
    await tester.pumpAndSettle();
    expect(find.text('Founder dashboard'), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    expect(find.textContaining('configuration is missing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact dashboard navigation and customer empty state work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeApi()
      ..restoring = false
      ..data = fixture();
    await tester.pumpWidget(
      MaterialApp(
        theme: dashboardTheme(),
        home: DashboardShell(api: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Registered users'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    await tester.tap(find.text('Customers').last);
    await tester.pumpAndSettle();
    expect(find.text('Search email or user ID'), findsOneWidget);
    expect(find.textContaining('No matching accounts'), findsOneWidget);
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    expect(find.text('Revenue'), findsOneWidget);
    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Payments and subscriptions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text keeps KPI cards within the viewport', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(375, 667),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 335,
              child: MetricGrid(
                metrics: [
                  {
                    'label': 'Monthly recurring revenue',
                    'value': null,
                    'period': 'Current',
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Apple font keeps chosen weight with Bold Text and dark mode enabled',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(boldText: true);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(FounderApp(api: FakeApi()));
      await tester.pumpAndSettle();
      final label = find.text('Founder dashboard');
      final context = tester.element(label);
      expect(Theme.of(context).brightness, Brightness.light);
      expect(MediaQuery.boldTextOf(context), isFalse);
      final paragraph = tester.renderObject<RenderParagraph>(label);
      final span = paragraph.text as TextSpan;
      expect(span.style!.fontFamily, 'CupertinoSystemDisplay');
      expect(span.style!.fontWeight, FontWeight.w400);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'every 60 seconds refreshes visible data and resume refreshes immediately',
    (tester) async {
      final api = RefreshApi()
        ..restoring = false
        ..session = {'access_token': 'fixture'}
        ..data = fixture();
      await tester.pumpWidget(FounderApp(api: api));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 59));
      expect(api.refreshes, 0);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(api.refreshes, 1);
      expect(find.text('13'), findsOneWidget);
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();
      expect(api.refreshes, 2);
      expect(find.text('14'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 60));
      expect(api.refreshes, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(api.refreshes, 3);
      expect(find.text('15'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'refresh replaces the complete snapshot, coalesces requests and preserves data on failure',
    () async {
      int calls = 0;
      bool fail = false;
      final gate = Completer<void>();
      final api = DashboardApi(
        client: MockClient((request) async {
          expect(request.url.path, endsWith('/snapshot'));
          expect(request.headers['Authorization'], 'Bearer fixture');
          calls++;
          if (calls == 1) await gate.future;
          if (fail) return http.Response('{"detail":"Offline"}', 503);
          return http.Response(
            jsonEncode({
              'at': '2026-10-18T10:00:00Z',
              'analytics': {
                'metrics': [
                  {'id': 'users', 'value': calls},
                ],
              },
              'revenue': {
                'metrics': [
                  {'id': 'mrr', 'value': null},
                ],
              },
              'ai': {
                'metrics': [
                  {'id': 'chats', 'value': calls},
                ],
              },
              'infrastructure': {
                'checks': [
                  {'healthy': true},
                ],
              },
              'customers': [
                {'id': 'customer-$calls'},
              ],
              'issues': [
                {'id': 'issue-$calls'},
              ],
              'activity': [
                {'id': 'event-$calls'},
              ],
            }),
            200,
          );
        }),
      )..session = {'access_token': 'fixture', 'expires_at': 4102444800};
      final first = api.refresh();
      final duplicate = api.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      gate.complete();
      await Future.wait([first, duplicate]);
      await api.refresh();
      expect(calls, 2);
      expect(api.data!['analytics']['metrics'][0]['value'], 2);
      expect(api.data!['ai']['metrics'][0]['value'], 2);
      expect(api.data!['customers'][0]['id'], 'customer-2');
      expect(api.data!['issues'][0]['id'], 'issue-2');
      expect(api.data!['activity'][0]['id'], 'event-2');
      expect(api.data!['revenue']['metrics'][0]['value'], isNull);
      final timestamp = api.lastSuccess;
      fail = true;
      await api.refresh();
      expect(api.error, 'Offline');
      expect(api.data!['customers'][0]['id'], 'customer-2');
      expect(api.lastSuccess, timestamp);
      api.dispose();
    },
  );
  testWidgets('an open customer record changes on the next full refresh', (
    tester,
  ) async {
    final api = FakeApi()
      ..restoring = false
      ..session = {'access_token': 'fixture'}
      ..data = fixture();
    Json customer(int items) => {
      'id': 'fixture-user',
      'email': 'founder-test@example.invalid',
      'items': items,
    };
    api.data!['customers'] = [customer(2)];
    await tester.pumpWidget(FounderApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customers').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('founder-test@example.invalid'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Inventory records'),
      240,
      scrollable: find
          .descendant(
            of: find.byType(CustomerDetail),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    api.data = {
      ...fixture(),
      'customers': [customer(9)],
    };
    api.notifyListeners();
    await tester.pump();
    expect(find.text('9'), findsOneWidget);
    expect(find.text('2'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
