import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/onboarding/onboarding_page.dart';
import 'package:mobile/features/onboarding/onboarding_prefs.dart';

Widget tour({
  VoidCallback? finish,
  bool replay = false,
  bool reduceMotion = false,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Future<void> Function()? writer,
}) => RepaintBoundary(
  key: const Key('onboarding-qa'),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.create(brightness).copyWith(
      textTheme: AppTheme.create(brightness).textTheme.apply(
        fontFamily: const bool.fromEnvironment('FINDEZ_VISUAL_QA')
            ? 'FindEZQA'
            : null,
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
      ),
      child: child!,
    ),
    home: OnboardingPage(
      onFinished: finish,
      isReplay: replay,
      completionWriter: writer,
    ),
  ),
);

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('onboarding-next')));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
      final font = FontLoader('FindEZQA')
        ..addFont(
          File(
            '/System/Library/Fonts/SFNS.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await font.load();
      await (FontLoader('Ahem')..addFont(
            File(
              '/System/Library/Fonts/SFNS.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
            rootBundle.load(
              'packages/cupertino_icons/assets/CupertinoIcons.ttf',
            ),
          ))
          .load();
    }
  });
  if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
    for (final brightness in Brightness.values) {
      testWidgets('visual walkthrough in ${brightness.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(tour(brightness: brightness));
        await tester.pumpAndSettle();
        for (var step = 0; step < 4; step++) {
          if (step == 1) await choose(tester, 'try-sample-capture');
          if (step == 3) await choose(tester, 'sample-world-1');
          expect(tester.takeException(), isNull);
          expect(
            find.text('Interactive example. Nothing is saved.').hitTestable(),
            findsOneWidget,
          );
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('onboarding-qa')),
            );
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/private/tmp/findez-tour-${brightness.name}-$step.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          if (step < 3) await next(tester);
        }
      });
    }
  }
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('four local examples complete without creating account data', (
    tester,
  ) async {
    var finished = 0;
    await tester.pumpWidget(tour(finish: () => finished++));
    await tester.pumpAndSettle();
    expect(find.text('Inventory for\nyour everyday.'), findsOneWidget);
    await choose(tester, 'intro-object-1');
    expect(find.text('USB-C cable'), findsOneWidget);
    await next(tester);
    await choose(tester, 'try-sample-capture');
    expect(find.byKey(const Key('sample-review')), findsOneWidget);
    await choose(tester, 'sample-space-1');
    expect(find.textContaining('Example location: Work.'), findsOneWidget);
    await next(tester);
    expect(find.text('Work'), findsOneWidget);
    await choose(tester, 'sample-question-1');
    expect(find.text('3 in this sample inventory'), findsOneWidget);
    await choose(tester, 'sample-question-2');
    expect(find.text('Possible match'), findsOneWidget);
    await next(tester);
    await choose(tester, 'sample-world-1');
    expect(find.text('Shared inventory'), findsOneWidget);
    expect(find.text('Continue to sign in'), findsOneWidget);
    await next(tester);
    expect(finished, 1);
    expect(await OnboardingPrefs.isCompleted(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'onboarding_completed'});
    expect(await OnboardingPrefs.getPendingFirstSpaceName(), isNull);
  });

  testWidgets('Skip persists completion and exits immediately', (tester) async {
    var finished = 0;
    await tester.pumpWidget(tour(finish: () => finished++));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(finished, 1);
    expect(await OnboardingPrefs.isCompleted(), isTrue);
  });

  testWidgets('sample Ask answer is visible at normal phone size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tour());
    await tester.pumpAndSettle();
    await next(tester);
    await next(tester);
    expect(find.text('Home').hitTestable(), findsOneWidget);
    expect(
      find.text('2 in this sample inventory').hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('back and horizontal swipe retain sample choices', (
    tester,
  ) async {
    await tester.pumpWidget(tour());
    await tester.pumpAndSettle();
    await next(tester);
    await choose(tester, 'try-sample-capture');
    await choose(tester, 'sample-space-2');
    await next(tester);
    await tester.tap(find.byTooltip('Previous step'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Example location: Lab.'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('onboarding-pages')),
      const Offset(-650, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ask a question.\nFind your things.'), findsOneWidget);
    expect(find.text('Lab'), findsOneWidget);
  });

  testWidgets('replay preserves completion, invitations and legacy signup', (
    tester,
  ) async {
    final original = <String, Object>{
      'onboarding_completed': false,
      'onboarding_post_signup_pending': true,
      'onboarding_first_space_name': 'Existing draft',
      'onboarding_persona': 'team',
      'findez.invitation.v1': 'unchanged invitation',
    };
    SharedPreferences.setMockInitialValues(original);
    var finished = 0;
    await tester.pumpWidget(tour(replay: true, finish: () => finished++));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await next(tester);
    }
    expect(find.text('Done'), findsOneWidget);
    await next(tester);
    expect(finished, 1);
    final prefs = await SharedPreferences.getInstance();
    expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, original);
  });

  testWidgets('failed completion stays in the tour and retries safely', (
    tester,
  ) async {
    var writes = 0, finished = 0;
    await tester.pumpWidget(
      tour(
        finish: () => finished++,
        writer: () async {
          writes++;
          if (writes == 1) throw StateError('SECRET native error');
          await OnboardingPrefs.setCompleted(true);
        },
      ),
    );
    await tester.pumpAndSettle();
    await choose(tester, 'intro-object-2');
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(finished, 0);
    expect(await OnboardingPrefs.isCompleted(), isFalse);
    expect(
      find.text('Could not save your progress. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('SECRET'), findsNothing);
    expect(find.text('Sample containers'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(writes, 2);
    expect(finished, 1);
  });

  testWidgets('completion is single-flight and disposal never navigates', (
    tester,
  ) async {
    final write = Completer<void>();
    var writes = 0, finished = 0;
    await tester.pumpWidget(
      tour(
        finish: () => finished++,
        writer: () {
          writes++;
          return write.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    final action = tester
        .widget<TextButton>(find.byKey(const Key('onboarding-skip')))
        .onPressed!;
    action();
    action();
    await tester.pump();
    expect(writes, 1);
    expect(find.text('Saving...'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    write.complete();
    await tester.pumpAndSettle();
    expect(finished, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion advances without waiting for animation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(tour(reduceMotion: true));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Step 1 of 4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    expect(find.text('Capture it.\nMake it yours.'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 2 of 4'), findsOneWidget);
    for (final animation in tester.widgetList<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    )) {
      expect(animation.duration, Duration.zero);
    }
    for (final animation in tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    )) {
      expect(animation.duration, Duration.zero);
    }
    semantics.dispose();
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0, 3.4]) {
      testWidgets('all slides fit 320px / $brightness / text $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          tour(brightness: brightness, textScale: scale, replay: true),
        );
        await tester.pumpAndSettle();
        await choose(tester, 'intro-object-2');
        expect(tester.takeException(), isNull);
        await next(tester);
        await choose(tester, 'try-sample-capture');
        await choose(tester, 'sample-space-1');
        expect(tester.takeException(), isNull);
        await next(tester);
        await choose(tester, 'sample-question-2');
        expect(tester.takeException(), isNull);
        await next(tester);
        await choose(tester, 'sample-world-1');
        expect(tester.takeException(), isNull);
        expect(find.text('Done').hitTestable(), findsOneWidget);
      });
    }
  }

  test(
    'missing and malformed completion flags are treated as fresh installs',
    () async {
      expect(await OnboardingPrefs.isCompleted(), isFalse);
      SharedPreferences.setMockInitialValues({'onboarding_completed': 'true'});
      expect(await OnboardingPrefs.isCompleted(), isFalse);
      SharedPreferences.setMockInitialValues({'onboarding_completed': true});
      expect(await OnboardingPrefs.isCompleted(), isTrue);
    },
  );
}
