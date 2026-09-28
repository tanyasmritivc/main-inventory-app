import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';

double _contrast(Color first, Color second) {
  final light = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final dark = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  test('interior body text clears 4.5 to 1 on its used surfaces', () {
    for (final t in [AppTokens.light, AppTokens.dark]) {
      final commonSurfaces = [t.bg, t.card, t.s1, t.s2, t.s3];
      for (final surface in commonSurfaces) {
        expect(_contrast(t.ink, surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(t.text2, surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(t.warn, surface), greaterThanOrEqualTo(4.5));
      }
      for (final surface in [t.bg, t.card, t.s1, t.s2]) {
        expect(_contrast(t.text3, surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(t.accentText, surface), greaterThanOrEqualTo(4.5));
      }
      expect(_contrast(t.onAccent, t.accent), greaterThanOrEqualTo(4.5));
      expect(_contrast(t.paper, t.ink), greaterThanOrEqualTo(4.5));
    }
  });
}
