import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/chat/chat_page.dart';
import 'package:mobile/features/onboarding/scan_entry.dart';
import 'package:mobile/features/scan/scan_camera_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../test/support/hierarchy_fixture.dart';
import '../test/scan_entry_flow_test.dart' show FakeScanCamera;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.6]) {
      testWidgets('scan surfaces ${brightness.name} text $scale', (
        tester,
      ) async {
        fixture.respond = (_) => {
          'items': [],
          'spaces': [],
          'inventories': [],
          'conversations': [],
          'notifications': [],
          'parsed': {},
        };
        final world = ApiClient.forWorld(
          fixture.api,
          'personal',
          isCurrent: () => true,
        );
        for (final entry in <String, Widget>{
          'welcome': const ScanEntryPage(),
          'ask': ChatPage(api: world, worldHeading: 'Personal'),
          'camera': ScanCameraPage(
            api: world,
            cameraFactory: FakeScanCamera.new,
          ),
        }.entries) {
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.create(brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: Scaffold(body: entry.value),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final path =
              '${Directory.systemTemp.path}/scan-${entry.key}-${brightness.name}-$scale.png';
          await File(path).writeAsBytes(
            (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List(),
          );
          image.dispose();
          debugPrint('SCAN_AUDIT_IMAGE $path');
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      });
    }
  }
}
