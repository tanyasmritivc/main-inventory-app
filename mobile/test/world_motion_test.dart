import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/pending_world.dart';
import 'package:mobile/features/onboarding/world_scene.dart';

const organization = PendingWorld(
  path: 'team',
  orgName: 'Test Lab',
  step: WorldStep.organization,
);
const purpose = PendingWorld(
  path: 'team',
  orgName: 'Test Lab',
  workspacePurpose: 'Production',
  step: WorldStep.workspace,
);
const inventory = PendingWorld(
  path: 'team',
  orgName: 'Test Lab',
  workspacePurpose: 'Production',
  inventoryName: 'Hardware',
  step: WorldStep.inventory,
);

Future<WorldModel> mount(WidgetTester tester, PendingWorld setup) async {
  final model = WorldModel(
    const TestVSync(),
    setup,
    const WorldCamera(195, 500, .8),
  );
  addTearDown(model.dispose);
  await tester.pumpWidget(
    MaterialApp(home: CustomPaint(painter: WorldPainter(model))),
  );
  return model;
}

void main() {
  testWidgets(
    'interrupted camera starts from the visible position without a jump',
    (tester) async {
      final model = await mount(tester, organization);
      model.moveTo(const WorldCamera(195, 360, .6), milliseconds: 350);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 175));
      final current = model.camera;
      model.moveTo(const WorldCamera(112, 520, .62), milliseconds: 800);
      expect(model.camera.x, current.x);
      expect(model.camera.y, current.y);
      expect(model.camera.scale, current.scale);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(model.camera.x, 112);
      expect(model.camera.y, 520);
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'block grows in 700ms, ghosts start at 1000ms, reselect only settles',
    (tester) async {
      final model = await mount(tester, organization);
      model.update(purpose, const WorldCamera(195, 490, .9), reduce: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 701));
      expect(model.blockHeight, closeTo(1, .001));
      expect(model.block.isAnimating, isFalse);
      expect(model.ghostOpacity, 0);
      await tester.pump(const Duration(milliseconds: 600));
      expect(model.ghostOpacity, closeTo(.5, .005));
      model.update(
        purpose.copyWith(workspacePurpose: 'R&D'),
        const WorldCamera(195, 490, .9),
        reduce: false,
      );
      expect(model.block.value, 1);
      expect(model.blockHeight, closeTo(.96, .001));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(model.blockHeight, closeTo(1, .001));
      await tester.pumpAndSettle();
    },
  );
  testWidgets('tray and seven staggered drops follow the requested timeline', (
    tester,
  ) async {
    final model = await mount(tester, purpose);
    model.update(inventory, const WorldCamera(195, 480, 1), reduce: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(model.trayHeight, closeTo(1, .001));
    expect(model.itemProgress(0), 0);
    await tester.pump(const Duration(milliseconds: 425));
    expect(model.itemProgress(0), closeTo(.5, .001));
    expect(model.itemElevation(0), lessThan(10));
    expect(model.itemProgress(2), 0);
    await tester.pump(const Duration(milliseconds: 945));
    for (var i = 0; i < 7; i++) {
      expect(model.itemProgress(i), 1);
    }
    model.update(
      inventory.copyWith(inventoryName: 'Electronics'),
      const WorldCamera(195, 480, 1),
      reduce: false,
    );
    expect(model.drops.value, 1);
    expect(model.tray.value, 1);
    expect(model.trayHeight, closeTo(.96, .001));
    await tester.pumpAndSettle();
  });
  testWidgets('back and forward restore retained blocks and trays', (
    tester,
  ) async {
    final model = await mount(tester, inventory);
    model.update(
      inventory.copyWith(step: WorldStep.organization),
      const WorldCamera(195, 500, .8),
      reduce: false,
    );
    await tester.pumpAndSettle();
    expect(model.blockHeight, closeTo(0, .001));
    model.update(inventory, const WorldCamera(195, 480, 1), reduce: false);
    await tester.pumpAndSettle();
    expect(model.blockHeight, closeTo(1, .001));
    expect(model.trayHeight, closeTo(1, .001));
    expect(model.itemProgress(6), 1);
  });
  testWidgets(
    'Reduce Motion resolves camera and every model channel immediately',
    (tester) async {
      final model = await mount(tester, organization);
      model.update(inventory, const WorldCamera(112, 520, .62), reduce: true);
      expect(model.camera.x, 112);
      expect(model.blockHeight, 1);
      expect(model.trayHeight, 1);
      expect(model.itemProgress(6), 1);
      expect(model.cameraMove.isAnimating, isFalse);
      expect(model.drops.isAnimating, isFalse);
    },
  );
  testWidgets(
    'the same world state stays mounted from Choose through back navigation',
    (tester) async {
      final setup = ValueNotifier(
        const PendingWorld(path: 'team', step: WorldStep.choose),
      );
      addTearDown(setup.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<PendingWorld>(
            valueListenable: setup,
            builder: (_, value, _) => WorldScene(
              setup: value,
              camera: const WorldCamera(195, 500, .8),
              reduced: true,
            ),
          ),
        ),
      );
      final state = tester.state(find.byType(WorldScene));
      setup.value = inventory;
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(WorldScene)), same(state));
      setup.value = organization;
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(WorldScene)), same(state));
    },
  );
}
