import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/ui/app_colors.dart';
import 'package:mobile/features/shell/home_navigation.dart';

const _labels = ['Home', 'Capture', 'Ask', 'Find', 'Profile'];

void _expectHiddenLabels(WidgetTester tester) {
  final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
  expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysHide);
  expect(bar.indicatorShape, isA<CircleBorder>());
  for (final label in _labels) {
    // The names remain in the semantic tree, but are never painted.
    final fades = tester.widgetList<FadeTransition>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fades.any((fade) => fade.opacity.value == 0), isTrue);
    expect(find.byTooltip(label), findsOneWidget);
  }
}

void main() {
  testWidgets(
    'icons switch every tab with hidden labels and accessible names',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var selected = 0;
        final tapped = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                bottomNavigationBar: HomeNavigation(
                  selectedIndex: selected,
                  onSelected: (index) => setState(() {
                    selected = index;
                    tapped.add(index);
                  }),
                ),
              ),
            ),
          ),
        );

        for (final index in [1, 2, 3, 4, 0]) {
          await tester.tap(find.byType(NavigationDestination).at(index));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            index,
          );
          _expectHiddenLabels(tester);
          for (
            var destination = 0;
            destination < _labels.length;
            destination++
          ) {
            final node = tester.getSemantics(find.text(_labels[destination]));
            expect(
              node.label,
              '${_labels[destination]}\nTab ${destination + 1} of 5',
            );
            expect(
              node.flagsCollection.isSelected,
              destination == index ? ui.Tristate.isTrue : ui.Tristate.isFalse,
            );
            expect(
              node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
              isTrue,
            );
          }
        }
        expect(tapped, [1, 2, 3, 4, 0]);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('saved profile avatar remains visible selected and unselected', (
    tester,
  ) async {
    for (final selected in [0, 4]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: HomeNavigation(
              selectedIndex: selected,
              onSelected: (_) {},
              profileAvatar: const CircleAvatar(
                key: Key('saved-avatar'),
                radius: 12,
                child: Icon(CupertinoIcons.person_fill),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      _expectHiddenLabels(tester);
      expect(find.byKey(const Key('saved-avatar')), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.person_crop_circle), findsNothing);
      expect(find.byIcon(CupertinoIcons.person_crop_circle_fill), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'compact pills keep safe insets outside, centered icons and full tap targets',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      const visualQa = bool.fromEnvironment('FINDEZ_VISUAL_QA');
      if (visualQa) {
        final font = FontLoader('packages/cupertino_icons/CupertinoIcons')
          ..addFont(
            rootBundle.load(
              'packages/cupertino_icons/assets/CupertinoIcons.ttf',
            ),
          );
        await font.load();
      }
      for (final size in [
        const Size(320, 568),
        const Size(390, 844),
        const Size(844, 390),
      ]) {
        for (final parentSafeArea in [false, true]) {
          tester.view.physicalSize = size;
          var selected = -1;
          final insets = EdgeInsets.fromLTRB(
            size.width > size.height ? 44 : 0,
            0,
            size.width > size.height ? 44 : 0,
            34,
          );
          final scaffold = Scaffold(
            backgroundColor: const Color(0xFF09090B),
            body: const SizedBox.expand(key: Key('page-content')),
            bottomNavigationBar: RepaintBoundary(
              key: const Key('nav-visual-qa'),
              child: HomeNavigation(
                selectedIndex: 0,
                onSelected: (index) => selected = index,
              ),
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark().copyWith(
                navigationBarTheme: NavigationBarThemeData(
                  iconTheme: WidgetStateProperty.resolveWith(
                    (states) => IconThemeData(
                      color: states.contains(WidgetState.selected)
                          ? Colors.white
                          : AppColors.muted,
                      size: 22,
                    ),
                  ),
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(3),
                  padding: insets,
                  viewPadding: insets,
                ),
                child: child!,
              ),
              home: parentSafeArea ? SafeArea(child: scaffold) : scaffold,
            ),
          );
          await tester.pumpAndSettle();
          _expectHiddenLabels(tester);
          final pill = find.descendant(
            of: find.byType(HomeNavigation),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is DecoratedBox &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).borderRadius ==
                      BorderRadius.circular(30),
            ),
          );
          expect(pill, findsOneWidget);
          final pillBounds = tester.getRect(pill);
          expect(pillBounds.height, 58); // 56pt bar plus its 1pt border.
          expect(pillBounds.bottom, size.height - 34 - 8);
          expect(pillBounds.left, insets.left + 18);
          expect(pillBounds.right, size.width - insets.right - 18);
          expect(
            tester.getBottomLeft(find.byKey(const Key('page-content'))).dy,
            lessThanOrEqualTo(
              tester.getTopLeft(find.byType(HomeNavigation)).dy,
            ),
          );
          for (var index = 0; index < _labels.length; index++) {
            final destination = find.byType(NavigationDestination).at(index);
            final bounds = tester.getRect(destination);
            expect(bounds.width, greaterThanOrEqualTo(44));
            expect(bounds.height, greaterThanOrEqualTo(44));
            final icon = find.descendant(
              of: destination,
              matching: find.byType(Icon),
            );
            expect(
              tester.getCenter(icon).dy,
              closeTo(pillBounds.center.dy, 0.1),
            );
            await tester.tapAt(Offset(bounds.left + 2, bounds.center.dy));
            expect(selected, index);
          }
          expect(tester.takeException(), isNull);
          if (visualQa && size.width == 390 && parentSafeArea) {
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('nav-visual-qa')),
              );
              final snapshot = await boundary.toImage(pixelRatio: 3);
              try {
                final png = await snapshot.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '/private/tmp/findez-compact-nav-qa.png',
                ).writeAsBytes(
                  png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
                );
              } finally {
                snapshot.dispose();
              }
            });
          }
        }
      }
    },
  );
}
