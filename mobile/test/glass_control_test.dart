import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/glass_control.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final highContrast in [false, true]) {
      testWidgets(
        '${brightness.name} neutral actions preserve labels, taps and disabled state with contrast $highContrast',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          var saves = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.create(brightness),
              home: MediaQuery(
                data: MediaQueryData(
                  highContrast: highContrast,
                  textScaler: TextScaler.linear(2.6),
                ),
                child: Scaffold(
                  body: Builder(
                    builder: (context) => ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ElevatedButton(
                          onPressed: () => saves++,
                          style: GlassControl.buttonStyle(
                            context,
                            base: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                          child: const Text('Save item'),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: null,
                          style: GlassControl.buttonStyle(
                            context,
                            base: FilledButton.styleFrom(),
                          ),
                          child: const Text('Saving'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Save item').hitTestable(), findsOneWidget);
          expect(
            tester.getSemantics(
              find.widgetWithText(ElevatedButton, 'Save item'),
            ),
            matchesSemantics(
              label: 'Save item',
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              isFocusable: true,
              hasTapAction: true,
              hasFocusAction: true,
            ),
          );
          await tester.tap(find.text('Save item'));
          await tester.pumpAndSettle();
          expect(saves, 1);
          await tester.tap(find.text('Saving'));
          await tester.pumpAndSettle();
          expect(saves, 1);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
      );
    }
  }
}
