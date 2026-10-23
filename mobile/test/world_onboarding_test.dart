import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/ui/findez_wordmark.dart';
import 'package:mobile/features/auth/auth_page.dart';
import 'package:mobile/features/onboarding/onboarding_page.dart';
import 'package:mobile/features/onboarding/pending_world.dart';
import 'package:mobile/features/onboarding/world_scene.dart';

Future<void> phone(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  bool reduce = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduce,
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> advance(WidgetTester tester) async {
  final next = find.byKey(const Key('onboarding-next'));
  await tester.ensureVisible(next);
  await tester.tap(next);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('organization hint is never a prefilled name or a valid answer', (
    tester,
  ) async {
    await phone(
      tester,
      const OnboardingPage(
        initialSetup: PendingWorld(path: 'team', step: WorldStep.organization),
      ),
    );
    final field = tester.widget<TextField>(
      find.byKey(const Key('world-organization')),
    );
    expect(field.decoration?.hintText, 'e.g. FindEZ AI');
    expect(field.controller!.text, isEmpty);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Done'))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('world-organization')),
      'Northstar Lab',
    );
    await tester.pumpAndSettle();
    expect((await WorldSetupStore.draft())!.orgName, 'Northstar Lab');
  });
  testWidgets(
    'choose waits for a real selection and advances directly on its tap',
    (tester) async {
      await phone(
        tester,
        const OnboardingPage(
          initialSetup: PendingWorld(step: WorldStep.choose),
        ),
      );
      expect(find.byKey(const Key('onboarding-next')), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text("Who's FindEZ for?"), findsOneWidget);
      await tester.tap(find.byKey(const Key('world-path-team')));
      await tester.pumpAndSettle();
      expect((await WorldSetupStore.draft())!.path, 'team');
      expect(find.text('Name your\norganization'), findsOneWidget);
      expect(find.byType(FindEZWordmark), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('organization updates its model tag live, back keeps the name', (
    tester,
  ) async {
    await phone(
      tester,
      const OnboardingPage(
        initialSetup: PendingWorld(path: 'team', step: WorldStep.organization),
      ),
    );
    final input = find.byKey(const Key('world-organization'));
    await tester.enterText(input, 'Kestrel Labs');
    await tester.pumpAndSettle();
    expect(find.text('Kestrel Labs'), findsNWidgets(2));
    expect((await WorldSetupStore.draft())!.orgName, 'Kestrel Labs');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('world-chip-R&D')));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(2, 400), const Offset(160, 0));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(2, 400), const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(find.text('Name your\norganization'), findsOneWidget);
    expect(tester.widget<TextField>(input).controller!.text, 'Kestrel Labs');
    expect(tester.takeException(), isNull);
  });
  testWidgets('field follows keyboard insets without first jumping down', (
    tester,
  ) async {
    await phone(
      tester,
      const OnboardingPage(
        initialSetup: PendingWorld(path: 'team', step: WorldStep.organization),
      ),
    );
    final field = find.byKey(const Key('world-organization'));
    final initial = tester.getTopLeft(field).dy;
    tester.view.viewInsets = const FakeViewPadding(bottom: 60);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(field).dy, lessThanOrEqualTo(initial));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(field).dy, lessThan(844 - 300));
    expect(tester.getBottomLeft(find.text('Done')).dy, lessThan(844 - 300));
  });
  testWidgets(
    'native keyboard keeps the live organization tag above its field',
    (tester) async {
      await phone(
        tester,
        const OnboardingPage(
          initialSetup: PendingWorld(
            path: 'team',
            orgName: 'Northstar Lab',
            step: WorldStep.organization,
          ),
        ),
      );
      final field = find.byKey(const Key('world-organization'));
      await tester.tap(field);
      tester.view.viewInsets = const FakeViewPadding(bottom: 346);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final label = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'Northstar Lab',
      );
      expect(
        tester.getBottomLeft(label).dy,
        lessThan(tester.getTopLeft(field).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('personal custom purpose and changed inventory reuse one world', (
    tester,
  ) async {
    await phone(
      tester,
      const OnboardingPage(
        initialSetup: PendingWorld(path: 'personal', step: WorldStep.workspace),
      ),
    );
    await tester.tap(find.byKey(const Key('world-chip-+ Custom')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('world-custom')),
      'Field service',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect((await WorldSetupStore.draft())!.workspacePurpose, 'Field service');
    expect(find.text('Create your first\ninventory'), findsOneWidget);
    await tester.tap(find.byKey(const Key('world-chip-Tools')));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(2, 400), const Offset(160, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('world-chip-Electronics')));
    await tester.pumpAndSettle();
    expect(find.byType(WorldScene), findsOneWidget);
    expect((await WorldSetupStore.draft())!.inventoryName, 'Electronics');
    expect(find.text('Only you'), findsOneWidget);
    expect(find.text('Electronics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'resuming onboarding restores the exact step without auto advancing',
    (tester) async {
      await WorldSetupStore.saveDraft(
        const PendingWorld(
          path: 'team',
          orgName: 'Lab',
          workspacePurpose: 'Production',
          step: WorldStep.inventory,
        ),
      );
      await phone(tester, const OnboardingPage());
      expect(find.text('Create your first\ninventory'), findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Create your first\ninventory'), findsOneWidget);
      expect(find.text('Lab'), findsOneWidget);
    },
  );
  for (final step in [
    WorldStep.choose,
    WorldStep.organization,
    WorldStep.workspace,
    WorldStep.inventory,
    WorldStep.world,
  ]) {
    testWidgets(
      '${step.name} supports largest accessibility text without clipping',
      (tester) async {
        await phone(
          tester,
          OnboardingPage(
            initialSetup: PendingWorld(
              path: 'team',
              orgName: 'Kestrel Labs',
              workspacePurpose: 'Production',
              inventoryName: 'Hardware',
              step: step,
            ),
          ),
          scale: 3.4,
        );
        final target = switch (step) {
          WorldStep.choose => find.byKey(const Key('world-path-team')),
          WorldStep.organization => find.text('Done'),
          WorldStep.workspace => find.byKey(const Key('world-chip-Production')),
          WorldStep.inventory => find.byKey(const Key('world-chip-Hardware')),
          _ => find.byKey(const Key('onboarding-next')),
        };
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        expect(target.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final variant in [false, true]) {
    testWidgets(
      'auth ${variant ? 'prepared' : 'returning'} uses one screen and preserves email entry',
      (tester) async {
        await phone(tester, AuthPage(fromOnboarding: variant));
        expect(
          find.text(variant ? 'Your dashboard is ready' : 'Welcome back'),
          findsOneWidget,
        );
        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.text('Continue with Apple'), findsOneWidget);
        expect(find.text('Continue with Email'), findsNothing);
        expect(find.text('Continue with Microsoft'), findsNothing);
        expect(find.text('Continue with SSO'), findsNothing);
        await tester.ensureVisible(find.byKey(const Key('auth-more-options')));
        await tester.tap(find.byKey(const Key('auth-more-options')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('auth-email-option')));
        await tester.tap(find.byKey(const Key('auth-email-option')));
        await tester.pumpAndSettle();
        expect(find.text('Forgot password?'), findsOneWidget);
        expect(find.text('New here? Create account'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
