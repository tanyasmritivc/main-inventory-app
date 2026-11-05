import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/native_presentation.dart';
import 'package:mobile/features/chat/auto_extract/extract_style.dart';

// Retained for older audit entry points. UIKit screenshots are captured natively.
Future<void> Function(String, Uint8List)? photoSheetCapture;

void main() {
  for (final mode in ThemeMode.values) {
    for (final large in [false, true]) {
      testWidgets('photo sheet system actions ${mode.name} large=$large', (
        t,
      ) async {
        debugNativePresentationOverride = false;
        addTearDown(() => debugNativePresentationOverride = null);
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        bool? result;
        var completed = false;
        await t.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(Brightness.light),
            darkTheme: AppTheme.create(Brightness.dark),
            themeMode: mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(large ? 2.6 : 1)),
              child: child!,
            ),
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await showExtractPhotoSheet(context);
                      completed = true;
                    },
                    child: const Text('Open photo'),
                  ),
                ),
              ),
            ),
          ),
        );
        for (final label in ['Camera', 'Photo Library', 'Cancel']) {
          completed = false;
          await t.tap(find.text('Open photo'));
          await t.pumpAndSettle();
          expect(find.text('Add from a photo'), findsNothing);
          expect(find.byType(CupertinoActionSheet), findsOneWidget);
          await t.tap(find.text(label));
          await t.pumpAndSettle();
          expect(completed, isTrue);
          expect(result, label == 'Cancel' ? null : label == 'Camera');
          expect(find.text('Open photo'), findsOneWidget);
          expect(t.takeException(), isNull);
        }
      });
    }
  }
  for (final action in ['camera', 'library', 'cancel', 'error']) {
    testWidgets('native photo source returns $action after dismissal', (
      t,
    ) async {
      debugNativePresentationOverride = true;
      addTearDown(() => debugNativePresentationOverride = null);
      final reply = Completer<Map<String, dynamic>?>();
      Map? presented;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        NativePresentation.channel,
        (call) async {
          if (call.method == 'present') {
            presented = call.arguments as Map;
            return reply.future;
          }
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          NativePresentation.channel,
          null,
        ),
      );
      bool? value;
      bool done = false;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  value = await showExtractPhotoSheet(context);
                  done = true;
                },
                child: const Text('Open native'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open native'));
      await t.pumpAndSettle();
      expect(presented?['kind'], 'photoSource');
      expect(done, isFalse);
      expect(find.text('Add from a photo'), findsNothing);
      if (action == 'error') {
        reply.completeError(PlatformException(code: 'presentation_busy'));
      } else {
        reply.complete(action == 'cancel' ? null : {'action': action});
      }
      await t.pumpAndSettle();
      expect(done, isTrue);
      expect(value, switch (action) {
        'camera' => true,
        'library' => false,
        _ => null,
      });
      if (action == 'error') {
        expect(
          find.text('Could not open this control. Please try again.'),
          findsOneWidget,
        );
      }
    });
  }
}
