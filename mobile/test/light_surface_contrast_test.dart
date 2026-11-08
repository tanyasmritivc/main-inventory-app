import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/announcements/announcement_widgets.dart';
import 'package:mobile/features/workspaces/place_ui.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  for (final highContrast in [false, true]) {
    testWidgets(
      'light directories and announcements have visible separators, high contrast $highContrast',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(Brightness.light),
            home: MediaQuery(
              data: MediaQueryData(highContrast: highContrast),
              child: Builder(
                builder: (context) {
                  final p = PlacePalette.of(context);
                  final a = AnnouncementColors(context);
                  expect(p.background, const Color(0xFFF6F8F9));
                  expect(p.card, Colors.white);
                  for (final line in [
                    p.separator,
                    p.border,
                    a.hairline,
                    a.ring,
                    Theme.of(context).dividerColor,
                  ]) {
                    expect(
                      line.a,
                      1,
                      reason: 'Separators must not fade against white',
                    );
                    expect(contrast(line, p.card), greaterThanOrEqualTo(2));
                  }
                  for (final text in [
                    p.primary,
                    p.secondary,
                    p.dim,
                    p.label,
                    p.chevron,
                    a.text,
                    a.secondary,
                    a.tertiary,
                  ]) {
                    for (final surface in [p.card, p.background, a.soft]) {
                      expect(
                        contrast(text, surface),
                        greaterThanOrEqualTo(4.5),
                      );
                    }
                  }
                  expect(contrast(p.outline, p.card), greaterThanOrEqualTo(3));
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
