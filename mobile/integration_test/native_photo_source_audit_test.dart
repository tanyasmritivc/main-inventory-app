import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/app_text.dart';
import 'package:mobile/features/chat/auto_extract/extract_style.dart';

// Interactive UIKit audit: operate the actual system sheet in Simulator.
// Stops at source selection; never opens a real camera/library.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in [
    (Brightness.dark, 'Camera', true),
    (Brightness.light, 'Photo Library', false),
    (Brightness.dark, 'Cancel', null),
  ]) {
    testWidgets('UIKit photo source ${scenario.$2} ${scenario.$1.name}', (
      t,
    ) async {
      final completion = Completer<bool?>();
      final anchor = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(scenario.$1),
          builder: (_, child) => AppTypography(child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: anchor,
                  onPressed: () async => completion.complete(
                    await showExtractPhotoSheet(context, anchorKey: anchor),
                  ),
                  child: const AppText('Choose photo source'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Choose photo source'));
      await t.pumpAndSettle();
      debugPrint('NATIVE_PHOTO_ACTION ${scenario.$2} ${scenario.$1.name}');
      final value = await t.runAsync(
        () => completion.future.timeout(const Duration(minutes: 4)),
      );
      expect(value, scenario.$3);
      await t.pumpAndSettle();
      expect(find.text('Choose photo source'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
