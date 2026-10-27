import 'dart:math' as math;
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'pending_world.dart';

class WorldCamera {
  const WorldCamera(this.x, this.y, this.scale);
  final double x, y, scale;
  static WorldCamera lerp(WorldCamera a, WorldCamera b, double t) =>
      WorldCamera(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.scale + (b.scale - a.scale) * t,
      );
  Offset project(double x, double y, double z) => Offset(
    this.x + scale * (x - y) * math.sqrt(3) / 2,
    this.y + scale * ((x + y) / 2 - z),
  );
}

double backOut(double t) =>
    1 + 2.5 * math.pow(t - 1, 3) + 1.5 * math.pow(t - 1, 2);
double phase(double milliseconds, double start, double duration) =>
    ((milliseconds - start) / duration).clamp(0.0, 1.0);

/// The canvas listens directly to this model. Animation ticks do not rebuild
/// the step tree. Interrupted camera moves always start at the visible camera.
class WorldModel extends ChangeNotifier {
  WorldModel(
    TickerProvider vsync,
    this.setup,
    WorldCamera initial, {
    this.mini = false,
    this.personalMini = false,
    this.reduced = false,
  }) : _from = initial,
       _to = initial {
    AnimationController make(int ms, double value) {
      final controller = AnimationController(
        vsync: vsync,
        duration: Duration(milliseconds: ms),
        value: value,
      )..addListener(notifyListeners);
      _controllers.add(controller);
      return controller;
    }

    cameraMove = make(800, 1);
    block = make(700, hasBlock ? 1 : 0);
    tray = make(600, hasTray ? 1 : 0);
    drops = make(1970, hasTray ? 1 : 0);
    ghost = make(1600, hasBlock ? 1 : 0);
    blockSettle = make(300, 1);
    traySettle = make(300, 1);
    organizationTag = make(400, organization.isNotEmpty ? 1 : 0);
    blockTag = make(800, hasBlock ? 1 : 0);
    trayTag = make(800, hasTray ? 1 : 0);
    tags = make(300, isRecap ? 0 : 1);
    world = make(180, shown ? 1 : 0);
    shadow = make(1200, shown ? 1 : 0);
    exit = make(900, 0);
  }
  PendingWorld setup;
  final bool mini, personalMini;
  bool reduced;
  final _controllers = <AnimationController>[];
  late final AnimationController cameraMove,
      block,
      tray,
      drops,
      ghost,
      blockSettle,
      traySettle,
      organizationTag,
      blockTag,
      trayTag,
      tags,
      world,
      shadow,
      exit;
  WorldCamera _from, _to;
  bool get personal => personalMini || !setup.isTeam;
  String get organization => personal ? 'Personal' : setup.orgName.trim();
  bool get shown => mini || setup.step.index > WorldStep.choose.index;
  bool get isRecap =>
      setup.step == WorldStep.world || setup.step == WorldStep.auth;
  bool get hasBlock =>
      mini ||
      (setup.step.index >= WorldStep.workspace.index &&
          setup.workspacePurpose.isNotEmpty);
  bool get hasTray =>
      (mini && !personalMini) ||
      (!mini &&
          setup.step.index >= WorldStep.inventory.index &&
          setup.inventoryName.isNotEmpty);
  WorldCamera get camera => WorldCamera.lerp(
    _from,
    _to,
    Curves.easeInOutCubic.transform(cameraMove.value),
  );
  double get opacity => world.value * (1 - phase(exit.value * 900, 300, 500));
  double get shadowOpacity => mini ? 0 : phase(shadow.value * 1200, 400, 800);
  double get blockHeight =>
      math.max(0, backOut(block.value)) *
      (.96 + .04 * backOut(blockSettle.value));
  double get trayHeight =>
      math.max(0, backOut(tray.value)) *
      (.96 + .04 * backOut(traySettle.value));
  double get ghostOpacity =>
      !mini && hasBlock ? phase(ghost.value * 1600, 1000, 600) : 0;
  double get blockTagOpacity =>
      phase(blockTag.value * 800, 400, 400) * tags.value;
  double get trayTagOpacity =>
      phase(trayTag.value * 800, 400, 400) * tags.value;
  double get organizationTagOpacity => organizationTag.value * tags.value;
  double get itemsTime => hasTray ? drops.value * 1.97 : -1;
  double itemProgress(int index) =>
      phase(itemsTime * 1000, 800 + index * 120, 450);
  double itemElevation(int index) {
    final progress = itemProgress(index);
    return progress < .75
        ? 80 * (1 - Curves.easeOutCubic.transform(progress / .75))
        : math.sin((progress - .75) / .25 * math.pi) * 6;
  }

  void _toValue(AnimationController controller, double target) {
    if (controller.value == target && !controller.isAnimating) return;
    if (reduced) {
      controller.value = target;
    } else if (target == 1) {
      controller.forward();
    } else {
      controller.reverse();
    }
  }

  void moveTo(WorldCamera target, {required int milliseconds}) {
    if (_to.x == target.x && _to.y == target.y && _to.scale == target.scale) {
      return;
    }
    _from = camera;
    _to = target;
    cameraMove.duration = Duration(milliseconds: milliseconds);
    reduced ? cameraMove.value = 1 : cameraMove.forward(from: 0);
  }

  void update(
    PendingWorld next,
    WorldCamera target, {
    required bool reduce,
    WorldCamera? tileOrigin,
    bool focused = false,
  }) {
    final previous = setup;
    final oldBlock = hasBlock, oldTray = hasTray, wasShown = shown;
    final oldOrganization = organization;
    setup = next;
    reduced = reduce;
    if (!wasShown && shown && tileOrigin != null) {
      _from = _to = tileOrigin;
      cameraMove.value = 1;
      shadow.value = 0;
      _toValue(shadow, 1);
    }
    final duration = focused
        ? 350
        : previous.step == next.step
        ? 500
        : next.step == WorldStep.workspace
        ? 700
        : next.step == WorldStep.auth
        ? 900
        : 800;
    moveTo(target, milliseconds: duration);
    _toValue(world, shown ? 1 : 0);
    if (oldOrganization.isEmpty && organization.isNotEmpty) {
      _toValue(organizationTag, 1);
    }
    if (hasBlock != oldBlock) {
      _toValue(block, hasBlock ? 1 : 0);
      _toValue(blockTag, hasBlock ? 1 : 0);
      if (hasBlock && ghost.value == 0) _toValue(ghost, 1);
    } else if (hasBlock && previous.workspacePurpose != next.workspacePurpose) {
      reduced ? blockSettle.value = 1 : blockSettle.forward(from: 0);
    }
    if (hasTray != oldTray) {
      _toValue(tray, hasTray ? 1 : 0);
      _toValue(trayTag, hasTray ? 1 : 0);
      _toValue(drops, hasTray ? 1 : 0);
    } else if (hasTray && previous.inventoryName != next.inventoryName) {
      reduced ? traySettle.value = 1 : traySettle.forward(from: 0);
    }
    _toValue(tags, isRecap ? 0 : 1);
    if (next.step == WorldStep.auth && previous.step != WorldStep.auth) {
      _toValue(exit, 1);
    }
    if (reduce) {
      block.value = hasBlock ? 1 : 0;
      tray.value = drops.value = hasTray ? 1 : 0;
      blockTag.value = hasBlock ? 1 : 0;
      trayTag.value = hasTray ? 1 : 0;
      shadow.value = shown ? 1 : 0;
      ghost.value = hasBlock ? 1 : 0;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
