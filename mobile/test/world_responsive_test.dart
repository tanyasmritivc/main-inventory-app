import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/app_gradient_background.dart';
import 'package:mobile/features/onboarding/onboarding_page.dart';
import 'package:mobile/features/onboarding/pending_world.dart';
import 'package:mobile/features/onboarding/world_scene.dart';

Future<void> mountPhone(
  WidgetTester tester,
  PendingWorld setup, {
  Size size = const Size(390, 844),
  EdgeInsets safe = const EdgeInsets.only(top: 47, bottom: 34),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.create(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: safe,
          viewPadding: safe,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: AppGradientBackground(child: OnboardingPage(initialSetup: setup)),
    ),
  );
  await tester.pumpAndSettle();
}

void expectWorldAbove(WidgetTester tester, Finder controls) {
  final scene = find.byType(WorldScene);
  final widget = tester.widget<WorldScene>(scene);
  final box = tester.renderObject<RenderBox>(scene);
  final front = box.localToGlobal(widget.camera.project(100, 100, 0));
  expect(
    front.dy,
    lessThan(tester.getTopLeft(controls).dy - 8),
    reason:
        'The platform must stay clear of the controls in the launch safe area',
  );
}

void main() {
  testWidgets('production safe area keeps platform above organization input', (
    tester,
  ) async {
    await mountPhone(
      tester,
      const PendingWorld(path: 'team', step: WorldStep.organization),
    );
    expectWorldAbove(tester, find.byKey(const Key('world-organization')));
  });
  testWidgets(
    'production safe area keeps platform and tag above purpose chips',
    (tester) async {
      await mountPhone(
        tester,
        const PendingWorld(
          path: 'team',
          orgName: 'FindEZ AI',
          step: WorldStep.workspace,
        ),
      );
      final chips = find.byKey(const Key('world-chip-R&D'));
      expectWorldAbove(tester, chips);
      expect(
        tester.getBottomLeft(find.text('FindEZ AI')).dy,
        lessThan(tester.getTopLeft(chips).dy - 8),
      );
    },
  );
  for (final device in [
    (const Size(320, 568), const EdgeInsets.only(top: 20)),
    (const Size(375, 667), const EdgeInsets.only(top: 20)),
    (const Size(375, 812), const EdgeInsets.only(top: 44, bottom: 34)),
    (const Size(390, 844), const EdgeInsets.only(top: 47, bottom: 34)),
    (const Size(393, 852), const EdgeInsets.only(top: 59, bottom: 34)),
    (const Size(402, 874), const EdgeInsets.only(top: 62, bottom: 34)),
    (const Size(430, 932), const EdgeInsets.only(top: 59, bottom: 34)),
    (const Size(440, 956), const EdgeInsets.only(top: 62, bottom: 34)),
    (
      const Size(844, 390),
      const EdgeInsets.only(left: 44, right: 44, bottom: 21),
    ),
    (const Size(768, 1024), const EdgeInsets.only(top: 24, bottom: 20)),
  ]) {
    for (final step in [
      WorldStep.organization,
      WorldStep.workspace,
      WorldStep.inventory,
    ]) {
      testWidgets('${device.$1} ${step.name} separates model and controls', (
        tester,
      ) async {
        await mountPhone(
          tester,
          PendingWorld(
            path: 'team',
            orgName: 'FindEZ AI',
            workspacePurpose: 'Production',
            inventoryName: 'Hardware',
            step: step,
          ),
          size: device.$1,
          safe: device.$2,
        );
        final control = find.byKey(
          Key(
            step == WorldStep.organization
                ? 'world-organization'
                : step == WorldStep.workspace
                ? 'world-chip-R&D'
                : 'world-chip-Hardware',
          ),
        );
        await tester.ensureVisible(control);
        await tester.pumpAndSettle();
        expectWorldAbove(tester, control);
        final tag = find.descendant(
          of: find.byType(WorldScene),
          matching: find.text('FindEZ AI'),
        );
        expect(
          tester.getBottomLeft(tag).dy,
          lessThan(tester.getTopLeft(control).dy - 8),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final scale in [1.0, 1.3, 3.4]) {
    testWidgets('long labels fit at text scale $scale', (tester) async {
      await mountPhone(
        tester,
        PendingWorld(
          path: 'team',
          orgName: 'Very long organization name for the whole workshop and lab',
          workspacePurpose: 'Long workspace name for advanced projects',
          inventoryName: 'Long inventory name for special equipment',
          step: WorldStep.organization,
        ),
        textScale: scale,
      );
      final control = find.byKey(const Key('world-organization'));
      await tester.ensureVisible(control);
      await tester.pumpAndSettle();
      expectWorldAbove(tester, control);
      final tag = find.descendant(
        of: find.byType(WorldScene),
        matching: find.textContaining('Very long'),
      );
      expect(
        tester.getBottomLeft(tag).dy,
        lessThan(tester.getTopLeft(control).dy - 8),
      );
      final rect = tester.getRect(tag);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(390));
      expect(tester.takeException(), isNull);
    });
  }
  for (final size in [
    const Size(375, 667),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('$size keyboard leaves the complete input controls visible', (
      tester,
    ) async {
      await mountPhone(
        tester,
        const PendingWorld(
          path: 'team',
          orgName: 'FindEZ AI',
          step: WorldStep.organization,
        ),
        size: size,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.tap(find.byKey(const Key('world-organization')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Done'));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('world-organization'));
      expect(tester.getBottomLeft(field).dy, lessThan(size.height - 300));
      expect(
        tester.getBottomLeft(find.text('Done')).dy,
        lessThan(size.height - 300),
      );
      expectWorldAbove(tester, field);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('long recap remains scrollable above its dashboard action', (
    tester,
  ) async {
    await mountPhone(
      tester,
      const PendingWorld(
        path: 'team',
        orgName: 'Very long organization name for the whole workshop and lab',
        workspacePurpose: 'Long workspace name for advanced projects',
        inventoryName: 'Long inventory name for special equipment',
        step: WorldStep.world,
      ),
    );
    final action = find.byKey(const Key('onboarding-next'));
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    expect(action.hitTestable(), findsOneWidget);
    expect(
      tester
          .getBottomLeft(find.text('Long inventory name for special equipment'))
          .dy,
      lessThan(tester.getTopLeft(action).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
