import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/app_colors.dart';
import 'package:mobile/core/ui/brand_colors.dart';
import 'package:mobile/core/ui/findez_wordmark.dart';
import 'package:mobile/core/ui/primary_gradient_button.dart';
import 'package:mobile/features/inventory/item_editor_sheet.dart';

double _contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  test('exact guide tokens and monochrome legacy UI roles', () {
    expect(BrandColors.ink.toARGB32(), 0xFF111112);
    expect(BrandColors.signal.toARGB32(), 0xFFE8590C);
    expect(BrandColors.paper.toARGB32(), 0xFFFFFFFF);
    expect(BrandColors.surface.toARGB32(), 0xFFF7F7F6);
    expect(BrandColors.hairline.toARGB32(), 0xFFE6E6E2);
    expect(BrandColors.inkSoft.toARGB32(), 0xFF5B5B60);
    expect(BrandColors.inkMuted.toARGB32(), 0xFF96969C);
    expect(BrandColors.warning.toARGB32(), 0xFF8A5A00);
    expect(BrandColors.success.toARGB32(), 0xFF2F7D5A);
    expect(BrandColors.danger.toARGB32(), 0xFFC9363E);
    for (final brightness in Brightness.values) {
      final theme = AppTheme.create(brightness);
      expect(theme.colorScheme.primary, BrandColors.signal);
      expect(theme.colorScheme.onPrimary, BrandColors.ink);
      expect(theme.bottomSheetTheme.showDragHandle, isFalse);
      final scheme = theme.colorScheme;
      for (final pair in [
        (scheme.primary, scheme.onPrimary),
        (scheme.primaryContainer, scheme.onPrimaryContainer),
        (scheme.secondary, scheme.onSecondary),
        (scheme.secondaryContainer, scheme.onSecondaryContainer),
        (scheme.tertiary, scheme.onTertiary),
        (scheme.tertiaryContainer, scheme.onTertiaryContainer),
        (scheme.surface, scheme.onSurface),
        (scheme.surface, scheme.onSurfaceVariant),
        (scheme.error, scheme.onError),
        (scheme.errorContainer, scheme.onErrorContainer),
      ]) {
        expect(_contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
      for (final retired in [0xFF6997DD, 0xFFA78BFA, 0xFF64D2FF, 0xFFFF7A2F]) {
        expect(
          AppTheme.resolve(brightness, Color(retired)),
          brightness == Brightness.dark
              ? AppTheme.darkTextSecondary
              : BrandColors.inkSoft,
        );
      }
      for (final status in [
        AppColors.warning,
        AppColors.success,
        AppColors.danger,
      ]) {
        final resolved = AppTheme.resolve(brightness, status);
        expect(resolved, isNot(BrandColors.signal));
        for (final surface in [
          theme.scaffoldBackgroundColor,
          theme.colorScheme.surface,
          theme.colorScheme.surfaceContainer,
        ]) {
          expect(_contrast(resolved, surface), greaterThanOrEqualTo(4.5));
        }
      }
    }
    expect(
      AppTheme.resolve(Brightness.light, AppColors.warning),
      BrandColors.warning,
    );
    expect(
      AppTheme.resolve(Brightness.light, AppColors.success),
      BrandColors.success,
    );
    expect(
      AppTheme.resolve(Brightness.light, AppColors.danger),
      BrandColors.danger,
    );
    expect(
      _contrast(BrandColors.ink, BrandColors.signal),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('native icon is a full opaque square with original signal/paper', () {
    final icon = image.decodePng(
      File('assets/brand/findez-app-icon.png').readAsBytesSync(),
    )!;
    expect([icon.width, icon.height, icon.numChannels], [1024, 1024, 3]);
    expect(icon.getPixel(0, 0).toList(), [17, 17, 18]);
    expect(icon.getPixel(600, 300).toList(), [232, 89, 12]);
    expect(icon.getPixel(400, 400).toList(), [255, 255, 255]);
  });

  test(
    'original mark and outlined wordmark retain overlap and square joins',
    () async {
      for (final name in ['findez-mark.svg', 'findez-wordmark.svg']) {
        final svg = await rootBundle.loadString('assets/brand/$name');
        expect(svg, contains('M25.25 40.75H55.25V70.75'));
        expect(svg, contains('M50.25 30.75H65.25V45.75'));
        expect(svg, contains('stroke-linejoin="miter"'));
        expect(svg, contains('stroke-linecap="butt"'));
        expect(svg, isNot(contains('<text')));
        expect(svg, isNot(contains('Gradient')));
      }
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} resolved text stays readable in children', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(brightness),
          home: Builder(
            builder: (context) {
              final primary = AppTheme.adaptive(context, Colors.white);
              expect(
                AppTheme.foreground(context, primary),
                AppTheme.textPrimary(context),
              );
              expect(
                _contrast(
                  AppTheme.foreground(context, primary),
                  AppTheme.surface(context),
                ),
                greaterThanOrEqualTo(4.5),
              );
              // Legacy selected controls invert a white surface/black label
              // together; don't confuse their black label with resolved Ink.
              expect(
                _contrast(
                  AppTheme.foreground(context, Colors.black),
                  AppTheme.adaptive(context, Colors.white),
                ),
                greaterThanOrEqualTo(4.5),
              );
              return const Scaffold();
            },
          ),
        ),
      );
    });

    testWidgets(
      '${brightness.name} wordmark preserves orange and only reverses ink',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(brightness),
            home: const Scaffold(body: FindEZWordmark()),
          ),
        );
        await tester.pumpAndSettle();
        final loader =
            tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader
                as SvgAssetLoader;
        final mapper = loader.colorMapper;
        if (brightness == Brightness.dark) {
          expect(
            mapper!.substitute(null, 'path', 'stroke', BrandColors.ink),
            BrandColors.paper,
          );
          expect(
            mapper.substitute(null, 'path', 'stroke', BrandColors.signal),
            BrandColors.signal,
          );
        } else {
          expect(mapper, isNull);
        }
        expect(find.bySemanticsLabel('FindEZ'), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets('${brightness.name} primary button is flat and contrast safe', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(brightness),
          home: Scaffold(
            body: PrimaryGradientButton(
              onPressed: () {},
              child: const Text('Continue'),
            ),
          ),
        ),
      );
      final ink = tester.widget<Ink>(find.byType(Ink));
      final decoration = ink.decoration! as BoxDecoration;
      expect(decoration.gradient, isNull);
      expect(decoration.color, BrandColors.signal);
      expect(
        DefaultTextStyle.of(tester.element(find.text('Continue'))).style.color,
        BrandColors.ink,
      );
    });

    for (final scale in [1.0, 2.6]) {
      testWidgets(
        '${brightness.name} edit sheet has one handle at $scale text',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final item = InventoryItem.fromJson({
            'item_id': 'fixture',
            'name': 'Cable',
            'category': 'Electronics',
            'location': 'Workshop',
            'quantity': 2,
          });
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.create(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showModalBottomSheet<ItemEditorResult>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ItemEditorSheet(item: item),
                    ),
                    child: const Text('Open editor'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open editor'));
          await tester.pumpAndSettle();
          final handle = find.byKey(const ValueKey('item-editor-drag-handle'));
          expect(handle, findsOneWidget);
          expect(
            tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
            isFalse,
          );
          expect(
            tester.getTopLeft(handle).dy -
                tester.getTopLeft(find.byType(ItemEditorSheet)).dy,
            // Container bounds include its margin; only the 0.5pt sheet border
            // precedes it, with no extra native handle/header above it.
            closeTo(.5, .1),
          );
          await tester.ensureVisible(find.text('Cancel'));
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(find.byType(ItemEditorSheet), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
