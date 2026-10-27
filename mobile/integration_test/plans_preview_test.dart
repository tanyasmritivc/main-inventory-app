import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/profile/plans_page.dart';
import 'package:mobile/features/profile/plans_welcome.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.6]) {
      testWidgets('signup plans popup ${brightness.name} text $scale', (
        tester,
      ) async {
        final boundary = GlobalKey();
        var closed = false;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
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
              home: Scaffold(
                body: PlansWelcomeDialog(onClose: () => closed = true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        final path =
            '${Directory.systemTemp.path}/plans-${brightness.name}-$scale.png';
        await File(path).writeAsBytes(bytes);
        debugPrint('PLANS_AUDIT_IMAGE $path');
        image.dispose();
        await tester.scrollUntilVisible(find.text('Yearly'), 120);
        await tester.tap(find.text('Yearly'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Team'), 100);
        await tester.tap(find.text('Team'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('\$299/year'), 140);
        expect(find.text('\$299/year'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('10 people included'), 140);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Continue with Free'));
        await tester.pumpAndSettle();
        expect(closed, isTrue);
        await tester.pumpWidget(const SizedBox());
      });
    }
    testWidgets('plan comparison on iOS in ${brightness.name}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(brightness),
          home: const PlansPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(plansNotice), findsOneWidget);
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('\$99/year'), 200);
      expect(find.text('\$99/year'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('\$299/year'), 200);
      expect(find.text('\$299/year'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('How the planned limits work'),
        200,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
