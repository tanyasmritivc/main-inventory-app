// Actual UIKit registration/layout; request and save contracts stay in host tests.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/chat/native_scan_progress.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final brightness in Brightness.values) {
    for (final layout in ['normal', 'large', 'keyboard', 'keyboard-large']) {
      testWidgets('UIKit scan ${brightness.name} $layout', (tester) async {
        // This isolated fixture creates exactly one platform view.
        final nativeId = platformViewsRegistry.getNextPlatformViewId() + 1;
        var status = 'Finding objects...';
        var reduced = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(brightness),
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: reduced,
                    textScaler: TextScaler.linear(
                      layout.contains('large') ? 2.6 : 1,
                    ),
                  ),
                  child: Scaffold(
                    body: SafeArea(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: layout.startsWith('keyboard')
                              ? 320
                              : double.infinity,
                          height: layout.startsWith('keyboard') ? 260 : 600,
                          child: NativeScanProgress(
                            image: const AssetImage(
                              'assets/onboarding/sample_workbench.jpg',
                            ),
                            message: status,
                            onStop: () {},
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(seconds: 1));
        update(() => status = 'Reading details...');
        await tester.pumpAndSettle();
        debugPrint('NATIVE_CAPTURE_READY scan-${brightness.name}-$layout');
        await Future<void>.delayed(const Duration(seconds: 2));
        expect(find.byType(UiKitView), findsOneWidget);
        final channel = MethodChannel('com.findez.app/scan-progress/$nativeId');
        final geometry = (await channel.invokeMapMethod<String, num>(
          'auditLayout',
        ))!;
        expect(geometry['viewportHeight'], greaterThan(0));
        expect(
          geometry['contentHeight']! + 1,
          greaterThanOrEqualTo(geometry['footerBottom']!),
        );
        expect(geometry['sweepActive'], 1);
        expect(geometry['tipTimerActive'], 1);
        if (layout == 'normal') {
          await Future<void>.delayed(const Duration(seconds: 8));
          final rotated = (await channel.invokeMapMethod<String, num>(
            'auditLayout',
          ))!;
          expect(rotated['tipIndex'], greaterThan(0));
          expect(
            rotated['contentHeight'],
            geometry['contentHeight'],
            reason: 'Tips must not shift the scan layout',
          );
          update(() => reduced = true);
          await tester.pumpAndSettle();
          final quiet = (await channel.invokeMapMethod<String, num>(
            'auditLayout',
          ))!;
          expect(quiet['sweepActive'], 0);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const MaterialApp(home: Text('Draft review')));
        await tester.pumpAndSettle();
        expect(find.byType(UiKitView), findsNothing);
        expect(find.text('Draft review'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
