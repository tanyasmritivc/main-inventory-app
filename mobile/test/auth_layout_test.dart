import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/auth_page.dart';
import 'onboarding_page_test.dart' show qaTheme;

Widget auth(Brightness brightness, double scale) => RepaintBoundary(
  key: const Key('auth-qa'),
  child: MaterialApp(
    theme: qaTheme(brightness).copyWith(platform: TargetPlatform.iOS),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: const AuthPage(),
  ),
);

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
      await (FontLoader('FindEZQA')..addFont(
            File(
              '/System/Library/Fonts/SFNS.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.2, 3.4]) {
      testWidgets(
        'auth controls remain reachable at 320pt ${brightness.name} ${scale}x',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(auth(brightness, scale));
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const Key('auth-more-options')),
          );
          await tester.tap(find.byKey(const Key('auth-more-options')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const Key('auth-email-option')),
          );
          await tester.tap(find.byKey(const Key('auth-email-option')));
          await tester.pumpAndSettle();
          for (final label in [
            'Forgot password?',
            'Continue with Apple',
            'Continue with Google',
            'New here? Create account',
          ]) {
            await tester.ensureVisible(find.text(label));
            await tester.pumpAndSettle();
            expect(find.text(label).hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await tester.tap(find.text('New here? Create account'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Work details (optional)'));
          await tester.tap(find.text('Work details (optional)'));
          await tester.pumpAndSettle();
          for (final label in ['Role (optional)', 'Organization (optional)']) {
            final field = find.byWidgetPredicate(
              (widget) =>
                  widget is TextField && widget.decoration?.labelText == label,
            );
            await tester.ensureVisible(field);
            await tester.pumpAndSettle();
            expect(field.hitTestable(), findsOneWidget);
          }
          await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Create account'),
          );
          await tester.pumpAndSettle();
          expect(
            find.widgetWithText(FilledButton, 'Create account').hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
    if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
      testWidgets('render auth ${brightness.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(auth(brightness, 1));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('auth-qa')),
              )
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/private/tmp/findez-auth-${brightness.name}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
