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
  FakeApi({super.client, super.vault});
  @override
  Future<void> restore() async {
    restoring = false;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {}
}

class MemoryVault extends SessionVault {
  String? saved;
  Future<bool> Function()? authenticate;
  @override
  Future<String?> read() async => saved;
  @override
  Future<void> write(String value) async {
    saved = value;
  }

  @override
  Future<void> clear() async {
    saved = null;
  }

  @override
  Future<bool> unlock() => authenticate?.call() ?? Future.value(true);
}

class SignInApi extends DashboardApi {
  SignInApi({required super.client, required super.vault});
  @override
  bool get configured => true;
}

Json sessionFixture() => {
  'access_token': 'isolated-auth-fixture',
  'refresh_token': 'isolated-refresh-fixture',
  'expires_at': 4102444800,
  'user': {'factors': []},
};

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
  testWidgets(
    'a signed-in session can load before its first snapshot arrives',
    (tester) async {
      final api = FakeApi()
        ..restoring = false
        ..session = {'access_token': 'fixture'}
        ..loading = true;
      await tester.pumpWidget(FounderApp(api: api));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Loading your dashboard...'), findsOneWidget);
      api.data = fixture();
      api.loading = false;
      api.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Registered users'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'password sign-in loads, handles a failed first request and retries',
    (tester) async {
      final firstSnapshot = Completer<http.Response>();
      var requests = 0;
      final api = SignInApi(
        vault: MemoryVault(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/v1/token')) {
            return http.Response(jsonEncode(sessionFixture()), 200);
          }
          expect(request.url.path, endsWith('/snapshot'));
          requests++;
          return requests == 1
              ? firstSnapshot.future
              : http.Response(jsonEncode(fixture()), 200);
        }),
      );
      await tester.pumpWidget(FounderApp(api: api));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'isolated-fixture-password',
      );
      await tester.tap(find.text('Open dashboard'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(requests, 1);
      expect(find.text('Loading your dashboard...'), findsOneWidget);
      expect(tester.takeException(), isNull);
      firstSnapshot.complete(
        http.Response('{"detail":"Temporarily unavailable"}', 503),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Temporarily unavailable'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Registered users'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(requests, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'canceled device unlock stays visible and can recover without a resume callback',
    (tester) async {
      final canceled = Completer<bool>();
      var attempts = 0;
      final vault = MemoryVault()
        ..authenticate = () {
          attempts++;
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          return attempts == 1 ? canceled.future : Future.value(true);
        };
      final api =
          SignInApi(
              vault: vault,
              client: MockClient(
                (_) async => http.Response(jsonEncode(fixture()), 200),
              ),
            )
            ..session = sessionFixture()
            ..locked = true;
      await tester.pumpWidget(FounderApp(api: api));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unlock dashboard'));
      await tester.pump();
      expect(find.text('FindEZ Dashboard'), findsOneWidget);
      expect(
        find.text('Complete device authentication to continue.'),
        findsOneWidget,
      );
      canceled.complete(false);
      await tester.pumpAndSettle();
      expect(api.locked, isTrue);
      expect(
        find.text('Unlock was canceled. Try again.').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Return to dashboard'));
      await tester.pumpAndSettle();
      expect(api.locked, isFalse);
      expect(find.text('Registered users').hitTestable(), findsOneWidget);
      expect(find.text('12').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('backgrounding invalidates an in-flight device unlock', () async {
    final accepted = Completer<bool>();
    final vault = MemoryVault()..authenticate = () => accepted.future;
    var requests = 0;
    final api =
        SignInApi(
            vault: vault,
            client: MockClient((_) async {
              requests++;
              return http.Response('{}', 200);
            }),
          )
          ..session = sessionFixture()
          ..locked = true;
    final pending = api.unlock();
    api.lock();
    accepted.complete(true);
    await pending;
    expect(api.locked, isTrue);
    expect(api.unlocking, isFalse);
    expect(requests, 0);
    api.dispose();
  });
  testWidgets(
    'a revoked saved refresh token returns to sign-in and a new login works',
    (tester) async {
      final vault = MemoryVault()
        ..saved = jsonEncode({...sessionFixture(), 'expires_at': 0});
      var refreshes = 0;
      final api = SignInApi(
        vault: vault,
        client: MockClient((request) async {
          if (request.url.queryParameters['grant_type'] == 'refresh_token') {
            refreshes++;
            return http.Response(
              '{"msg":"Invalid refresh token: refresh token not found"}',
              400,
            );
          }
          if (request.url.queryParameters['grant_type'] == 'password') {
            return http.Response(jsonEncode(sessionFixture()), 200);
          }
          return http.Response(jsonEncode(fixture()), 200);
        }),
      );
      await tester.pumpWidget(FounderApp(api: api));
      await tester.pumpAndSettle();
      expect(refreshes, 1);
      expect(api.session, isNull);
      expect(vault.saved, isNull);
      expect(find.text('Your session expired. Sign in again.'), findsOneWidget);
      expect(find.text('Open dashboard'), findsOneWidget);
      expect(find.textContaining('Invalid refresh token'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byType(TextField).last,
        'isolated-fixture-password',
      );
      await tester.tap(find.text('Open dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Registered users').hitTestable(), findsOneWidget);
      expect(api.signedIn, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'token expiry is normalized from expires_in before first synchronization',
    () async {
      var refreshes = 0;
      final value = {...sessionFixture(), 'expires_in': 3600}
        ..remove('expires_at');
      final api = SignInApi(
        vault: MemoryVault(),
        client: MockClient((request) async {
          if (request.url.queryParameters['grant_type'] == 'password') {
            return http.Response(jsonEncode(value), 200);
          }
          if (request.url.queryParameters['grant_type'] == 'refresh_token') {
            refreshes++;
          }
          return http.Response(jsonEncode(fixture()), 200);
        }),
      );
      await api.signIn('fixture@example.invalid', 'fixture-password');
      expect(refreshes, 0);
      expect(
        api.session!['expires_at'],
        greaterThan(DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3500),
      );
      expect(api.data, isNotNull);
      api.dispose();
    },
  );

  test(
    'automatic refresh and an issue write share a single token rotation',
    () async {
      var rotations = 0;
      final rotate = Completer<http.Response>();
      final vault = MemoryVault();
      final api = SignInApi(
        vault: vault,
        client: MockClient((request) async {
          if (request.url.queryParameters['grant_type'] == 'refresh_token') {
            rotations++;
            return rotate.future;
          }
          if (request.url.path.endsWith('/issues')) {
            return http.Response('{"saved":true}', 201);
          }
          return http.Response(jsonEncode(fixture()), 200);
        }),
      )..session = {...sessionFixture(), 'expires_at': 0};
      final refresh = api.refresh();
      final write = api.saveIssue(title: 'Isolated token rotation fixture');
      await Future<void>.delayed(Duration.zero);
      expect(rotations, 1);
      rotate.complete(
        http.Response(
          jsonEncode({
            ...sessionFixture(),
            'refresh_token': 'isolated-new-refresh-fixture',
          }),
          200,
        ),
      );
      await Future.wait([refresh, write]);
      expect(rotations, 1);
      expect(api.session!['refresh_token'], 'isolated-new-refresh-fixture');
      expect(
        jsonDecode(vault.saved!)['refresh_token'],
        'isolated-new-refresh-fixture',
      );
      expect(api.signedIn, isTrue);
      api.dispose();
    },
  );

  test(
    'a temporary auth outage preserves the saved session for retry',
    () async {
      final saved = {...sessionFixture(), 'expires_at': 0};
      final vault = MemoryVault()..saved = jsonEncode(saved);
      final api =
          SignInApi(
              vault: vault,
              client: MockClient(
                (_) async =>
                    http.Response('{"msg":"Temporarily unavailable"}', 503),
              ),
            )
            ..session = saved
            ..data = fixture();
      await api.refresh();
      expect(api.session, isNotNull);
      expect(api.data, isNotNull);
      expect(vault.saved, isNotNull);
      expect(api.error, 'Temporarily unavailable');
      api.dispose();
    },
  );
  for (final rejected in [false, true]) {
    testWidgets(
      'eight-hour background resume with ${rejected ? 'revoked' : 'renewable'} session stays recoverable',
      (tester) async {
        var refreshes = 0;
        var snapshots = 0;
        final api =
            SignInApi(
                vault: MemoryVault(),
                client: MockClient((request) async {
                  if (request.url.queryParameters['grant_type'] ==
                      'refresh_token') {
                    refreshes++;
                    return rejected
                        ? http.Response(
                            '{"msg":"Invalid refresh token: refresh token not found"}',
                            400,
                          )
                        : http.Response(jsonEncode(sessionFixture()), 200);
                  }
                  if (request.url.queryParameters['grant_type'] == 'password') {
                    return http.Response(jsonEncode(sessionFixture()), 200);
                  }
                  snapshots++;
                  return http.Response(jsonEncode(fixture()), 200);
                }),
              )
              ..session = sessionFixture()
              ..data = fixture();
        await tester.pumpWidget(FounderApp(api: api));
        await tester.pumpAndSettle();
        expect(find.text('Registered users').hitTestable(), findsOneWidget);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump(const Duration(hours: 8));
        api.session!['expires_at'] = 0;
        expect(refreshes, 0);
        expect(snapshots, 0);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Your dashboard is locked').hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.text('Unlock dashboard'));
        await tester.pumpAndSettle();
        expect(refreshes, 1);
        if (rejected) {
          expect(
            find.text('Your session expired. Sign in again.').hitTestable(),
            findsOneWidget,
          );
          expect(find.text('Open dashboard').hitTestable(), findsOneWidget);
          await tester.enterText(
            find.byType(TextField).last,
            'isolated-fixture-password',
          );
          await tester.tap(find.text('Open dashboard'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Registered users').hitTestable(), findsOneWidget);
        expect(snapshots, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
