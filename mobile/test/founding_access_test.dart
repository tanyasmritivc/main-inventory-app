import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/founding_access/founding_access_gate.dart';
import 'package:mobile/features/founding_access/founding_access_sheet.dart';
import 'package:mobile/features/founding_access/founding_access_store.dart';
import 'package:mobile/features/founding_access/riso_art.dart';
import 'package:mobile/features/profile/plans_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> Function(String)? foundingCapture;

User account(
  String id, {
  bool fresh = true,
  bool confirmed = true,
  bool anonymous = false,
  bool identity = true,
}) {
  final now = DateTime.now().toUtc();
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: now
        .subtract(fresh ? Duration.zero : const Duration(days: 20))
        .toIso8601String(),
    emailConfirmedAt: confirmed ? now.toIso8601String() : null,
    isAnonymous: anonymous,
    identities: identity
        ? [
            UserIdentity(
              id: id,
              userId: id,
              identityData: const {},
              provider: 'email',
              createdAt: now.toIso8601String(),
              lastSignInAt: now.toIso8601String(),
              updatedAt: now.toIso8601String(),
              identityId: id,
            ),
          ]
        : [],
  );
}

class _Ask extends StatefulWidget {
  const _Ask(this.id);
  final String id;
  @override
  State<_Ask> createState() => _AskState();
}

class _AskState extends State<_Ask> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FoundingAskReady(widget.id).dispatch(context);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Ask')));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool reduced = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('founding-frame'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.create(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 44, bottom: 24),
              viewPadding: const EdgeInsets.only(top: 44, bottom: 24),
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduced,
            ),
            child: child!,
          ),
          home: child,
        ),
      ),
    );
    await tester.pump();
  }

  test('only newly created accounts acquire a local pending receipt', () async {
    final store = FoundingAccessStore();
    final started = DateTime.now().toUtc();
    for (final user in [
      account('old', fresh: false),
      account('anon', anonymous: true),
      account('duplicate', identity: false),
    ]) {
      await store.recordSignup(user, started, email: true);
      expect(await store.shouldShow(user), isFalse);
    }
    expect(await store.shouldShow(account('cached-new')), isFalse);
    final fresh = account('new');
    await store.recordSignup(fresh, started, email: true);
    expect(await store.shouldShow(fresh), isTrue);
    await store.dismiss(fresh.id);
    expect(await FoundingAccessStore().shouldShow(fresh), isFalse);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'founding_access_seen_new',
      ),
      isTrue,
    );
    expect(await store.shouldShow(account('another')), isFalse);
  });

  test(
    'unverified email waits and keeps its account-bound receipt across relaunch',
    () async {
      final store = FoundingAccessStore();
      await store.recordSignup(
        account('email', confirmed: false),
        DateTime.now().toUtc(),
        email: true,
      );
      expect(
        await store.shouldShow(account('email', confirmed: false)),
        isFalse,
      );
      expect(
        await FoundingAccessStore().shouldShow(account('email', fresh: false)),
        isTrue,
      );
      await store.recordSignup(account('oauth'), DateTime.now().toUtc());
      expect(await store.shouldShow(account('oauth')), isTrue);
    },
  );

  testWidgets('signup waits for Ask then shows once and survives relaunch', (
    tester,
  ) async {
    final store = FoundingAccessStore();
    final user = account('signup');
    await store.recordSignup(user, DateTime.now().toUtc());
    await mount(
      tester,
      FoundingAccessGate(
        user: user,
        store: store,
        child: const Scaffold(body: Text('Onboarding')),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(FoundingAccessSheet), findsNothing);
    await mount(
      tester,
      FoundingAccessGate(user: user, store: store, child: _Ask(user.id)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(FoundingAccessSheet), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text("You're in early."), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(FoundingAccessSheet), findsNothing);
    expect(find.text('Ask'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await mount(
      tester,
      FoundingAccessGate(
        user: user,
        store: FoundingAccessStore(),
        child: _Ask(user.id),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(FoundingAccessSheet), findsNothing);
  });

  testWidgets(
    'returning login and account switch never show another account receipt',
    (tester) async {
      final store = FoundingAccessStore();
      final a = account('a'), b = account('b', fresh: false);
      await store.recordSignup(a, DateTime.now().toUtc());
      await mount(
        tester,
        FoundingAccessGate(
          key: ValueKey(a.id),
          user: a,
          store: store,
          child: _Ask(a.id),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await mount(
        tester,
        FoundingAccessGate(
          key: ValueKey(b.id),
          user: b,
          store: store,
          child: _Ask(b.id),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(FoundingAccessSheet), findsNothing);
    },
  );

  for (final action in ['Get started', 'Got it', 'backdrop', 'swipe']) {
    testWidgets('$action marks signup seen', (tester) async {
      final store = FoundingAccessStore();
      final user = account(action);
      await store.recordSignup(user, DateTime.now().toUtc());
      await mount(
        tester,
        FoundingAccessGate(user: user, store: store, child: _Ask(user.id)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();
      if (action == 'Got it') {
        await tester.tap(find.text("See what's included"));
        await tester.pumpAndSettle();
      }
      if (action == 'backdrop') {
        await tester.tapAt(const Offset(10, 20));
      } else if (action == 'swipe') {
        await tester.dragFrom(
          tester.getCenter(find.byKey(const ValueKey('founding-grab-handle'))),
          const Offset(0, 100),
        );
      } else {
        await tester.tap(find.text(action));
      }
      await tester.pumpAndSettle();
      expect(find.byType(FoundingAccessSheet), findsNothing);
      expect(await FoundingAccessStore().shouldShow(user), isFalse);
    });
  }

  for (final device in [
    ('small', const Size(375, 667), 1.0),
    ('standard', const Size(390, 844), 1.0),
    ('max', const Size(440, 956), 1.0),
    ('large-text', const Size(320, 568), 2.0),
  ]) {
    testWidgets(
      '${device.$1} both views fit, scroll and retain reachable buttons',
      (tester) async {
        var closed = false;
        await mount(
          tester,
          FoundingAccessSheet(onClosed: () => closed = true),
          size: device.$2,
          scale: device.$3,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.text('Get started')).bottom,
          lessThan(device.$2.height),
        );
        await foundingCapture?.call('${device.$1}-welcome');
        final art = find.byType(RisoArt).first;
        expect(
          tester
              .widget<ClipRRect>(
                find
                    .descendant(of: art, matching: find.byType(ClipRRect))
                    .first,
              )
              .borderRadius,
          BorderRadius.circular(26),
        );
        await tester.tap(find.text("See what's included"));
        await tester.pumpAndSettle();
        expect(find.text("What's included"), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.text('Got it')).bottom,
          lessThan(device.$2.height),
        );
        await foundingCapture?.call('${device.$1}-details');
        await tester.ensureVisible(find.text('Import a spreadsheet'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byTooltip('Back'));
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.text("You're in early."), findsOneWidget);
        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle();
        expect(closed, isTrue);
      },
    );
  }

  testWidgets('Settings Plans row opens details and Back closes', (
    tester,
  ) async {
    await mount(tester, const PlansPage());
    await tester.pumpAndSettle();
    await foundingCapture?.call('settings-row');
    await tester.tap(find.byKey(const ValueKey('founding-access-plan-row')));
    await tester.pumpAndSettle();
    expect(find.text("You're in early."), findsNothing);
    expect(find.byType(FoundingAccessSheet), findsOneWidget);
    await foundingCapture?.call('settings-your-plan');
    await tester.tap(find.byTooltip('Back').last);
    await tester.pumpAndSettle();
    expect(find.byType(FoundingAccessSheet), findsNothing);
    expect(find.byType(PlansPage), findsOneWidget);
  });

  testWidgets('large text Settings row fits and reduced motion settles', (
    tester,
  ) async {
    await mount(
      tester,
      const PlansPage(),
      size: const Size(320, 568),
      scale: 2,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('founding-access-plan-row')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('normal motion enters, changes views, and dismisses cleanly', (
    tester,
  ) async {
    var closed = false;
    await mount(
      tester,
      FoundingAccessSheet(onClosed: () => closed = true),
      reduced: false,
    );
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    await foundingCapture?.call('motion-welcome');
    await tester.tap(find.text("See what's included"));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    await foundingCapture?.call('motion-details');
    await tester.tap(find.text('Got it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(closed, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
