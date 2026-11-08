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
    for (final layout in ['normal', 'large', 'keyboard']) {
      testWidgets('UIKit scan ${brightness.name} $layout', (tester) async {
        // This isolated fixture creates exactly one platform view.
        final nativeId = platformViewsRegistry.getNextPlatformViewId() + 1;
        var status = 'Finding objects...';
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(brightness),
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(layout == 'large' ? 2.6 : 1),
                  ),
                  child: Scaffold(
                    body: SafeArea(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: layout == 'keyboard' ? 320 : double.infinity,
                          height: layout == 'keyboard' ? 260 : 600,
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
