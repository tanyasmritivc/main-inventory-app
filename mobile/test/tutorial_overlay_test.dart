import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/showcase/tutorial_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

ThemeData qaTheme(Brightness brightness) {
  final theme = AppTheme.create(brightness);
  if (!const bool.fromEnvironment('FINDEZ_VISUAL_QA')) return theme;
  TextStyle font(TextStyle? s) =>
      (s ?? const TextStyle()).copyWith(fontFamily: 'FindEZQA');
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'FindEZQA'),
    listTileTheme: theme.listTileTheme.copyWith(
      titleTextStyle: font(theme.listTileTheme.titleTextStyle),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: theme.filledButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(
          font(theme.filledButtonTheme.style?.textStyle?.resolve({})),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: theme.textButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(
          font(theme.textButtonTheme.style?.textStyle?.resolve({})),
        ),
      ),
    ),
  );
}

class TourHarness extends StatefulWidget {
  const TourHarness({super.key, this.withSpace = true});
  final bool withSpace;
  @override
  State<TourHarness> createState() => _TourHarnessState();
}

class _TourHarnessState extends State<TourHarness> {
  final pages = PageController();
  @override
  void dispose() {
    TutorialController.instance.dismiss();
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          TextButton(
            onPressed: () => unawaited(
              TutorialController.instance.maybeStart(
                userId: 'tour-user',
                pageController: pages,
                context: context,
              ),
            ),
            child: const Text('Start tour'),
          ),
          Expanded(
            child: PageView(
              controller: pages,
              children: [
                const Center(child: Text('Home')),
                const Center(child: Text('Ask')),
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    key: TutorialController.scanToggleKey,
                    padding: const EdgeInsets.all(16),
                    child: const Text('Photo / Barcode'),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      key: TutorialController.teamsSegmentKey,
                      width: 260,
                      padding: const EdgeInsets.all(16),
                      child: const Text('Spaces / Teams'),
                    ),
                    Container(
                      key: TutorialController.inventorySearchKey,
                      padding: const EdgeInsets.all(16),
                      child: const Text('Search inventory'),
                    ),
                    if (widget.withSpace)
                      Container(
                        key: TutorialController.firstSpaceCardKey,
                        padding: const EdgeInsets.all(24),
                        child: const Text('Workshop'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Icon(
                Icons.home_outlined,
                key: TutorialController.inventoryIconKey,
                size: 36,
              ),
              Icon(
                Icons.chat_bubble_outline,
                key: TutorialController.assistTabKey,
                size: 36,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test',
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
    if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
      await (FontLoader('FindEZQA')..addFont(
            File(
              '/System/Library/Fonts/SFNS.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();

      await (FontLoader('Ahem')..addFont(
            File(
              '/System/Library/Fonts/SFNS.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  setUp(() {
    TutorialController.instance.dismiss();
    SharedPreferences.setMockInitialValues({});
  });
  Future<void> mount(
    WidgetTester tester,
    Brightness brightness, {
    double scale = 1,
    bool withSpace = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('tour-qa'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: qaTheme(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 47, bottom: 34),
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: TourHarness(withSpace: withSpace),
        ),
      ),
    );
    await tester.tap(find.text('Start tour'));
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'all tutorial controls in ${brightness.name}, back and completion',
      (tester) async {
        await mount(tester, brightness);
        final titles = [
          'Start at Home',
          'Capture an item',
          'Ask about saved items',
          'Search your inventory',
          'Open a Space',
          'Work with others',
        ];
        for (var i = 0; i < 6; i++) {
          expect(find.text(titles[i]), findsOneWidget);
          expect(tester.takeException(), isNull);
          final rect = tester.getRect(find.byKey(const Key('tutorial-card')));
          expect(rect.left, greaterThanOrEqualTo(16));
          expect(rect.right, lessThanOrEqualTo(374));
          expect(rect.top, greaterThanOrEqualTo(63));
          expect(rect.bottom, lessThanOrEqualTo(794));
          if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
            await tester.runAsync(() async {
              final image = await tester
                  .renderObject<RenderRepaintBoundary>(
                    find.byKey(const Key('tour-qa')),
                  )
                  .toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '/private/tmp/findez-coach-${brightness.name}-$i.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          if (i == 2) {
            await tester.tap(find.byTooltip('Previous step'));
            await tester.pumpAndSettle();
            expect(find.text(titles[1]), findsOneWidget);
            await tester.tap(find.byKey(const Key('tutorial-next')));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.byKey(const Key('tutorial-next')));
          await tester.pumpAndSettle();
        }
        expect(find.byKey(const Key('tutorial-card')), findsNothing);
        expect(
          (await SharedPreferences.getInstance()).getBool(
            'tutorial_done_tour-user',
          ),
          isTrue,
        );
      },
    );
    for (final scale in [1.6, 2.2, 3.4]) {
      testWidgets(
        'tutorial stays usable with ${scale}x text in ${brightness.name}',
        (tester) async {
          await mount(tester, brightness, scale: scale, withSpace: false);
          for (var i = 0; i < 5; i++) {
            expect(
              find.byKey(const Key('tutorial-next')).hitTestable(),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await tester.tap(find.byKey(const Key('tutorial-next')));
            await tester.pumpAndSettle();
          }
          expect(find.byKey(const Key('tutorial-card')), findsNothing);
        },
      );
    }
  }
  testWidgets('skip saves completion and leaves the app usable', (
    tester,
  ) async {
    await mount(tester, Brightness.light);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tutorial-card')), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'tutorial_done_tour-user',
      ),
      isTrue,
    );
  });
}
