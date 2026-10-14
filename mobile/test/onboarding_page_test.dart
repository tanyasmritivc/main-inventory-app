import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/onboarding/onboarding_page.dart';
import 'package:mobile/features/onboarding/onboarding_answers.dart';
import 'package:mobile/features/onboarding/onboarding_prefs.dart';

ThemeData qaTheme(Brightness brightness) {
  final theme = AppTheme.create(brightness);
  if (!const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
    return theme;
  }
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

class SetupApi extends ApiClient {
  SetupApi({this.actor = 'account-a', this.fail = false, this.pending})
    : super(baseUrl: 'https://api.test');
  String? actor;
  bool fail;
  Completer<void>? pending;
  Map<String, dynamic>? record;
  final writes = <({String? owner, Map<String, dynamic> answers})>[];
  @override
  String? get accountId => actor;
  @override
  Future<Map<String, dynamic>?> getOnboardingAnswers() async => record;
  @override
  Future<void> saveOnboardingAnswers(Map<String, dynamic> answers) async {
    final owner = actor;
    if (pending != null) await pending!.future;
    if (fail) throw StateError('offline');
    writes.add((owner: owner, answers: answers));
    record = answers;
  }
}

const answers = OnboardingAnswers(
  useCase: 'business',
  inventoryTypes: ['tools', 'equipment'],
  primaryGoal: 'find_items',
  collaboration: 'others',
);
Widget setup({
  ApiClient? api,
  Brightness brightness = Brightness.light,
  double scale = 1,
  bool replay = false,
  bool reduceMotion = true,
  VoidCallback? done,
  Future<void> Function()? writer,
}) => RepaintBoundary(
  key: const Key('setup-qa'),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: qaTheme(brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: reduceMotion,
      ),
      child: child!,
    ),
    home: OnboardingPage(
      api: api,
      isReplay: replay,
      onFinished: done,
      completionWriter: writer,
    ),
  ),
);
Future<void> choose(WidgetTester tester, String key) async {
  final finder = find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(Icon),
  );
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('onboarding-next')));
  await tester.pumpAndSettle();
}

Future<void> answerAll(WidgetTester tester, {bool submit = true}) async {
  for (final key in [
    'setup-use-household',
    'setup-inventory-tools',
    'setup-goal-find_items',
    'setup-collaboration-solo',
  ]) {
    await choose(tester, key);
    if (key != 'setup-collaboration-solo' || submit) await next(tester);
  }
}

void main() {
  testWidgets('questionnaire has a small accessible X and no brand header', (
    tester,
  ) async {
    await tester.pumpWidget(setup());
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsNothing);
    expect(find.text('Skip'), findsNothing);
    final close = find.byKey(const Key('onboarding-skip'));
    expect(tester.widget<IconButton>(close).tooltip, 'Skip setup');
    expect((tester.widget<IconButton>(close).icon as Icon).size, 18);
    expect(tester.getSize(close).shortestSide, greaterThanOrEqualTo(44));
    expect(find.text('What will you use FindEZ for?'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'FindEZWordmark',
      ),
      findsNothing,
    );
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
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
  testWidgets(
    'four answers are queued without inventory or unauthenticated API writes',
    (tester) async {
      var done = 0;
      await tester.pumpWidget(setup(done: () => done++));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('onboarding-next')))
            .onPressed,
        isNull,
      );
      await answerAll(tester);
      expect(done, 1);
      expect(await OnboardingPrefs.isCompleted(), isTrue);
      expect(await OnboardingPrefs.getPendingFirstSpaceName(), isNull);
      final saved = await OnboardingAnswerStore.pendingFor('account-a');
      expect(saved?.useCase, 'household');
      expect(saved?.inventoryTypes, ['tools']);
      expect(saved?.primaryGoal, 'find_items');
      expect(saved?.collaboration, 'solo');
      expect(await OnboardingAnswerStore.pendingFor('account-b'), isNull);
    },
  );
  testWidgets('multi-select, Back and custom input retain the real draft', (
    tester,
  ) async {
    await tester.pumpWidget(setup());
    await choose(tester, 'setup-use-other');
    await tester.enterText(find.byType(TextField), 'Costume department');
    await tester.pumpAndSettle();
    await next(tester);
    await choose(tester, 'setup-inventory-tools');
    await choose(tester, 'setup-inventory-other');
    await tester.enterText(find.byType(TextField), 'Fabric and props');
    await tester.pumpAndSettle();
    await next(tester);
    await tester.tap(find.byTooltip('Previous step'));
    await tester.pumpAndSettle();
    expect(find.text('Fabric and props'), findsOneWidget);
    await next(tester);
    await choose(tester, 'setup-goal-organize_spaces');
    await next(tester);
    await choose(tester, 'setup-collaboration-others');
    await next(tester);
    final a = await OnboardingAnswerStore.pendingFor('account-a');
    expect(a?.useCaseOther, 'Costume department');
    expect(a?.inventoryTypes, containsAll(['tools', 'other']));
    expect(a?.inventoryOther, 'Fabric and props');
  });
  testWidgets('assistive activation selects single and multiple choices', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(setup());
      await tester.pumpAndSettle();
      for (final key in ['setup-use-business', 'setup-inventory-tools']) {
        final finder = find.byKey(Key(key));
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        final node = tester.getSemantics(finder);
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        tester.binding.performSemanticsAction(
          ui.SemanticsActionEvent(
            viewId: tester.view.viewId,
            nodeId: node.id,
            type: ui.SemanticsAction.tap,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<Semantics>(finder).properties.selected, isTrue);
        await next(tester);
      }
    } finally {
      semantics.dispose();
    }
  });
  testWidgets(
    'animated transitions resist repeated taps and preserve answers',
    (tester) async {
      await tester.pumpWidget(setup(reduceMotion: false));
      await choose(tester, 'setup-use-business');
      final page = tester
          .widget<PageView>(find.byKey(const Key('onboarding-pages')))
          .controller!;
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(page.page, greaterThan(0));
      expect(page.page, lessThan(1));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('onboarding-next')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(page.page, 1);
      await tester.tap(find.byTooltip('Previous step'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('setup-use-business')))
            .properties
            .selected,
        isTrue,
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Skip does not fabricate answers or clear pending signup choices',
    (tester) async {
      await OnboardingPrefs.setPendingFirstSpaceName('Existing draft');
      var done = 0;
      await tester.pumpWidget(setup(done: () => done++));
      await tester.tap(find.byKey(const Key('onboarding-skip')));
      await tester.pumpAndSettle();
      expect(done, 1);
      expect(await OnboardingAnswerStore.pendingFor('account-a'), isNull);
      expect(
        await OnboardingPrefs.getPendingFirstSpaceName(),
        'Existing draft',
      );
    },
  );
  testWidgets('signed-in save retries without losing answers', (tester) async {
    final api = SetupApi(fail: true);
    var done = 0;
    await tester.pumpWidget(setup(api: api, replay: true, done: () => done++));
    await tester.pumpAndSettle();
    await answerAll(tester);
    expect(done, 0);
    expect(find.textContaining('Could not save your setup'), findsOneWidget);
    expect(
      (await OnboardingAnswerStore.pendingFor('account-a'))?.inventoryTypes,
      ['tools'],
    );
    api.fail = false;
    await next(tester);
    expect(done, 1);
    expect(api.writes.length, 1);
    expect(await OnboardingAnswerStore.pendingFor('account-a'), isNull);
    expect(await OnboardingPrefs.isCompleted(), isFalse);
  });
  testWidgets('saved answers prefill replay and can be edited', (tester) async {
    final api = SetupApi()..record = answers.toJson();
    await tester.pumpWidget(setup(api: api, replay: true));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('setup-use-business')))
          .properties
          .selected,
      isTrue,
    );
    await choose(tester, 'setup-use-laboratory');
    await next(tester);
    await next(tester);
    await next(tester);
    await next(tester);
    expect(api.record?['use_case'], 'laboratory');
    expect(api.record?['inventory_types'], ['equipment', 'tools']);
  });
  testWidgets('pending save disables duplicate actions and completion', (
    tester,
  ) async {
    final wait = Completer<void>();
    final api = SetupApi(pending: wait);
    var done = 0;
    await tester.pumpWidget(setup(api: api, replay: true, done: () => done++));
    await tester.pumpAndSettle();
    await answerAll(tester, submit: false);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('onboarding-next')))
          .onPressed,
      isNull,
    );
    expect(done, 0);
    wait.complete();
    await tester.pumpAndSettle();
    expect(done, 1);
    expect(api.writes.length, 1);
  });
  testWidgets('account switch during save cannot finish or copy the draft', (
    tester,
  ) async {
    final wait = Completer<void>();
    final api = SetupApi(pending: wait);
    var done = 0;
    await tester.pumpWidget(setup(api: api, replay: true, done: () => done++));
    await tester.pumpAndSettle();
    await answerAll(tester, submit: false);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    api.actor = 'account-b';
    wait.complete();
    await tester.pumpAndSettle();
    expect(done, 0);
    expect(api.writes.single.owner, 'account-a');
    expect(await OnboardingAnswerStore.pendingFor('account-b'), isNull);
    expect(await OnboardingAnswerStore.pendingFor('account-a'), isNotNull);
  });
  testWidgets('failed progress write shows retry and does not finish', (
    tester,
  ) async {
    var fail = true, done = 0;
    await tester.pumpWidget(
      setup(
        done: () => done++,
        writer: () async {
          if (fail) throw StateError('disk');
        },
      ),
    );
    await answerAll(tester);
    expect(done, 0);
    expect(find.textContaining('Could not save your setup'), findsOneWidget);
    fail = false;
    await next(tester);
    expect(done, 1);
  });
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.6, 2.2, 3.4]) {
      testWidgets('setup questions fit 320pt ${brightness.name} at ${scale}x', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(setup(brightness: brightness, scale: scale));
        await tester.pumpAndSettle();
        for (final key in [
          'setup-use-business',
          'setup-inventory-equipment',
          'setup-goal-track_stock',
          'setup-collaboration-others',
        ]) {
          await choose(tester, key);
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const Key('onboarding-next')).hitTestable(),
            findsOneWidget,
          );
          await next(tester);
        }
      });
    }
    if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
      testWidgets('visual setup in ${brightness.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(setup(brightness: brightness));
        await tester.pumpAndSettle();
        final keys = [
          'setup-use-business',
          'setup-inventory-equipment',
          'setup-goal-find_items',
          'setup-collaboration-others',
        ];
        for (var i = 0; i < 4; i++) {
          await choose(tester, keys[i]);
          final scrollable = find.descendant(
            of: find.byKey(ValueKey('onboarding-slide-$i')),
            matching: find.byType(Scrollable),
          );
          tester.state<ScrollableState>(scrollable).position.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(
                  find.byKey(const Key('setup-qa')),
                )
                .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '/private/tmp/findez-setup-${brightness.name}-$i.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
          if (i < 3) await next(tester);
        }
      });
    }
  }
  test('answer queues serialize edits and preserve newer drafts', () async {
    final wait = Completer<void>();
    final api = SetupApi(pending: wait);
    await OnboardingAnswerStore.saveDraft(answers, accountId: 'account-a');
    final first = OnboardingAnswerStore.sync(api);
    await Future<void>.delayed(Duration.zero);
    const edited = OnboardingAnswers(
      useCase: 'laboratory',
      inventoryTypes: ['parts'],
      primaryGoal: 'track_stock',
      collaboration: 'solo',
    );
    await OnboardingAnswerStore.saveDraft(edited, accountId: 'account-a');
    final second = OnboardingAnswerStore.sync(api);
    wait.complete();
    await Future.wait([first, second]);
    expect(api.record?['use_case'], 'laboratory');
    expect(await OnboardingAnswerStore.pendingFor('account-a'), isNull);
  });
}
