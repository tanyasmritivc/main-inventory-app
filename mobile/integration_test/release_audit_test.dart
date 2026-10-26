// Run the actual app widgets on iOS with synthetic identities and API fixtures.
// This complements (and does not replace) real backend/SQL authorization tests.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:mobile/core/ui/native_presentation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/hierarchy_page_test.dart' as hierarchy;
import '../test/workspace_home_test.dart' as workspace;
import '../test/workspace_deletion_test.dart' as deletion;
import '../test/organization_leave_test.dart' as leave;
import '../test/item_detail_sheet_test.dart' as items;
import '../test/profile_navigation_test.dart' as profile;
import '../test/profile_photo_crop_test.dart' as crop;
import '../test/chat_focus_test.dart' as chat;
import '../test/chat_item_action_test.dart' as actions;
import '../test/task_member_avatar_test.dart' as tasks;
import '../test/account_deletion_test.dart' as account;
import '../test/member_avatar_accessibility_test.dart' as avatar;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('FINDEZ_NATIVE_SCREENSHOTS')) {
    Future<void> capture(String name) async {
      final key = name.startsWith('chat-')
          ? 'chat-focus-qa'
          : 'release-audit-frame';
      final boundary =
          find.byKey(ValueKey(key)).evaluate().single.renderObject!
              as RenderRepaintBoundary;
      final frame = await boundary.toImage(pixelRatio: 2);
      final bytes = (await frame.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      await File(
        '${Directory.systemTemp.path}/findez-audit-$name.png',
      ).writeAsBytes(bytes);
      frame.dispose();
      // Allow the host collector to preserve evidence before test-app cleanup.
      await Future<void>.delayed(const Duration(seconds: 3));
    }

    chat.releaseAuditCapture = capture;
    deletion.releaseAuditCapture = capture;
    profile.releaseAuditCapture = capture;
  }
  group('Native workspace directory', hierarchy.main);
  group('Native organization navigation', workspace.main);
  group('Native move and deletion dialogs', deletion.main);
  group('Native organization leave', leave.main);
  group('Native item details', () {
    // Flutter dialog assertions; actual UIKit controls are inspected separately.
    setUp(() => debugNativePresentationOverride = false);
    tearDown(() => debugNativePresentationOverride = null);
    items.main();
  });
  group('Native profile navigation', () {
    // Flutter dialog assertions; actual UIKit controls are inspected separately.
    setUp(() => debugNativePresentationOverride = false);
    tearDown(() => debugNativePresentationOverride = null);
    profile.main();
  });
  group('Native profile crop', crop.main);
  group('Native focused chat', chat.main);
  group('Native chat actions', () {
    // Flutter dialog assertions; actual UIKit controls are inspected separately.
    setUp(() => debugNativePresentationOverride = false);
    tearDown(() => debugNativePresentationOverride = null);
    actions.main();
  });
  group('Native task attribution', tasks.main);
  group('Native account deletion', account.main);
  group('Native avatar accessibility', avatar.main);
}
