import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/chat/auto_extract/extract_style.dart';

Future<void> Function(String, Uint8List)? photoSheetCapture;

void main() {
  if (const bool.fromEnvironment('PHOTO_SHEET_VISUAL')) {
    photoSheetCapture = (name, bytes) async {
      await File('/private/tmp/$name.png').writeAsBytes(bytes);
    };
  }
  for (final mode in ThemeMode.values) {
    for (final compact in [false, true]) {
      testWidgets('photo sheet ${mode.name} compact=$compact', (t) async {
        t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
        addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
        t.view.physicalSize = compact
            ? const Size(320, 568)
            : const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetViewInsets);
        bool? result;
        var completed = false;
        await t.pumpWidget(
          RepaintBoundary(
            key: const Key('photo-sheet-frame'),
            child: MaterialApp(
              theme: AppTheme.create(Brightness.light),
              darkTheme: AppTheme.create(Brightness.dark),
              themeMode: mode,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(compact ? 2.6 : 1),
                  boldText: true,
                  disableAnimations: compact,
                ),
                child: child!,
              ),
              home: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: TextButton(
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
            ),
          ),
        );
        for (final choice in ['Camera', 'Library']) {
          completed = false;
          await t.tap(find.text('Open photo'));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          final sheet = find.byKey(const ValueKey('auto-extract-source-sheet'));
          Color sheetColor() => t.widget<Material>(sheet).color!;
          expect(sheetColor().computeLuminance() > .5, mode != ThemeMode.dark);
          if (mode == ThemeMode.system) {
            t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
            await t.pumpAndSettle();
            expect(sheetColor().computeLuminance(), lessThan(.1));
            t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
            await t.pumpAndSettle();
            expect(sheetColor().computeLuminance(), greaterThan(.5));
          }
          for (final button in t.widgetList<FilledButton>(
            find.byType(FilledButton),
          )) {
            final style = button.style!;
            final color = style.backgroundColor!.resolve({})!;
            expect(color.a, 1);
            final marker = Container();
            expect(
              style.backgroundBuilder!(t.element(sheet), {}, marker),
              same(marker),
            );
            expect(style.shape!.resolve({}), isA<StadiumBorder>());
          }
          if (!compact) expect(t.getSize(sheet).height, lessThan(300));
          if (photoSheetCapture != null) {
            await t.runAsync(() async {
              final boundary = t.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('photo-sheet-frame')),
              );
              final image = await boundary.toImage(pixelRatio: 2);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await photoSheetCapture!(
                'photo-sheet-${mode.name}-$compact',
                data!.buffer.asUint8List(),
              );
              image.dispose();
            });
          }
          for (final label in ['Add from a photo', 'Camera', 'Library']) {
            final richText = find.descendant(
              of: find.text(label),
              matching: find.byType(RichText),
            );
            expect(
              (t.widget<RichText>(richText).text as TextSpan).style!.fontWeight,
              FontWeight.w400,
            );
            final style = t.widget<RichText>(richText).text.style!;
            expect(style.fontFamily, 'CupertinoSystemText');
            expect(style.fontSize, label == 'Add from a photo' ? 20 : 16);
          }
          // A pre-existing keyboard must not hide the final source choice.
          if (compact) {
            t.view.viewInsets = const FakeViewPadding(bottom: 216);
            await t.pumpAndSettle();
          }
          await t.ensureVisible(find.text(choice));
          await t.pumpAndSettle();
          expect(find.text(choice).hitTestable(), findsOneWidget);
          await t.tap(find.text(choice));
          await t.pumpAndSettle();
          expect(result, choice == 'Camera');
          expect(completed, isTrue);
          expect(find.text('Open photo'), findsOneWidget);
          expect(t.takeException(), isNull);
          t.view.resetViewInsets();
          await t.pumpAndSettle();
        }
        completed = false;
        await t.tap(find.text('Open photo'));
        await t.pumpAndSettle();
        await t.dragFrom(
          t.getTopLeft(
                find.byKey(const ValueKey('auto-extract-source-handle')),
              ) +
              const Offset(18, 2),
          const Offset(0, 160),
        );
        await t.pumpAndSettle();
        expect(completed, isTrue);
        expect(result, isNull);
        completed = false;
        await t.tap(find.text('Open photo'));
        await t.pumpAndSettle();
        await t.tapAt(const Offset(12, 12));
        await t.pumpAndSettle();
        expect(completed, isTrue);
        expect(result, isNull);
        expect(find.text('Open photo'), findsOneWidget);
      });
    }
  }
}
