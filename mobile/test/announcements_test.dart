import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/announcements/announcement_controller.dart';
import 'package:mobile/features/announcements/announcement_host.dart';
import 'package:mobile/features/announcements/announcement_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/announcement_fixture.dart';

class AnnouncementApi extends ApiClient {
  AnnouncementApi() : super(baseUrl: 'https://test.invalid');
  final calls = <String>[];
  final payloads = <Map<String, dynamic>?>[];
  bool failWrites = false, failClaim = false;
  Completer<Map<String, dynamic>>? pending;
  Completer<void>? receiptPending;
  @override
  Future<Map<String, dynamic>> collaboration(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async {
    calls.add(path);
    payloads.add(data);
    if (path.endsWith('/claim')) {
      if (failClaim) throw StateError('offline');
      return pending?.future ??
          {'campaign': welcomeCampaign, 'access': announcementAccess};
    }
    if (path.endsWith('/receipt')) {
      if (data?['event'] == 'shown' && receiptPending != null) {
        await receiptPending!.future;
      }
      if (failWrites) throw StateError('offline');
      return {'saved': true};
    }
    return announcementAccess;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('incomplete access is rejected without invented allowances', () {
    expect(() => verifiedAnnouncementAccess({}), throwsFormatException);
    expect(
      () => verifiedAnnouncementAccess({
        ...announcementAccess,
        'rows': [{}],
      }),
      throwsFormatException,
    );
    expect(verifiedAnnouncementAccess(announcementAccess), announcementAccess);
  });
  testWidgets('downward swipe on announcement body dismisses at the top', (
    tester,
  ) async {
    late BuildContext launcher;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            launcher = context;
            return const Scaffold();
          },
        ),
      ),
    );
    final closed = Navigator.of(
      launcher,
    ).push(announcementRoute(launcher, welcomeCampaign, announcementAccess));
    await tester.pumpAndSettle();
    await tester.drag(find.text("You're in early."), const Offset(0, 240));
    await tester.pumpAndSettle();
    expect(find.byType(AnnouncementSheet), findsNothing);
    expect(await closed, 'dismissed');
  });
  test(
    'claim once, account-bound legacy receipt, and session identity',
    () async {
      SharedPreferences.setMockInitialValues({
        'findez_plan_intro_v1:a': 'dismissed',
        'findez_plan_intro_v1:b': 'pending',
      });
      final api = AnnouncementApi();
      final c = AnnouncementController(
        api: api,
        accountId: 'a',
        isCurrent: () => true,
        platform: 'ios',
      );
      await Future.wait([c.evaluate(), c.evaluate()]);
      expect(api.calls.where((p) => p.endsWith('/claim')).length, 1);
      expect(api.payloads.last?['legacy_seen'], true);
      expect(c.access?['name'], 'Free pre-launch access');
      expect(c.sessionId, matches(RegExp(r'^[a-f0-9-]{36}$')));
      c.dispose();
    },
  );
  test('late claim cannot move data into another account', () async {
    final api = AnnouncementApi()..pending = Completer();
    var current = true;
    final c = AnnouncementController(
      api: api,
      accountId: 'a',
      isCurrent: () => current,
      platform: 'ios',
    );
    final request = c.evaluate();
    await Future<void>.delayed(Duration.zero);
    current = false;
    api.pending!.complete({
      'campaign': welcomeCampaign,
      'access': announcementAccess,
    });
    await request;
    expect(c.campaign, isNull);
    expect(await c.record('welcome-test', 'clicked'), false);
    expect(api.calls.where((p) => p.endsWith('/receipt')), isEmpty);
    c.dispose();
  });
  test(
    'offline receipts retry without authorizing another popup or another account write',
    () async {
      final api = AnnouncementApi()..failWrites = true;
      final c = AnnouncementController(
        api: api,
        accountId: 'a',
        isCurrent: () => true,
        platform: 'ios',
      );
      await c.evaluate();
      expect(await c.record('welcome-test', 'dismissed'), false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('announcement_receipts:a'), hasLength(1));
      final b = AnnouncementController(
        api: api,
        accountId: 'b',
        isCurrent: () => true,
        platform: 'ios',
      );
      await b.flush();
      expect(prefs.getStringList('announcement_receipts:a'), hasLength(1));
      api.failWrites = false;
      await c.flush();
      expect(prefs.getStringList('announcement_receipts:a'), isEmpty);
      await c.evaluate();
      expect(api.calls.where((p) => p.endsWith('/claim')), hasLength(1));
      c.dispose();
      b.dispose();
    },
  );
  test(
    'claim failure is not an entitlement fallback or polling loop',
    () async {
      final api = AnnouncementApi()..failClaim = true;
      final c = AnnouncementController(
        api: api,
        accountId: 'a',
        isCurrent: () => true,
        platform: 'ios',
      );
      await expectLater(c.evaluate(), throwsStateError);
      await c.evaluate();
      expect(c.access, isNull);
      expect(c.campaign, isNull);
      expect(api.calls, hasLength(1));
      c.dispose();
    },
  );
  test(
    'a quick dismissal drains after an in-flight impression write',
    () async {
      final api = AnnouncementApi()..receiptPending = Completer<void>();
      final c = AnnouncementController(
        api: api,
        accountId: 'a',
        isCurrent: () => true,
        platform: 'ios',
      );
      final shown = c.record('welcome-test', 'shown');
      await Future<void>.delayed(Duration.zero);
      final dismissed = c.record('welcome-test', 'dismissed');
      await Future<void>.delayed(Duration.zero);
      api.receiptPending!.complete();
      await Future.wait([shown, dismissed]);
      expect(api.payloads.map((e) => e?['event']), ['shown', 'dismissed']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('announcement_receipts:a'), isEmpty);
      c.dispose();
    },
  );
  for (final action in ['Got it', 'Close announcement', 'backdrop', 'swipe']) {
    testWidgets('$action closes and returns the correct receipt', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push(
                    announcementRoute(
                      context,
                      welcomeCampaign,
                      announcementAccess,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(AnnouncementSheet), findsOneWidget);
      if (action == 'backdrop') {
        await tester.tapAt(const Offset(5, 5));
      } else if (action == 'swipe') {
        await tester.flingFrom(
          tester.getTopLeft(find.byType(AnnouncementSheet)) +
              const Offset(100, 10),
          const Offset(0, 180),
          1000,
        );
      } else {
        final f = action == 'Got it'
            ? find.text(action)
            : find.byTooltip(action);
        await tester.ensureVisible(f);
        await tester.tap(f);
      }
      await tester.pumpAndSettle();
      expect(find.byType(AnnouncementSheet), findsNothing);
      expect(
        result,
        action == 'Got it'
            ? 'acknowledged'
            : action == 'backdrop' || action == 'swipe'
            ? isNull
            : 'dismissed',
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final brightness in Brightness.values) {
    for (final size in [const Size(320, 568), const Size(430, 932)]) {
      for (final scale in [1.0, 2.6]) {
        testWidgets('accessible sheet $brightness $size $scale', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      announcementRoute(
                        context,
                        welcomeCampaign,
                        announcementAccess,
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text('Got it'),
            200,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.tap(find.text('Got it'));
          await tester.pumpAndSettle();
          expect(find.byType(AnnouncementSheet), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets(
    'gate waits for readiness and busy workflow to finish, then one per session',
    (tester) async {
      final api = AnnouncementApi();
      final c = AnnouncementController(
        api: api,
        accountId: 'a',
        isCurrent: () => true,
        platform: 'ios',
      );
      addTearDown(c.dispose);
      var safe = false;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [announcementRoutes],
          home: AnnouncementScope(
            controller: c,
            child: Scaffold(
              body: AnnouncementGate(
                isSafe: () => safe,
                clock: tester.binding.clock.now,
                onCapture: () {},
                child: const Text('Home'),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 4));
      expect(api.calls, isEmpty);
      safe = true;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(AnnouncementSheet), findsOneWidget);
      expect(find.text('Got it'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      expect(find.byType(AnnouncementSheet), findsNothing);
      expect(api.calls.where((p) => p.endsWith('/claim')), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'a late claim defers for a workflow and logout removes the sheet',
    (tester) async {
      final api = AnnouncementApi()..pending = Completer();
      var current = true, safe = true;
      final c = AnnouncementController(
        api: api,
        accountId: 'a',
        isCurrent: () => current,
        platform: 'ios',
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [announcementRoutes],
          home: AnnouncementScope(
            controller: c,
            child: Scaffold(
              body: AnnouncementGate(
                isSafe: () => safe,
                clock: tester.binding.clock.now,
                onCapture: () {},
                child: const Text('Home'),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      safe = false;
      api.pending!.complete({
        'campaign': welcomeCampaign,
        'access': announcementAccess,
      });
      await tester.pumpAndSettle();
      expect(find.byType(AnnouncementSheet), findsNothing);
      safe = true;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(AnnouncementSheet), findsOneWidget);
      current = false;
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Signed out'))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnnouncementSheet), findsNothing);
      expect(api.calls.where((p) => p.endsWith('/claim')), hasLength(1));
    },
  );
  testWidgets('capture CTA opens without waiting for receipt delivery', (
    tester,
  ) async {
    final api = AnnouncementApi()..receiptPending = Completer<void>();
    api.pending = Completer()
      ..complete({
        'campaign': {
          ...welcomeCampaign,
          'design': 'whats_new',
          'action': 'capture',
          'cta': 'Try it',
        },
        'access': announcementAccess,
      });
    final c = AnnouncementController(
      api: api,
      accountId: 'a',
      isCurrent: () => true,
      platform: 'ios',
    );
    addTearDown(c.dispose);
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [announcementRoutes],
        home: AnnouncementScope(
          controller: c,
          child: Scaffold(
            body: AnnouncementGate(
              isSafe: () => true,
              clock: tester.binding.clock.now,
              onCapture: () => opened = true,
              child: const Text('Home'),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Try it'));
    await tester.tap(find.text('Try it'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(opened, true);
    expect(find.byType(AnnouncementSheet), findsNothing);
    api.receiptPending!.complete();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
