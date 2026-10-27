import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/workspaces/place_ui.dart';

void main() {
  double contrast(Color a, Color b) {
    final l1 = a.computeLuminance(), l2 = b.computeLuminance();
    return (math.max(l1, l2) + .05) / (math.min(l1, l2) + .05);
  }

  for (final mode in Brightness.values) {
    for (final highContrast in [false, true]) {
      testWidgets(
        '${mode.name}, contrast=$highContrast preserves theme and readable directory roles',
        (tester) async {
          late PlacePalette palette;
          late ThemeData actual;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.create(mode),
              home: MediaQuery(
                data: MediaQueryData(highContrast: highContrast),
                child: PlaceTheme(
                  child: Builder(
                    builder: (context) {
                      palette = PlacePalette.of(context);
                      actual = Theme.of(context);
                      return Scaffold(
                        body: PlaceCardList(
                          children: [
                            PlaceRow(
                              title: 'Hardware',
                              subtitle: '12 items',
                              onTap: () {},
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          expect(actual.brightness, mode);
          expect(actual.colorScheme.brightness, mode);
          expect(actual.scaffoldBackgroundColor, palette.background);
          for (final surface in [palette.background, palette.card]) {
            expect(contrast(palette.primary, surface), greaterThanOrEqualTo(7));
            for (final color in [
              palette.secondary,
              palette.dim,
              palette.label,
              palette.destructive,
            ]) {
              expect(contrast(color, surface), greaterThanOrEqualTo(4.5));
            }
          }
          expect(
            contrast(Colors.white, palette.darkOrange),
            greaterThanOrEqualTo(4.5),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
