import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/inventory_chat_test.dart' as inventory;
import '../test/workspace_home_test.dart' as workspace;

Future<void> capture(WidgetTester tester, String key, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(ValueKey(key)),
  );
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
  final path = '${Directory.systemTemp.path}/consistency181-$key-$name.png';
  await File(path).writeAsBytes(bytes);
  image.dispose();
  debugPrint('TYPOGRAPHY_IMAGE $path');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('inventory', () {
    inventory.main(
      capture: (tester, name) => capture(tester, 'inventory-frame', name),
    );
  });
  group('workspace', () {
    workspace.workspaceCapture = (tester, name) =>
        capture(tester, 'workspace-frame', name);
    workspace.main();
  });
}
