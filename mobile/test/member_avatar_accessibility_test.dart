import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/member_avatar.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} avatar initials fit at largest text size', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3.4)),
            child: child!,
          ),
          home: const Scaffold(
            body: Center(child: MemberAvatar(name: 'Willow', size: 32)),
          ),
        ),
      );
      final avatar = tester.getRect(find.byType(MemberAvatar));
      final initial = tester.getRect(find.text('W'));
      expect(avatar.deflate(3).contains(initial.topLeft), isTrue);
      expect(avatar.deflate(3).contains(initial.bottomRight), isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
